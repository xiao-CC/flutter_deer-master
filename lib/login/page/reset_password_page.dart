import 'package:flutter/material.dart';
import 'package:flutter_deer/login/widgets/my_text_field.dart';
import 'package:flutter_deer/res/resources.dart';
import 'package:flutter_deer/util/change_notifier_manage.dart';
import 'package:flutter_deer/util/other_utils.dart';
import 'package:flutter_deer/util/toast_utils.dart';
import 'package:flutter_deer/widgets/my_app_bar.dart';
import 'package:flutter_deer/widgets/my_button.dart';
import 'package:flutter_deer/widgets/my_scroll_view.dart';
import '../../l10n/deer_localizations.dart';
import '../../services/reset_password_service.dart';

/// design/1注册登录/index.html#artboard9
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  _ResetPasswordPageState createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> with ChangeNotifierMixin<ResetPasswordPage> {
  // 定义controller
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _vCodeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // 焦点节点
  final FocusNode _nodeText1 = FocusNode();
  final FocusNode _nodeText2 = FocusNode();
  final FocusNode _nodeText3 = FocusNode();
  final FocusNode _nodeText4 = FocusNode();

  bool _clickable = false;
  bool _isLoading = false;
  bool _isCodeSending = false;

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

    // 验证邮箱
    if (email.isEmpty || !PasswordResetService.isValidEmail(email)) {
      clickable = false;
    }

    // 验证验证码
    if (vCode.isEmpty || vCode.length < 6) {
      clickable = false;
    }

    // 验证密码
    if (password.isEmpty || !PasswordResetService.isValidPassword(password)) {
      clickable = false;
    }

    // 验证确认密码
    if (confirmPassword.isEmpty || password != confirmPassword) {
      clickable = false;
    }

    if (clickable != _clickable) {
      setState(() {
        _clickable = clickable;
      });
    }
  }

  /// 发送验证码
  Future<bool> _sendVerificationCode() async {
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

  /// 重置密码
  void _resetPassword() async {
    if (_isLoading) return;

    final String email = _emailController.text;
    final String vCode = _vCodeController.text;
    final String password = _passwordController.text;
    final String confirmPassword = _confirmPasswordController.text;

    // 再次验证
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

      // 延迟1秒后返回登录页
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
      appBar: MyAppBar(
        title: DeerLocalizations.of(context)!.forgotPasswordLink,
      ),
      body: MyScrollView(
        keyboardConfig: Utils.getKeyboardActionsConfig(
            context,
            <FocusNode>[_nodeText1, _nodeText2, _nodeText3, _nodeText4]
        ),
        crossAxisAlignment: CrossAxisAlignment.center,
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 20.0),
        children: _buildBody(),
      ),
    );
  }

  List<Widget> _buildBody() {
    return <Widget>[
      Text(
        DeerLocalizations.of(context)!.resetLoginPassword,
        style: TextStyles.textBold26,
      ),
      Gaps.vGap16,

      // 邮箱输入
      MyTextField(
        focusNode: _nodeText1,
        controller: _emailController,
        maxLength: 50,
        keyboardType: TextInputType.emailAddress,
        hintText: '请输入邮箱地址',
      ),
      Gaps.vGap8,

      // 验证码输入
      MyTextField(
        focusNode: _nodeText2,
        controller: _vCodeController,
        keyboardType: TextInputType.number,
        getVCode: _isCodeSending ? null : _sendVerificationCode,
        maxLength: 6,
        hintText: DeerLocalizations.of(context)!.inputVerificationCodeHint,
      ),
      Gaps.vGap8,

      // 新密码输入
      MyTextField(
        focusNode: _nodeText3,
        isInputPwd: true,
        controller: _passwordController,
        keyboardType: TextInputType.visiblePassword,
        hintText: '请输入新密码（至少6位，包含字母和数字）',
      ),
      Gaps.vGap8,

      // 确认密码输入
      MyTextField(
        focusNode: _nodeText4,
        isInputPwd: true,
        controller: _confirmPasswordController,
        keyboardType: TextInputType.visiblePassword,
        hintText: '请再次输入新密码',
      ),
      Gaps.vGap24,

      // 重置密码按钮
      MyButton(
        onPressed: (_clickable && !_isLoading) ? _resetPassword : null,
        text: _isLoading ? '重置中...' : DeerLocalizations.of(context)!.confirm,
      ),
    ];
  }

  @override
  void dispose() {
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
