import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';

class BleDeviceSession {
  BleDeviceSession(this.device) {
    _connectionSubscription = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        clearAuthentication();
      }
    });
  }

  final BluetoothDevice device;

  late final StreamSubscription<BluetoothConnectionState>
      _connectionSubscription;

  // 仅保存当前连接的认证结果，不保存密码，也不写入本地存储。
  final RxString authStatus = 'fail'.obs;

  /// 保存设备返回的密码验证结果。
  void updateAuthentication(bool success) {
    // 只有连接仍有效时，才允许记录认证成功。
    authStatus.value = success && device.isConnected ? 'success' : 'fail';
  }

  /// 断开连接或设备要求重新验证时，清除认证。
  void clearAuthentication() {
    authStatus.value = 'fail';
  }

  Future<void> dispose() async {
    await _connectionSubscription.cancel();
    clearAuthentication();
  }
}

class BleSessionService extends GetxService {
  final Map<String, BleDeviceSession> _sessions = {};

  BleDeviceSession getOrCreate(BluetoothDevice device) {
    final id = device.remoteId.str;

    final session = _sessions.putIfAbsent(
      id,
      () => BleDeviceSession(device),
    );

    // 再次使用会话时检查当前连接状态，避免沿用已断开的认证结果。
    if (!device.isConnected) {
      session.clearAuthentication();
    }

    return session;
  }

  @override
  void onClose() {
    // 服务被显式清理时，释放它持有的全部监听。
    for (final session in _sessions.values) {
      unawaited(session.dispose());
    }

    _sessions.clear();
    super.onClose();
  }
}
