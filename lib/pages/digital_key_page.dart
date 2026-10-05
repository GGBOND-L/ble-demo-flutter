import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../controllers/digital_key_controller.dart';
import '../pages/operation_detail_page.dart';
import '../ble/digital_key_protocol.dart';

class DigitalKeyPage extends GetView<DigitalKeyController> {
  const DigitalKeyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('数字钥匙'), centerTitle: true),
      body: Column(
        children: [
          _buildDeviceInfo(),
          SizedBox(height: 16),
          _buildControlPanel(),
          // 操作记录区：操作名称、结果、时间。
          Expanded(
            child: Obx(() {
              return _buildOperationList();
            }),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildDeviceInfo() {
    // 设备信息区：设备名称、连接状态、认证状态。
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Color(0xFFFF8A15)),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('设备名称：${controller.device.platformName}'),
          Text('设备 ID: ${controller.device.remoteId.str}'),
          Obx(() {
            return Text('连接状态: ${controller.isConnected ? '已连接' : '未连接'}');
          }),
          Obx(
            () => Text(
              '认证状态：'
              '${controller.authStatus.value == 'success' ? '已通过密码验证' : '未通过密码验证'}',
            ),
          ),
          Obx(() => Text('通信状态：${controller.message.value}')),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    // 控制按钮区：解锁、锁车、寻车、尾箱。
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Color(0xFFFF8A15)),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('蓝牙控车'),
          SizedBox(height: 8),
          Obx(() {
            final disabled =
                controller.authStatus.value == 'success' ||
                !controller.isConnected ||
                !controller.isReady.value ||
                controller.isOperating.value;
            return ElevatedButton(
              onPressed: disabled
                  ? null
                  : () => controller.startPasswordVerify(),
              child: Text('密码验证'),
            );
          }),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildControlButton('解锁', () {
                  controller.startControlCommand(ControlType.unlock);
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildControlButton('锁车', () {
                  controller.startControlCommand(ControlType.lock);
                }),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildControlButton('寻车', () {
                  controller.startControlCommand(ControlType.alarm);
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildControlButton('尾箱', () {
                  controller.startControlCommand(ControlType.unboot);
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOperationList() {
    if (controller.records.isEmpty) {
      return const Center(child: Text('暂无操作记录'));
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: controller.records.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final record = controller.records[index];
        final timeText = _formatTime(record.time);

        return Obx(
          () => _buildRecordItem(
            name: record.name,
            result: record.result.value,
            timeText: timeText,
            commandCount: record.exchanges.length,
            onTap: () {
              Get.to(() => OperationDetailPage(record: record));
            },
          ),
        );
      },
    );
  }

  Widget _buildControlButton(String title, VoidCallback onTap) {
    // 监听连接、密码验证和通信准备状态，任一条件不满足就禁用控车。
    return Obx(() {
      final enabled = controller.canControl && !controller.isOperating.value;
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), // 设置阴影颜色
              blurRadius: 8, // 设置阴影模糊程度
              offset: const Offset(0, 2), // 设置阴影偏移量
            ),
          ],
        ),
        child: Material(
          color: enabled ? Colors.white : const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias, // 防止圆角溢出
          child: InkWell(
            // InkWell 的 onTap 为 null 时不会响应点击，也不会显示点击水波纹。
            onTap: enabled ? onTap : null,
            child: SizedBox(
              height: 50, // 设置按钮高度
              child: Center(
                child: Text(
                  title,
                  style: TextStyle(
                    color: enabled
                        ? const Color(0xFF333333)
                        : const Color(0xFFAAAAAA),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildRecordItem({
    required String name,
    required String result,
    required String timeText,
    required int commandCount,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Color(0xFFFF8A15)),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Text(
              result,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF333333), fontSize: 16),
            ),
            SizedBox(width: 8),
            Column(
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Color(0xFF333333),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '$commandCount 条指令',
                  style: const TextStyle(color: Color(0xFF999999)),
                ),
              ],
            ),
            const Spacer(),
            Text(
              timeText,
              style: const TextStyle(color: Color(0xFF333333), fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  /// 底部操作区：根据连接状态统一控制按钮、间距和文字。
  Widget _buildBottomActions() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Obx(() {
          // 必须在 Obx 回调内读取，连接状态变化时才会更新布局。
          final connected = controller.isConnected;

          return Row(
            children: [
              // 已连接时才显示断开按钮和按钮之间的间距。
              if (connected) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: controller.disconnect,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      minimumSize: const Size(0, 52),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('断开连接', style: TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 12),
              ],

              // 这个按钮始终显示，文字根据连接状态变化。
              Expanded(
                child: OutlinedButton(
                  onPressed: controller.onGotoSearch,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: const Color(0xFFFF8A15),
                    minimumSize: const Size(0, 52),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    connected ? '切换设备' : '搜索设备',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');

    return '$hour:$minute:$second';
  }
}
