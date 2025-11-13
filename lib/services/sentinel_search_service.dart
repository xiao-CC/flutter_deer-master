import 'dart:convert';
import 'package:http/http.dart' as http;
import '../sentinel/models/sentinel_search_models.dart';

/// 卫星影像搜索服务
class SentinelSearchService {
  static const String baseUrl = 'http://39.103.98.255:6002/api/search/satellite-search/';

  /// 搜索卫星影像
  static Future<SentinelApiResponse> searchImages(SentinelSearchParams params) async {
    try {
      final uri = Uri.parse(baseUrl);
      final requestBody = json.encode(params.toJson());

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: requestBody,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('请求超时，请检查网络连接');
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return SentinelApiResponse.fromJson(jsonData);
      } else {
        // 尝试解析错误信息
        String errorMessage = 'HTTP错误 ${response.statusCode}';
        try {
          final errorData = json.decode(response.body);
          if (errorData['message'] != null || errorData['error'] != null || errorData['detail'] != null) {
            errorMessage += ': ${errorData['message'] ?? errorData['error'] ?? errorData['detail']}';
          }
        } catch (e) {
          errorMessage += ': ${response.body}';
        }
        throw Exception(errorMessage);
      }

    } catch (e) {
      if (e.toString().contains('SocketException') || e.toString().contains('HandshakeException')) {
        throw Exception('网络连接失败，请检查网络连接或服务器状态');
      } else if (e.toString().contains('TimeoutException')) {
        throw Exception('请求超时，请稍后重试');
      } else {
        rethrow;
      }
    }
  }

  /// 获取影像瓦片信息
  static Future<Map<String, dynamic>> getTileJsonInfo(String imageId, SatelliteDataType dataType) async {
    try {
      final layerConfig = SatelliteLayerConfig.fromDataType(dataType, imageId);

      // 如果是DEM数据，直接返回瓦片URL
      if (dataType == SatelliteDataType.copDemGlo30) {
        return {
          'tiles': [layerConfig.directTileUrl],
          'minzoom': 1,
          'maxzoom': 18,
          'attribution': '© Copernicus DEM'
        };
      }

      // 其他数据类型使用tilejson API
      if (layerConfig.tileJsonUrl == null) {
        throw Exception('该数据类型不支持瓦片服务');
      }

      final response = await http.get(Uri.parse(layerConfig.tileJsonUrl!)).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        // 验证响应数据结构
        if (data['tiles'] == null || (data['tiles'] as List).isEmpty) {
          throw Exception('响应中缺少瓦片URL信息');
        }

        final tileUrl = data['tiles'][0] as String;

        // 验证瓦片URL格式
        try {
          final uri = Uri.parse(tileUrl);
          if (uri.host.isEmpty) {
            throw Exception('瓦片URL缺少主机名: $tileUrl');
          }
        } catch (e) {
          throw Exception('瓦片URL格式无效: $e');
        }

        return data;
      } else {
        final errorBody = response.body;

        if (response.statusCode == 404) {
          throw Exception('影像 $imageId 不存在或已过期');
        } else if (response.statusCode == 403) {
          throw Exception('无权限访问影像 $imageId');
        } else {
          throw Exception('服务器错误 ${response.statusCode}: $errorBody');
        }
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('网络请求超时，请检查网络连接');
      } else {
        rethrow;
      }
    }
  }

  /// 获取影像边界信息
  static Future<Map<String, dynamic>> getImageFootprint(String imageId, SatelliteDataType dataType) async {
    try {
      final layerConfig = SatelliteLayerConfig.fromDataType(dataType, imageId);
      final itemUrl = layerConfig.itemUrl;

      final response = await http.get(Uri.parse(itemUrl)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data;
      } else {
        if (response.statusCode == 404) {
          throw Exception('影像边界信息不存在');
        } else {
          throw Exception('获取影像边界失败: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('获取边界信息超时');
      } else {
        rethrow;
      }
    }
  }

  /// 获取数据类型的显示颜色
  static String getDataTypeColor(SatelliteDataType dataType) {
    switch (dataType) {
      case SatelliteDataType.sentinel2L2A:
        return '#05a6f0'; // 蓝色
      case SatelliteDataType.sentinel1RTC:
        return '#ff6b35'; // 橙色
      case SatelliteDataType.sentinel1GRD:
        return '#f7931e'; // 橙黄色
      case SatelliteDataType.landsatC2L2:
        return '#4caf50'; // 绿色
      case SatelliteDataType.copDemGlo30:
        return '#9c27b0'; // 紫色
    }
  }
}
