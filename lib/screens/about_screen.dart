import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/storage_service.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await StorageService().clearCredentials();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  Future<void> _launchGithub() async {
    final Uri url = Uri.parse('https://github.com/KNA7022/HIIT-Schedul');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('无法打开链接');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('关于'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: ListTile(
              title: const Text('开源地址'),
              subtitle: const Text('GitHub'),
              trailing: const Icon(Icons.open_in_new),
              onTap: _launchGithub,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '免责声明',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '本应用为第三方应用，与哈尔滨信息工程学院无关。'
                    '您的账号密码等个人信息仅储存在本地设备，不会上传至任何服务器。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '哈信息-我的课程表 v1.3.0',  // 更新版本号
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          Text(
            '作者联系方式：',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _buildContactItem(context, '微信：', 'KNA7022'),
          const SizedBox(height: 8),
          _buildContactItem(context, 'QQ：', '2597792343'),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            '隐私政策',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          _buildPrivacySection(
            context,
            '信息收集',
            [
              '本应用仅收集用户的登录凭证（用户名和密码）',
              '所有信息均存储在用户本地设备上',
              '不会将任何信息上传至任何服务器',
              '不会收集任何其他个人信息',
            ],
          ),
          const SizedBox(height: 16),
          _buildPrivacySection(
            context,
            '信息使用',
            [
              '收集的信息仅用于访问哈尔滨信息工程学院教务系统',
              '用于自动登录功能',
            ],
          ),
          const SizedBox(height: 16),
          _buildPrivacySection(
            context,
            '信息安全',
            [
              '所有信息仅保存在用户设备本地',
              '用户可以随时通过"退出登录"功能清除所有保存的信息',
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
              ),
              onPressed: () => _logout(context),
              child: const Text('退出登录'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildContactItem(BuildContext context, String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacySection(
    BuildContext context,
    String title,
    List<String> points,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...points.map((point) => Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• '),
              Expanded(
                child: Text(
                  point,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
}
