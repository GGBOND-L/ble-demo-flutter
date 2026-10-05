import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/operation_record.dart';
import '../models/command_exchange.dart';
import '../services/ble_session_service.dart';
import '../ble/digital_key_protocol.dart';
// import 'dart:convert';

class DigitalKeyController extends GetxController {
  DigitalKeyController(this.device)
    : session = Get.find<BleSessionService>().getOrCreate(device);
  final BluetoothDevice device;
  final BleDeviceSession session;

  BluetoothCharacteristic? _notifyCharacteristic;
  BluetoothCharacteristic? _writeCharacteristic;
  StreamSubscription<List<int>>? _notifySubscription;

  late StreamSubscription<BluetoothConnectionState>
  _connectionStateSubscription;

  final message = '通信准备中...'.obs;
  final isReady = false.obs;
  // 保留原有访问方式，但实际读取的是会话中的共享状态。
  // 页面重新创建时，不会再把认证状态初始化为 fail。
  RxString get authStatus => session.authStatus;
  final connectionState = BluetoothConnectionState.disconnected.obs;

  bool get isConnected =>
      connectionState.value == BluetoothConnectionState.connected;

  // 控车前必须已连接、密码验证成功，并且服务与通知已准备完成。
  // 页面和指令入口共用这个条件，避免两处判断不一致。
  bool get canControl =>
      isConnected && authStatus.value == 'success' && isReady.value;

  final isOperating = false.obs;

  late List<int> _pendingControlPacket;

  final records = <OperationRecord>[].obs;
  // 当前正在进行的操作
  OperationRecord? _currentOperation;

  @override
  void onInit() {
    super.onInit();
    _connectionStateSubscription = device.connectionState.listen((
      BluetoothConnectionState state,
    ) {
      connectionState.value = state;
      if (state == BluetoothConnectionState.disconnected) {
        // 通信准备状态属于当前连接，断开后失效。
        isReady.value = false;
      }
    });
    prepareCommunication(); // 初始化服务与通知
  }

  @override
  void onClose() {
    _notifySubscription?.cancel();
    _notifySubscription = null;
    _connectionStateSubscription.cancel();
    super.onClose();
  }

  void onGotoSearch() {
    // if()
    Get.back();
  }

  Future<void> disconnect() => device.disconnect();

  void _parseB6Response(List<int> value) {
    if (value.length < 5) return;

    final status = value[3];
    final freezeTime = value[4];

    final statusMap = {
      1: '密码正确',
      2: '密码错误',
      3: '需验证密码',
      4: '更改密码成功',
      5: '更改密码失败',
      6: '密码输入错误5次,冻结$freezeTime分钟',
    };
    debugPrint('parseB6Response状态:$status');
    // 只有“密码正确”允许控车，其余结果清除之前的验证成功状态。
    // 验证结果保存到设备会话，页面关闭后仍保留。
    // 非成功结果会清除之前的认证状态。
    session.updateAuthentication(status == 1);

    message.value = statusMap[status] ?? '未知状态';
    final result = message.value;

    final operation = _currentOperation;
    if (operation == null) return;

    operation.result.value = result;
    isOperating.value = false;

    // final json = const JsonEncoder.withIndent('  ')
    //     .convert(operation.toJson()); // 将操作记录转换为 JSON
    // debugPrint(json);
  }

  void _parseA6Response(List<int> value) {
    if (value.length < 5) return;

    final status = value[3];
    final cmdType = value[4];
    // final detail = value[5];
    debugPrint('parseA6Response状态:$status');
    debugPrint('parseA6Response命令:$cmdType');

    final statusMap = {1: '执行成功', 2: '执行超时', 3: '执行失败', 4: '格式错误/AES密钥错误'};

    final operation = _currentOperation;
    if (operation == null) return;

    operation.result.value = statusMap[status] ?? '未知状态';
    isOperating.value = false;
  }

  Future<void> prepareCommunication() async {
    try {
      final List<BluetoothService> services = await device.discoverServices();

      final service = services.firstWhere(
        (s) => s.uuid == Guid('ffe0'),
        orElse: () => throw Exception('未找到 FFE0 服务'),
      );

      _notifyCharacteristic = service.characteristics.firstWhere(
        (c) => c.uuid == Guid('ffe4'),
        orElse: () => throw Exception('未找到 FFE4 特征值'),
      );

      _writeCharacteristic = service.characteristics.firstWhere(
        (c) => c.uuid == Guid('ffe9'),
        orElse: () => throw Exception('未找到 FFE9 特征值'),
      );

      if (!_notifyCharacteristic!.properties.notify) {
        throw Exception('FFE4 不支持通知');
      }

      if (!_writeCharacteristic!.properties.write) {
        throw Exception('FFE9 不支持写入');
      }

      // 重建监听前，取消旧监听
      await _notifySubscription?.cancel();

      // 先建立 Dart 监听
      _notifySubscription = _notifyCharacteristic!.onValueReceived.listen((
        value,
      ) {
        _handleReceivedData(value);
      });

      // 连接成功后，开启监听
      await _notifyCharacteristic!.setNotifyValue(true);

      isReady.value = true;
      message.value = '通信准备完成';
    } catch (e) {
      debugPrint('连接失败:$e');
      message.value = '通信准备失败:$e';
      isReady.value = false;
    }
  }

