import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/operation_record.dart';
import '../models/command_exchange.dart';
// import 'dart:convert';

enum ControlType {
  lock,
  unlock,
  alarm,
  unboot,
}

class DigitalKeyController extends GetxController {
  DigitalKeyController(this.device);
  final BluetoothDevice device;

  BluetoothCharacteristic? _ffe4;
  BluetoothCharacteristic? _ffe9;
  StreamSubscription<List<int>>? _ffe4Subscription;

  late StreamSubscription<BluetoothConnectionState>
      _connectionStateSubscription;

  final message = '通信准备中...'.obs;
  final isReady = false.obs;
  final authStatus = 'fail'.obs;
  final connectionState = BluetoothConnectionState.disconnected.obs;

  bool get isConnected =>
      connectionState.value == BluetoothConnectionState.connected;

  late List<int> controlPacket;
  final controllerStatusMessage = ''.obs;
  final controllerCmd = ''.obs;

  final records = <OperationRecord>[].obs;
  // 当前正在进行的操作
  OperationRecord? _currentOperation;

  static const List<int> _b1Packet = [
    0xBD,
    0x11,
    0xB1,
    0x00,
    0x01,
    0x02,
    0x03,
    0x04,
    0x05,
    0x06,
    0x07,
    0x08,
    0x09,
    0x0A,
    0x0B,
    0x0C,
    0x0D,
    0x0E,
    0x0F,
    0x08, // checksum
  ];

  static const List<int> _b2Packet = [
    0xBD,
    0x11,
    0xB2,
    0x00,
    0x01,
    0x02,
    0x03,
    0x04,
    0x05,
    0x06,
    0x07,
    0x08,
    0x09,
    0x0A,
    0x0B,
    0x0C,
    0x0D,
    0x0E,
    0x0F,
    0x07, // checksum
  ];
  static const List<int> _b4Packet = [
    // BD11B4FC6D673954 70 1B A1 84C6 A9 4A B8 DC 6E189D
    0xBD,
    0x11,
    0xB4,
    0xFC,
    0x6D,
    0x67,
    0x39,
    0x54,
    0x70,
    0x1B,
    0xA1,
    0x84,
    0xC6,
    0xA9,
    0x4A,
    0xB8,
    0xDC,
    0x6E,
    0x18,
    0x9D,
  ];
  static const List<int> _a2Packet = [
    0xBD,
    0x11,
    0xA2,
    0x00,
    0x01,
    0x02,
    0x03,
    0x04,
    0x05,
    0x06,
    0x07,
    0x08,
    0x09,
    0x0A,
    0x0B,
    0x0C,
    0x0D,
    0x0E,
    0x0F,
    0x17, // checksum
  ];
  static const List<int> _a5Packet = [
    0xBD,
    0x11,
    0xA5,
    0xBD,
    0x6A,
    0x3C,
    0xC0,
    0xE7,
    0xB0,
    0x8F,
    0x2A,
    0xC3,
    0x90,
    0xDE,
    0xA3,
    0x2D,
    0x7B,
    0x63,
    0x3E,
    0xFC,
  ];
  static const List<int> _a4Packet = [
    0xBD,
    0x11,
    0xA4,
    0x2C,
    0xD2,
    0x05,
    0xB6,
    0x5E,
    0xFD,
    0x8F,
    0x38,
    0xF3,
    0xA6,
    0xDA,
    0x5C,
    0xF9,
    0xEF,
    0x90,
    0x99,
    0xD2
  ];
  static const List<int> _c2Packet = [
    0xBD,
    0x11,
    0xC2,
    0xB6,
    0x17,
    0xC1,
    0xF6,
    0xFD,
    0x44,
    0xA0,
    0x7B,
    0x6D,
    0x69,
    0x16,
    0x32,
    0xC6,
    0x08,
    0xC8,
    0x7E,
    0x5D
  ];
  static const List<int> _c1Packet = [
    0xBD,
    0x11,
    0xC1,
    0x41,
    0x2B,
    0x04,
    0xAC,
    0xEA,
    0xBA,
    0xDE,
    0x9E,
    0x5F,
    0x92,
    0x70,
    0x49,
    0xE5,
    0xF6,
    0x85,
    0x8B,
    0x9F,
  ];
  // 控制指令流程  A2 → [A3] → Ax → [A6]
  // 控制权限申请发送 A2: BD 11 A2 00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F 17
  // 开锁发送 A5: BD 11 A5 BD 6A 3C C0 E7 B0 8F 2A C3 90 DE A3 2D 7B 63 3E FC
  // 锁车发送 A4: BD 11 A4 2C D2 05 B6 5E FD 8F 38 F3 A6 DA 5C F9 EF 90 99 D2
  // 寻车发送 C2: BD 11 C2 B6 17 C1 F6 FD 44 A0 7B 6D 69 16 32 C6 08 C8 7E 5D
  // 开尾箱发送 C1: BD 11 C1 41 2B 04 AC EA BA DE 9E 5F 92 70 49 E5 F6 85 8B 9F
  @override
  void onInit() {
    super.onInit();
    _connectionStateSubscription =
        device.connectionState.listen((BluetoothConnectionState state) {
      connectionState.value = state;
    });
    prepareConnection(); // 连接设备
  }

  void onGotoSearch() {
    // if()
    Get.back();
  }

  void disconnect() => device.disconnect();

