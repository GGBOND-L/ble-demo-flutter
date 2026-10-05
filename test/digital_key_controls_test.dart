import 'package:ble_demo_flutter/controllers/digital_key_controller.dart';
import 'package:ble_demo_flutter/pages/digital_key_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

// 隔离真实蓝牙初始化，测试按钮状态变化和点击是否能够到达指令入口。
class _PageTestController extends DigitalKeyController {
  _PageTestController() : super(BluetoothDevice.fromId('test-device'));

  final commands = <String>[];

  @override
  void onInit() {}

  @override
  void onClose() {}

  @override
  void startControlCommand(dynamic controlType) {
    commands.add(controlType as String);
  }
}

void main() {
  const titles = ['解锁', '锁车', '寻车', '尾箱'];

  tearDown(() => Get.reset());

  testWidgets('控车按钮随连接、密码验证和通信状态更新', (tester) async {
    final controller = _PageTestController();
    Get.put<DigitalKeyController>(controller);
    await tester.pumpWidget(
      const GetMaterialApp(home: DigitalKeyPage()),
    );

    Future<void> checkButtons(bool enabled) async {
      for (final title in titles) {
        final button = find.ancestor(
          of: find.text(title),
          matching: find.byType(InkWell),
        );
        expect(
          tester.widget<InkWell>(button).onTap,
          enabled ? isNotNull : isNull,
        );
        await tester.tap(find.text(title));
      }
    }

    // 初始未连接，以及已连接但尚未验证时，都不能触发控车。
    await checkButtons(false);
    controller.connectionState.value = BluetoothConnectionState.connected;
    controller.isReady.value = true;
    await tester.pump();
    await checkButtons(false);
    expect(controller.commands, isEmpty);

    controller.parseB6Response([0xBD, 0x11, 0xB6, 1, 0]);
    await tester.pump();
    await checkButtons(true);
    expect(controller.commands, ['unlock', 'lock', 'alarm', 'unboot']);

    // 验证结果变为失败、通信未就绪、连接断开时，都要立即禁用。
    controller.parseB6Response([0xBD, 0x11, 0xB6, 2, 0]);
    await tester.pump();
    await checkButtons(false);

    controller.authStatus.value = 'success';
    controller.isReady.value = false;
    await tester.pump();
    await checkButtons(false);

    controller.isReady.value = true;
    controller.connectionState.value = BluetoothConnectionState.disconnected;
    await tester.pump();
    await checkButtons(false);
    expect(controller.commands, hasLength(4));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('直接调用指令入口时也拒绝未满足条件的控车操作', () {
    final controller = DigitalKeyController(
      BluetoothDevice.fromId('test-device'),
    );

    void attemptCommands() {
      for (final command in ['unlock', 'lock', 'alarm', 'unboot']) {
        controller.startControlCommand(command);
      }
      // 被拦截的操作不能创建记录，更不能继续访问蓝牙写入特征值。
      expect(controller.records, isEmpty);
    }

    attemptCommands();
    controller.connectionState.value = BluetoothConnectionState.connected;
    controller.isReady.value = true;
    attemptCommands();
    controller.authStatus.value = 'success';
    controller.isReady.value = false;
    attemptCommands();
    controller.isReady.value = true;
    controller.connectionState.value = BluetoothConnectionState.disconnected;
    attemptCommands();
  });
}
