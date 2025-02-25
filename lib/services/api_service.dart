import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'storage_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;
  String _sessionId = '';
  String _token = '';
  
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
        
        // 更新请求头
        _updateHeaders();
        
        // 验证凭证
        print('Testing stored credentials...');
        print('Headers before test: ${_dio.options.headers}');
        
        final response = await _dio.get('/pub/getCourseCalendar');
        print('Test response with stored credentials: ${response.data}');
        
        if (response.data['code'] == 200) {
          return true;
        }
        
        // 尝试重新登录
        if (credentials['username'] != null && credentials['password'] != null) {
          print('Trying to re-login with stored credentials...');
          return login(credentials['username']!, credentials['password']!);
        }
      }
      return false;
    } catch (e) {
      print('Initialize from storage error: $e');
      return false;
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

  Future<Map<String, dynamic>> getSemesterInfo() async {
    try {
      final response = await _dio.get('/pub/getCourseCalendar');
      return response.data;
    } catch (e) {
      print('Get semester info error: $e');
      return {'code': 500, 'message': '获取学期信息失败'};
    }
  }

  Future<Map<String, dynamic>> getWeekSchedule(int week) async {
    try {
      print('获取第 $week 周课表');
      print('当前请求头: ${_dio.options.headers}');
      
      final response = await _dio.get(
        '/timetable/getDataWeek',
        queryParameters: {'week': week.toString()},
        options: Options(validateStatus: (status) => status != null && status < 500),
      );
      
      print('课表响应: ${response.data}');
      return response.data;
    } catch (e) {
      print('获取周课表失败: $e');
      return {'code': 500, 'message': '获取周课表失败: $e'};
    }
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
}
