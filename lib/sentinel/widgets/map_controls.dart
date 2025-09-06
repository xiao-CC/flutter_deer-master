import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong2/latlong.dart';

/// 地图配置常量
class MapControlConfig {
  static const double initialZoom = 13.0;
}

/// 地图缩放控制器组件
class CustomZoomControls extends StatelessWidget {
  final MapController mapController;

  const CustomZoomControls({
    super.key,
    required this.mapController,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 150,
      right: 12,
      child: Column(
        children: [
          FloatingActionButton(
            mini: true,
            backgroundColor: Colors.blue,
            child: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              mapController.move(
                mapController.center,
                mapController.zoom + 1,
              );
            },
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            mini: true,
            backgroundColor: Colors.blue,
            child: const Icon(Icons.remove, color: Colors.white),
            onPressed: () {
              mapController.move(
                mapController.center,
                mapController.zoom - 1,
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 地图定位按钮组件
class LocationButton extends StatelessWidget {
  final MapController mapController;
  final LatLng targetLocation;

  const LocationButton({
    super.key,
    required this.mapController,
    required this.targetLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 80,
      right: 12,
      child: FloatingActionButton(
        mini: true,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.my_location, color: Colors.white),
        onPressed: () {
          mapController.move(targetLocation, MapControlConfig.initialZoom);
        },
      ),
    );
  }
}
