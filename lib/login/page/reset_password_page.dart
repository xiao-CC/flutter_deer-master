import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_deer/util/change_notifier_manage.dart';
import 'package:flutter_deer/util/toast_utils.dart';
import '../../services/reset_password_service.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  _ResetPasswordPageState createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> with ChangeNotifierMixin<ResetPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _vCodeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final FocusNode _nodeText1 = FocusNode();
  final FocusNode _nodeText2 = FocusNode();
  final FocusNode _nodeText3 = FocusNode();
  final FocusNode _nodeText4 = FocusNode();

  bool _clickable = false;
  bool _isLoading = false;
  bool _isCodeSending = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // 验证码倒计时相关
  Timer? _countdownTimer;
  int _countdown = 0;
  static const int _maxCountdown = 600;

  @override
  Map<ChangeNotifier, List<VoidCallback>?>? changeNotifier() {
    final List<VoidCallback> callbacks = <VoidCallback>[_verify];
    return <ChangeNotifier, List<VoidCallback>?>{
      _emailController: callbacks,
      _vCodeController: callbacks,
      _passwordController: callbacks,
      _confirmPasswordController: callbacks,
      _nodeText1: null,
      _nodeText2: null,
      _nodeText3: null,
      _nodeText4: null,
    };
  }

  void _verify() {
    final String email = _emailController.text;
    final String vCode = _vCodeController.text;
    final String password = _passwordController.text;
    final String confirmPassword = _confirmPasswordController.text;

    bool clickable = true;

    if (email.isEmpty || !PasswordResetService.isValidEmail(email)) {
      clickable = false;
    }

    if (vCode.isEmpty || vCode.length < 6) {
      clickable = false;
    }

    if (password.isEmpty || !PasswordResetService.isValidPassword(password)) {
      clickable = false;
    }

    if (confirmPassword.isEmpty || password != confirmPassword) {
      clickable = false;
    }

    if (clickable != _clickable) {
      setState(() {
        _clickable = clickable;
      });
    }
  }

  Future<bool> _sendVerificationCode() async {
    if (_isCodeSending || _countdown > 0) return false;

    final String email = _emailController.text;

    if (email.isEmpty) {
      Toast.show('请输入邮箱地址');
      return false;
    }

    if (!PasswordResetService.isValidEmail(email)) {
      Toast.show('请输入有效的邮箱地址');
      return false;
    }

    setState(() {
      _isCodeSending = true;
    });

    try {
      await PasswordResetService.sendVerificationCode(email);
      Toast.show('验证码已发送，请查收邮件');
      // 启动倒计时
      _startCountdown();
      return true;
    } catch (e) {
      Toast.show('发送验证码失败：${e.toString()}');
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isCodeSending = false;
        });
      }
    }
  }

  // 启动倒计时
  void _startCountdown() {
    setState(() {
      _countdown = _maxCountdown;
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          _countdownTimer?.cancel();
          _countdownTimer = null;
        }
      });
    });
  }

  // 格式化倒计时显示
  String _formatCountdown() {
    final minutes = _countdown ~/ 60;
    final seconds = _countdown % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}后再试';
  }

  void _resetPassword() async {
    if (_isLoading) return;

    final String email = _emailController.text;
    final String vCode = _vCodeController.text;
    final String password = _passwordController.text;
    final String confirmPassword = _confirmPasswordController.text;

    if (!PasswordResetService.isValidEmail(email)) {
      Toast.show('请输入有效的邮箱地址');
      return;
    }

    if (vCode.length < 6) {
      Toast.show('请输入6位验证码');
      return;
    }

    if (!PasswordResetService.isValidPassword(password)) {
      Toast.show(PasswordResetService.getPasswordStrengthHint());
      return;
    }

    if (password != confirmPassword) {
      Toast.show('两次输入的密码不一致');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await PasswordResetService.resetPassword(
        email: email,
        verificationCode: vCode,
        newPassword: password,
        confirmPassword: confirmPassword,
      );

      Toast.show('密码重置成功！');

      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });

    } catch (e) {
      Toast.show('密码重置失败：${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2937)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '重置密码',
          style: const TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildBody(),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBody() {
    return <Widget>[
      const SizedBox(height: 40),

      // 页面标题
      const Text(
        '重置登录密码',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1F2937),
        ),
      ),

      const SizedBox(height: 8),

      Text(
        '请输入注册邮箱，我们将发送验证码到您的邮箱',
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
        ),
      ),

      const SizedBox(height: 40),

      // 邮箱输入
      _buildInputContainer(
        child: TextField(
          controller: _emailController,
          focusNode: _nodeText1,
          style: const TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: '请输入邮箱地址',
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
            border: InputBorder.none,
            prefixIcon: const Icon(
              Icons.email_outlined,
              color: Color(0xFF6B7280),
              size: 20,
            ),
            counterText: '',
          ),
          keyboardType: TextInputType.emailAddress,
          maxLength: 50,
        ),
      ),

      const SizedBox(height: 16),

      // 验证码输入
      _buildInputContainer(
        child: TextField(
          controller: _vCodeController,
          focusNode: _nodeText2,
          style: const TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: '请输入6位验证码',
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
            border: InputBorder.none,
            prefixIcon: const Icon(
              Icons.verified_user_outlined,
              color: Color(0xFF6B7280),
              size: 20,
            ),
            suffixIcon: Container(
              margin: const EdgeInsets.all(8),
              child: ElevatedButton(
                onPressed: (_isCodeSending || _countdown > 0) ? null : _sendVerificationCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: (_isCodeSending || _countdown > 0)
                      ? Colors.grey[300]
                      : const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: const Size(80, 32),
                ),
                child: _isCodeSending
                    ? const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : Text(
                  _countdown > 0 ? _formatCountdown() : '发送',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            counterText: '',
          ),
          keyboardType: TextInputType.number,
          maxLength: 6,
        ),
      ),

      const SizedBox(height: 16),

      // 新密码输入
      _buildInputContainer(
        child: TextField(
          controller: _passwordController,
          focusNode: _nodeText3,
          obscureText: _obscurePassword,
          style: const TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: '请输入新密码（至少6位，包含字母和数字）',
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
            border: InputBorder.none,
            prefixIcon: const Icon(
              Icons.lock_outline,
              color: Color(0xFF6B7280),
              size: 20,
            ),
            suffixIcon: GestureDetector(
              onTap: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
              child: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: const Color(0xFF9CA3AF),
                size: 20,
              ),
            ),
          ),
          keyboardType: TextInputType.visiblePassword,
        ),
      ),

      const SizedBox(height: 16),

      // 确认密码输入
      _buildInputContainer(
        child: TextField(
          controller: _confirmPasswordController,
          focusNode: _nodeText4,
          obscureText: _obscureConfirmPassword,
          style: const TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: '请再次输入新密码',
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
            border: InputBorder.none,
            prefixIcon: const Icon(
              Icons.lock_outline,
              color: Color(0xFF6B7280),
              size: 20,
            ),
            suffixIcon: GestureDetector(
              onTap: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
              child: Icon(
                _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: const Color(0xFF9CA3AF),
                size: 20,
              ),
            ),
          ),
          keyboardType: TextInputType.visiblePassword,
        ),
      ),

      const SizedBox(height: 40),

      // 重置密码按钮
      Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _clickable && !_isLoading
                ? [const Color(0xFF2563EB), const Color(0xFF1D4ED8)]
                : [const Color(0xFFD1D5DB), const Color(0xFFD1D5DB)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: _clickable && !_isLoading
              ? [
            BoxShadow(
              color: const Color(0xFF2563EB).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: (_clickable && !_isLoading) ? _resetPassword : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              alignment: Alignment.center,
              child: _isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
              )
                  : const Text(
                '重置密码',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),

      const SizedBox(height: 30),

      // 密码要求说明
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFE9ECEF),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '密码要求：',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF1F2937),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '• 至少6位字符\n• 必须包含字母和数字\n• 建议使用大小写字母、数字和特殊字符的组合',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 40),
    ];
  }

  Widget _buildInputContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        border: Border.all(
          color: const Color(0xFFE9ECEF),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _emailController.dispose();
    _vCodeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nodeText1.dispose();
    _nodeText2.dispose();
    _nodeText3.dispose();
    _nodeText4.dispose();
    super.dispose();
  }
}