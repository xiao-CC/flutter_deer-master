import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RegionService {
  static const String _baseUrl = 'http://39.103.98.255:6002';
  static const String _regionsEndpoint = '/api/regions/';

  /// 保存区域到服务器
  ///
  /// [geoJsonString] GeoJSON 格式的字符串
  /// [regionName] 区域名称（可选，默认使用时间戳生成）
  ///
  /// 返回 region_id，失败时抛出异常
  static Future<String> saveRegion({
    required String geoJsonString,
    String? regionName,
  }) async {
    try {
      // 获取 token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null || token.isEmpty) {
        throw Exception('用户未登录，请先登录');
      }

      // 解析 GeoJSON
      dynamic geoJsonData;
      try {
        geoJsonData = jsonDecode(geoJsonString);
      } catch (e) {
        throw Exception('GeoJSON 格式错误：$e');
      }

      //  GeoJSON转换FeatureCollection
      Map<String, dynamic> featureCollection;
      featureCollection = {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'properties': {},
            'geometry': geoJsonData,
          }
        ],
      };

      // 生成区域名称
      final name = regionName ?? '我的区域_${DateTime.now().millisecondsSinceEpoch}';

      // 构建请求体
      final requestBody = {
        "name": name,
        "geojson_data": featureCollection,
      };

      // 发送请求
      final response = await http.post(
        Uri.parse('$_baseUrl$_regionsEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('请求超时，请检查网络连接');
        },
      );

      // 处理响应
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);

        if (responseData['id'] == null) {
          throw Exception('服务器返回数据格式错误');
        }

        final regionId = responseData['id'].toString();

        // 存储 region_id
        await prefs.setString('region_id', regionId);

        return regionId;
      } else if (response.statusCode == 401) {
        throw Exception('登录已过期，请重新登录');
      } else if (response.statusCode == 400) {
        throw Exception('请求参数错误：${response.body}');
      } else {
        throw Exception('保存失败：${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('保存区域失败：$e');
    }
  }

  /// 获取已保存的 region_id
  static Future<String?> getSavedRegionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('region_id');
  }

  /// 清除已保存的 region_id
  static Future<void> clearSavedRegionId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('region_id');
  }
}