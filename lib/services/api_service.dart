import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/rank_model.dart';  // 添加这行导入
import 'storage_service.dart';
import 'network_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;
  String _sessionId = '';
  String _token = '';
  final NetworkService _networkService = NetworkService();
  
  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: 'https://api.greathiit.com/api',
      headers: {
        "Host": "api.greathiit.com",
        "Connection": "keep-alive",
        "xweb_xhr": "1",
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36 MicroMessenger/7.0.20.1781(0x6700143B) NetType/WIFI MiniProgramEnv/Windows WindowsWechat/WMPF WindowsWechat(0x63090c25)XWEB/11581",
        "Accept": "*/*",
        "Sec-Fetch-Site": "cross-site",
        "Sec-Fetch-Mode": "cors",
        "Sec-Fetch-Dest": "empty",
        "Referer": "https://servicewechat.com/wx3db178bd95510b66/86/page-frame.html",
        "Accept-Encoding": "gzip, deflate, br",
        "Accept-Language": "zh-CN,zh;q=0.9"
      },
    ));
    _initDio();
  }

  void _initDio() {
    if (!kIsWeb) {
      (_dio.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate = (client) {
        client.badCertificateCallback = (cert, host, port) => true;
        return client;
      };
    }

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        print('Request: ${options.uri}');
        print('Headers: ${options.headers}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        print('Response: ${response.data}');
        return handler.next(response);
      },
      onError: (error, handler) {
        print('Error: ${error.message}');
        return handler.next(error);
      },
    ));
  }

  String generateCode() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        32, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  Future<bool> login(String username, String password) async {
    try {
      String code = generateCode();
      print('Generated code: $code');

      final response = await _dio.get(
        '/user/loginUsername',
        queryParameters: {
          "username": username,
          "password": password,
          "code": code,
        },
      );

      print('Login response: ${response.data}');

      if (response.data['code'] == 200) {
        _sessionId = response.data['data']['sessionId'];
        _token = response.data['data']['token'];

        // 保存凭证
        await StorageService().saveCredentials(
          username: username,
          password: password,
          sessionId: _sessionId,
          token: _token,
        );

        // 更新请求头
        _updateHeaders();
        
        // 验证更新后的请求头
        final testResponse = await _dio.get('/pub/getCourseCalendar');
        print('Test request headers: ${_dio.options.headers}');
        print('Test response: ${testResponse.data}');

        return testResponse.data['code'] == 200;
      }
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  Future<bool> initializeFromStorage() async {
    try {
      final credentials = await StorageService().getCredentials();
      if (credentials['sessionId'] != null && credentials['token'] != null) {
        _sessionId = credentials['sessionId']!;
        _token = credentials['token']!;
        _updateHeaders();
        
        // 检查网络连接
        final isConnected = await _networkService.checkConnectivity();
        if (!isConnected) {
          print('网络不可用，启用离线模式');
          _networkService.setOfflineMode(true);
          return true; // 允许进入离线模式
        }
        
        // 如果有网络，尝试验证凭证
        try {
          final response = await _dio.get(
            '/pub/getCourseCalendar',
            options: Options(
              sendTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
            ),
          );
          if (response.data['code'] == 200) {
            _networkService.setOfflineMode(false);
            return true;
          }
        } catch (e) {
          print('验证凭证失败，启用离线模式: $e');
          _networkService.setOfflineMode(true);
          return true; // 允许进入离线模式
        }
        
        // 如果有保存的账号密码，尝试重新登录
        if (credentials['username'] != null && credentials['password'] != null) {
          return login(credentials['username']!, credentials['password']!);
        }
      }
      return false;
    } catch (e) {
      print('从存储初始化失败: $e');
      _networkService.setOfflineMode(true);
      return true; // 允许进入离线模式
    }
  }

  void _updateHeaders() {
    print('Updating headers...');
    print('Before update: ${_dio.options.headers}');
    
    // 使用新的Headers实例
    final newHeaders = Map<String, dynamic>.from(_dio.options.headers);
    newHeaders['Cookie'] = 'JSESSIONID=$_sessionId';
    newHeaders['Authorization'] = _token;
    
    _dio.options.headers = newHeaders;
    
    print('After update: ${_dio.options.headers}');
  }

  void reset() {
    _sessionId = '';
    _token = '';
    
    // 重置请求头，移除认证相关信息
    final newHeaders = Map<String, dynamic>.from(_dio.options.headers);
    newHeaders.remove('Cookie');
    newHeaders.remove('Authorization');
    _dio.options.headers = newHeaders;
    
    print('ApiService已重置');
    print('当前请求头: ${_dio.options.headers}');
  }

  Future<Map<String, dynamic>> getSemesterInfo() async {
    try {
      final response = await _dio.get('/pub/getCourseCalendar');
      return response.data;
    } catch (e) {
      print('Get semester info error: $e');
      return {'code': 500, 'message': '获取学期信息失败'};
    }
  }

  Future<Map<String, dynamic>> _safeApiCall(Future<Response> Function() apiCall) async {
    if (_networkService.isOfflineMode) {
      return {'code': 200, 'message': '离线模式', 'data': null};
    }
    try {
      final response = await apiCall();
      return response.data as Map<String, dynamic>;
    } catch (e) {
      print('API 调用失败: $e');
      return {'code': 500, 'message': e.toString(), 'data': null};
    }
  }

  Future<Map<String, dynamic>> getWeekSchedule(int week) async {
    return _safeApiCall(() => _dio.get(
      '/timetable/getDataWeek',
      queryParameters: {'week': week.toString()},
    ));
  }

  Future<Map<String, dynamic>> getClassInfo(String timeAdd) async {
    try {
      print('获取课程详情: $timeAdd');
      final response = await _dio.get(
        '/sign/getCurrentClass',
        queryParameters: {'timeAdd': timeAdd},
        options: Options(validateStatus: (status) => status != null && status < 500),
      );
      
      print('课程详情响应: ${response.data}');
      return response.data;
    } catch (e) {
      print('获取课程详情失败: $e');
      return {'code': 500, 'message': '获取课程详情失败: $e'};
    }
  }

  Future<Map<String, dynamic>> getUserInfo() async {
    try {
      print('获取用户信息...');
      print('当前请求头: ${_dio.options.headers}');
      
      final response = await _dio.get('/user/info');
      print('用户信息响应: ${response.data}');
      return response.data;
    } catch (e) {
      print('获取用户信息失败: $e');
      return {'code': 500, 'message': '获取用户信息失败: $e'};
    }
  }

  Future<List<String>> getTerms() async {
    try {
      print('获取学期列表...');
      final response = await _dio.get('/score/getTerm');
      print('学期列表响应: ${response.data}');
      
      if (response.data['code'] == 200) {
        return List<String>.from(response.data['data']);
      }
      return [];
    } catch (e) {
      print('获取学期列表失败: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getTermScores(String term, String studentNumber) async {
    try {
      print('正在获取 $term 学期成绩...');
      final response = await _dio.get(
        '/score/getScore',
        queryParameters: {
          'term': term,
          'studentNumber': studentNumber,
        },
      );
      
      // 使用更安全的日志打印方式
      final responseData = response.data;
      print('成绩响应状态码: ${responseData['code']}');
      print('成绩数量: ${responseData['data']?['collect']?.length ?? 0}');
      
      if (responseData['code'] == 200 && 
          responseData['data'] != null &&
          responseData['data']['collect'] != null) {
        // 打印每个成绩的课程名称进行验证
        final courses = (responseData['data']['collect'] as List)
            .map((item) => item['courseName'])
            .toList();
        print('获取到的课程: $courses');
      }

      return response.data;
    } catch (e) {
      print('获取成绩失败: $e');
      return {'code': 500, 'message': '获取成绩失败: $e'};
    }
  }

  Future<List<RankInfo>> getRankList() async {
    try {
      print('获取班级排名...');
      final response = await _dio.get('/score/getRank');
      
      if (response.data['code'] == 200 && response.data['data'] != null) {
        return (response.data['data'] as List)
            .map((item) => RankInfo.fromJson(item))
            .toList();
      }
      return [];
    } catch (e) {
      print('获取班级排名失败: $e');
      return [];
    }
  }
}
