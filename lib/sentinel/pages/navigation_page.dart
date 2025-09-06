import 'package:flutter/material.dart';

import 'enhanced_show_page.dart';
import 'home_page.dart';
import 'profile_page.dart';

/// 主导航页面，包含底部导航栏
class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;

  final List<BottomNavigationBarItem> _navigationItems = [
    const BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home),
      label: '首页',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.map_outlined),
      activeIcon: Icon(Icons.map),
      label: '地图',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: '我的',
    ),
  ];

  // 页面列表 - 使用懒加载
  late final List<Widget> _pages;
  final Set<int> _loadedPages = {0}; // 首页默认加载

  @override
  void initState() {
    super.initState();
    _pages = [
      const HomePage(), // 首页始终加载
      Container(), // 地图页面占位符，将在需要时加载
      Container(), // 个人页面占位符，将在需要时加载
    ];
  }

  // 为不同页面定义不同的AppBar
  PreferredSizeWidget? _getAppBarForIndex(int index) {
    switch (index) {
      case 0:
      // 首页的AppBar
        return AppBar(
          title: const Text("首页"),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        );
      case 1:
      // 地图页面的AppBar
        return AppBar(
          title: const Text("前瞻一号影像 + 多源卫星搜索"),
          centerTitle: true,
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        );
      case 2:
      // 个人页面的AppBar
        return AppBar(
          title: const Text("个人中心"),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        );
      default:
        return null;
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      // 懒加载页面
      if (!_loadedPages.contains(index)) {
        _pages[index] = _buildPageContent(index);
        _loadedPages.add(index);

        // 如果是地图页面，添加调试信息
        if (index == 1) {
          debugPrint('地图页面首次加载: ${DateTime.now()}');
        }
      }

      _currentIndex = index;
    });
  }

  Widget _buildPageContent(int index) {
    switch (index) {
      case 0:
        return const HomePage();
      case 1:
        debugPrint('创建地图页面组件');
        return const MobileEnhancedShowPageContent();
      case 2:
        return const ProfilePage();
      default:
        return Container();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _getAppBarForIndex(_currentIndex),
      // 使用 IndexedStack 替代 PageView
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          items: _navigationItems,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey.shade600,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 12,
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
