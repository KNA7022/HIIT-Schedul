import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const Duration _cacheValidity = Duration(hours: 24);
  static const String _prefixWeek = 'week_';
  static const String _prefixCourseDetail = 'course_';
  static const String _keyLastCleanup = 'last_cache_cleanup';

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
}
