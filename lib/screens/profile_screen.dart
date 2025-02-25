import 'package:flutter/material.dart';
import '../models/user_info_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/cache_service.dart';
import 'about_screen.dart';
import 'scores_screen.dart';
import 'rank_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final CacheService _cacheService = CacheService();  // 添加这一行
  UserInfo? _userInfo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    setState(() => _isLoading = true);
    try {
      // 先尝试从缓存加载
      final cachedData = await _cacheService.getCachedUserInfo();
      if (cachedData != null) {
        setState(() {
          _userInfo = UserInfo.fromJson(cachedData);
          _isLoading = false;
        });
      }

      // 从服务器获取最新数据
      final response = await ApiService().getUserInfo();
      if (response['code'] == 200 && response['data'] != null) {
        await _cacheService.cacheUserInfo(response['data']);
        if (mounted) {
          setState(() {
            _userInfo = UserInfo.fromJson(response['data']);
          });
        }
      } else {
        if (mounted && cachedData == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('获取个人信息失败: ${response['message']}')),
          );
        }
      }
    } catch (e) {
      print('加载用户信息失败: $e');
      if (mounted && _userInfo == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    try {
      // 1. 重置 API 客户端
      ApiService().reset();
      
      // 2. 清除所有缓存
      await _cacheService.clearAllCache();
      
      // 3. 清除登录凭证
      await StorageService().clearCredentials();
      
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      print('退出登录失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('退出登录失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('个人信息'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserInfo,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                if (_userInfo != null) ...[
                  _buildUserInfoCard(context),
                  _buildMenuItems(context),
                ],
              ],
            ),
    );
  }

  Widget _buildUserInfoCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    _userInfo!.name.isEmpty ? '?' : _userInfo!.name[0],
                    style: const TextStyle(fontSize: 32, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userInfo!.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _userInfo!.studentNumber,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            _buildInfoRow('性别', _userInfo!.genderText),
            _buildInfoRow('考生号', _userInfo!.exaNumber),
            _buildInfoRow('学院', _userInfo!.companyName),
            _buildInfoRow('专业', _userInfo!.officeName),
            _buildInfoRow('年级', '${_userInfo!.grade}级'),
            _buildInfoRow('班级', _userInfo!.formattedClassInfo),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItems(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.school),
            title: const Text('我的成绩'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _userInfo != null ? Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ScoresScreen(userInfo: _userInfo!),
              ),
            ) : null,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.leaderboard),
            title: const Text('班级排名'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const RankScreen()),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AboutScreen()),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.logout,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              '退出登录',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}
