import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../services/sentinel_search_service.dart';
import '../config/map_config.dart';
import '../models/sentinel_search_models.dart';
import '../widgets/map_controls.dart';
import '../widgets/sentinel_search_panel.dart';

class MobileEnhancedShowPage extends StatelessWidget {
  const MobileEnhancedShowPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: MobileEnhancedShowPageContent(),
    );
  }
}

class MobileEnhancedShowPageContent extends StatefulWidget {
  const MobileEnhancedShowPageContent({super.key});

  @override
  State<MobileEnhancedShowPageContent> createState() => _MobileEnhancedShowPageContentState();
}

class _MobileEnhancedShowPageContentState extends State<MobileEnhancedShowPageContent>
    with TickerProviderStateMixin {
  // 地图控制器
  late final MapController _mapController;

  // 面板动画控制器（保留用于FAB按钮动画）
  late final AnimationController _panelAnimationController;
  late final Animation<double> _panelAnimation;

  // 搜索面板状态
  bool _isPanelOpen = false;
  double _currentPanelHeight = 80; // 面板初始高度，显示拖拽指示器和标题
  final double _minPanelHeight = 80; // 最小高度
  double _maxPanelHeight = 400; // 最大高度，将在initState中重新计算

  // 拖拽相关状态
  double _dragStartY = 0;
  bool _isDragging = false;

  // 搜索相关状态
  bool _isLoading = false;
  List<SentinelSearchResult> _searchResults = [];
  String? _errorMessage;

  // 地图图层管理
  final Set<String> _visibleImages = <String>{};
  final Map<String, List<Widget>> _imageLayers = <String, List<Widget>>{};

  // 搜索边界
  Widget? _searchBoundaryLayer;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _panelAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _panelAnimation = CurvedAnimation(
      parent: _panelAnimationController,
      curve: Curves.easeInOut,
    );

    // 在下一帧计算屏幕尺寸
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculatePanelDimensions();
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    _panelAnimationController.dispose();
    super.dispose();
  }

  /// 计算面板尺寸
  void _calculatePanelDimensions() {
    final screenHeight = MediaQuery.of(context).size.height;
    // 修复：不需要再计算底部导航栏高度，因为外层已经处理了
    final topPadding = MediaQuery.of(context).padding.top;
    final appBarHeight = AppBar().preferredSize.height;
    final availableHeight = screenHeight - topPadding - appBarHeight;

    setState(() {
      // 面板最大高度为可用高度的 70%
      _maxPanelHeight = availableHeight * 0.7;
      if (_currentPanelHeight > _maxPanelHeight) {
        _currentPanelHeight = _maxPanelHeight;
      }
    });
  }

  /// 切换搜索面板
  void _togglePanel() {
    if (_isPanelOpen) {
      _animateToHeight(_minPanelHeight);
    } else {
      _animateToHeight(_maxPanelHeight);
    }
  }

  /// 关闭搜索面板
  void _closePanel() {
    if (_isPanelOpen) {
      _animateToHeight(_minPanelHeight);
    }
  }

  /// 动画到指定高度
  void _animateToHeight(double targetHeight) {
    final currentHeight = _currentPanelHeight;
    final duration = const Duration(milliseconds: 300);

    final controller = AnimationController(duration: duration, vsync: this);
    final animation = Tween<double>(
      begin: currentHeight,
      end: targetHeight,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutCubic));

    animation.addListener(() {
      setState(() {
        _currentPanelHeight = animation.value;
        _isPanelOpen = _currentPanelHeight > _minPanelHeight + 50;
      });

      // 更新FAB动画状态
      if (_isPanelOpen) {
        _panelAnimationController.forward();
      } else {
        _panelAnimationController.reverse();
      }
    });

    controller.forward().then((_) {
      controller.dispose();
      // 在动画结束时添加触觉反馈
      HapticFeedback.lightImpact();
    });
  }

  /// 执行影像搜索
  Future<void> _performSearch(SentinelSearchParams params) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _searchResults = [];
      _visibleImages.clear();
      _imageLayers.clear();
      _searchBoundaryLayer = null;
    });

    try {
      final response = await SentinelSearchService.searchImages(params);

      if (response.isSuccessful) {
        setState(() {
          _searchResults = response.dataInformation;
        });

        // 如果有GeoJSON搜索区域，在地图上显示
        if (params.geoJson != null && params.geoJson!.isNotEmpty) {
          _displaySearchBoundary(params.geoJson!);
        }

        _showSuccessSnackBar('搜索成功，找到 ${response.dataInformation.length} 个影像');
      } else {
        throw Exception('搜索失败');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      _showErrorSnackBar(_errorMessage!);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 显示搜索边界
  void _displaySearchBoundary(String geoJsonString) {
    try {
      final dynamic geoJsonData = json.decode(geoJsonString);

      // 验证GeoJSON数据结构
      if (geoJsonData == null || geoJsonData is! Map<String, dynamic>) {
        return;
      }

      final geoJsonMap = geoJsonData as Map<String, dynamic>;

      final boundaryLayer = GeoJsonLayer(
        geoJsonData: geoJsonMap,
        style: const GeoJsonStyle(
          color: Colors.red,
          strokeWidth: 3,
          fillOpacity: 0.1,
        ),
      );

      setState(() {
        _searchBoundaryLayer = boundaryLayer;
      });

      // 调整地图视图到搜索边界
      final features = geoJsonMap['features'];
      if (features != null && features is List && features.isNotEmpty) {
        _fitMapToBounds(geoJsonMap);
      } else if (geoJsonMap['type'] == 'Feature' && geoJsonMap['geometry'] != null) {
        // 处理单个Feature的情况
        _fitMapToBounds({
          'features': [geoJsonMap]
        });
      }
    } catch (e) {
      // 静默处理错误，避免影响用户体验
      debugPrint('GeoJSON解析错误: $e');
    }
  }

  void _fitMapToBounds(Map<String, dynamic> geoJsonData) {
    try {
      double minLat = double.infinity;
      double maxLat = double.negativeInfinity;
      double minLng = double.infinity;
      double maxLng = double.negativeInfinity;

      final features = geoJsonData['features'];
      if (features == null || features is! List) {
        return;
      }

      for (final feature in features) {
        if (feature is! Map<String, dynamic>) continue;

        final geometry = feature['geometry'];
        if (geometry is! Map<String, dynamic>) continue;

        if (geometry['type'] == 'Polygon') {
          final coordinates = geometry['coordinates'];
          if (coordinates is! List || coordinates.isEmpty) continue;

          final firstRing = coordinates[0];
          if (firstRing is! List) continue;

          for (final coord in firstRing) {
            if (coord is! List || coord.length < 2) continue;

            final lngValue = coord[0];
            final latValue = coord[1];

            if (lngValue is! num || latValue is! num) continue;

            final lng = lngValue.toDouble();
            final lat = latValue.toDouble();

            minLat = minLat > lat ? lat : minLat;
            maxLat = maxLat < lat ? lat : maxLat;
            minLng = minLng > lng ? lng : minLng;
            maxLng = maxLng < lng ? lng : maxLng;
          }
        }
      }

      if (minLat != double.infinity) {
        final bounds = LatLngBounds(
          LatLng(minLat, minLng),
          LatLng(maxLat, maxLng),
        );

        _mapController.fitBounds(bounds, options: const FitBoundsOptions(
          padding: EdgeInsets.all(50),
        ));
      }
    } catch (e) {
      // 静默处理错误，避免影响用户体验
      debugPrint('边界计算错误: $e');
    }
  }

  /// 切换影像显示状态
  Future<void> _toggleImageVisibility(SentinelSearchResult result, int index) async {
    final imageId = result.imageId;

    if (_visibleImages.contains(imageId)) {
      // 隐藏影像
      setState(() {
        _visibleImages.remove(imageId);
        _imageLayers.remove(imageId);
      });
    } else {
      // 显示影像
      _showLoadingSnackBar('正在加载影像...');

      try {
        final layers = await _createImageLayers(result, index);

        setState(() {
          _visibleImages.add(imageId);
          _imageLayers[imageId] = layers;
        });

        _hideCurrentSnackBar();
        _showSuccessSnackBar('影像加载成功');
      } catch (e) {
        _hideCurrentSnackBar();
        _showErrorSnackBar('加载影像失败: ${e.toString()}');
      }
    }
  }

  /// 创建影像图层
  Future<List<Widget>> _createImageLayers(SentinelSearchResult result, int index) async {
    final imageId = result.imageId;
    final dataType = result.dataType;

    try {
      final layers = <Widget>[];

      // 获取瓦片信息
      final tileJsonData = await SentinelSearchService.getTileJsonInfo(imageId, dataType);

      if (tileJsonData['tiles'] == null ||
          tileJsonData['tiles'] is! List ||
          (tileJsonData['tiles'] as List).isEmpty) {
        throw Exception('瓦片URL列表为空');
      }

      final tileUrls = tileJsonData['tiles'] as List;
      final firstTile = tileUrls[0];
      if (firstTile is! String) {
        throw Exception('无效的瓦片URL格式');
      }

      final tileUrl = firstTile;

      // 创建瓦片图层
      final tileLayer = Opacity(
        opacity: dataType == SatelliteDataType.copDemGlo30 ? 0.8 : 1.0,
        child: TileLayer(
          urlTemplate: tileUrl,
          minZoom: double.tryParse(tileJsonData['minzoom']!.toString()) ?? 1.0,
          maxZoom: double.tryParse(tileJsonData['maxzoom']!.toString()) ?? 18.0,
          backgroundColor: Colors.transparent,
          additionalOptions: const {
            'crossOrigin': 'anonymous',
          },
          errorTileCallback: (tile, error, stackTrace) {
            // 静默处理瓦片加载错误
          },
        ),
      );

      layers.add(tileLayer);

      // 获取影像边界并创建边界图层
      try {
        final footprintData = await SentinelSearchService.getImageFootprint(imageId, dataType);

        // 根据数据类型设置边界颜色
        final borderColor = _getDataTypeColor(dataType);

        final boundaryLayer = GeoJsonLayer(
          geoJsonData: footprintData,
          style: GeoJsonStyle(
            color: borderColor,
            strokeWidth: 3,
            fillOpacity: 0.1,
          ),
          onTap: (feature, latLng) {
            _showImageInfoDialog(result);
          },
        );
        layers.add(boundaryLayer);
      } catch (e) {
        // 如果无法获取边界信息，只显示瓦片图层
        debugPrint('无法获取边界信息: $e');
      }

      return layers;
    } catch (e) {
      // 如果是瓦片服务问题，尝试创建一个仅显示边界的图层
      if (e.toString().contains('瓦片') || e.toString().contains('URL')) {
        try {
          final footprintData = await SentinelSearchService.getImageFootprint(imageId, dataType);

          if (footprintData is Map<String, dynamic>) {
            final borderColor = _getDataTypeColor(dataType);

            final boundaryLayer = GeoJsonLayer(
              geoJsonData: footprintData,
              style: GeoJsonStyle(
                color: borderColor,
                strokeWidth: 4,
                fillOpacity: 0.2,
              ),
              onTap: (feature, latLng) {
                _showImageInfoDialog(result);
                _showErrorSnackBar('该影像暂时无法显示，仅显示覆盖范围');
              },
            );

            return [boundaryLayer];
          }
        } catch (fallbackError) {
          // 备用方案也失败时重新抛出原始错误
        }
      }

      rethrow;
    }
  }

  /// 根据数据类型获取颜色
  Color _getDataTypeColor(SatelliteDataType dataType) {
    switch (dataType) {
      case SatelliteDataType.sentinel2L2A:
        return const Color(0xFF05a6f0); // 蓝色
      case SatelliteDataType.sentinel1RTC:
        return const Color(0xFFff6b35); // 橙色
      case SatelliteDataType.sentinel1GRD:
        return const Color(0xFFf7931e); // 橙黄色
      case SatelliteDataType.landsatC2L2:
        return const Color(0xFF4caf50); // 绿色
      case SatelliteDataType.copDemGlo30:
        return const Color(0xFF9c27b0); // 紫色
    }
  }

  /// 显示影像信息对话框
  void _showImageInfoDialog(SentinelSearchResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.satellite_alt, color: _getDataTypeColor(result.dataType)),
            const SizedBox(width: 8),
            const Text('卫星影像信息'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('影像ID', result.imageId, isMonospace: true),
              const SizedBox(height: 12),
              _buildInfoRow('数据类型', result.satelliteTypeName),
              const SizedBox(height: 12),
              _buildInfoRow('拍摄日期', result.captureDate),
              const SizedBox(height: 12),
              if (result.cloudCover != null) ...[
                _buildInfoRow('云量', '${result.cloudCover!.toStringAsFixed(1)}%'),
                const SizedBox(height: 12),
              ],
              _buildInfoRow('平台', result.platform),
              const SizedBox(height: 12),
              _buildInfoRow('星座', result.constellation),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isMonospace = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontFamily: isMonospace ? 'monospace' : null,
              fontSize: isMonospace ? 12 : 14,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  /// SnackBar显示方法
  void _showSuccessSnackBar(String message) {
    final bottomMargin = _currentPanelHeight + MediaQuery.of(context).padding.bottom + 20;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: bottomMargin,
          left: 16,
          right: 16,
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    final bottomMargin = _currentPanelHeight + MediaQuery.of(context).padding.bottom + 20;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: bottomMargin,
          left: 16,
          right: 16,
        ),
      ),
    );
  }

  void _showLoadingSnackBar(String message) {
    final bottomMargin = _currentPanelHeight + MediaQuery.of(context).padding.bottom + 20;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 30),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: bottomMargin,
          left: 16,
          right: 16,
        ),
      ),
    );
  }

  void _hideCurrentSnackBar() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          bottom: _currentPanelHeight,
          child: _buildMap(),
        ),

        // 悬浮搜索按钮
        Positioned(
          top: 16,
          left: 16,
          child: _buildSearchFab(),
        ),

        // 面板背景遮罩
        if (_isPanelOpen)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: _currentPanelHeight,
            child: GestureDetector(
              onTap: _closePanel,
              child: Container(
                color: Colors.black.withOpacity(0.3),
              ),
            ),
          ),

        // 底部搜索面板
        _buildSearchPanel(),
      ],
    );
  }

  /// 构建搜索悬浮按钮
  Widget _buildSearchFab() {
    return FloatingActionButton(
      onPressed: _togglePanel,
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
      elevation: 6,
      child: AnimatedBuilder(
        animation: _panelAnimation,
        builder: (context, child) {
          return Transform.rotate(
            angle: _panelAnimation.value * 0.5,
            child: Icon(_isPanelOpen ? Icons.close : Icons.search),
          );
        },
      ),
    );
  }

  /// 构建搜索面板
  Widget _buildSearchPanel() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: _currentPanelHeight,
      child: GestureDetector(
        onTap: () {}, // 防止点击穿透到地图
        onPanStart: (details) {
          _dragStartY = details.globalPosition.dy;
          _isDragging = true;
        },
        onPanUpdate: (details) {
          if (!_isDragging) return;

          final delta = _dragStartY - details.globalPosition.dy;
          final newHeight = (_currentPanelHeight + delta).clamp(_minPanelHeight, _maxPanelHeight);

          setState(() {
            _currentPanelHeight = newHeight;
            _isPanelOpen = _currentPanelHeight > _minPanelHeight + 50;
          });

          // 更新FAB动画状态
          final progress = (_currentPanelHeight - _minPanelHeight) / (_maxPanelHeight - _minPanelHeight);
          _panelAnimationController.value = progress.clamp(0.0, 1.0);

          _dragStartY = details.globalPosition.dy;
        },
        onPanEnd: (details) {
          _isDragging = false;

          // 根据拖拽速度和当前高度决定最终位置
          final velocity = details.velocity.pixelsPerSecond.dy;

          if (velocity.abs() > 500) {
            // 快速拖拽，根据方向决定
            if (velocity < 0) {
              // 向上快速拖拽，打开面板
              _animateToHeight(_maxPanelHeight);
            } else {
              // 向下快速拖拽，关闭面板
              _animateToHeight(_minPanelHeight);
            }
          } else {
            // 慢速拖拽，根据当前位置决定
            final midPoint = (_minPanelHeight + _maxPanelHeight) / 2;
            if (_currentPanelHeight > midPoint) {
              _animateToHeight(_maxPanelHeight);
            } else {
              _animateToHeight(_minPanelHeight);
            }
          }
        },
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // 拖拽指示器和标题 - 始终可见
              _buildPanelHeader(),

              // 可展开的内容区域
              if (_currentPanelHeight > _minPanelHeight + 20)
                Expanded(
                  child: Opacity(
                    opacity: ((_currentPanelHeight - _minPanelHeight) / (_maxPanelHeight - _minPanelHeight)).clamp(0.0, 1.0),
                    child: MobileSentinelSearchPanel(
                      onSearch: _performSearch,
                      isLoading: _isLoading,
                      searchResults: _searchResults,
                      onToggleImage: _toggleImageVisibility,
                      visibleImages: _visibleImages,
                      onClosePanel: () => _animateToHeight(_minPanelHeight),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建面板头部（拖拽指示器和标题）
  Widget _buildPanelHeader() {
    return Container(
      height: _minPanelHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // 拖拽指示器
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 标题行
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.satellite_alt, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  '多源卫星影像搜索',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_searchResults.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_searchResults.length} 个结果',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                // 上下箭头指示器
                Icon(
                  _currentPanelHeight > _minPanelHeight + 50
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_up,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建地图组件
  Widget _buildMap() {
    final layers = <Widget>[];

    // 添加吉林一号底图
    layers.add(_buildJl1TileLayer());

    // 添加可见的影像图层
    for (final imageLayers in _imageLayers.values) {
      layers.addAll(imageLayers);
    }

    // 添加搜索边界图层（确保在最上层显示）
    if (_searchBoundaryLayer != null) {
      layers.add(_searchBoundaryLayer!);
    }

    // 添加地图控制器
    layers.addAll([
      CustomZoomControls(mapController: _mapController),
      LocationButton(
        mapController: _mapController,
        targetLocation: MapConfig.initialCenter,
      ),
    ]);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        center: MapConfig.initialCenter,
        zoom: MapConfig.initialZoom,
        minZoom: MapConfig.minZoom,
        maxZoom: MapConfig.maxZoom,
        // 禁用地图旋转
        interactiveFlags: InteractiveFlag.all & ~InteractiveFlag.rotate,
      ),
      children: layers,
    );
  }

  /// 构建吉林一号影像切片图层
  Widget _buildJl1TileLayer() {
    return TileLayer(
      urlTemplate: MapConfig.tileUrlTemplate,
      tms: true,
      backgroundColor: Colors.grey.shade200,
    );
  }
}

/// GeoJSON图层组件
class GeoJsonLayer extends StatelessWidget {
  final Map<String, dynamic> geoJsonData;
  final GeoJsonStyle style;
  final Function(Map<String, dynamic>, LatLng)? onTap;

  const GeoJsonLayer({
    super.key,
    required this.geoJsonData,
    required this.style,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final polygons = <Polygon>[];

    try {
      if (geoJsonData['type'] == 'FeatureCollection') {
        final features = geoJsonData['features'];
        if (features is List) {
          for (final feature in features) {
            if (feature is Map<String, dynamic>) {
              final polygon = _createPolygonFromFeature(feature);
              if (polygon != null) {
                polygons.add(polygon);
              }
            }
          }
        }
      } else if (geoJsonData['type'] == 'Feature') {
        final polygon = _createPolygonFromFeature(geoJsonData);
        if (polygon != null) {
          polygons.add(polygon);
        }
      }
    } catch (e) {
      // 静默处理GeoJSON解析错误
      debugPrint('GeoJSON解析错误: $e');
    }

    return PolygonLayer(polygons: polygons);
  }

  Polygon? _createPolygonFromFeature(Map<String, dynamic> feature) {
    try {
      final geometry = feature['geometry'];
      if (geometry is! Map<String, dynamic>) return null;

      if (geometry['type'] == 'Polygon') {
        final coordinatesData = geometry['coordinates'];
        if (coordinatesData is! List || coordinatesData.isEmpty) return null;

        final coordinates = coordinatesData[0];
        if (coordinates is! List) return null;

        final points = <LatLng>[];

        for (final coord in coordinates) {
          if (coord is List && coord.length >= 2) {
            final lng = (coord[0] as num).toDouble();
            final lat = (coord[1] as num).toDouble();
            points.add(LatLng(lat, lng));
          }
        }

        if (points.isEmpty) return null;

        return Polygon(
          points: points,
          color: style.color.withOpacity(style.fillOpacity),
          borderColor: style.color,
          borderStrokeWidth: style.strokeWidth,
        );
      }
    } catch (e) {
      // 静默处理多边形创建错误
      debugPrint('多边形创建错误: $e');
    }
    return null;
  }
}

/// GeoJSON样式类
class GeoJsonStyle {
  final Color color;
  final double strokeWidth;
  final double fillOpacity;

  const GeoJsonStyle({
    required this.color,
    this.strokeWidth = 2.0,
    this.fillOpacity = 0.2,
  });
}
