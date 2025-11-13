import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../services/sentinel_search_service.dart';
import '../models/sentinel_search_models.dart';

/// 地图图层管理器
/// 负责管理卫星影像图层的显示、隐藏和搜索功能
class MapLayerManager {
  // 地图图层管理
  final Set<String> visibleImages = <String>{};
  final Map<String, List<Widget>> imageLayers = <String, List<Widget>>{};

  // 搜索边界
  Widget? searchBoundaryLayer;

  // 搜索相关状态
  bool isLoading = false;
  List<SentinelSearchResult> searchResults = [];
  String? errorMessage;

  // 回调函数
  final void Function(String message) onShowMessage;
  final void Function(String message) onShowError;
  final void Function(String message) onShowLoading;
  final VoidCallback onHideLoading;
  final VoidCallback onUpdate;
  final MapController mapController;
  final BuildContext Function() getContext;

  MapLayerManager({
    required this.onShowMessage,
    required this.onShowError,
    required this.onShowLoading,
    required this.onHideLoading,
    required this.onUpdate,
    required this.mapController,
    required this.getContext,
  });

  /// 执行影像搜索
  Future<void> performSearch(SentinelSearchParams params) async {
    isLoading = true;
    errorMessage = null;
    searchResults = [];
    visibleImages.clear();
    imageLayers.clear();
    searchBoundaryLayer = null;
    onUpdate();

    try {
      final response = await SentinelSearchService.searchImages(params);

      if (response.isSuccessful) {
        searchResults = response.dataInformation;

        // 如果有GeoJSON搜索区域，在地图上显示
        if (params.geoJson != null && params.geoJson!.isNotEmpty) {
          displaySearchBoundary(params.geoJson!);
        }

        onShowMessage('搜索成功，找到 ${response.dataInformation.length} 个影像');
      } else {
        throw Exception('搜索失败');
      }
    } catch (e) {
      errorMessage = e.toString();
      onShowError(errorMessage!);
    } finally {
      isLoading = false;
      onUpdate();
    }
  }

  /// 显示搜索边界
  void displaySearchBoundary(String geoJsonString) {
    try {
      final dynamic geoJsonData = json.decode(geoJsonString);

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

      searchBoundaryLayer = boundaryLayer;
      onUpdate();

      final features = geoJsonMap['features'];
      if (features != null && features is List && features.isNotEmpty) {
        _fitMapToBounds(geoJsonMap);
      } else if (geoJsonMap['type'] == 'Feature' && geoJsonMap['geometry'] != null) {
        _fitMapToBounds({
          'features': [geoJsonMap]
        });
      }
    } catch (e) {
      debugPrint('GeoJSON解析错误: $e');
    }
  }

  /// 调整地图视野以适应边界
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

        mapController.fitBounds(bounds, options: const FitBoundsOptions(
          padding: EdgeInsets.all(50),
        ));
      }
    } catch (e) {
      debugPrint('边界计算错误: $e');
    }
  }

  /// 切换影像显示状态
  Future<void> toggleImageVisibility(SentinelSearchResult result, int index) async {
    final imageId = result.imageId;

    if (visibleImages.contains(imageId)) {
      // 隐藏影像
      visibleImages.remove(imageId);
      imageLayers.remove(imageId);
      onUpdate();
    } else {
      // 显示影像
      onShowLoading('正在加载影像...');

      try {
        final layers = await createImageLayers(result, index);

        visibleImages.add(imageId);
        imageLayers[imageId] = layers;
        onUpdate();

        onHideLoading();
        onShowMessage('影像加载成功');
      } catch (e) {
        onHideLoading();
        onShowError('加载影像失败: ${e.toString()}');
      }
    }
  }

  /// 创建影像图层
  Future<List<Widget>> createImageLayers(SentinelSearchResult result, int index) async {
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

        final borderColor = getDataTypeColor(dataType);

        final boundaryLayer = GeoJsonLayer(
          geoJsonData: footprintData,
          style: GeoJsonStyle(
            color: borderColor,
            strokeWidth: 3,
            fillOpacity: 0.1,
          ),
          onTap: (feature, latLng) {
            showImageInfoDialog(result);
          },
        );
        layers.add(boundaryLayer);
      } catch (e) {
        debugPrint('无法获取边界信息: $e');
      }

      return layers;
    } catch (e) {
      if (e.toString().contains('瓦片') || e.toString().contains('URL')) {
        try {
          final footprintData = await SentinelSearchService.getImageFootprint(imageId, dataType);

          if (footprintData is Map<String, dynamic>) {
            final borderColor = getDataTypeColor(dataType);

            final boundaryLayer = GeoJsonLayer(
              geoJsonData: footprintData,
              style: GeoJsonStyle(
                color: borderColor,
                strokeWidth: 4,
                fillOpacity: 0.2,
              ),
              onTap: (feature, latLng) {
                showImageInfoDialog(result);
                onShowError('该影像暂时无法显示，仅显示覆盖范围');
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
  Color getDataTypeColor(SatelliteDataType dataType) {
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
  void showImageInfoDialog(SentinelSearchResult result) {
    final context = getContext();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.satellite_alt, color: getDataTypeColor(result.dataType)),
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

  /// 构建信息行组件
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

  /// 清除所有图层
  void clearAllLayers() {
    visibleImages.clear();
    imageLayers.clear();
    searchBoundaryLayer = null;
    searchResults = [];
    errorMessage = null;
    onUpdate();
  }

  /// 获取所有可见的图层
  List<Widget> getVisibleLayers() {
    final layers = <Widget>[];

    // 添加所有可见的影像图层
    for (final imageLayers in imageLayers.values) {
      layers.addAll(imageLayers);
    }

    // 添加搜索边界图层（确保在最上层显示）
    if (searchBoundaryLayer != null) {
      layers.add(searchBoundaryLayer!);
    }

    return layers;
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