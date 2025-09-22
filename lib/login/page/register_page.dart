import 'package:flutter/material.dart';
import 'package:flutter_deer/login/widgets/my_text_field.dart';
import 'package:flutter_deer/res/resources.dart';
import 'package:flutter_deer/routers/fluro_navigator.dart';
import 'package:flutter_deer/util/change_notifier_manage.dart';
import 'package:flutter_deer/util/other_utils.dart';
import 'package:flutter_deer/util/toast_utils.dart';
import 'package:flutter_deer/widgets/my_app_bar.dart';
import 'package:flutter_deer/widgets/my_button.dart';
import 'package:flutter_deer/widgets/my_scroll_view.dart';
import '../../l10n/deer_localizations.dart';
import '../../services/register_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with ChangeNotifierMixin<RegisterPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _vCodeController = TextEditingController();

  final FocusNode _nodeText1 = FocusNode();
  final FocusNode _nodeText2 = FocusNode();
  final FocusNode _nodeText3 = FocusNode();
  final FocusNode _nodeText4 = FocusNode();
  final FocusNode _nodeText5 = FocusNode();

  bool _clickable = false;
  bool _isLoading = false;
  bool _isCodeSending = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  Map<ChangeNotifier, List<VoidCallback>?>? changeNotifier() {
    final List<VoidCallback> callbacks = <VoidCallback>[_verify];
    return <ChangeNotifier, List<VoidCallback>?>{
      _emailController: callbacks,
      _usernameController: callbacks,
      _passwordController: callbacks,
      _confirmPasswordController: callbacks,
      _vCodeController: callbacks,
      _nodeText1: null,
      _nodeText2: null,
      _nodeText3: null,
      _nodeText4: null,
      _nodeText5: null,
    };
  }

  void _verify() {
    final String email = _emailController.text;
    final String username = _usernameController.text;
    final String password = _passwordController.text;
    final String confirmPassword = _confirmPasswordController.text;
    final String vCode = _vCodeController.text;

    bool clickable = true;

    if (email.isEmpty || !RegisterService.isValidEmail(email)) {
      clickable = false;
    }

    if (username.isEmpty || !RegisterService.isValidUsername(username)) {
      clickable = false;
    }

    if (password.isEmpty || !RegisterService.isValidPassword(password)) {
      clickable = false;
    }

    if (confirmPassword.isEmpty || password != confirmPassword) {
      clickable = false;
    }

    if (vCode.isEmpty || vCode.length < 6) {
      clickable = false;
    }

    if (clickable != _clickable) {
      setState(() {
        _clickable = clickable;
      });
    }
  }

  Future<bool> _sendVerificationCode() async {
    if (_isCodeSending) return false;

    final email = _emailController.text;
    if (!RegisterService.isValidEmail(email)) {
      Toast.show('请输入有效的邮箱地址');
      return false;
    }

    setState(() {
      _isCodeSending = true;
    });

    try {
      final result = await RegisterService.sendRegisterCode(email: email);

      if (result.success) {
        Toast.show(result.message);
        return true;
      } else {
        Toast.show(result.message);
        return false;
      }
    } catch (e) {
      Toast.show('发送验证码失败: ${e.toString()}');
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isCodeSending = false;
        });
      }
    }
  }

  void _register() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await RegisterService.register(
        email: _emailController.text,
        username: _usernameController.text,
        password: _passwordController.text,
        confirmPassword: _confirmPasswordController.text,
        verificationCode: _vCodeController.text,
      );

      if (result.success) {
        if (mounted) {
          _showSuccessDialog(result.message);
        }
      } else {
        if (mounted) {
          _showErrorDialog(result.message);
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('注册过程中发生错误: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '注册成功',
                style: TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          actions: [
            Container(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  NavigatorUtils.goBack(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '去登录',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '注册失败',
                style: TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          actions: [
            Container(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B7280),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '确定',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
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
        title: const Text(
          '注册',
          style: TextStyle(
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
        '注册你的账户',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1F2937),
        ),
      ),

      const SizedBox(height: 8),

      Text(
        '创建一个新账户，开始您的旅程',
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
        ),
      ),

      const SizedBox(height: 40),

      // 邮箱输入框
      _buildInputContainer(
        child: TextField(
          key: const Key('email'),
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

      // 用户名输入框
      _buildInputContainer(
        child: TextField(
          key: const Key('username'),
          controller: _usernameController,
          focusNode: _nodeText2,
          style: const TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: '请输入用户名（3-20位字母数字下划线）',
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
            border: InputBorder.none,
            prefixIcon: const Icon(
              Icons.person_outline,
              color: Color(0xFF6B7280),
              size: 20,
            ),
            counterText: '',
          ),
          keyboardType: TextInputType.text,
          maxLength: 20,
        ),
      ),

      const SizedBox(height: 16),

      // 密码输入框
      _buildInputContainer(
        child: TextField(
          key: const Key('password'),
          controller: _passwordController,
          focusNode: _nodeText3,
          obscureText: _obscurePassword,
          style: const TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: '请输入密码（至少8位，包含字母和数字）',
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

      // 确认密码输入框
      _buildInputContainer(
        child: TextField(
          key: const Key('confirmPassword'),
          controller: _confirmPasswordController,
          focusNode: _nodeText4,
          obscureText: _obscureConfirmPassword,
          style: const TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: '请再次输入密码',
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

      const SizedBox(height: 16),

      // 验证码输入框
      _buildInputContainer(
        child: TextField(
          key: const Key('vcode'),
          controller: _vCodeController,
          focusNode: _nodeText5,
          style: const TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: '请输入验证码',
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
                onPressed: _isCodeSending ? null : _sendVerificationCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isCodeSending ? Colors.grey[300] : const Color(0xFF2563EB),
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
                    : const Text(
                  '发送',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
            counterText: '',
          ),
          keyboardType: TextInputType.number,
          maxLength: 6,
        ),
      ),

      const SizedBox(height: 30),

      // 注册按钮
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
            onTap: _clickable && !_isLoading ? _register : null,
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
                '注册',
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
              '• 至少8位字符\n• 必须包含字母和数字\n• 用户名只能包含字母、数字和下划线\n• 用户名长度为3-20位',
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
}