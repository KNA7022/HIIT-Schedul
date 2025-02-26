import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rank_model.dart';  // 添加这行导入

class CacheService {
  static const Duration _cacheValidity = Duration(hours: 24);
  static const String _prefixWeek = 'week_';
  static const String _prefixCourseDetail = 'course_';
  static const String _keyLastCleanup = 'last_cache_cleanup';
  static const String _keyUserInfo = 'cached_user_info';
  static const String _prefixTermScores = 'term_scores_';
  static const String _keyTermList = 'term_list';
  static const String _keyRankList = 'rank_list';  // 添加排名缓存的键名
  static const String _keySemesterInfo = 'semester_info';

  // 缓存周数据
  Future<void> cacheWeekSchedule(int week, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheData = {
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
      'week': week,
    };
    await prefs.setString('$_prefixWeek$week', jsonEncode(cacheData));
    print('已缓存第 $week 周数据');
    
    // 定期清理过期缓存
    await _performCacheCleanup();
  }

  // 获取周缓存
  Future<Map<String, dynamic>?> getCachedWeekSchedule(int week) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('$_prefixWeek$week');
    
    if (cached == null) {
      print('第 $week 周无缓存数据');
      return null;
    }

    try {
      final cachedData = jsonDecode(cached) as Map<String, dynamic>;
      final timestamp = DateTime.parse(cachedData['timestamp'] as String);
      
      if (DateTime.now().difference(timestamp) > _cacheValidity) {
        print('第 $week 周缓存数据已过期');
        await prefs.remove('$_prefixWeek$week');
        return null;
      }

      print('使用第 $week 周缓存数据');
      return cachedData['data'] as Map<String, dynamic>;
    } catch (e) {
      print('解析缓存数据失败: $e');
      await prefs.remove('$_prefixWeek$week');
      return null;
    }
  }

  // 缓存课程详细信息
  Future<void> cacheCourseDetail(String timeAdd, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheData = {
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await prefs.setString('$_prefixCourseDetail$timeAdd', jsonEncode(cacheData));
  }

  // 获取课程详细信息缓存
  Future<Map<String, dynamic>?> getCachedCourseDetail(String timeAdd) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('$_prefixCourseDetail$timeAdd');
    
    if (cached == null) return null;

    try {
      final cachedData = jsonDecode(cached) as Map<String, dynamic>;
      final timestamp = DateTime.parse(cachedData['timestamp'] as String);
      
      if (DateTime.now().difference(timestamp) > _cacheValidity) {
        await prefs.remove('$_prefixCourseDetail$timeAdd');
        return null;
      }

      return cachedData['data'] as Map<String, dynamic>;
    } catch (e) {
      await prefs.remove('$_prefixCourseDetail$timeAdd');
      return null;
    }
  }

  Future<void> cacheUserInfo(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheData = {
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_keyUserInfo, jsonEncode(cacheData));
    print('已缓存用户信息');
  }

  Future<Map<String, dynamic>?> getCachedUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_keyUserInfo);
    
    if (cached == null) return null;

    try {
      final cachedData = jsonDecode(cached) as Map<String, dynamic>;
      final timestamp = DateTime.parse(cachedData['timestamp'] as String);
      
      if (DateTime.now().difference(timestamp) > _cacheValidity) {
        await prefs.remove(_keyUserInfo);
        return null;
      }

      return cachedData['data'] as Map<String, dynamic>;
    } catch (e) {
      print('解析用户信息缓存失败: $e');
      await prefs.remove(_keyUserInfo);
      return null;
    }
  }

  Future<void> cacheTermList(List<String> terms) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheData = {
      'data': terms,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_keyTermList, jsonEncode(cacheData));
  }

  Future<List<String>?> getCachedTermList() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_keyTermList);
    if (cached == null) return null;

    try {
      final cachedData = jsonDecode(cached) as Map<String, dynamic>;
      final timestamp = DateTime.parse(cachedData['timestamp'] as String);
      
      if (DateTime.now().difference(timestamp) > _cacheValidity) {
        await prefs.remove(_keyTermList);
        return null;
      }
      return List<String>.from(cachedData['data']);
    } catch (e) {
      await prefs.remove(_keyTermList);
      return null;
    }
  }

  Future<void> cacheTermScores(String term, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheData = {
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await prefs.setString('$_prefixTermScores$term', jsonEncode(cacheData));
  }

  Future<Map<String, dynamic>?> getCachedTermScores(String term) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('$_prefixTermScores$term');
    if (cached == null) return null;

    try {
      final cachedData = jsonDecode(cached) as Map<String, dynamic>;
      final timestamp = DateTime.parse(cachedData['timestamp'] as String);
      
      if (DateTime.now().difference(timestamp) > _cacheValidity) {
        await prefs.remove('$_prefixTermScores$term');
        return null;
      }
      return cachedData['data'] as Map<String, dynamic>;
    } catch (e) {
      await prefs.remove('$_prefixTermScores$term');
      return null;
    }
  }

  Future<void> cacheSemesterInfo(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheData = {
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_keySemesterInfo, jsonEncode(cacheData));
  }

  Future<Map<String, dynamic>?> getCachedSemesterInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_keySemesterInfo);
    if (cached == null) return null;

    try {
      final cachedData = jsonDecode(cached) as Map<String, dynamic>;
      final timestamp = DateTime.parse(cachedData['timestamp'] as String);
      
      if (DateTime.now().difference(timestamp) > _cacheValidity) {
        await prefs.remove(_keySemesterInfo);
        return null;
      }
      return cachedData['data'] as Map<String, dynamic>;
    } catch (e) {
      await prefs.remove(_keySemesterInfo);
      return null;
    }
  }

  // 定期清理过期缓存
  Future<void> _performCacheCleanup() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCleanup = prefs.getString(_keyLastCleanup);
    final now = DateTime.now();

    // 每24小时执行一次清理
    if (lastCleanup != null) {
      final lastCleanupTime = DateTime.parse(lastCleanup);
      if (now.difference(lastCleanupTime) < const Duration(hours: 24)) {
        return;
      }
    }

    // 清理过期缓存
    final keys = prefs.getKeys();
    for (var key in keys) {
      if (key.startsWith(_prefixWeek) || key.startsWith(_prefixCourseDetail)) {
        try {
          final data = jsonDecode(prefs.getString(key)!) as Map<String, dynamic>;
          final timestamp = DateTime.parse(data['timestamp'] as String);
          if (now.difference(timestamp) > _cacheValidity) {
            await prefs.remove(key);
          }
        } catch (e) {
          await prefs.remove(key);
        }
      }
    }

    await prefs.setString(_keyLastCleanup, now.toIso8601String());
  }

  // 预加载相邻周的数据
  Future<void> preloadAdjacentWeeks(int currentWeek, Future<Map<String, dynamic>> Function(int) fetcher) async {
    final weeks = [
      if (currentWeek > 1) currentWeek - 1,
      if (currentWeek < 20) currentWeek + 1,
    ];

    for (final week in weeks) {
      if (await getCachedWeekSchedule(week) == null) {
        try {
          final data = await fetcher(week);
          await cacheWeekSchedule(week, data);
        } catch (e) {
          print('预加载第 $week 周数据失败: $e');
        }
      }
    }
  }

  Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 获取所有键
      final keys = prefs.getKeys();
      print('开始清理缓存，找到 ${keys.length} 个缓存项');

      // 需要清理的前缀和键名列表
      final prefixesToClear = [_prefixWeek, _prefixCourseDetail, _prefixTermScores];
      final keysToRemove = [
        _keyLastCleanup,
        _keyUserInfo,
        _keyTermList,
        _keyRankList,
        _keySemesterInfo,  // 添加学期信息缓存键
      ];

      // 按前缀清理
      for (var prefix in prefixesToClear) {
        final matchingKeys = keys.where((key) => key.startsWith(prefix)).toList();
        print('清理 $prefix 相关缓存: ${matchingKeys.length} 项');
        for (var key in matchingKeys) {
          await prefs.remove(key);
        }
      }

      // 清理特定键
      for (var key in keysToRemove) {
        if (prefs.containsKey(key)) {
          await prefs.remove(key);
          print('清理缓存: $key');
        }
      }

      print('缓存清理完成');
    } catch (e) {
      print('清理缓存时出错: $e');
      rethrow;
    }
  }

  // 添加排名缓存相关方法
  Future<List<Map<String, dynamic>>?> getCachedRankList() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('rank_list');
    if (jsonString != null) {
      return List<Map<String, dynamic>>.from(
        jsonDecode(jsonString).map((x) => Map<String, dynamic>.from(x))
      );
    }
    return null;
  }

  Future<void> cacheRankList(List<RankInfo> rankList) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(
      rankList.map((r) => {
        'average': r.average,
        'studentNumber': r.studentNumber,
        'studentName': r.studentName,
        'self': r.isSelf ? '1' : '0',
        'rank': r.rank,
        'credit': r.credit,
        'className': r.className,
        'classId': r.classId,
      }).toList()
    );
    await prefs.setString('rank_list', jsonString);
  }
}
