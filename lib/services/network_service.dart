import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'dart:async';

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;

  final Connectivity _connectivity = Connectivity();
  bool _isOfflineMode = false;
  Timer? _connectivityTimer;
  StreamSubscription? _connectivitySubscription;
  Function(bool)? _onConnectivityChanged;

  NetworkService._internal() {
    // 立即检查网络状态
    checkConnectivity();
    
    // 设置网络状态变化监听
    _connectivity.onConnectivityChanged.listen((result) async {
      if (result == ConnectivityResult.none) {
        setOfflineMode(true);
      } else {
        // 当网络恢复时，进行实际的连接测试
        final isConnected = await _testConnection();
        setOfflineMode(!isConnected);
      }
    });
  }

  bool get isOfflineMode => _isOfflineMode;

  Future<bool> checkConnectivity() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        setOfflineMode(true);
        return false;
      }

      // 测试API连接
      final isConnected = await _testConnection();
      setOfflineMode(!isConnected);
      return isConnected;
    } catch (e) {
      print('网络状态检测失败: $e');
      return false;
    }
  }

  Future<bool> _testConnection() async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 3),
        sendTimeout: const Duration(seconds: 3),
      ));
      
      final response = await dio.get('https://api.greathiit.com/api/pub/getCourseCalendar');
      return response.statusCode == 200;
    } catch (e) {
      print('连接测试失败: $e');
      return false;
    }
  }

  Future<void> _checkAndUpdateConnectivity() async {
    final isConnected = await checkConnectivity();
    final wasOffline = _isOfflineMode;
    _isOfflineMode = !isConnected;
    
    if (wasOffline && isConnected) {
      // 从离线恢复到在线
      _onConnectivityChanged?.call(true);
    } else if (!wasOffline && !isConnected) {
      // 从在线变为离线
      _onConnectivityChanged?.call(false);
    }
  }

  void setOfflineMode(bool value) {
    if (_isOfflineMode != value) {
      _isOfflineMode = value;
      print(value ? '切换到离线模式' : '切换到在线模式');
      _onConnectivityChanged?.call(!value);
    }
  }

  void startConnectivityMonitor(Function(bool) onConnectivityChanged) {
    _onConnectivityChanged = onConnectivityChanged;
    
    // 取消现有监听器和定时器
    _connectivitySubscription?.cancel();
    _connectivityTimer?.cancel();
    
    // 设置网络状态变化监听
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) async {
      // 添加防抖，避免频繁切换
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (result == ConnectivityResult.none) {
        setOfflineMode(true);
      } else {
        final isConnected = await _testConnection();
        if (isConnected != !_isOfflineMode) {  // 只在状态真正需要改变时才设置
          setOfflineMode(!isConnected);
        }
      }
    });

    // 设置定期检查
    _connectivityTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => checkConnectivity(),
    );
  }

  void dispose() {
    _connectivityTimer?.cancel();
    _connectivitySubscription?.cancel();
  }
}
