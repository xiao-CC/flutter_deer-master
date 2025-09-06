import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_deer/login/widgets/my_text_field.dart';
import 'package:flutter_deer/res/resources.dart';
import 'package:flutter_deer/routers/fluro_navigator.dart';
import 'package:flutter_deer/util/change_notifier_manage.dart';
import 'package:flutter_deer/util/other_utils.dart';
import 'package:flutter_deer/widgets/my_app_bar.dart';
import 'package:flutter_deer/widgets/my_button.dart';
import 'package:flutter_deer/widgets/my_scroll_view.dart';
import 'package:sp_util/sp_util.dart';

import '../../l10n/deer_localizations.dart';
import '../../sentinel/pages/enhanced_show_page.dart';
import '../../sentinel/sentinel_router.dart';
import '../../services/auth_service.dart';
import '../login_router.dart';

/// design/1注册登录/index.html
class LoginPage extends StatefulWidget {

  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with ChangeNotifierMixin<LoginPage> {
  //定义一个controller
  final TextEditingController _emailController = TextEditingController();  // 改为email
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _nodeText1 = FocusNode();
  final FocusNode _nodeText2 = FocusNode();
  bool _clickable = false;
  bool _isLoading = false; // 添加加载状态

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
      /// 显示状态栏和导航栏
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
    });
    // 加载之前保存的邮箱
    _emailController.text = SpUtil.getString('saved_email') ?? '';
  }

  void _verify() {
    final String email = _emailController.text;
    final String password = _passwordController.text;
    bool clickable = true;

    // 验证邮箱格式
    if (email.isEmpty || !AuthService.isValidEmail(email)) {
      clickable = false;
    }

    // 验证密码长度
    if (password.isEmpty || password.length < 6) {
      clickable = false;
    }

    /// 状态不一样再刷新，避免不必要的setState
    if (clickable != _clickable) {
      setState(() {
        _clickable = clickable;
      });
    }
  }

  void _login() async {
    if (_isLoading) {
      return; // 防止重复点击
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await AuthService.login(
        email: _emailController.text,     // 改为email参数
        password: _passwordController.text,
      );

      if (result.success) {

        // 显示成功消息
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
        // 登录失败，显示错误信息
        if (mounted) {
          _showErrorDialog(result.message);
        }
      }
    } catch (e) {
      // 处理未预期的错误
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

  // 显示错误对话框
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
      appBar: MyAppBar(
        isBack: false,
        actionName: DeerLocalizations.of(context)!.verificationCodeLogin,
        onPressed: () {
          NavigatorUtils.push(context, LoginRouter.smsLoginPage);
        },
      ),
      body: MyScrollView(
        keyboardConfig: Utils.getKeyboardActionsConfig(context, <FocusNode>[_nodeText1, _nodeText2]),
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 20.0),
        children: _buildBody,
      ),
    );
  }

  List<Widget> get _buildBody => <Widget>[
    Text(
      DeerLocalizations.of(context)!.passwordLogin,
      style: TextStyles.textBold26,
    ),
    Gaps.vGap16,
    MyTextField(
      key: const Key('email'),              // 改为email key
      focusNode: _nodeText1,
      controller: _emailController,         // 改为email controller
      maxLength: 50,                        // 邮箱长度限制调整
      keyboardType: TextInputType.emailAddress,  // 改为邮箱键盘类型
      hintText: '请输入邮箱地址',             // 修改提示文本
    ),
    Gaps.vGap8,
    MyTextField(
      key: const Key('password'),
      keyName: 'password',
      focusNode: _nodeText2,
      isInputPwd: true,
      controller: _passwordController,
      keyboardType: TextInputType.visiblePassword,
      hintText: DeerLocalizations.of(context)!.inputPasswordHint,
    ),
    Gaps.vGap24,
    MyButton(
      key: const Key('Login'),
      onPressed: _clickable && !_isLoading ? _login : null,  // 加载时禁用按钮
      text: _isLoading ? '登录中...' : DeerLocalizations.of(context)!.login,  // 显示加载状态
    ),
    MyButton(
      key: const Key('weChatLogin'),
      onPressed: () => NavigatorUtils.push(context, LoginRouter.weChatLoginPage),
      text: DeerLocalizations.of(context)!.weChatLogin,
    ),
    Container(
      height: 40.0,
      alignment: Alignment.centerRight,
      child: GestureDetector(
        child: Text(
          DeerLocalizations.of(context)!.forgotPasswordLink,
          key: const Key('forgotPassword'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        onTap: () => NavigatorUtils.push(context, LoginRouter.resetPasswordPage),
      ),
    ),
    Gaps.vGap16,
    Container(
        alignment: Alignment.center,
        child: GestureDetector(
          child: Text(
            DeerLocalizations.of(context)!.noAccountRegisterLink,
            key: const Key('noAccountRegister'),
            style: TextStyle(
                color: Theme.of(context).primaryColor
            ),
          ),
          onTap: () => NavigatorUtils.push(context, LoginRouter.registerPage),
        )
    )
  ];
}
