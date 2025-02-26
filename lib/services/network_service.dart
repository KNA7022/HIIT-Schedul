import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'dart:async';

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;

  bool _isOfflineMode = false;
  Timer? _connectivityTimer;
  final _connectivityCheckInterval = const Duration(minutes: 1);
  final Connectivity _connectivity = Connectivity();  // 添加 Connectivity 实例

  NetworkService._internal();

  bool get isOfflineMode => _isOfflineMode;

  Future<bool> checkConnectivity() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }

      // 测试API连通性
      final dio = Dio();
      final response = await dio.get('https://api.greathiit.com/api/pub/getCourseCalendar');
      return response.statusCode == 200;
    } catch (e) {
      print('连接测试失败: $e');
      return false;
    }
  }

  void startConnectivityTimer(Function(bool) onConnectivityChanged) {
    _connectivityTimer?.cancel();
    _connectivityTimer = Timer.periodic(_connectivityCheckInterval, (timer) async {
      final isConnected = await checkConnectivity();
      if (isConnected && _isOfflineMode) {
        _isOfflineMode = false;
        onConnectivityChanged(true);
      } else if (!isConnected && !_isOfflineMode) {
        _isOfflineMode = true;
        onConnectivityChanged(false);
      }
    });
  }

  void setOfflineMode(bool value) {
    _isOfflineMode = value;
  }

  void dispose() {
    _connectivityTimer?.cancel();
  }
}
