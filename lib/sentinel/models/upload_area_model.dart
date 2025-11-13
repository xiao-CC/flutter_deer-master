import 'dart:convert';

/// 上传区域响应模型
class UploadAreaResponse {
  final String filename;
  final String id;
  final Map<String, dynamic> geojsonData;

  UploadAreaResponse({
    required this.filename,
    required this.id,
    required this.geojsonData,
  });

  /// 从 JSON 创建实例
  factory UploadAreaResponse.fromJson(
      Map<String, dynamic> json,
      String filename,
      ) {
    return UploadAreaResponse(
      filename: filename,
      id: json['id'].toString(),
      geojsonData: json['geojson_data'] as Map<String, dynamic>,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'filename': filename,
      'id': id,
      'geojson_data': geojsonData,
    };
  }

  /// 获取 GeoJSON 字符串
  String get geojsonString => jsonEncode(geojsonData);
}
