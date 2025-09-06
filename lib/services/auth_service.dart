import 'dart:convert';
import 'package:sp_util/sp_util.dart';
import 'http_service.dart';

class AuthService {
  static const String loginEndpoint = '/api/v1/auth/login/';
  static const String logoutEndpoint = '/api/v1/auth/logout/';
  static const String refreshEndpoint = '/api/v1/auth/refresh/';

  // 登录请求 - 修改为使用email字段
  static Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final requestBody = {
        'email': email,        // 改为email字段
        'password': password,
      };

      final response = await HttpService.post(
        loginEndpoint,
        body: requestBody,
        requireAuth: false, // 登录请求不需要token
      );

      final data = HttpService.handleResponse(response);

      // 安全地保存JWT token
      final token = data['token'];
      if (token != null) {
        await SpUtil.putString('jwt_token', token.toString());
      }

      // 安全地保存用户信息
      final userInfo = data['user'];
      if (userInfo != null) {
        await SpUtil.putString('user_info', json.encode(userInfo));
      }

      return LoginResult(
        success: true,
        message: data['message']?.toString() ?? '登录成功',
        token: token?.toString(),
        userInfo: userInfo is Map<String, dynamic> ? userInfo : null,
      );
    } catch (e) {
      return LoginResult(
        success: false,
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  // 登出
  static Future<void> logout() async {
    try {
      // 尝试调用服务器登出接口
      await HttpService.post(logoutEndpoint);
    } catch (e) {
      // 即使服务器登出失败，也要清除本地数据
      print('服务器登出失败: $e');
    } finally {
      // 清除本地存储的认证信息
      await SpUtil.remove('jwt_token');
      await SpUtil.remove('user_info');
    }
  }

  // 获取保存的JWT token
  static String? getToken() {
    return SpUtil.getString('jwt_token');
  }

  // 获取保存的用户信息
  static Map<String, dynamic>? getUserInfo() {
    final userInfoString = SpUtil.getString('user_info');
    if (userInfoString != null && userInfoString.isNotEmpty) {
      try {
        final decoded = json.decode(userInfoString);
        return decoded is Map<String, dynamic> ? decoded : null;
      } catch (e) {
        print('解析用户信息失败: $e');
        return null;
      }
    }
    return null;
  }

  // 检查是否已登录
  static bool isLoggedIn() {
    final token = getToken();
    return token != null && token.isNotEmpty;
  }

  // 刷新Token（如果API支持）
  static Future<bool> refreshToken() async {
    try {
      final response = await HttpService.post(refreshEndpoint);
      final data = HttpService.handleResponse(response);

      final newToken = data['token'];
      if (newToken != null) {
        await SpUtil.putString('jwt_token', newToken.toString());
        return true;
      }
      return false;
    } catch (e) {
      print('刷新Token失败: $e');
      return false;
    }
  }

  // 验证邮箱格式
  static bool isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }
}