  Future<void> _handleReceivedData(List<int> value) async {
    final hex = value
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ')
        .toUpperCase(); // 将每个字节转换为十六进制字符串
    // 处理接收到的数据
    debugPrint('接收到的数据:${value.toString()}');
    debugPrint('FFE4 RX: $hex');

    // 基本检查，避免访问 value[2] 时越界
    if (value.length < 3 || value[0] != 0xBD) return;

    final cmd = value[2];
    switch (cmd) {
      case 0xB3:
        debugPrint('收到B3');
        _currentOperation?.exchanges.add(
          CommandExchange(
            direction: 'RX',
            bytes: List<int>.from(value),
            time: DateTime.now(),
          ),
        );
        // 发送B4
        try {
          await _writePacket(DigitalKeyProtocol.b4Packet, _currentOperation!);
        } catch (e) {
          debugPrint('写入B4失败:$e');
        }
        break;
      case 0xB6:
        debugPrint('收到B6');
        _currentOperation?.exchanges.add(
          CommandExchange(
            direction: 'RX',
            bytes: List<int>.from(value),
            time: DateTime.now(),
          ),
        );
        _parseB6Response(value);
        break;
      case 0xA3:
        debugPrint('收到A3');
        _currentOperation?.exchanges.add(
          CommandExchange(
            direction: 'RX',
            bytes: List<int>.from(value),
            time: DateTime.now(),
          ),
        );
        // 发送x指令
        debugPrint('TX x指令: $_pendingControlPacket');
        try {
          await _writePacket(_pendingControlPacket, _currentOperation!);
        } catch (e) {
          debugPrint('写入x指令失败:$e');
        }
        break;
      case 0xA6:
        debugPrint('收到A6');
        _currentOperation?.exchanges.add(
          CommandExchange(
            direction: 'RX',
            bytes: List<int>.from(value),
            time: DateTime.now(),
          ),
        );
        _parseA6Response(value);
        break;
    }
  }

  Future<void> _writePacket(List<int> packet, OperationRecord operation) async {
    debugPrint('TX : $packet');

    await _writeCharacteristic!.write(packet);
    operation.exchanges.add(
      CommandExchange(
        direction: 'TX',
        bytes: List<int>.from(packet),
        time: DateTime.now(),
      ),
    );
  }

  void _finishOperation(String result) {
    _currentOperation?.result.value = result;
    _currentOperation = null;
    isOperating.value = false;
  }

  Future<void> startPasswordVerify() async {
    // 密码验证流程B1×2 →B2 →［B3］→B4 →[B6］

    if (isOperating.value) return;
    if (authStatus.value == 'success' ||
        isReady.value == false ||
        isConnected == false) {
      return;
    }
    final operation = OperationRecord(name: '密码验证', time: DateTime.now());
    records.insert(0, operation);
    _currentOperation = operation;

    isOperating.value = true;

    try {
      await _writePacket(DigitalKeyProtocol.b1Packet, operation);
      await _writePacket(DigitalKeyProtocol.b1Packet, operation);
      await _writePacket(DigitalKeyProtocol.b2Packet, operation);
    } catch (e) {
      debugPrint('密码验证发送失败：$e');
      _finishOperation('发送失败');
    }
  }

  Future<void> startControlCommand(ControlType controlType) async {
    // 指令入口也校验权限，防止直接调用方法绕过页面按钮的禁用状态。
    if (!canControl) {
      debugPrint('控车条件未满足：需要已连接、密码验证成功且通信准备完成');
      return;
    }
    if (isOperating.value) return;

    // 保存本次控制报文，收到 A3 后发送。
    _pendingControlPacket = DigitalKeyProtocol.packetFor(controlType);

    final operationName = DigitalKeyProtocol.nameFor(controlType);

    final operation = OperationRecord(
      name: operationName,
      time: DateTime.now(),
    );
    records.insert(0, operation);
    _currentOperation = operation;

    isOperating.value = true;

    try {
      await _writePacket(DigitalKeyProtocol.a2Packet, operation);
    } catch (e) {
      debugPrint('控车失败:$e');
    }
  }
}
