import 'package:flutter/material.dart';
import '../models/rank_model.dart';
import '../services/api_service.dart';

class RankScreen extends StatefulWidget {
  const RankScreen({super.key});

  @override
  State<RankScreen> createState() => _RankScreenState();
}

class _RankScreenState extends State<RankScreen> {
  List<RankInfo> _rankList = [];
  bool _isLoading = true;
  String _className = '';

  @override
  void initState() {
    super.initState();
    _loadRankList();
  }

  Future<void> _loadRankList() async {
    setState(() => _isLoading = true);
    try {
      final rankList = await ApiService().getRankList();
      setState(() {
        _rankList = rankList;
        if (rankList.isNotEmpty) {
          _className = rankList.first.className;
        }
        _isLoading = false;
      });
    } catch (e) {
      print('加载排名失败: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
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
}
