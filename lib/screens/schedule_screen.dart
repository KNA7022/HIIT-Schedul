import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:convert';  // 添加此导入
import '../services/api_service.dart';
import '../models/course_model.dart';
import 'dart:math';
import '../widgets/course_detail_dialog.dart';
import '../services/cache_service.dart';
import 'profile_screen.dart';
import '../models/user_info_model.dart';
import '../services/network_service.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final ApiService _apiService = ApiService();
  final CacheService _cacheService = CacheService();
  final NetworkService _networkService = NetworkService();
  late AnimationController _animationController;
  late Animation<double> _animation;
  int _currentWeek = 1;
  int _totalWeeks = 20;
  bool _isLoading = false;
  bool _isLoadingBackground = false;
  List<List<CourseInfo?>> _weekCourses = List.generate(7, (_) => List.filled(5, null));
  int _currentDay = DateTime.now().weekday; // 添加当前日期
  DateTime? _semesterStartDate;  // 添加学期开始日期
  List<DateTime> _weekDates = [];  // 添加当前周的日期列表
  UserInfo? _userInfo;
  
  // 添加手势相关属性
  double _startDragX = 0;
  bool _isDragging = false;

  // 添加当前实际周次属性
  int _actualCurrentWeek = 1;

  // 添加预加载缓存
  Map<int, List<List<CourseInfo?>>> _courseCache = {};

  // 添加周切换动画属性
  late final PageController _pageController;
  double _currentPageValue = 0.0;
  bool _isAnimating = false;
  final Duration _animationDuration = const Duration(milliseconds: 250);
  final Curve _animationCurve = Curves.easeInOutCubic;

  // 添加预加载数据缓存
  Map<int, List<List<CourseInfo?>>> _preloadedData = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    // 设置动画初始值为1.0，这样内容一开始就是可见的
    _animationController.value = 1.0;

    // 立即检查网络状态
    _networkService.checkConnectivity();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSchedule();
      _loadUserInfo();  // 加载用户信息
    });
    _initializeNetworkMonitoring();
    WidgetsBinding.instance.addObserver(this);

    _pageController = PageController(
      initialPage: _currentWeek - 1,
      viewportFraction: 1.0,
    )..addListener(_handlePageScroll);

    // 初始化后立即开始预加载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadAdjacentWeeks(_currentWeek);
    });
  }

  void _handlePageScroll() {
    if (mounted) {
      setState(() {
        _currentPageValue = _pageController.page ?? 0;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 当页面重新获得焦点时，同步网络状态
    _syncNetworkState();
  }

  Future<void> _syncNetworkState() async {
    final isConnected = await _networkService.checkConnectivity();
    if (mounted && isConnected != !_networkService.isOfflineMode) {
      setState(() {
        // 强制刷新UI
      });
    }
  }

  void _initializeNetworkMonitoring() {
    _networkService.startConnectivityMonitor((isConnected) {
      if (mounted) {
        setState(() {});
        if (isConnected) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('网络已恢复，正在同步数据...'),
              duration: Duration(seconds: 2),
            ),
          );
          _loadWeekSchedule();
          _loadUserInfo();  // 同时刷新用户信息
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('网络连接已断开，切换至离线模式'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncNetworkState();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _courseCache.clear();
    _networkService.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeSchedule() async {
    try {
      // 先尝试从缓存初始化学期信息
      final cachedSemesterInfo = await _cacheService.getCachedSemesterInfo();
      if (cachedSemesterInfo != null) {
        await _processSemesterInfo(cachedSemesterInfo);
      }

      // 如果不是离线模式，尝试获取最新学期信息
      if (!_networkService.isOfflineMode) {
        final semesterInfo = await _apiService.getSemesterInfo();
        if (semesterInfo['code'] == 200 && semesterInfo['data'] != null) {
          await _cacheService.cacheSemesterInfo(semesterInfo);
          await _processSemesterInfo(semesterInfo);
        }
      }
    } catch (e) {
      print('初始化课表出错：$e');
      // 如果没有任何缓存数据且网络请求失败，才跳转登录
      if (_semesterStartDate == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('初始化失败，请检查网络连接')),
          );
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    }
  }

  Future<void> _processSemesterInfo(Map<String, dynamic> semesterInfo) async {
    if (semesterInfo['data'] != null) {
      CourseInfo.setCurrentTerm(semesterInfo);
      _semesterStartDate = DateTime.parse(semesterInfo['data']['calendarDay']);
      final now = DateTime.now();
      final difference = now.difference(_semesterStartDate!).inDays;
      final calculatedWeek = max(1, min((difference / 7).ceil(), _totalWeeks));
      
      if (mounted) {
        setState(() {
          _currentWeek = calculatedWeek;
          _actualCurrentWeek = calculatedWeek;
        });
      }
      
      _updateWeekDates();
      await _loadWeekSchedule();
    }
  }

  Future<void> _loadUserInfo() async {
    try {
      // 优先使用缓存数据
      final cachedData = await _cacheService.getCachedUserInfo();
      if (cachedData != null) {
        setState(() {
          _userInfo = UserInfo.fromJson(cachedData);
        });
      }

      // 在线模式才获取新数据
      if (!_networkService.isOfflineMode) {
        final response = await _apiService.getUserInfo();
        if (response['code'] == 200 && response['data'] != null) {
          await _cacheService.cacheUserInfo(response['data']);
          if (mounted) {
            setState(() {
              _userInfo = UserInfo.fromJson(response['data']);
            });
          }
        }
      }
    } catch (e) {
      print('加载用户信息失败: $e');
      // 错误时尝试使用缓存数据
      final cachedData = await _cacheService.getCachedUserInfo();
      if (cachedData != null && mounted) {
        setState(() {
          _userInfo = UserInfo.fromJson(cachedData);
        });
      }
    }
  }

  Future<void> _loadWeekSchedule() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      // 1. 加载缓存
      final cachedData = await _cacheService.getCachedWeekSchedule(_currentWeek);
      bool hasCachedData = false;
      
      if (cachedData != null) {
        // 验证缓存数据是否属于当前周
        if (cachedData['week'] == _currentWeek) {
          final processedData = await _processCourseData(cachedData);
          if (mounted) {
            setState(() {
              _weekCourses = processedData;
              _courseCache[_currentWeek] = processedData;
            });
          }
          hasCachedData = true;
        }

        // 如果是离线模式且没有当前周的缓存，显示空课表
        if (_networkService.isOfflineMode && !hasCachedData) {
          setState(() {
            _weekCourses = List.generate(7, (_) => List.filled(5, null));
          });
          return;
        }
      }

      // 2. 在线模式下加载新数据
      if (!_networkService.isOfflineMode) {
        setState(() => _isLoadingBackground = true);
        final newData = await _apiService.getWeekSchedule(_currentWeek);
        
        if (newData['code'] == 200) {
          // 添加周次信息到缓存数据中
          newData['week'] = _currentWeek;
          await _cacheService.cacheWeekSchedule(_currentWeek, newData);
          
          final processedData = await _processCourseData(newData);
          if (mounted) {
            setState(() {
              _weekCourses = processedData;
              _courseCache[_currentWeek] = processedData;
              _isLoadingBackground = false;
            });
          }
        }
      }
    } catch (e) {
      print('加载课表异常: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingBackground = false;
        });
      }
    }
  }

  bool _compareScheduleData(Map<String, dynamic>? old, Map<String, dynamic> new_) {
    if (old == null) return false;
    return jsonEncode(old['data']) == jsonEncode(new_['data']);
  }

  Future<void> _updateScheduleData(Map<String, dynamic> data, {bool animate = false}) async {
    if (!mounted) return;

    if (animate) {
      // 先更新数据，再执行动画
      setState(() {
        _processScheduleData(data);
      });
      // 执行淡出淡入动画
      await _animationController.animateTo(0.0);
      await _animationController.animateTo(1.0);
    } else {
      setState(() {
        _processScheduleData(data);
      });
    }
  }

  Future<void> _processScheduleData(Map<String, dynamic> schedule) async {
    print('处理课表数据: $schedule');
    
    // 修改列表初始化方式，使用 CourseInfo? 类型
    final newWeekCourses = List<List<CourseInfo?>>.generate(
      7,
      (_) => List<CourseInfo?>.filled(5, null)
    );
    
    if (!schedule.containsKey('data') || schedule['data'] == null) {
      print('课表数据为空');
      return;
    }

    final List<dynamic> courses = schedule['data'];
    print('课程总数: ${courses.length}');

    // 批量获取所有课程的 timeAdd
    final List<String> timeAdds = courses
        .where((course) => course['timeAdd'] != null)
        .map<String>((course) => course['timeAdd'] as String)
        .toList();

    // 批量获取所有课程详情
    final Map<String, Map<String, dynamic>> courseDetails = {};
    await Future.wait(
      timeAdds.map((timeAdd) async {
        // 先尝试从缓存获取
        final cached = await _cacheService.getCachedCourseDetail(timeAdd);
        if (cached != null) {
          courseDetails[timeAdd] = cached;
          return;
        }

        // 如果缓存没有，从服务器获取
        final response = await _apiService.getClassInfo(timeAdd);
        if (response['code'] == 200) {
          courseDetails[timeAdd] = response;
          await _cacheService.cacheCourseDetail(timeAdd, response);
        }
      }),
    );

    // 处理所有课程
    for (var courseData in courses) {
      try {
        final String timeAdd = courseData['timeAdd'];
        final classInfo = courseDetails[timeAdd];
        
        if (classInfo != null && 
            classInfo['code'] == 200 && 
            classInfo['data'] != null && 
            classInfo['data']['ClassInfo'] != null) {
          final courseInfo = classInfo['data']['ClassInfo'];
          final course = CourseInfo.fromJson(courseInfo);
          final timeIndex = _getTimeIndex(course.jie);
          final dayIndex = _getDayIndex(course.xq);
          
          if (timeIndex != -1 && dayIndex != -1) {
            newWeekCourses[dayIndex][timeIndex] = course;  // 现在这里不会报错
          }
        }
      } catch (e) {
        print('处理单个课程失败: $e');
      }
    }

    // 一次性更新UI
    if (mounted) {
      setState(() {
        _weekCourses = newWeekCourses;
      });
    }
  }

  Future<List<List<CourseInfo?>>> _processCourseData(Map<String, dynamic> data) async {
    final newWeekCourses = List<List<CourseInfo?>>.generate(
      7,
      (_) => List<CourseInfo?>.filled(5, null)
    );

    if (!data.containsKey('data') || data['data'] == null) return newWeekCourses;

    // 处理所有课程
    final List<dynamic> courses = data['data'];
    print('课程总数: ${courses.length}');

    // 批量获取所有课程的 timeAdd
    final List<String> timeAdds = courses
        .where((course) => course['timeAdd'] != null)
        .map<String>((course) => course['timeAdd'] as String)
        .toList();

    // 批量获取所有课程详情
    final Map<String, Map<String, dynamic>> courseDetails = {};
    await Future.wait(
      timeAdds.map((timeAdd) async {
        // 先尝试从缓存获取
        final cached = await _cacheService.getCachedCourseDetail(timeAdd);
        if (cached != null) {
          courseDetails[timeAdd] = cached;
          return;
        }

        // 如果缓存没有，从服务器获取
        final response = await _apiService.getClassInfo(timeAdd);
        if (response['code'] == 200) {
          courseDetails[timeAdd] = response;
          await _cacheService.cacheCourseDetail(timeAdd, response);
        }
      }),
    );

    // 处理所有课程
    for (var courseData in courses) {
      try {
        final String timeAdd = courseData['timeAdd'];
        final classInfo = courseDetails[timeAdd];
        
        if (classInfo != null && 
            classInfo['code'] == 200 && 
            classInfo['data'] != null && 
            classInfo['data']['ClassInfo'] != null) {
          final courseInfo = classInfo['data']['ClassInfo'];
          final course = CourseInfo.fromJson(courseInfo);
          final timeIndex = _getTimeIndex(course.jie);
          final dayIndex = _getDayIndex(course.xq);
          
          if (timeIndex != -1 && dayIndex != -1) {
            newWeekCourses[dayIndex][timeIndex] = course;  // 现在这里不会报错
          }
        }
      } catch (e) {
        print('处理单个课程失败: $e');
      }
    }

    return newWeekCourses;
  }

  int _getTimeIndex(String jie) {
    print('Converting jie: $jie');
    final normalizedJie = jie.replaceAll('节', '').trim();
    final numbers = normalizedJie.split('-');
    if (numbers.isEmpty) return -1;
    
    final firstNumber = int.tryParse(numbers[0]);
    if (firstNumber == null) return -1;
    
    switch (firstNumber) {
      case 1: return 0;
      case 3: return 1;
      case 5: return 2;
      case 7: return 3;
      case 9: return 4;
      default: return -1;
    }
  }

  int _getDayIndex(String xq) {
    print('Converting xq: $xq');
    switch (xq.trim()) {
      case '周一': return 0;
      case '周二': return 1;
      case '周三': return 2;
      case '周四': return 3;
      case '周五': return 4;
      case '周六': return 5;
      case '周日': return 6;
      default: 
        print('Unknown day: $xq');
        return -1;
    }
  }

  void _updateWeekDates() {
    if (_semesterStartDate == null) return;
    
    // 计算当前周的起始日期（周一）
    DateTime weekStart = _semesterStartDate!.add(Duration(days: (_currentWeek - 1) * 7));
    // 调整到本周的周一
    while (weekStart.weekday != DateTime.monday) {
      weekStart = weekStart.subtract(const Duration(days: 1));
    }
    
    // 生成本周所有日期
    _weekDates = List.generate(7, (index) {
      return weekStart.add(Duration(days: index));
    });

    // 如果当前周包含今天，更新_currentDay
    final now = DateTime.now();
    final weekEnd = weekStart.add(const Duration(days: 6));
    if (now.isAfter(weekStart.subtract(const Duration(days: 1))) && 
        now.isBefore(weekEnd.add(const Duration(days: 1)))) {
      setState(() {
        _currentDay = now.weekday;
      });
    } else {
      setState(() {
        _currentDay = 0; // 不是当前周时，不高亮显示任何日期
      });
    }
  }

  // 在周次改变时更新日期
  Future<void> _changeWeek(int newWeek) async {
    if (newWeek == _currentWeek || _isAnimating) return;
    
    _isAnimating = true;
    final previousWeek = _currentWeek;
    
    try {
      // 1. 预加载新周数据
      List<List<CourseInfo?>>? nextWeekData = _preloadedData[newWeek];
      
      if (nextWeekData == null) {
        // 尝试从缓存加载
        final cachedData = await _cacheService.getCachedWeekSchedule(newWeek);
        if (cachedData != null && cachedData['week'] == newWeek) {
          nextWeekData = await _processCourseData(cachedData);
        }
        
        // 如果没有缓存数据且在线，从服务器获取
        if (nextWeekData == null && !_networkService.isOfflineMode) {
          final newData = await _apiService.getWeekSchedule(newWeek);
          if (newData['code'] == 200) {
            newData['week'] = newWeek;
            await _cacheService.cacheWeekSchedule(newWeek, newData);
            nextWeekData = await _processCourseData(newData);
          }
        }
        
        // 如果仍然没有数据，使用空课表
        nextWeekData ??= List.generate(7, (_) => List.filled(5, null));
      }

      // 2. 开始切换动画
      setState(() {
        _currentWeek = newWeek;
        _updateWeekDates();
      });

      // 3. 执行页面切换动画
      await _pageController.animateToPage(
        newWeek - 1,
        duration: _animationDuration,
        curve: _animationCurve,
      );

      // 4. 应用新数据
      if (mounted) {
        setState(() {
          _weekCourses = nextWeekData!;
          _courseCache[newWeek] = nextWeekData;
        });
      }

      // 5. 清理并开始预加载相邻周
      _preloadedData.clear();
      _preloadAdjacentWeeks(newWeek);

    } catch (e) {
      print('切换周次失败: $e');
      if (mounted) {
        setState(() {
          _currentWeek = previousWeek;
          _updateWeekDates();
        });
      }
    } finally {
      _isAnimating = false;
    }
  }

  // 修改预加载方法
  Future<void> _preloadAdjacentWeeks(int currentWeek) async {
    final List<int> weeksToPreload = [
      if (currentWeek > 1) currentWeek - 1,
      if (currentWeek < _totalWeeks) currentWeek + 1,
    ];

    for (final week in weeksToPreload) {
      try {
        // 如果已经有缓存数据，跳过
        if (_courseCache.containsKey(week)) {
          _preloadedData[week] = _courseCache[week]!;
          continue;
        }

        // 尝试从本地缓存加载
        final cachedData = await _cacheService.getCachedWeekSchedule(week);
        if (cachedData != null && cachedData['week'] == week) {
          final processedData = await _processCourseData(cachedData);
          _preloadedData[week] = processedData;
          continue;
        }

        // 在线模式下从服务器获取
        if (!_networkService.isOfflineMode) {
          final newData = await _apiService.getWeekSchedule(week);
          if (newData['code'] == 200) {
            newData['week'] = week;
            await _cacheService.cacheWeekSchedule(week, newData);
            final processedData = await _processCourseData(newData);
            _preloadedData[week] = processedData;
          }
        }
      } catch (e) {
        print('预加载第 $week 周数据失败: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '第$_currentWeek周课表',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                if (_currentWeek != _actualCurrentWeek) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '非本周',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Text(
              _userInfo != null 
                ? '${CourseInfo.currentTerm} | ${_userInfo!.className}'
                : CourseInfo.currentTerm,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: '选择周次',
            onPressed: () => _showWeekPicker(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新课表',
            onPressed: _loadWeekSchedule,
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: '个人信息',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_networkService.isOfflineMode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.error.withOpacity(0.8),
                    Theme.of(context).colorScheme.errorContainer,
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '离线模式 - 使用本地缓存',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: GestureDetector(
              onHorizontalDragStart: (details) {
                if (!_isAnimating) {
                  _startDragX = details.localPosition.dx;
                  _isDragging = true;
                }
              },
              onHorizontalDragUpdate: (details) {
                if (!_isDragging || _isAnimating) return;
                final delta = details.localPosition.dx - _startDragX;
                
                if (delta.abs() > MediaQuery.of(context).size.width * 0.2) {
                  _isDragging = false;
                  if (delta > 0 && _currentWeek > 1) {
                    _changeWeek(_currentWeek - 1);
                  } else if (delta < 0 && _currentWeek < _totalWeeks) {
                    _changeWeek(_currentWeek + 1);
                  }
                }
              },
              onHorizontalDragEnd: (details) => _isDragging = false,
              child: PageView.builder(
                controller: _pageController,
                physics: _isAnimating 
                    ? const NeverScrollableScrollPhysics() 
                    : const BouncingScrollPhysics(),
                onPageChanged: (index) {
                  if (!_isAnimating) {
                    _changeWeek(index + 1);
                  }
                },
                itemCount: _totalWeeks,
                itemBuilder: (context, index) {
                  // 优化动画计算
                  final double position = (index - _currentPageValue).clamp(-1.0, 1.0);
                  final double opacity = (1 - position.abs()).clamp(0.3, 1.0);
                  
                  return RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, child) {
                        return Transform(
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001)
                            ..rotateY(position * 0.2), // 减小旋转角度
                          alignment: position <= 0 
                              ? Alignment.centerRight 
                              : Alignment.centerLeft,
                          child: Opacity(
                            opacity: opacity,
                            child: child,
                          ),
                        );
                      },
                      child: _buildTimeTableLayout(MediaQuery.of(context).size),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeTableLayout(Size screenSize) {
    // 计算剩余高度
    final appBar = AppBar();
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final totalHeaderHeight = appBar.preferredSize.height + statusBarHeight;
    final weekHeaderHeight = screenSize.height * 0.06;
    final availableHeight = screenSize.height - totalHeaderHeight - weekHeaderHeight;
    final cellHeight = availableHeight / 5;  // 将剩余高度平均分配给5个时间段

    return Container(
      width: screenSize.width,
      height: screenSize.height,
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Container(
            height: weekHeaderHeight,
            child: _buildHeaderRow(),
          ),
          Expanded(
            child: _buildTimeTable(screenSize.width, cellHeight),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeTable(double width, double cellHeight) {
    const timeSlots = [
      '1-2节\n8:20\n9:50',  // 修改时间格式，添加结束时间
      '3-4节\n10:05\n11:35',
      '5-6节\n12:55\n14:25',
      '7-8节\n14:40\n16:10',
      '9-10节\n17:30\n19:00',
    ];

    // 调整时间栏宽度比例
    final timeColumnWidth = width * 0.09; // 增加到9%确保显示完整
    final remainingWidth = width - timeColumnWidth;
    final dayColumnWidth = remainingWidth / 7;

    return Table(
      border: TableBorder.all(
        color: Theme.of(context).colorScheme.outlineVariant,
        width: 0.5,
      ),
      defaultVerticalAlignment: TableCellVerticalAlignment.fill,
      columnWidths: {
        0: FixedColumnWidth(timeColumnWidth),
        for (var i = 1; i <= 7; i++) 
          i: FixedColumnWidth(dayColumnWidth),
      },
      children: List.generate(5, (timeIndex) {
        return TableRow(
          decoration: BoxDecoration(
            color: timeIndex.isEven
                ? Theme.of(context).colorScheme.surface
                : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          ),
          children: [
            _buildTimeSlotCell(timeSlots[timeIndex], cellHeight),
            ...List.generate(7, (dayIndex) =>
                _buildCourseCell(_weekCourses[dayIndex][timeIndex], cellHeight)),
          ],
        );
      }),
    );
  }

  Widget _buildTimeSlotCell(String text, double height) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Center(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 10, // 稍微减小字号以适应更多文本
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.1, // 减小行高使文本更紧凑
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildCourseCell(CourseInfo? course, double height) {
    return TableCell(
      child: Container(
        height: height, // 增加高度到160
        padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.0),
        child: course != null
            ? InkWell( // 添加点击效果
                onTap: () => _showCourseDetail(course),
                child: Card(
                  margin: EdgeInsets.zero,
                  elevation: 2,
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 2.0), // 稍微增加垂直内边距
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          flex: 6, // 增加课程名称的占比
                          child: Center(
                            child: Text(
                              course.courseName,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (course.teacherName.isNotEmpty) ...[
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: Text(
                                course.teacherName,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        if (course.school.isNotEmpty || course.room.isNotEmpty) ...[
                          Expanded(
                            flex: 3,
                            child: Center(
                              child: Text(
                                '${course.school}\n${course.room}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  height: 1.1,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  void _showCourseDetail(CourseInfo course) {
    showDialog(
      context: context,
      builder: (context) => CourseDetailDialog(course: course),
    );
  }

  Widget _buildHeaderRow() {
    const weekdays = ['时间', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: weekdays.asMap().entries.map((entry) {
          final int index = entry.key;
          final String day = entry.value;
          final bool isCurrentDay = (index == _currentDay) && (_currentDay > 0);
          String dateStr = '';
          if (index > 0 && _weekDates.isNotEmpty) {
            dateStr = '${_weekDates[index - 1].day}日';
          }
          
          return Expanded(
            flex: day == '时间' ? 2 : 3,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: isCurrentDay ? Theme.of(context).colorScheme.primary : null,
                border: Border(
                  right: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                    width: 0.5,
                  ),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    day,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isCurrentDay 
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  if (dateStr.isNotEmpty)
                    Text(
                      dateStr,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isCurrentDay 
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onPrimaryContainer,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showWeekPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _currentWeek > 1 ? () {
                    setState(() => _currentWeek--);
                    _loadWeekSchedule();
                    Navigator.pop(context);
                  } : null,
                ),
                Text(
                  '选择周次',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _currentWeek < _totalWeeks ? () {
                    setState(() => _currentWeek++);
                    _loadWeekSchedule();
                    Navigator.pop(context);
                  } : null,
                ),
              ],
            ),
            SizedBox(
              height: 200,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  childAspectRatio: 1.5,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: _totalWeeks,
                itemBuilder: (context, index) {
                  final week = index + 1;
                  final isSelected = week == _currentWeek;
                  return OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surface,
                      foregroundColor: isSelected
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurface,
                      side: BorderSide(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                      ),
                      padding: EdgeInsets.zero, // 移除内边距
                    ),
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$week',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    onPressed: () {
                      _changeWeek(week);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
