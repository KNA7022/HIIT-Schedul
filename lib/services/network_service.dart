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
    // 初始化时立即检查网络状态
    checkConnectivity().then((isConnected) {
      _isOfflineMode = !isConnected;
    });
    
    // 直接设置网络状态监听
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (result) => _checkAndUpdateConnectivity(),
    );
  }

  bool get isOfflineMode => _isOfflineMode;

  Future<bool> checkConnectivity() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }

      // 测试API连通性
      final dio = Dio();
      final response = await dio.get(
        'https://api.greathiit.com/api/pub/getCourseCalendar',
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
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
    _isOfflineMode = value;
    if (value) {
      print('切换到离线模式');
    } else {
      print('切换到在线模式');
      // 切换到在线模式时立即检查连接状态
      _checkAndUpdateConnectivity();
    }
    // 触发回调通知状态变化
    _onConnectivityChanged?.call(!value);
  }

  void startConnectivityMonitor(Function(bool) onConnectivityChanged) {
    _onConnectivityChanged = onConnectivityChanged;
    
    // 取消现有定时器
    _connectivityTimer?.cancel();
    
    // 设置定期检查
    _connectivityTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkAndUpdateConnectivity(),
    );
  }

  void dispose() {
    _connectivityTimer?.cancel();
    _connectivitySubscription?.cancel();
  }
}
