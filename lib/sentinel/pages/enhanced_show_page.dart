import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config/map_config.dart';
import '../widgets/geojson_controls.dart';
import '../widgets/map_controls.dart';
import '../widgets/map_layer_manager.dart';
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

  // 管理器
  late final MapLayerManager _layerManager;
  late final PolygonDrawingManager _polygonManager;

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

    // 初始化管理器
    _layerManager = MapLayerManager(
      onShowMessage: _showSuccessSnackBar,
      onShowError: _showErrorSnackBar,
      onShowLoading: _showLoadingSnackBar,
      onHideLoading: _hideCurrentSnackBar,
      onUpdate: () => setState(() {}),
      mapController: _mapController,
      getContext: () => context,
    );

    _polygonManager = PolygonDrawingManager(
      onShowMessage: (message, {isSuccess = false}) {
        if (isSuccess) {
          _showSuccessSnackBar(message);
        } else {
          _showInfoSnackBar(message);
        }
      },
      onUpdate: () => setState(() {}),
    );

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
    final topPadding = MediaQuery.of(context).padding.top;
    final appBarHeight = AppBar().preferredSize.height;
    final availableHeight = screenHeight - topPadding - appBarHeight;

    setState(() {
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

      if (_isPanelOpen) {
        _panelAnimationController.forward();
      } else {
        _panelAnimationController.reverse();
      }
    });

    controller.forward().then((_) {
      controller.dispose();
      HapticFeedback.lightImpact();
    });
  }

  /// 处理地图点击事件
  void _onMapTap(TapPosition tapPosition, LatLng point) {
    _polygonManager.handleMapTap(
      point,
      isPanelOpen: _isPanelOpen,
      closePanel: _closePanel,
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

  void _showInfoSnackBar(String message) {
    final bottomMargin = _currentPanelHeight + MediaQuery.of(context).padding.bottom + 20;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blueAccent,
        duration: const Duration(seconds: 3),
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

        // 绘制控制按钮组
        Positioned(
          top: 16,
          left: 16,
          child: _buildDrawingControls(),
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

  /// 构建绘制控制按钮组
  Widget _buildDrawingControls() {
    return Column(
      children: [
        // 搜索按钮
        FloatingActionButton(
          onPressed: _togglePanel,
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 6,
          heroTag: "search_fab",
          child: AnimatedBuilder(
            animation: _panelAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _panelAnimation.value * 0.5,
                child: Icon(_isPanelOpen ? Icons.close : Icons.search),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        // 多边形绘制按钮
        FloatingActionButton(
          onPressed: () => _polygonManager.togglePolygonMode(),
          backgroundColor: _polygonManager.isPolygonMode ? Colors.red : Colors.green,
          foregroundColor: Colors.white,
          elevation: 6,
          heroTag: "polygon_fab",
          child: Icon(_polygonManager.isPolygonMode ? Icons.stop : Icons.edit_location),
        ),

        // 如果在绘制模式且有点，显示清除按钮
        if (_polygonManager.isPolygonMode && _polygonManager.polygonPoints.isNotEmpty) ...[
          const SizedBox(height: 12),
          FloatingActionButton(
            onPressed: () => _polygonManager.clearPolygonPoints(),
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            elevation: 6,
            mini: true,
            heroTag: "clear_fab",
            child: const Icon(Icons.refresh),
          ),
        ],
      ],
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
        onVerticalDragStart: (details) {
          // 拖拽开始时记录位置
        },
        onVerticalDragUpdate: (details) {
          setState(() {
            // 向下拖拽减少高度，向上拖拽增加高度
            _currentPanelHeight -= details.delta.dy;

            // 限制高度范围
            if (_currentPanelHeight < _minPanelHeight) {
              _currentPanelHeight = _minPanelHeight;
            } else if (_currentPanelHeight > _maxPanelHeight) {
              _currentPanelHeight = _maxPanelHeight;
            }

            // 更新面板状态
            _isPanelOpen = _currentPanelHeight > _minPanelHeight + 50;
          });
        },
        onVerticalDragEnd: (details) {
          // 根据最终高度决定是否完全打开或关闭
          final velocity = details.primaryVelocity ?? 0;

          if (velocity < -500) {
            // 快速向上滑动，打开面板
            _animateToHeight(_maxPanelHeight);
          } else if (velocity > 500) {
            // 快速向下滑动，关闭面板
            _animateToHeight(_minPanelHeight);
          } else {
            // 根据当前位置决定
            final middleHeight = (_minPanelHeight + _maxPanelHeight) / 2;
            if (_currentPanelHeight > middleHeight) {
              _animateToHeight(_maxPanelHeight);
            } else {
              _animateToHeight(_minPanelHeight);
            }
          }

          HapticFeedback.lightImpact();
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // 面板头部
              _buildPanelHeader(),

              // 面板内容
              Expanded(
                child: Opacity(
                  opacity: ((_currentPanelHeight - _minPanelHeight) / (_maxPanelHeight - _minPanelHeight)).clamp(0.0, 1.0),
                  child: MobileSentinelSearchPanel(
                    onSearch: _layerManager.performSearch,
                    isLoading: _layerManager.isLoading,
                    searchResults: _layerManager.searchResults,
                    onToggleImage: _layerManager.toggleImageVisibility,
                    visibleImages: _layerManager.visibleImages,
                    onClosePanel: () => _animateToHeight(_minPanelHeight),
                    // 地图打点相关参数
                    onTogglePolygonMode: () => _polygonManager.togglePolygonMode(),
                    onClearPolygonPoints: () => _polygonManager.clearPolygonPoints(),
                    onUsePolygonAsGeoJson: () => _polygonManager.usePolygonAsGeoJson(),
                    isPolygonMode: _polygonManager.isPolygonMode,
                    polygonPointsCount: _polygonManager.polygonPointsCount,
                    hasValidPolygon: _polygonManager.hasValidPolygon,
                    polygonGeoJson: _polygonManager.polygonPointsToGeoJson(),
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
                // 绘制状态指示器
                if (_polygonManager.isPolygonMode)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_location, size: 12, color: Colors.orange.shade700),
                        const SizedBox(width: 4),
                        Text(
                          '绘制中',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_polygonManager.polygonPoints.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_polygonManager.polygonPoints.length} 个点',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  )
                else if (_layerManager.searchResults.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_layerManager.searchResults.length} 个结果',
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

    // 添加可见的影像图层（使用管理器）
    layers.addAll(_layerManager.getVisibleLayers());

    // 添加多边形绘制图层
    if (_polygonManager.polygonLayer != null) {
      layers.add(_polygonManager.polygonLayer!);
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
        interactiveFlags: InteractiveFlag.all & ~InteractiveFlag.rotate & ~InteractiveFlag.doubleTapZoom,
        onTap: _onMapTap, // 处理地图点击事件
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