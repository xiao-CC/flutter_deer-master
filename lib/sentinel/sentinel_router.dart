import 'package:fluro/fluro.dart';
import 'package:flutter_deer/routers/i_router.dart';

import 'pages/enhanced_show_page.dart';
import 'pages/home_page.dart';
import 'pages/navigation_page.dart';
import 'pages/profile_page.dart';

class SentinelRouter implements IRouterProvider{

  static String enhancedShowPage = '/sentinel/enhancedShow';
  static String homePage = '/sentinel/home';
  static String navigationPage='/sentinel/navigation';
  static String profilePage = '/sentinel/profile';

  @override
  void initRouter(FluroRouter router) {

    router.define(enhancedShowPage, handler: Handler(handlerFunc: (_, __)=> const MobileEnhancedShowPage()));
    router.define(homePage, handler: Handler(handlerFunc: (_, __) => const HomePage()));
    router.define(navigationPage, handler: Handler(handlerFunc: (_, __) => const MainNavigationPage()));
    router.define(profilePage, handler: Handler(handlerFunc: (_, __) => const ProfilePage()));
  }
  
}
