import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_deer/demo/demo_page.dart';
import 'package:flutter_deer/login/login_router.dart';
import 'package:flutter_deer/routers/fluro_navigator.dart';
import 'package:flutter_deer/util/app_navigator.dart';
import 'package:flutter_deer/util/device_utils.dart';
import 'package:flutter_deer/util/theme_utils.dart';
import 'package:flutter_deer/widgets/fractionally_aligned_sized_box.dart';
import 'package:flutter_deer/widgets/load_image.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sp_util/sp_util.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  _SplashPageState createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  StreamSubscription<dynamic>? _subscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await SpUtil.getInstance();
      await Device.initDeviceInfo();
      _initSplash();
    });

    if (Device.isAndroid) {
      const QuickActions quickActions = QuickActions();
      quickActions.initialize((String shortcutType) async {
        if (shortcutType == 'demo') {
          AppNavigator.pushReplacement(context, const DemoPage());
          _subscription?.cancel();
        }
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _initSplash() {
    _subscription = Stream.value(1).delay(const Duration(milliseconds: 1500)).listen((_) {
      _goLogin();
    });
  }

  void _goLogin() {
    NavigatorUtils.push(context, LoginRouter.loginPage, replace: true);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.backgroundColor,
      child: const FractionallyAlignedSizedBox(
          heightFactor: 0.3,
          widthFactor: 0.33,
          leftFactor: 0.33,
          bottomFactor: 0,
          child: LoadAssetImage('mylogo')
      ),
    );
  }
}
