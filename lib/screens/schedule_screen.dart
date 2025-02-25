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

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final CacheService _cacheService = CacheService();
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
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSchedule();
      _loadUserInfo();  // 加载用户信息
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeSchedule() async {
    try {
      final semesterInfo = await _apiService.getSemesterInfo();
      print('学期信息: $semesterInfo');
      
      if (semesterInfo['code'] == 200 && semesterInfo['data'] != null) {
        CourseInfo.setCurrentTerm(semesterInfo); // 设置当前学期信息
        _semesterStartDate = DateTime.parse(semesterInfo['data']['calendarDay']);
        final now = DateTime.now();
        final difference = now.difference(_semesterStartDate!).inDays;
        setState(() {
          _currentWeek = max(1, min((difference / 7).ceil(), _totalWeeks));
        });
        _updateWeekDates(); // 更新日期
        await _loadWeekSchedule();
      } else {
        print('获取学期信息失败：${semesterInfo['message']}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('获取学期信息失败，请重新登录')),
          );
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    } catch (e) {
      print('初始化课表出错：$e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('初始化失败: $e')),
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  Future<void> _loadUserInfo() async {
    try {
      // 先尝试从缓存加载
      final cachedData = await _cacheService.getCachedUserInfo();
      if (cachedData != null) {
        setState(() {
          _userInfo = UserInfo.fromJson(cachedData);
        });
      }

      // 从服务器获取最新数据
      final response = await _apiService.getUserInfo();
      if (response['code'] == 200 && response['data'] != null) {
        await _cacheService.cacheUserInfo(response['data']);
        setState(() {
          _userInfo = UserInfo.fromJson(response['data']);
        });
      }
    } catch (e) {
      print('加载用户信息失败: $e');
    }
  }

  Future<void> _loadWeekSchedule() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      // 1. 先尝试加载缓存
      final cachedData = await _cacheService.getCachedWeekSchedule(_currentWeek);
      if (cachedData != null) {
        print('使用缓存数据: $cachedData');
        await _updateScheduleData(cachedData, animate: true);
      }

      // 2. 加载新数据
      setState(() => _isLoadingBackground = true);
      final newData = await _apiService.getWeekSchedule(_currentWeek);
      print('获取到新数据: $newData');
      setState(() => _isLoadingBackground = false);

      // 3. 如果获取成功则更新
      if (newData['code'] == 200) {
        await _cacheService.cacheWeekSchedule(_currentWeek, newData);
        await _updateScheduleData(newData, animate: false);
      } else {
        print('获取课表失败: ${newData['message']}');
        if (cachedData == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('获取课表失败: ${newData['message']}')),
          );
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
      if (mounted) setState(() => _isLoading = false);
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
    
    // 清空现有数据
    _weekCourses = List.generate(7, (_) => List.filled(5, null));
    
    if (!schedule.containsKey('data') || schedule['data'] == null) {
      print('课表数据为空');
      return;
    }

    final List<dynamic> courses = schedule['data'];
    print('课程总数: ${courses.length}');

    for (var courseData in courses) {
      try {
        if (!courseData.containsKey('timeAdd')) {
          print('课程数据缺少timeAdd字段: $courseData');
          continue;
        }

        final String timeAdd = courseData['timeAdd'];
        print('处理课程: $timeAdd');

        // 尝试获取课程详情
        Map<String, dynamic>? classInfo = await _cacheService.getCachedCourseDetail(timeAdd);
        
        if (classInfo == null) {
          classInfo = await _apiService.getClassInfo(timeAdd);
          if (classInfo['code'] == 200) {
            await _cacheService.cacheCourseDetail(timeAdd, classInfo);
          }
        }

        print('课程详情: $classInfo');

        if (classInfo['code'] == 200 && 
            classInfo['data'] != null && 
            classInfo['data']['ClassInfo'] != null) {
          final courseInfo = classInfo['data']['ClassInfo'];
          final course = CourseInfo.fromJson(courseInfo);
          final timeIndex = _getTimeIndex(course.jie);
          final dayIndex = _getDayIndex(course.xq);
          
          print('添加课程: ${course.courseName} 到位置[$dayIndex, $timeIndex]');

          if (timeIndex != -1 && dayIndex != -1 && mounted) {
            setState(() {
              _weekCourses[dayIndex][timeIndex] = course;
            });
          }
        }
      } catch (e) {
        print('处理单个课程失败: $e');
      }
    }

    // 打印最终课表状态
    for (int i = 0; i < _weekCourses.length; i++) {
      for (int j = 0; j < _weekCourses[i].length; j++) {
        if (_weekCourses[i][j] != null) {
          print('位置[$i, $j]: ${_weekCourses[i][j]!.courseName}');
        }
      }
    }
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
  void _changeWeek(int newWeek) {
    if (newWeek == _currentWeek) return;

    setState(() {
      _currentWeek = newWeek;
    });
    _updateWeekDates();
    _loadWeekSchedule();
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
            Text(
              '第$_currentWeek周课表',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
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
      body: GestureDetector(
        onHorizontalDragStart: (details) {
          _startDragX = details.localPosition.dx;
          _isDragging = true;
        },
        onHorizontalDragUpdate: (details) {
          if (!_isDragging) return;
          final delta = details.localPosition.dx - _startDragX;
          
          // 当拖动超过屏幕宽度的20%时切换周次
          if (delta.abs() > screenSize.width * 0.2) {
            _isDragging = false;
            if (delta > 0 && _currentWeek > 1) {
              // 向右滑动，上一周
              _changeWeek(_currentWeek - 1);
            } else if (delta < 0 && _currentWeek < _totalWeeks) {
              // 向左滑动，下一周
              _changeWeek(_currentWeek + 1);
            }
          }
        },
        onHorizontalDragEnd: (details) {
          _isDragging = false;
        },
        child: Stack(
          children: [
            FadeTransition(
              opacity: _animation,
              child: _buildTimeTableLayout(screenSize),
            ),
            if (_isLoadingBackground)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '同步中',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
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
