import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_deer/routers/fluro_navigator.dart';
import 'package:flutter_deer/util/change_notifier_manage.dart';
import 'package:sp_util/sp_util.dart';

import '../../sentinel/sentinel_router.dart';
import '../../services/auth_service.dart';
import '../login_router.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with ChangeNotifierMixin<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _nodeText1 = FocusNode();
  final FocusNode _nodeText2 = FocusNode();
  bool _clickable = false;
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;

  @override
  Map<ChangeNotifier, List<VoidCallback>?>? changeNotifier() {
    final List<VoidCallback> callbacks = <VoidCallback>[_verify];
    return <ChangeNotifier, List<VoidCallback>?>{
      _emailController: callbacks,
      _passwordController: callbacks,
      _nodeText1: null,
      _nodeText2: null,
    };
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
    });
    _emailController.text = SpUtil.getString('saved_email') ?? '';
    _rememberMe = SpUtil.getBool('remember_me') ?? false;
  }

  void _verify() {
    final String email = _emailController.text;
    final String password = _passwordController.text;
    bool clickable = true;

    if (email.isEmpty || !AuthService.isValidEmail(email)) {
      clickable = false;
    }

    if (password.isEmpty || password.length < 6) {
      clickable = false;
    }

    if (clickable != _clickable) {
      setState(() {
        _clickable = clickable;
      });
    }
  }

  void _login() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await AuthService.login(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (result.success) {
        if (_rememberMe) {
          SpUtil.putString('saved_email', _emailController.text);
          SpUtil.putBool('remember_me', true);
        } else {
          SpUtil.remove('saved_email');
          SpUtil.putBool('remember_me', false);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.green,
            ),
          );
          NavigatorUtils.push(context, SentinelRouter.navigationPage);
        }
      } else {
        if (mounted) {
          _showErrorDialog(result.message);
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('登录过程中发生错误: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('登录失败'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('确定'),
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            children: _buildBody,
          ),
        ),
      ),
    );
  }

  List<Widget> get _buildBody => <Widget>[
    const SizedBox(height: 60),

    // 头像
    Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const Icon(
        Icons.person,
        size: 40,
        color: Colors.white,
      ),
    ),

    const SizedBox(height: 20),

    // 欢迎回来文字
    const Text(
      '欢迎回来',
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1F2937),
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
          hintText: '请输入邮箱',
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

    // 密码输入框
    _buildInputContainer(
      child: TextField(
        key: const Key('password'),
        controller: _passwordController,
        focusNode: _nodeText2,
        obscureText: _obscurePassword,
        style: const TextStyle(
          color: Color(0xFF1F2937),
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: '请输入密码',
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

    const SizedBox(height: 20),

    // 记住我
    Row(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _rememberMe = !_rememberMe;
            });
          },
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: _rememberMe ? const Color(0xFF2563EB) : Colors.transparent,
              border: Border.all(
                color: _rememberMe ? const Color(0xFF2563EB) : const Color(0xFFD1D5DB),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: _rememberMe
                ? const Icon(
              Icons.check,
              size: 12,
              color: Colors.white,
            )
                : null,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          '记住我',
          style: TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 14,
          ),
        ),
      ],
    ),

    const SizedBox(height: 30),

    // 登录按钮
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
          onTap: _clickable && !_isLoading ? _login : null,
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
              '登录',
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

    const SizedBox(height: 20),

    // 忘记密码
    GestureDetector(
      onTap: () => NavigatorUtils.push(context, LoginRouter.resetPasswordPage),
      child: const Text(
        '忘记密码？',
        key: Key('forgotPassword'),
        style: TextStyle(
          color: Color(0xFF2563EB),
          fontSize: 14,
        ),
      ),
    ),

    const SizedBox(height: 40),

    // 分割线
    Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: const Color(0xFFE5E7EB),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '或使用其他方式登录',
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: const Color(0xFFE5E7EB),
          ),
        ),
      ],
    ),

    const SizedBox(height: 30),

    // 第三方登录图标
    Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 微信登录
        _buildSocialButton(
          key: const Key('weChatLogin'),
          icon: Icons.wechat,
          color: const Color(0xFF07C160),
          onTap: () => NavigatorUtils.push(context, LoginRouter.weChatLoginPage),
        ),

        const SizedBox(width: 16),

        // QQ登录
        _buildSocialButton(
          icon: Icons.person,
          color: const Color(0xFF12B7F5),
          onTap: () {
            // QQ登录逻辑
          },
        ),

        const SizedBox(width: 16),

        // Apple登录
        _buildSocialButton(
          icon: Icons.apple,
          color: const Color(0xFF1F2937),
          onTap: () {
            // Apple登录逻辑
          },
        ),
      ],
    ),

    const SizedBox(height: 50),

    // 注册链接
    GestureDetector(
      key: const Key('noAccountRegister'),
      onTap: () => NavigatorUtils.push(context, LoginRouter.registerPage),
      child: RichText(
        text: const TextSpan(
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
          ),
          children: [
            TextSpan(text: '还没有账号？'),
            TextSpan(
              text: '立即注册',
              style: TextStyle(
                color: Color(0xFF2563EB),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),

    const SizedBox(height: 40),
  ];

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

  Widget _buildSocialButton({
    Key? key,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: const Color(0xFFE5E7EB),
            width: 2,
          ),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: color,
          size: 20,
        ),
      ),
    );
  }
}