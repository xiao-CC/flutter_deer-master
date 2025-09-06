import 'package:flutter/material.dart';

/// 我的页面
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  String _mapQuality = 'high'; // high, medium, low

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // 移除了 Scaffold，只返回页面内容
    return Container(
      color: Colors.grey.shade50,
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildUserProfileSection(),
              const SizedBox(height: 20),
              _buildStatsSection(),
              const SizedBox(height: 20),
              _buildMenuSection(),
              const SizedBox(height: 20),
              _buildAboutSection(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建用户信息区域
  Widget _buildUserProfileSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.blue.shade50,
                child: Icon(
                  Icons.person,
                  size: 40,
                  color: Colors.blue.shade600,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.edit,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '访客用户',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'guest@satellite-platform.com',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildProfileStat('搜索次数', '23'),
              Container(
                height: 30,
                width: 1,
                color: Colors.grey.shade300,
              ),
              _buildProfileStat('下载量', '156MB'),
              Container(
                height: 30,
                width: 1,
                color: Colors.grey.shade300,
              ),
              _buildProfileStat('使用天数', '12'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showLoginDialog(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '登录账户',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 个人统计项
  Widget _buildProfileStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  /// 构建统计数据区域
  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.search,
              title: '今日搜索',
              value: '5',
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.download,
              title: '今日下载',
              value: '12MB',
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.access_time,
              title: '使用时长',
              value: '2.5h',
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  /// 统计卡片
  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 构建功能菜单区域
  Widget _buildMenuSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildMenuGroup([
            _buildMenuItem(
              icon: Icons.history,
              title: '搜索历史',
              subtitle: '查看过往搜索记录',
              onTap: () => _showComingSoon('搜索历史'),
            ),
            _buildMenuItem(
              icon: Icons.bookmark,
              title: '收藏夹',
              subtitle: '管理收藏的影像数据',
              onTap: () => _showComingSoon('收藏夹'),
            ),
            _buildMenuItem(
              icon: Icons.download,
              title: '下载管理',
              subtitle: '查看下载进度和历史',
              onTap: () => _showComingSoon('下载管理'),
            ),
          ]),
          const SizedBox(height: 16),
          _buildMenuGroup([
            _buildMenuItem(
              icon: Icons.settings_outlined,
              title: '应用设置',
              subtitle: '通知、主题和其他偏好设置',
              onTap: () => _showSettingsDialog(),
            ),
            _buildMenuItem(
              icon: Icons.help_outline,
              title: '帮助中心',
              subtitle: '使用指南和常见问题',
              onTap: () => _showHelpDialog(),
            ),
            _buildMenuItem(
              icon: Icons.feedback,
              title: '意见反馈',
              subtitle: '提交建议和问题反馈',
              onTap: () => _showFeedbackDialog(),
            ),
            _buildMenuItem(
              icon: Icons.info_outline,
              title: '关于应用',
              subtitle: '版本信息和开发团队',
              onTap: () => _showAboutDialog(),
            ),
          ]),
        ],
      ),
    );
  }

  /// 菜单分组
  Widget _buildMenuGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: children.asMap().entries.map((entry) {
          final index = entry.key;
          final child = entry.value;
          return Column(
            children: [
              child,
              if (index < children.length - 1)
                Divider(height: 1, color: Colors.grey.shade200),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// 菜单项
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: Colors.grey.shade700,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey.shade400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建关于区域
  Widget _buildAboutSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey.shade100,
            Colors.grey.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.satellite_alt,
            size: 48,
            color: Colors.blue.shade600,
          ),
          const SizedBox(height: 12),
          const Text(
            '卫星影像平台',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'v1.0.0',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '提供多源卫星影像数据查询、可视化和下载服务',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 显示设置对话框
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.settings, color: Colors.blue, size: 24),
              SizedBox(width: 8),
              Text('应用设置'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('推送通知'),
                subtitle: const Text('接收搜索结果和更新通知'),
                value: _notificationsEnabled,
                onChanged: (value) {
                  setState(() {
                    _notificationsEnabled = value;
                  });
                  this.setState(() {
                    _notificationsEnabled = value;
                  });
                },
              ),
              SwitchListTile(
                title: const Text('深色模式'),
                subtitle: const Text('启用深色主题'),
                value: _darkModeEnabled,
                onChanged: (value) {
                  setState(() {
                    _darkModeEnabled = value;
                  });
                  this.setState(() {
                    _darkModeEnabled = value;
                  });
                  _showComingSoon('深色模式');
                },
              ),
              ListTile(
                title: const Text('地图质量'),
                subtitle: Text(_getMapQualityText(_mapQuality)),
                trailing: DropdownButton<String>(
                  value: _mapQuality,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _mapQuality = value;
                      });
                      this.setState(() {
                        _mapQuality = value;
                      });
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: 'high', child: Text('高')),
                    DropdownMenuItem(value: 'medium', child: Text('中')),
                    DropdownMenuItem(value: 'low', child: Text('低')),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      ),
    );
  }

  /// 获取地图质量文本
  String _getMapQualityText(String quality) {
    switch (quality) {
      case 'high':
        return '高质量（更多流量）';
      case 'medium':
        return '中等质量（平衡）';
      case 'low':
        return '低质量（节省流量）';
      default:
        return '中等质量';
    }
  }

  /// 显示登录对话框
  void _showLoginDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.login, color: Colors.blue, size: 24),
            SizedBox(width: 8),
            Text('用户登录'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: '用户名或邮箱',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: '密码',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showComingSoon('用户登录');
            },
            child: const Text('登录'),
          ),
        ],
      ),
    );
  }

  /// 显示帮助对话框
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help, color: Colors.blue, size: 24),
            SizedBox(width: 8),
            Text('帮助中心'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('常见问题：'),
            SizedBox(height: 8),
            Text('• 如何搜索卫星影像？'),
            Text('• 支持哪些数据格式？'),
            Text('• 如何下载影像数据？'),
            Text('• 搜索结果为空怎么办？'),
            SizedBox(height: 12),
            Text('更多帮助信息请访问官方文档。'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 显示反馈对话框
  void _showFeedbackDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.feedback, color: Colors.blue, size: 24),
            SizedBox(width: 8),
            Text('意见反馈'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              maxLines: 4,
              decoration: InputDecoration(
                labelText: '请输入您的意见或建议',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                labelText: '联系方式（可选）',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('感谢您的反馈！')),
              );
            },
            child: const Text('提交'),
          ),
        ],
      ),
    );
  }

  /// 显示关于对话框
  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: '卫星影像平台',
      applicationVersion: '1.0.0',
      applicationIcon: Icon(
        Icons.satellite_alt,
        size: 48,
        color: Colors.blue.shade600,
      ),
      children: const [
        Text('多源卫星影像数据查询和可视化平台'),
        SizedBox(height: 8),
        Text('支持哨兵-2、Landsat、吉林一号等多种数据源'),
        SizedBox(height: 8),
        Text('© 2025 Geomaper影像平台团队'),
      ],
    );
  }

  /// 显示即将推出提示
  void _showComingSoon(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.rocket_launch, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Text('即将推出'),
          ],
        ),
        content: Text('$feature 功能正在开发中，敬请期待！'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}