import 'dart:convert';
import 'http_service.dart';

class RegisterService {
  static const String registerEndpoint = '/api/v1/auth/register/';
  static const String sendCodeEndpoint = '/api/v1/auth/send-code/';

  // 注册请求
  static Future<RegisterResult> register({
    required String email,
    required String username,
    required String password,
    required String confirmPassword,
    required String verificationCode,
  }) async {
    try {
      final requestBody = {
        'email': email,
        'username': username,
        'password': password,
        'confirm_password': confirmPassword,
        'verification_code': verificationCode,
      };

      final response = await HttpService.post(
        registerEndpoint,
        body: requestBody,
        requireAuth: false, // 注册请求不需要token
      );

      final data = HttpService.handleResponse(response);

      return RegisterResult(
        success: true,
        message: data['message']?.toString() ?? '注册成功',
        userId: data['user_id']?.toString(),
        userInfo: data['user'] is Map<String, dynamic>
            ? data['user'] as Map<String, dynamic>
            : null,
      );
    } catch (e) {
      return RegisterResult(
        success: false,
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  // 通用发送验证码方法
  static Future<VerificationCodeResult> sendVerificationCode({
    required String email,
    required String purpose,
  }) async {
    try {
      final requestBody = {
        'email': email,
        'purpose': purpose,
      };

      final response = await HttpService.post(
        sendCodeEndpoint,
        body: requestBody,
        requireAuth: false,
      );

      final data = HttpService.handleResponse(response);

      return VerificationCodeResult(
        success: true,
        message: data['message']?.toString() ?? '验证码已发送',
      );
    } catch (e) {
      return VerificationCodeResult(
        success: false,
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  // 为注册发送验证码
  static Future<VerificationCodeResult> sendRegisterCode({
    required String email,
  }) async {
    return sendVerificationCode(email: email, purpose: 'register');
  }

  // 验证邮箱格式
  static bool isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }

  // 验证用户名格式（3-20位字母数字下划线）
  static bool isValidUsername(String username) {
    return RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(username);
  }

  // 验证密码强度（至少8位，包含字母和数字）
  static bool isValidPassword(String password) {
    return password.length >= 8 &&
        RegExp(r'^(?=.*[A-Za-z])(?=.*\d)').hasMatch(password);
  }
}

// 注册结果模型
class RegisterResult {
  final bool success;
  final String message;
  final String? userId;
  final Map<String, dynamic>? userInfo;

  RegisterResult({
    required this.success,
    required this.message,
    this.userId,
    this.userInfo,
  });

  @override
  String toString() {
    return 'RegisterResult{success: $success, message: $message, hasUserId: ${userId != null}}';
  }
}

// 验证码结果模型
class VerificationCodeResult {
  final bool success;
  final String message;

  VerificationCodeResult({
    required this.success,
    required this.message,
  });

  @override
  String toString() {
    return 'VerificationCodeResult{success: $success, message: $message}';
  }
}