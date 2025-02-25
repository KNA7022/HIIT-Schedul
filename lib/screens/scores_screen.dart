import 'package:flutter/material.dart';
import '../models/score_model.dart';
import '../models/user_info_model.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';

class ScoresScreen extends StatefulWidget {
  final UserInfo userInfo;
  
  const ScoresScreen({super.key, required this.userInfo});

  @override
  State<ScoresScreen> createState() => _ScoresScreenState();
}

class _ScoresScreenState extends State<ScoresScreen> {
  final ApiService _apiService = ApiService();
  final CacheService _cacheService = CacheService();
  List<String> _terms = [];
  Map<String, TermScores> _termScores = {};
  bool _isLoading = true;
  String? _selectedTerm;

  @override
  void initState() {
    super.initState();
    _loadTerms();
  }

  Future<void> _loadTerms() async {
    try {
      // 先尝试从缓存加载学期列表
      final cachedTerms = await _cacheService.getCachedTermList();
      if (cachedTerms != null) {
        setState(() {
          _terms = cachedTerms;
          _selectedTerm = cachedTerms.isNotEmpty ? cachedTerms.first : null;
        });
        _loadSelectedTermScores();
      }

      // 获取最新的学期列表
      final terms = await _apiService.getTerms();
      if (terms.isNotEmpty) {
        await _cacheService.cacheTermList(terms);
        setState(() {
          _terms = terms;
          _selectedTerm ??= terms.first;
        });
        _loadSelectedTermScores();
      }
    } catch (e) {
      print('加载学期列表失败: $e');
    }
  }

  Future<void> _loadSelectedTermScores() async {
    if (_selectedTerm == null) return;
    
    setState(() => _isLoading = true);
    try {
      // 先尝试从缓存加载成绩
      final cachedScores = await _cacheService.getCachedTermScores(_selectedTerm!);
      if (cachedScores != null) {
        _processScores(_selectedTerm!, cachedScores);
      }

      // 获取最新成绩
      final response = await _apiService.getTermScores(
        _selectedTerm!,
        widget.userInfo.studentNumber,
      );
      
      if (response['code'] == 200) {
        await _cacheService.cacheTermScores(_selectedTerm!, response);
        _processScores(_selectedTerm!, response);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _processScores(String term, Map<String, dynamic> data) {
    if (data['data'] == null || 
        data['data']['collect'] == null) return;

    final scores = (data['data']['collect'] as List)
        .map((item) => ScoreInfo.fromJson(item))
        .toList();
    
    setState(() {
      _termScores[term] = TermScores(term, scores);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('成绩查询'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSelectedTermScores,
            tooltip: '刷新',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTermSelector(),
          if (_selectedTerm != null && _termScores.containsKey(_selectedTerm!))
            _buildTermSummary(_termScores[_selectedTerm!]!),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildScoresList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTermSelector() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: DropdownButton<String>(
          value: _selectedTerm,
          isExpanded: true,
          hint: const Text('选择学期'),
          items: _terms.map((term) {
            return DropdownMenuItem(
              value: term,
              child: Text(term),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null && value != _selectedTerm) {
              setState(() => _selectedTerm = value);
              _loadSelectedTermScores();
            }
          },
        ),
      ),
    );
  }

  Widget _buildTermSummary(TermScores termScores) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                Text(
                  'GPA',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  termScores.averageGPA.toStringAsFixed(2),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Column(
              children: [
                Text(
                  '总学分',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  termScores.totalCredits.toString(),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoresList() {
    if (_selectedTerm == null || !_termScores.containsKey(_selectedTerm!)) {
      return const Center(child: Text('暂无成绩数据'));
    }

    final scores = _termScores[_selectedTerm!]!.scores;
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: scores.length,
      itemBuilder: (context, index) {
        final score = scores[index];
        return Card(
          child: ListTile(
            title: Text(
              score.courseName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('任课教师: ${score.teacherName}'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('平时: ${score.classEvaValue}'),
                    const SizedBox(width: 16),
                    Text('期末: ${score.evaValue}'),
                    const SizedBox(width: 16),
                    Text('最终: ${score.finEvaValue}'),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('学分: ${score.credit}'),
                    const SizedBox(width: 16),
                    Text('绩点: ${score.point}'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
