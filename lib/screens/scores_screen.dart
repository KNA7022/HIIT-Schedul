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

  // 添加总体统计属性
  double _totalGPA = 0.0;
  double _totalCredits = 0.0;

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
        
        // 加载所有学期成绩计算总GPA
        await _loadAllTermsScores(terms);
        
        _loadSelectedTermScores();
      }
    } catch (e) {
      print('加载学期列表失败: $e');
    }
  }

  Future<void> _loadAllTermsScores(List<String> terms) async {
    double totalPoints = 0.0;
    int totalCourses = 0;
    double totalCredits = 0.0;  // 添加总学分统计

    for (var term in terms) {
      try {
        Map<String, dynamic>? scoreData = await _cacheService.getCachedTermScores(term);
        
        if (scoreData == null) {
          final response = await _apiService.getTermScores(term, widget.userInfo.studentNumber);
          if (response['code'] == 200) {
            scoreData = response;
            await _cacheService.cacheTermScores(term, response);
          }
        }

        if (scoreData != null && 
            scoreData['data'] != null && 
            scoreData['data']['collect'] != null) {
          final scores = (scoreData['data']['collect'] as List)
              .map((item) => ScoreInfo.fromJson(item))
              .toList();
          
          for (var score in scores) {
            totalPoints += score.gpa;
            totalCourses++;
            totalCredits += score.creditValue;  // 累加每门课的学分
          }
        }
      } catch (e) {
        print('加载 $term 学期成绩失败: $e');
      }
    }

    if (mounted) {
      setState(() {
        _totalGPA = totalCourses > 0 
            ? double.parse((totalPoints / totalCourses).toStringAsFixed(1))
            : 0.0;
        _totalCredits = double.parse(totalCredits.toStringAsFixed(1));  // 直接使用累加的总学分
      });
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
            onPressed: () {
              _loadSelectedTermScores();
              _loadAllTermsScores(_terms); // 刷新总体统计
            },
            tooltip: '刷新',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildOverallSummary(), // 添加总体统计卡片
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

  Widget _buildOverallSummary() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '总体统计',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      '总 GPA',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      _totalGPA.toStringAsFixed(1),  // 修改为一位小数
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
                      _totalCredits.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropdownButtonFormField<String>(
        value: _selectedTerm,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: '选择学期',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
        ),
        icon: Icon(
          Icons.expand_more_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
        elevation: 4,
        dropdownColor: Theme.of(context).colorScheme.surface,
        menuMaxHeight: MediaQuery.of(context).size.height * 0.5,
        style: Theme.of(context).textTheme.bodyLarge,
        items: _terms.map((term) {
          return DropdownMenuItem(
            value: term,
            child: Text(
              term,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null && value != _selectedTerm) {
            setState(() => _selectedTerm = value);
            _loadSelectedTermScores();
          }
        },
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
                  termScores.averageGPA.toStringAsFixed(1),  // 修改为一位小数
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
        final needsRetake = score.needsRetake;
        
        return Card(
          color: needsRetake 
              ? Theme.of(context).colorScheme.errorContainer.withOpacity(0.5)
              : null,
          child: ListTile(
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    score.courseName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (needsRetake)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '需补考',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onError,
                      ),
                    ),
                  ),
              ],
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
                    Text('期末: ${score.finEvaValue}'),  //显示期末成绩
                    const SizedBox(width: 16),
                    Text(
                      '最终: ${score.evaValue}',  // 显示最终成绩
                      style: TextStyle(
                        color: needsRetake 
                            ? Theme.of(context).colorScheme.error 
                            : null,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
