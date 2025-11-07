import 'dart:convert';

/// 上传区域响应模型
class UploadAreaResponse {
  final String filename;  // 文件名（用于显示）
  final Map<String, dynamic> geojsonData;  // GeoJSON 数据（业务核心）

  UploadAreaResponse({
    required this.filename,
    required this.geojsonData,
  });

  /// 从 JSON 创建实例
  factory UploadAreaResponse.fromJson(
      Map<String, dynamic> json,
      String filename,  // 从外部传入文件名
      ) {
    return UploadAreaResponse(
      filename: filename,
      geojsonData: json['geojson_data'] as Map<String, dynamic>,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'filename': filename,
      'geojson_data': geojsonData,
    };
  }

  /// 获取 GeoJSON 字符串
  String get geojsonString => jsonEncode(geojsonData);
}
