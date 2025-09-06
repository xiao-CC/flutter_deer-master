import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/sentinel_search_models.dart';

/// 移动端卫星影像搜索面板
class MobileSentinelSearchPanel extends StatefulWidget {
  final Function(SentinelSearchParams) onSearch;
  final bool isLoading;
  final List<SentinelSearchResult> searchResults;
  final Function(SentinelSearchResult, int) onToggleImage;
  final Set<String> visibleImages;
  final VoidCallback onClosePanel;

  const MobileSentinelSearchPanel({
    super.key,
    required this.onSearch,
    required this.isLoading,
    required this.searchResults,
    required this.onToggleImage,
    required this.visibleImages,
    required this.onClosePanel,
  });

  @override
  State<MobileSentinelSearchPanel> createState() => _MobileSentinelSearchPanelState();
}

class _MobileSentinelSearchPanelState extends State<MobileSentinelSearchPanel>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _cloudCoverController = TextEditingController(text: '50');
  final _geoJsonController = TextEditingController();

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 90)); // 90天前
  DateTime _endDate = DateTime.now(); // 今天

  // 数据类型选择
  Set<SatelliteDataType> _selectedDataTypes = {SatelliteDataType.sentinel2L2A};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _updateDateControllers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _cloudCoverController.dispose();
    _geoJsonController.dispose();
    super.dispose();
  }

  void _updateDateControllers() {
    _startDateController.text = '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}';
    _endDateController.text = '${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}';
  }

  void _fillSampleGeoJSON() {
    const sampleGeoJSON = {
      "type": "Feature",
      "properties": {},
      "geometry": {
        "coordinates": [
          [
            [121.61368646673998, 44.101992702134],
            [121.60504914997375, 43.99855484106067],
            [121.79737384655414, 43.99202124189398],
            [121.7946124972928, 44.10624118365462],
            [121.61368646673998, 44.101992702134]
          ]
        ],
        "type": "Polygon"
      }
    };

    _geoJsonController.text = const JsonEncoder.withIndent('  ').convert(sampleGeoJSON);
  }

  void _onSearch() {
    if (_selectedDataTypes.isEmpty) {
      _showErrorDialog('请至少选择一种数据类型');
      return;
    }

    final cloudCover = double.tryParse(_cloudCoverController.text) ?? 50.0;

    if (cloudCover < 0 || cloudCover > 100) {
      _showErrorDialog('云量值必须在0-100之间');
      return;
    }

    // 验证GeoJSON格式
    String? geoJson;
    if (_geoJsonController.text.trim().isNotEmpty) {
      try {
        final parsedJson = json.decode(_geoJsonController.text.trim()) as Map<String, dynamic>;

        // 确保转换为FeatureCollection格式
        Map<String, dynamic> geojsonData;
        if (parsedJson['type'] == 'FeatureCollection') {
          geojsonData = parsedJson;
        } else if (parsedJson['type'] == 'Feature') {
          geojsonData = {
            "type": "FeatureCollection",
            "features": [parsedJson]
          };
        } else if (parsedJson['type'] != null && parsedJson['coordinates'] != null) {
          geojsonData = {
            "type": "FeatureCollection",
            "features": [
              {
                "type": "Feature",
                "properties": {},
                "geometry": parsedJson
              }
            ]
          };
        } else {
          throw const FormatException('不支持的GeoJSON格式，请使用FeatureCollection、Feature或Geometry格式');
        }

        geoJson = json.encode(geojsonData);
      } catch (e) {
        _showErrorDialog('GeoJSON格式错误: ${e.toString()}');
        return;
      }
    }

    final params = SentinelSearchParams(
      startDate: _startDate,
      endDate: _endDate,
      maxCloudCover: cloudCover,
      geoJson: geoJson,
      dataTypes: _selectedDataTypes,
    );

    widget.onSearch(params);

    // 搜索后自动切换到结果标签页
    if (widget.searchResults.isNotEmpty || widget.isLoading) {
      _tabController.animateTo(1);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('输入错误'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(bool isStartDate) async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (selectedDate != null) {
      setState(() {
        if (isStartDate) {
          _startDate = selectedDate;
          if (_startDate.isAfter(_endDate)) {
            _endDate = _startDate.add(const Duration(days: 7));
          }
        } else {
          _endDate = selectedDate;
          if (_endDate.isBefore(_startDate)) {
            _startDate = _endDate.subtract(const Duration(days: 7));
          }
        }
        _updateDateControllers();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 紧凑的Tab栏
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade200, width: 1),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          height: 42,
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(5),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey.shade600,
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            padding: const EdgeInsets.all(2),
            tabs: [
              const Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search, size: 16),
                    SizedBox(width: 6),
                    Text('搜索'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.list, size: 16),
                    const SizedBox(width: 6),
                    Text('结果${widget.searchResults.isNotEmpty ? '(${widget.searchResults.length})' : ''}'),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Tab内容
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildSearchTab(),
              _buildResultsTab(),
            ],
          ),
        ),
      ],
    );
  }

  /// 搜索标签页
  Widget _buildSearchTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDataTypeSection(),
          const SizedBox(height: 12),
          _buildDateSection(),
          const SizedBox(height: 12),
          _buildCloudCoverSection(),
          const SizedBox(height: 12),
          _buildGeoJsonSection(),
          const SizedBox(height: 16),
          _buildSearchButton(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// 数据类型选择区域
  Widget _buildDataTypeSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.satellite_alt, color: Colors.blue, size: 16),
              SizedBox(width: 6),
              Text(
                '数据类型',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SatelliteDataType.values.map((dataType) {
              final isSelected = _selectedDataTypes.contains(dataType);
              return InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      if (_selectedDataTypes.length > 1) {
                        _selectedDataTypes.remove(dataType);
                      }
                    } else {
                      // 目前API只支持单选，清除其他选择
                      _selectedDataTypes.clear();
                      _selectedDataTypes.add(dataType);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    dataType.displayName,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          Text(
            '* 目前支持单选，未来将支持多选',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  /// 紧凑的日期选择区域
  Widget _buildDateSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.blue, size: 16),
              SizedBox(width: 6),
              Text(
                '时间范围',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildDateField('开始', _startDateController, () => _selectDate(true)),
              ),
              const SizedBox(width: 8),
              const Text('至', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDateField('结束', _endDateController, () => _selectDate(false)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 紧凑的云量设置区域
  Widget _buildCloudCoverSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cloud, color: Colors.blue, size: 16),
              SizedBox(width: 6),
              Text(
                '云量过滤',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: TextFormField(
              controller: _cloudCoverController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                labelText: '最大云量(%)',
                hintText: '0-100',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
                prefixIcon: const Icon(Icons.percent, size: 16),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
                labelStyle: const TextStyle(fontSize: 12),
                hintStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 紧凑的GeoJSON区域
  Widget _buildGeoJsonSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.blue, size: 16),
              const SizedBox(width: 6),
              const Text(
                'GeoJSON',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: _fillSampleGeoJSON,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_fix_high, size: 12, color: Colors.green.shade700),
                      const SizedBox(width: 3),
                      Text(
                        '示例',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: TextFormField(
              controller: _geoJsonController,
              maxLines: null,
              expands: true,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                height: 1.2,
              ),
              decoration: InputDecoration(
                hintText: '输入GeoJSON数据...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
                contentPadding: const EdgeInsets.all(8),
                hintStyle: const TextStyle(fontSize: 11),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(String label, TextEditingController controller, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 36,
          child: TextFormField(
            controller: controller,
            readOnly: true,
            onTap: onTap,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Colors.blue),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              suffixIcon: const Icon(Icons.calendar_today, size: 14),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchButton() {
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: ElevatedButton(
        onPressed: widget.isLoading ? null : _onSearch,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: widget.isLoading ? 0 : 1,
        ),
        child: widget.isLoading
            ? const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 8),
            Text('搜索中...', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        )
            : const Text('搜索影像', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }

  /// 结果标签页
  Widget _buildResultsTab() {
    if (widget.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('正在搜索影像数据...', style: TextStyle(fontSize: 14)),
          ],
        ),
      );
    }

    if (widget.searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              '暂无搜索结果',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '请设置搜索条件并点击搜索',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _tabController.animateTo(0),
              icon: const Icon(Icons.search, size: 16),
              label: const Text('去搜索', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      physics: const ClampingScrollPhysics(),
      itemCount: widget.searchResults.length,
      itemBuilder: (context, index) {
        if (index < 0 || index >= widget.searchResults.length) {
          return const SizedBox.shrink();
        }

        final result = widget.searchResults[index];
        final isVisible = widget.visibleImages.contains(result.imageId);

        return _buildResultItem(result, index, isVisible);
      },
    );
  }

  Widget _buildResultItem(SentinelSearchResult result, int index, bool isVisible) {
    final cloudLevel = result.cloudCoverLevel;
    Color cloudColor;
    Color cloudBgColor;

    switch (cloudLevel) {
      case CloudCoverLevel.high:
        cloudColor = Colors.red;
        cloudBgColor = Colors.red.withOpacity(0.1);
        break;
      case CloudCoverLevel.medium:
        cloudColor = Colors.orange;
        cloudBgColor = Colors.orange.withOpacity(0.1);
        break;
      case CloudCoverLevel.low:
        cloudColor = Colors.green;
        cloudBgColor = Colors.green.withOpacity(0.1);
        break;
      case CloudCoverLevel.unknown:
        cloudColor = Colors.grey;
        cloudBgColor = Colors.grey.withOpacity(0.1);
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isVisible ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isVisible ? Colors.blue : Colors.grey.shade200,
          width: isVisible ? 1.5 : 1,
        ),
        boxShadow: isVisible
            ? [BoxShadow(color: Colors.blue.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]
            : [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 2, offset: const Offset(0, 1))],
      ),
      child: InkWell(
        onTap: () {
          widget.onToggleImage(result, index);
          if (!isVisible) {
            Future.delayed(const Duration(milliseconds: 500), () {
              widget.onClosePanel();
            });
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.imageId,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isVisible ? Colors.blue.shade700 : Colors.blue,
                            fontSize: 10,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            result.satelliteTypeName,
                            style: TextStyle(
                              color: Colors.purple.shade700,
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isVisible ? Colors.blue.withOpacity(0.1) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isVisible ? Icons.visibility : Icons.visibility_off,
                      color: isVisible ? Colors.blue : Colors.grey,
                      size: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade600),
                      const SizedBox(width: 3),
                      Text(
                        result.captureDate,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (result.cloudCover != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: cloudBgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud, size: 10, color: cloudColor),
                          const SizedBox(width: 2),
                          Text(
                            '${result.cloudCover!.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: cloudColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border(
                    left: BorderSide(color: Colors.blue, width: 2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 10, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '平台: ${result.platform} | 星座: ${result.constellation}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 9,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}