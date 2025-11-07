import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/area_upload_service.dart';
import '../../services/auth_service.dart';
import '../models/sentinel_search_models.dart';
import '../models/upload_area_model.dart';

/// 移动端卫星影像搜索面板
class MobileSentinelSearchPanel extends StatefulWidget {
  final Function(SentinelSearchParams) onSearch;
  final bool isLoading;
  final List<SentinelSearchResult> searchResults;
  final Function(SentinelSearchResult, int) onToggleImage;
  final Set<String> visibleImages;
  final VoidCallback onClosePanel;
  final String? token;

  // 地图打点相关回调
  final VoidCallback onTogglePolygonMode;
  final VoidCallback onClearPolygonPoints;
  final VoidCallback onUsePolygonAsGeoJson;
  final bool isPolygonMode;
  final int polygonPointsCount;
  final bool hasValidPolygon;
  final String? polygonGeoJson; // 从多边形点生成的GeoJSON

  const MobileSentinelSearchPanel({
    super.key,
    required this.onSearch,
    required this.isLoading,
    required this.searchResults,
    required this.onToggleImage,
    required this.visibleImages,
    required this.onClosePanel,
    // 地图打点相关参数
    required this.onTogglePolygonMode,
    required this.onClearPolygonPoints,
    required this.onUsePolygonAsGeoJson,
    required this.isPolygonMode,
    required this.polygonPointsCount,
    required this.hasValidPolygon,
    this.polygonGeoJson,
    this.token,
  });

  @override
  State<MobileSentinelSearchPanel> createState() => _MobileSentinelSearchPanelState();
}