  void parseB6Response(List<int> value) {
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
    if (status == 1) authStatus.value = 'success';

    message.value = statusMap[status] ?? '未知状态';
    final result = message.value;

    final operation = _currentOperation;
    if (operation == null) return;

    operation.result.value = result;

    // final json = const JsonEncoder.withIndent('  ')
    //     .convert(operation.toJson()); // 将操作记录转换为 JSON
    // debugPrint(json);
  }

  void parseA6Response(List<int> value) {
    final status = value[3];
    final cmdType = value[4];
    // final detail = value[5];
    debugPrint('parseA6Response状态:$status');
    debugPrint('parseA6Response命令:$cmdType');

    final statusMap = {1: '执行成功', 2: '执行超时', 3: '执行失败', 4: '格式错误/AES密钥错误'};
    final cmdMap = {
      0xa4: '上锁',
      0xa5: '开锁',
      0xc2: '寻车',
      0xc1: '开尾箱',
    };
    controllerStatusMessage.value = statusMap[status] ?? '未知状态';
    controllerCmd.value = cmdMap[cmdType] ?? '未知命令';

    final operation = _currentOperation;
    if (operation == null) return;

    operation.result.value = statusMap[status] ?? '未知状态';
  }

  Future prepareConnection() async {
    try {
      List<BluetoothService> services = await device.discoverServices();

      final service = services.firstWhere(
        (s) => s.uuid == Guid('ffe0'),
        orElse: () => throw Exception('未找到 FFE0 服务'),
      );

      _ffe4 = service.characteristics.firstWhere(
        (c) => c.uuid == Guid('ffe4'),
        orElse: () => throw Exception('未找到 FFE4 特征值'),
      );

      _ffe9 = service.characteristics.firstWhere(
        (c) => c.uuid == Guid('ffe9'),
        orElse: () => throw Exception('未找到 FFE9 特征值'),
      );

      if (!_ffe4!.properties.notify) {
        throw Exception('FFE4 不支持通知');
      }

      if (!_ffe9!.properties.write) {
        throw Exception('FFE9 不支持写入');
      }

      // 重建监听前，取消旧监听
      await _ffe4Subscription?.cancel();

      // 先建立 Dart 监听
      _ffe4Subscription = _ffe4!.onValueReceived.listen((value) {
        _handleReceivedData(value);
      });

      // 连接成功后，开启监听
      await _ffe4!.setNotifyValue(true);

      isReady.value = true;
      message.value = '通信准备完成';
    } catch (e) {
      debugPrint('连接失败:$e');
      message.value = '通信准备失败:$e';
      isReady.value = false;
    }
  }

  void _handleReceivedData(List<int> value) {
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
        _ffe9!.write(_b4Packet);
        _currentOperation?.exchanges.add(
          CommandExchange(
            direction: 'TX',
            bytes: List<int>.from(_b4Packet),
            time: DateTime.now(),
          ),
        );
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
        parseB6Response(value);
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
        debugPrint('TX x指令: $controlPacket');
        _currentOperation?.exchanges.add(
          CommandExchange(
            direction: 'TX',
            bytes: List<int>.from(controlPacket),
            time: DateTime.now(),
          ),
        );
        _ffe9!.write(controlPacket);
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
        parseA6Response(value);
        break;
    }
  }

  void startPasswordVerify() {
    // 密码验证流程B1×2 →B2 →［B3］→B4 →[B6］

    final operation = OperationRecord(
      name: '密码验证',
      time: DateTime.now(),
    );
    records.insert(0, operation);
    _currentOperation = operation;

    if (authStatus.value == 'success' ||
        isReady.value == false ||
        isConnected == false) return;

    debugPrint('TX B1 #1: $_b1Packet');
    operation.exchanges.add(CommandExchange(
      direction: 'TX',
      bytes: List<int>.from(_b1Packet),
      time: DateTime.now(),
    ));
    _ffe9!.write(_b1Packet);

    debugPrint('TX B1 #2: $_b1Packet');
    operation.exchanges.add(CommandExchange(
      direction: 'TX',
      bytes: List<int>.from(_b1Packet),
      time: DateTime.now(),
    ));
    _ffe9!.write(_b1Packet);

    debugPrint('TX B2: $_b2Packet');
    operation.exchanges.add(CommandExchange(
      direction: 'TX',
      bytes: List<int>.from(_b2Packet),
      time: DateTime.now(),
    ));
    _ffe9!.write(_b2Packet);
  }

  void startControlCommand(controlType) {
    if (isConnected == false || isReady.value == false) {
      debugPrint('设备未连接');
      return;
    }
    final operation = OperationRecord(
      name: controlType,
      time: DateTime.now(),
    );
    records.insert(0, operation);
    _currentOperation = operation;

    switch (controlType) {
      case 'lock':
        controlPacket = _a4Packet;
        break;
      case 'unlock':
        controlPacket = _a5Packet;
        break;
      case 'alarm':
        controlPacket = _c2Packet;
        break;
      case 'unboot':
        controlPacket = _c1Packet;
        break;
      default:
        controlPacket = _c2Packet;
        break;
    }

    _currentOperation?.exchanges.add(CommandExchange(
      direction: 'TX',
      bytes: List<int>.from(_a2Packet),
      time: DateTime.now(),
    ));
    _ffe9!.write(_a2Packet);
  }

  @override
  void onClose() {
    _ffe4Subscription?.cancel();
    _ffe4Subscription = null;
    _connectionStateSubscription.cancel();
    super.onClose();
  }
}
