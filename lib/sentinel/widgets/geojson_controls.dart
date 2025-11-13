import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// 多边形绘制管理器
/// 负责管理地图上的多边形绘制功能
class PolygonDrawingManager {
  // 多边形点集合
  List<LatLng> polygonPoints = [];

  // 是否处于多边形绘制模式
  bool isPolygonMode = false;

  // 多边形图层
  Widget? polygonLayer;

  // 回调函数
  final Function(String message, {bool isSuccess}) onShowMessage;
  final VoidCallback onUpdate;

  PolygonDrawingManager({
    required this.onShowMessage,
    required this.onUpdate,
  });

  /// 切换多边形绘制模式
  void togglePolygonMode() {
    isPolygonMode = !isPolygonMode;
    HapticFeedback.lightImpact();

    if (isPolygonMode) {
      onShowMessage('双击地图添加点，3个点以上可形成搜索区域');
    } else {
      onShowMessage('已退出绘制模式');
    }

    onUpdate();
  }

  /// 清除多边形点
  void clearPolygonPoints() {
    polygonPoints.clear();
    polygonLayer = null;
    HapticFeedback.lightImpact();
    onShowMessage('已清除所有绘制点');
    onUpdate();
  }

  /// 使用多边形作为GeoJSON
  String? usePolygonAsGeoJson() {
    final geoJson = polygonPointsToGeoJson();
    if (geoJson != null) {
      onShowMessage('已将绘制区域设为搜索范围', isSuccess: true);
    }
    return geoJson;
  }

  /// 处理地图点击事件
  bool handleMapTap(LatLng point, {required bool isPanelOpen, required VoidCallback closePanel}) {
    if (!isPolygonMode) {
      // 非绘制模式下，点击关闭面板
      if (isPanelOpen) {
        closePanel();
      }
      return false;
    }

    // 绘制模式下，添加点
    polygonPoints.add(point);
    updatePolygonLayer();

    HapticFeedback.selectionClick();

    if (polygonPoints.length == 1) {
      onShowMessage('已添加第1个点，继续点击添加更多点');
    } else if (polygonPoints.length == 2) {
      onShowMessage('已添加第2个点，再添加1个点即可形成区域');
    } else if (polygonPoints.length >= 3) {
      onShowMessage('已添加${polygonPoints.length}个点，可以开始搜索了');
    }

    onUpdate();
    return true;
  }

  /// 更新多边形图层
  void updatePolygonLayer() {
    if (polygonPoints.isEmpty) {
      polygonLayer = null;
      return;
    }

    final layers = <Widget>[];

    // 添加点标记
    final markers = <Marker>[];
    for (int i = 0; i < polygonPoints.length; i++) {
      final point = polygonPoints[i];
      markers.add(
        Marker(
          point: point,
          width: 28,
          height: 28,
          builder: (context) => GestureDetector(
            onTap: () => removePolygonPoint(i),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    layers.add(MarkerLayer(markers: markers));

    // 如果有3个或更多点，添加多边形
    if (polygonPoints.length >= 3) {
      final polygons = [
        Polygon(
          points: [...polygonPoints, polygonPoints.first], // 闭合多边形
          color: Colors.blue.withOpacity(0.2),
          borderColor: Colors.blue,
          borderStrokeWidth: 2,
          isDotted: false,
        ),
      ];
      layers.add(PolygonLayer(polygons: polygons));
    } else if (polygonPoints.length == 2) {
      // 如果只有2个点，绘制线段
      final lines = [
        Polyline(
          points: polygonPoints,
          color: Colors.blue,
          strokeWidth: 2,
          isDotted: true,
        ),
      ];
      layers.add(PolylineLayer(polylines: lines));
    }

    // 将所有图层组合成一个Stack
    polygonLayer = Stack(children: layers);
  }

  /// 移除指定索引的多边形点
  void removePolygonPoint(int index) {
    if (index >= 0 && index < polygonPoints.length) {
      polygonPoints.removeAt(index);
      updatePolygonLayer();
      HapticFeedback.lightImpact();

      if (polygonPoints.isEmpty) {
        onShowMessage('已删除该点，当前无绘制点');
      } else if (polygonPoints.length < 3) {
        onShowMessage('已删除该点，还需${3 - polygonPoints.length}个点才能形成区域');
      } else {
        onShowMessage('已删除该点，当前有${polygonPoints.length}个点');
      }

      onUpdate();
    }
  }

  /// 将多边形点转换为GeoJSON格式
  String? polygonPointsToGeoJson() {
    if (polygonPoints.length < 3) {
      return null;
    }

    // 构建坐标数组，注意GeoJSON使用 [经度, 纬度] 的顺序
    final coordinates = polygonPoints.map((point) {
      return [point.longitude, point.latitude];
    }).toList();

    // 闭合多边形（第一个点和最后一个点相同）
    coordinates.add([polygonPoints.first.longitude, polygonPoints.first.latitude]);

    final geoJson = {
      "type": "Polygon",
      "coordinates": [coordinates],
    };

    return jsonEncode(geoJson);
  }

  /// 检查是否有有效的多边形
  bool get hasValidPolygon => polygonPoints.length >= 3;

  /// 获取多边形点的数量
  int get polygonPointsCount => polygonPoints.length;

  /// 重置所有状态
  void reset() {
    polygonPoints.clear();
    isPolygonMode = false;
    polygonLayer = null;
  }

  /// 从GeoJSON加载多边形
  bool loadFromGeoJson(String geoJsonString) {
    try {
      final geoJson = jsonDecode(geoJsonString);

      if (geoJson['type'] == 'Polygon') {
        final coordinates = geoJson['coordinates'][0] as List;
        polygonPoints.clear();

        for (final coord in coordinates) {
          if (coord is List && coord.length >= 2) {
            final lng = (coord[0] as num).toDouble();
            final lat = (coord[1] as num).toDouble();
            polygonPoints.add(LatLng(lat, lng));
          }
        }

        // 移除最后一个点（闭合点）
        if (polygonPoints.length > 1 &&
            polygonPoints.first.latitude == polygonPoints.last.latitude &&
            polygonPoints.first.longitude == polygonPoints.last.longitude) {
          polygonPoints.removeLast();
        }

        updatePolygonLayer();
        onUpdate();
        return true;
      }
    } catch (e) {
      debugPrint('加载GeoJSON失败: $e');
    }
    return false;
  }
}