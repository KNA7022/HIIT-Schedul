import 'package:flutter/material.dart';
import '../models/rank_model.dart';
import '../services/api_service.dart';
import '../services/network_service.dart';
import '../services/cache_service.dart';

class RankScreen extends StatefulWidget {
  const RankScreen({super.key});

  @override
  State<RankScreen> createState() => _RankScreenState();
}

class _RankScreenState extends State<RankScreen> {
  List<RankInfo> _rankList = [];
  bool _isLoading = true;
  String _className = '';
  final ApiService _apiService = ApiService();
  final CacheService _cacheService = CacheService();
  final NetworkService _networkService = NetworkService();

  @override
  void initState() {
    super.initState();
    _loadRankList();
  }

  Future<void> _loadRankList() async {
    setState(() => _isLoading = true);

    try {
      // 先尝试从缓存加载
      final cachedRanks = await _cacheService.getCachedRankList();
      if (cachedRanks != null) {
        setState(() {
          _rankList = List<RankInfo>.from(cachedRanks.map((r) => RankInfo.fromJson(r)));
          _processRankData();
        });
      }

      // 如果不是离线模式，则从服务器获取最新数据
      if (!_networkService.isOfflineMode) {
        final ranks = await _apiService.getRankList();
        if (ranks.isNotEmpty) {
          await _cacheService.cacheRankList(ranks);
          if (mounted) {
            setState(() {
              _rankList = ranks;
              _processRankData();
            });
          }
        }
      }
    } catch (e) {
      print('加载排名失败: $e');
      if (mounted && _rankList.isEmpty) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_className.isEmpty ? '班级排名' : '$_className 排名'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRankList,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rankList.isEmpty
              ? const Center(child: Text('暂无排名数据'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _rankList.length,
                  itemBuilder: (context, index) {
                    final rank = _rankList[index];
                    return Card(
                      elevation: rank.isSelf ? 4 : 1,
                      color: rank.isSelf 
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getRankColor(context, index),
                          child: Text(
                            '${rank.rank.toInt()}',
                            style: TextStyle(
                              color: index < 3 
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        title: Text(
                          rank.studentName.isEmpty 
                              ? '同学${rank.studentNumber.substring(6)}'
                              : rank.studentName,
                          style: TextStyle(
                            fontWeight: rank.isSelf 
                                ? FontWeight.bold 
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'GPA: ${rank.average.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: rank.isSelf
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                              ),
                            ),
                            Text(
                              '总学分: ${rank.credit.toStringAsFixed(1)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        trailing: rank.isSelf
                            ? Icon(
                                Icons.person,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                      ),
                    );
                  },
                ),
    );
  }

  Color _getRankColor(BuildContext context, int index) {
    switch (index) {
      case 0:
        return Colors.amber;
      case 1:
        return Colors.grey.shade400;
      case 2:
        return Colors.brown.shade300;
      default:
        return Theme.of(context).colorScheme.surfaceVariant;
    }
  }

  void _processRankData() {
    if (_rankList.isNotEmpty) {
      // 找到自己的数据来获取班级名称
      final selfData = _rankList.firstWhere(
        (rank) => rank.isSelf,
        orElse: () => _rankList.first,
      );
      setState(() {
        _className = selfData.className;
      });
    }
  }
}
