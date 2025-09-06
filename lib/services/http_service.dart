import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:sp_util/sp_util.dart';

class HttpService {
  static const String baseUrl = 'http://39.103.98.255:6004';
  static const Duration timeoutDuration = Duration(seconds: 30);

  // 获取Headers
  static Map<String, String> _getHeaders({bool requireAuth = true}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requireAuth) {
      // 直接从本地存储获取token，避免循环依赖
      final token = SpUtil.getString('jwt_token');
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // POST请求
  static Future<http.Response> post(
      String endpoint, {
        Map<String, dynamic>? body,
        bool requireAuth = true,
      }) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint');
      final headers = _getHeaders(requireAuth: requireAuth);

      final response = await http.post(
        url,
        headers: headers,
        body: body != null ? json.encode(body) : null,
      ).timeout(timeoutDuration);

      return response;
    } on SocketException {
      throw Exception('网络连接失败，请检查网络设置');
    } on HttpException {
      throw Exception('HTTP请求异常');
    } on FormatException {
      throw Exception('数据格式错误');
    } catch (e) {
      throw Exception('请求失败: ${e.toString()}');
    }
  }

  // GET请求
  static Future<http.Response> get(String endpoint) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint');
      final headers = _getHeaders();

      final response = await http.get(
        url,
        headers: headers,
      ).timeout(timeoutDuration);

      return response;
    } on SocketException {
      throw Exception('网络连接失败，请检查网络设置');
    } catch (e) {
      throw Exception('请求失败: ${e.toString()}');
    }
  }

  // PUT请求
  static Future<http.Response> put(
      String endpoint, {
        Map<String, dynamic>? body,
      }) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint');
      final headers = _getHeaders();

      final response = await http.put(
        url,
        headers: headers,
        body: body != null ? json.encode(body) : null,
      ).timeout(timeoutDuration);

      return response;
    } on SocketException {
      throw Exception('网络连接失败，请检查网络设置');
    } catch (e) {
      throw Exception('请求失败: ${e.toString()}');
    }
  }

  // DELETE请求
  static Future<http.Response> delete(String endpoint) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint');
      final headers = _getHeaders();

      final response = await http.delete(
        url,
        headers: headers,
      ).timeout(timeoutDuration);

      return response;
    } on SocketException {
      throw Exception('网络连接失败，请检查网络设置');
    } catch (e) {
      throw Exception('请求失败: ${e.toString()}');
    }
  }

  // 处理响应
  static Map<String, dynamic> handleResponse(http.Response response) {
    try {
      final responseBody = response.body;

      // 检查响应是否为空
      if (responseBody.isEmpty) {
        if (response.statusCode == 200 || response.statusCode == 201) {
          return <String, dynamic>{}; // 返回空Map
        } else {
          throw Exception('服务器响应为空');
        }
      }

      // 解析JSON
      final data = json.decode(responseBody);

      // 确保返回的是Map类型
      if (data is! Map<String, dynamic>) {
        throw Exception('服务器响应格式错误');
      }

      // 根据状态码处理
      switch (response.statusCode) {
        case 200:
        case 201:
          return data;
        case 401:
        // Token过期或无效，清除本地token
          SpUtil.remove('jwt_token');
          SpUtil.remove('user_info');
          throw Exception('认证失败，请重新登录');
        case 403:
          throw Exception('权限不足');
        case 404:
          throw Exception('请求的资源不存在');
        case 422:
        // 参数验证失败
          final message = data['message'] ?? '参数验证失败';
          throw Exception(message.toString());
        case 500:
          throw Exception('服务器内部错误');
        default:
          final message = data['message'] ?? '请求失败';
          throw Exception('${message.toString()} (${response.statusCode})');
      }
    } on FormatException {
      throw Exception('服务器响应格式错误');
    } catch (e) {
      if (e is Exception) {
        rethrow;
      } else {
        throw Exception('处理响应时发生错误: ${e.toString()}');
      }
    }
  }
}


// =================================
// 登录结果模型
// =================================
class LoginResult {
  final bool success;
  final String message;
  final String? token;
  final Map<String, dynamic>? userInfo;

  LoginResult({
    required this.success,
    required this.message,
    this.token,
    this.userInfo,
  });

  @override
  String toString() {
    return 'LoginResult{success: $success, message: $message, hasToken: ${token != null}}';
  }
}
