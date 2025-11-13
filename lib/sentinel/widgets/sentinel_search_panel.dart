import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:sp_util/sp_util.dart';

import '../../services/auth_service.dart';
import '../../services/region_draw_service.dart';
import '../../services/region_upload_service.dart';
import '../models/sentinel_search_models.dart';
import '../models/upload_area_model.dart';
import 'results_tab.dart';
import 'search_tab.dart';

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
  final String? polygonGeoJson;

  const MobileSentinelSearchPanel({
    super.key,
    required this.onSearch,
    required this.isLoading,
    required this.searchResults,
    required this.onToggleImage,
    required this.visibleImages,
    required this.onClosePanel,
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

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 90));
  DateTime _endDate = DateTime.now();

  Set<SatelliteDataType> _selectedDataTypes = {SatelliteDataType.sentinel2L2A};

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
    _startDateController.text =
    '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}';
    _endDateController.text =
    '${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}';
  }

  Future<void> _usePolygonAsGeoJson() async {
    if (widget.polygonGeoJson != null) {
      setState(() {
        _geoJsonController.text = widget.polygonGeoJson!;
        _isFileLoaded = false;
        _loadedFileName = null;
        _uploadedArea = null;
      });

      widget.onUsePolygonAsGeoJson();

      if (widget.isPolygonMode) {
        widget.onTogglePolygonMode();
      }

      try {
        final regionId = await RegionService.saveRegion(
          geoJsonString: widget.polygonGeoJson!,
          regionName: '绘制区域_${DateTime.now().year}${DateTime.now().month}${DateTime.now().day}',
        );
        await SpUtil.putString('region_Id', regionId);
        print('区域保存成功，ID: $regionId');
        _showSuccessDialog('已将绘制区域设为搜索范围');
      } catch (e) {
        print('保存区域失败: $e');
        _showSuccessDialog('已将绘制区域设为搜索范围\n（云端同步失败：${e.toString()}）');
      }
    }
  }

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

      // 提取 id
      final regionId = response.id;
      print('上传成功，ID: $regionId');

      await SpUtil.putString('region_id', regionId);
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

    String? geoJson;
    if (_geoJsonController.text.trim().isNotEmpty) {
      try {
        final parsedJson = json.decode(_geoJsonController.text.trim()) as Map<String, dynamic>;

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
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              SearchTab(
                startDateController: _startDateController,
                endDateController: _endDateController,
                cloudCoverController: _cloudCoverController,
                geoJsonController: _geoJsonController,
                selectedDataTypes: _selectedDataTypes,
                startDate: _startDate,
                endDate: _endDate,
                loadedFileName: _loadedFileName,
                isFileLoaded: _isFileLoaded,
                isUploading: _isUploading,
                isPolygonMode: widget.isPolygonMode,
                polygonPointsCount: widget.polygonPointsCount,
                hasValidPolygon: widget.hasValidPolygon,
                onDataTypeChanged: (dataType) {
                  setState(() {
                    if (_selectedDataTypes.contains(dataType)) {
                      if (_selectedDataTypes.length > 1) {
                        _selectedDataTypes.remove(dataType);
                      }
                    } else {
                      _selectedDataTypes.clear();
                      _selectedDataTypes.add(dataType);
                    }
                  });
                },
                onSelectDate: _selectDate,
                onImportZipFile: _importZipFile,
                onTogglePolygonMode: widget.onTogglePolygonMode,
                onClearPolygonPoints: widget.onClearPolygonPoints,
                onUsePolygonAsGeoJson: _usePolygonAsGeoJson,
                onSearch: _onSearch,
              ),
              ResultsTab(
                isLoading: widget.isLoading,
                searchResults: widget.searchResults,
                visibleImages: widget.visibleImages,
                onToggleImage: widget.onToggleImage,
                onClosePanel: widget.onClosePanel,
                onSwitchToSearch: () => _tabController.animateTo(0),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
