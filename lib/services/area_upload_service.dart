import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../sentinel/models/upload_area_model.dart';

/// 上传服务异常
class UploadServiceException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalError;

  UploadServiceException(
      this.message, {
        this.statusCode,
        this.originalError,
      });

  @override
  String toString() {
    if (statusCode != null) {
      return 'UploadServiceException: $message (状态码: $statusCode)';
    }
    return 'UploadServiceException: $message';
  }
}

/// 区域上传服务
class AreaUploadService {
  // API 基础 URL
  static const String _baseUrl = 'http://39.103.98.255:6002';
  static const String _uploadEndpoint = '/api/uploads/';

  // 超时设置
  static const Duration _defaultTimeout = Duration(seconds: 30);

  // 认证 Token
  String? _token;

  /// 构造函数
  AreaUploadService({String? token}) : _token = token;

  /// 设置认证 Token
  void setToken(String token) {
    _token = token;
  }

  /// 清除 Token
  void clearToken() {
    _token = null;
  }

  /// 获取当前 Token（用于调试）
  String? get token => _token;

  /// 上传区域压缩包文件
  ///
  /// [file] - 要上传的 zip 文件
  /// [timeout] - 请求超时时间
  ///
  /// 返回 [UploadAreaResponse] 包含 GeoJSON 数据和文件名
  ///
  /// 抛出 [UploadServiceException] 如果上传失败
  Future<UploadAreaResponse> uploadAreaFile({
    required File file,
    Duration timeout = _defaultTimeout,
  }) async {
    try {
      // 验证文件
      if (!await file.exists()) {
        throw UploadServiceException('文件不存在: ${file.path}');
      }

      // 检查文件扩展名
      if (!file.path.toLowerCase().endsWith('.zip')) {
        throw UploadServiceException('只支持 .zip 格式的文件');
      }

      // 获取文件名
      final filename = file.path.split('/').last;

      // 构建请求
      final uri = Uri.parse('$_baseUrl$_uploadEndpoint');
      var request = http.MultipartRequest('POST', uri);

      // 添加认证 Token（如果存在）
      if (_token != null && _token!.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $_token';
      }

      // 添加文件
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: filename,
        ),
      );

      // 使用文件名作为区域名称
      request.fields['name'] = filename;

      // 发送请求
      final streamedResponse = await request.send().timeout(timeout);
      final response = await http.Response.fromStream(streamedResponse);

      // 处理响应，传入文件名
      return _handleResponse(response, filename);
    } on SocketException catch (e) {
      throw UploadServiceException(
        '网络连接失败，请检查网络设置',
        originalError: e,
      );
    } on TimeoutException catch (e) {
      throw UploadServiceException(
        '请求超时，请稍后重试',
        originalError: e,
      );
    } on UploadServiceException {
      rethrow;
    } catch (e) {
      throw UploadServiceException(
        '上传失败: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// 处理 HTTP 响应
  /// 只提取 geojson_data 字段，其他字段忽略
  UploadAreaResponse _handleResponse(http.Response response, String filename) {
    // 检查状态码
    if (response.statusCode != 200 && response.statusCode != 201) {
      String errorMessage = '服务器返回错误';
      print('响应体：${response.body}');
      try {
        final errorData = json.decode(response.body);
        if (errorData is Map && errorData.containsKey('message')) {
          errorMessage = errorData['message'] as String;
        } else if (errorData is Map && errorData.containsKey('error')) {
          errorMessage = errorData['error'] as String;
        }
      } catch (_) {
        // 如果无法解析错误响应，使用默认消息
        errorMessage = response.body.isNotEmpty
            ? response.body
            : '服务器返回错误';
      }

      throw UploadServiceException(
        errorMessage,
        statusCode: response.statusCode,
      );
    }

    // 解析响应数据
    try {
      final responseData = json.decode(response.body) as Map<String, dynamic>;

      // 只验证 geojson_data 字段
      if (!responseData.containsKey('geojson_data')) {
        throw UploadServiceException('响应数据中缺少 geojson_data 字段');
      }

      // 创建响应模型，只传入必需的数据
      return UploadAreaResponse.fromJson(responseData, filename);
    } on FormatException catch (e) {
      throw UploadServiceException(
        '无法解析服务器响应',
        originalError: e,
      );
    } catch (e) {
      if (e is UploadServiceException) rethrow;

      throw UploadServiceException(
        '处理响应数据时出错: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// 测试 API 连接
  ///
  /// 返回 true 如果服务器可访问
  Future<bool> testConnection({Duration timeout = _defaultTimeout}) async {
    try {
      final uri = Uri.parse(_baseUrl);
      final response = await http.get(uri).timeout(timeout);
      return response.statusCode < 500;
    } catch (e) {
      return false;
    }
  }

  /// 获取 API 基础 URL（用于调试）
  String get baseUrl => _baseUrl;

  /// 获取上传端点（用于调试）
  String get uploadEndpoint => '$_baseUrl$_uploadEndpoint';
}
