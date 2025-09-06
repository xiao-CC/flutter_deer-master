import 'dart:convert';
import 'http_service.dart';

/// 密码重置服务类
class PasswordResetService {

  /// 发送验证码
  /// [email] 邮箱地址
  /// [purpose] 用途，这里固定为 'reset_password'
  static Future<Map<String, dynamic>> sendVerificationCode(String email) async {
    try {
      final body = {
        'email': email,
        'purpose': 'reset_password',
      };

      final response = await HttpService.post(
        '/api/v1/auth/send-code/',
        body: body,
        requireAuth: false, // 发送验证码不需要认证
      );

      return HttpService.handleResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  /// 重置密码
  /// [email] 邮箱地址
  /// [verificationCode] 验证码
  /// [newPassword] 新密码
  /// [confirmPassword] 确认密码
  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String verificationCode,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final body = {
        'email': email,
        'verification_code': verificationCode,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      };

      final response = await HttpService.post(
        '/api/v1/auth/reset-password/',
        body: body,
        requireAuth: false, // 重置密码不需要认证
      );

      return HttpService.handleResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  /// 验证邮箱格式
  static bool isValidEmail(String email) {
    final RegExp emailRegExp = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegExp.hasMatch(email);
  }

  /// 验证密码强度（可根据需求调整）
  static bool isValidPassword(String password) {
    // 至少6位，包含字母和数字
    if (password.length < 6) return false;

    final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);

    return hasLetter && hasNumber;
  }

  /// 获取密码强度提示
  static String getPasswordStrengthHint() {
    return '密码至少6位，需包含字母和数字';
  }
}