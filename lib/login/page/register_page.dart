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

/// design/1注册登录/index.html#artboard11
class RegisterPage extends StatefulWidget {

  const RegisterPage({super.key});

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with ChangeNotifierMixin<RegisterPage> {
  // 定义控制器
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

    // 验证邮箱
    if (email.isEmpty || !RegisterService.isValidEmail(email)) {
      clickable = false;
    }

    // 验证用户名
    if (username.isEmpty || !RegisterService.isValidUsername(username)) {
      clickable = false;
    }

    // 验证密码
    if (password.isEmpty || !RegisterService.isValidPassword(password)) {
      clickable = false;
    }

    // 验证确认密码
    if (confirmPassword.isEmpty || password != confirmPassword) {
      clickable = false;
    }

    // 验证验证码
    if (vCode.isEmpty || vCode.length < 6) {
      clickable = false;
    }

    if (clickable != _clickable) {
      setState(() {
        _clickable = clickable;
      });
    }
  }

  // 发送验证码
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
      return; // 防止重复点击
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
        // 注册成功
        if (mounted) {
          _showSuccessDialog(result.message);
        }
      } else {
        // 注册失败
        if (mounted) {
          _showErrorDialog(result.message);
        }
      }
    } catch (e) {
      // 处理未预期的错误
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

  // 显示成功对话框
  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('注册成功'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                NavigatorUtils.goBack(context); // 返回登录页面
              },
              child: const Text('去登录'),
            ),
          ],
        );
      },
    );
  }

  // 显示错误对话框
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('注册失败'),
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
      appBar: MyAppBar(
        title: DeerLocalizations.of(context)!.register,
      ),
      body: MyScrollView(
        keyboardConfig: Utils.getKeyboardActionsConfig(context, <FocusNode>[
          _nodeText1, _nodeText2, _nodeText3, _nodeText4, _nodeText5
        ]),
        crossAxisAlignment: CrossAxisAlignment.center,
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 20.0),
        children: _buildBody(),
      ),
    );
  }

  List<Widget> _buildBody() {
    return <Widget>[
      Text(
        DeerLocalizations.of(context)!.openYourAccount,
        style: TextStyles.textBold26,
      ),
      Gaps.vGap16,

      // 邮箱输入框
      MyTextField(
        key: const Key('email'),
        focusNode: _nodeText1,
        controller: _emailController,
        maxLength: 50,
        keyboardType: TextInputType.emailAddress,
        hintText: '请输入邮箱地址',
      ),
      Gaps.vGap8,

      // 用户名输入框
      MyTextField(
        key: const Key('username'),
        focusNode: _nodeText2,
        controller: _usernameController,
        maxLength: 20,
        keyboardType: TextInputType.text,
        hintText: '请输入用户名（3-20位字母数字下划线）',
      ),
      Gaps.vGap8,

      // 密码输入框
      MyTextField(
        key: const Key('password'),
        keyName: 'password',
        focusNode: _nodeText3,
        isInputPwd: true,
        controller: _passwordController,
        keyboardType: TextInputType.visiblePassword,
        hintText: '请输入密码（至少8位，包含字母和数字）',
      ),
      Gaps.vGap8,

      // 确认密码输入框
      MyTextField(
        key: const Key('confirmPassword'),
        keyName: 'confirmPassword',
        focusNode: _nodeText4,
        isInputPwd: true,
        controller: _confirmPasswordController,
        keyboardType: TextInputType.visiblePassword,
        hintText: '请再次输入密码',
      ),
      Gaps.vGap8,

      // 验证码输入框
      MyTextField(
        key: const Key('vcode'),
        focusNode: _nodeText5,
        controller: _vCodeController,
        keyboardType: TextInputType.number,
        getVCode: _sendVerificationCode,
        maxLength: 6,
        hintText: '请输入验证码',
      ),
      Gaps.vGap24,

      // 注册按钮
      MyButton(
        key: const Key('register'),
        onPressed: _clickable && !_isLoading ? _register : null,
        text: _isLoading ? '注册中...' : DeerLocalizations.of(context)!.register,
      ),

      Gaps.vGap16,

      // 密码要求说明
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '密码要求：',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '• 至少8位字符\n• 必须包含字母和数字',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      ),
    ];
  }
}