class _MobileSentinelSearchPanelState extends State<MobileSentinelSearchPanel>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  late final AreaUploadService _uploadService;

  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _cloudCoverController = TextEditingController(text: '50');
  final _geoJsonController = TextEditingController();

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 90)); // 90天前
  DateTime _endDate = DateTime.now(); // 今天

  // 数据类型选择
  Set<SatelliteDataType> _selectedDataTypes = {SatelliteDataType.sentinel2L2A};

  // 文件导入相关状态
  String? _loadedFileName;
  bool _isFileLoaded = false;
  bool _isUploading = false;
  UploadAreaResponse? _uploadedArea;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final String? token = widget.token ?? AuthService.getToken();
    _uploadService = AreaUploadService(token: token);
    _updateDateControllers();
  }

  @override
  void didUpdateWidget(MobileSentinelSearchPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.token != oldWidget.token) {
      final token = widget.token ?? AuthService.getToken();
      _uploadService = AreaUploadService(token: token);
    }
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

  /// 使用多边形作为GeoJSON
  void _usePolygonAsGeoJson() {
    if (widget.polygonGeoJson != null) {
      setState(() {
        _geoJsonController.text = widget.polygonGeoJson!;
        _isFileLoaded = false;
        _loadedFileName = null;
        _uploadedArea = null;
      });

      widget.onUsePolygonAsGeoJson();

      // 完成绘制后，退出绘制模式
      if (widget.isPolygonMode) {
        widget.onTogglePolygonMode();
      }
      _showSuccessDialog('已将绘制区域设为搜索范围');
    }
  }

  /// 导入压缩包文件
  Future<void> _importZipFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        withData: false,
        withReadStream: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        await _uploadFile(file);
      }
    } catch (e) {
      _showErrorDialog('文件选择失败: ${e.toString()}');
    }
  }

  /// 上传文件到服务器
  Future<void> _uploadFile(File file) async {
    setState(() {
      _isUploading = true;
    });

    try {

      final response = await _uploadService.uploadAreaFile(file: file);

      setState(() {
        _uploadedArea = response;
        _geoJsonController.text = response.geojsonString;
        _isFileLoaded = true;
        _loadedFileName = response.filename;
      });

      _showSuccessDialog('文件上传成功!\n文件: ${response.filename}');
    } on UploadServiceException catch (e) {
      _showErrorDialog(e.message);
    } catch (e) {
      _showErrorDialog('上传失败: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
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

        // 转换为FeatureCollection格式
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
          throw const FormatException('不支持的GeoJSON格式,请使用FeatureCollection、Feature或Geometry格式');
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
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('错误'),
          ],
        ),
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

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('成功'),
          ],
        ),
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
                      // 目前API只支持单选,清除其他选择
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
            '* 目前支持单选,未来将支持多选',
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
                prefixIcon: const Icon(Icons.cloud_outlined, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Colors.blue, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 搜索区域绘制
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
              const Expanded(
                child: Text(
                  '搜索范围',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              // 状态指示器
              _buildStatusIndicator(),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '支持导入shp文件的压缩包 or 点击地图绘制',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),

          // 操作按钮区域
          _buildActionButtons(),

          // 地图打点状态显示
          if (widget.isPolygonMode || widget.polygonPointsCount > 0)
            _buildPolygonStatus(),

          // 显示当前加载的文件名
          if (_isFileLoaded && _loadedFileName != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.attachment, size: 12, color: Colors.blue.shade700),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '当前区域: $_loadedFileName',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 上传进度提示
          if (_isUploading) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '正在上传文件...',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建状态指示器
  Widget _buildStatusIndicator() {
    if (_isFileLoaded && _loadedFileName != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 10, color: Colors.green.shade700),
            const SizedBox(width: 3),
            Text(
              '已导入文件',
              style: TextStyle(
                fontSize: 9,
                color: Colors.green.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    } else if (widget.hasValidPolygon) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_location, size: 10, color: Colors.blue.shade700),
            const SizedBox(width: 3),
            Text(
              '已绘制区域',
              style: TextStyle(
                fontSize: 9,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    } else if (widget.isPolygonMode) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade700),
              ),
            ),
            const SizedBox(width: 3),
            Text(
              '绘制中',
              style: TextStyle(
                fontSize: 9,
                color: Colors.orange.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  /// 构建操作按钮区域
  Widget _buildActionButtons() {
    return Column(
      children: [
        // 第一行：导入文件按钮
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: _isUploading ? Icons.hourglass_empty : Icons.file_upload,
                label: _isUploading ? '上传中...' : '导入压缩包',
                color: Colors.green,
                onTap: _isUploading ? null : _importZipFile,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // 第二行：地图绘制操作
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: widget.isPolygonMode ? Icons.stop : Icons.edit_location,
                label: widget.isPolygonMode ? '停止绘制' : '地图绘制',
                color: widget.isPolygonMode ? Colors.red : Colors.purple,
                onTap: () {
                  // 如果当前不是绘制模式，开启绘制模式前先清空已有点
                  if (!widget.isPolygonMode && widget.polygonPointsCount > 0) {
                    widget.onClearPolygonPoints();
                  }
                  widget.onTogglePolygonMode();
                },
              ),
            ),
            if (widget.polygonPointsCount > 0) ...[
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.refresh,
                  label: '清除点',
                  color: Colors.orange,
                  onTap: widget.onClearPolygonPoints,
                ),
              ),
            ],
            if (widget.hasValidPolygon) ...[
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.check,
                  label: '使用区域',
                  color: Colors.teal,
                  onTap: _usePolygonAsGeoJson,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// 构建多边形状态显示
  Widget _buildPolygonStatus() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: widget.isPolygonMode ? Colors.orange.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: widget.isPolygonMode ? Colors.orange.shade200 : Colors.blue.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                widget.isPolygonMode ? Icons.touch_app : Icons.check_circle,
                size: 14,
                color: widget.isPolygonMode ? Colors.orange.shade700 : Colors.blue.shade700,
              ),
              const SizedBox(width: 6),
              Text(
                widget.isPolygonMode ? '地图绘制模式' : '已绘制区域',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.isPolygonMode ? Colors.orange.shade700 : Colors.blue.shade700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: widget.isPolygonMode ? Colors.orange.shade100 : Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${widget.polygonPointsCount} 个点',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: widget.isPolygonMode ? Colors.orange.shade800 : Colors.blue.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.isPolygonMode
                ? '点击地图添加点,3个点以上可形成搜索区域'
                : widget.hasValidPolygon
                ? '点击"使用区域"将绘制的多边形设为搜索范围'
                : '需要至少3个点才能形成有效搜索区域',
            style: TextStyle(
              fontSize: 10,
              color: widget.isPolygonMode ? Colors.orange.shade600 : Colors.blue.shade600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    final isDisabled = onTap == null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isDisabled ? Colors.grey.shade200 : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDisabled ? Colors.grey.shade300 : color.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isDisabled ? Colors.grey : color, size: 16),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isDisabled ? Colors.grey : color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField(String label, TextEditingController controller, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                controller.text,
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchButton() {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: widget.isLoading ? null : _onSearch,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: widget.isLoading
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 18),
            SizedBox(width: 6),
            Text('开始搜索', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
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
