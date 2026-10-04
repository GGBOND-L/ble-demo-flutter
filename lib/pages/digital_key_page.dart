import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../controllers/digital_key_controller.dart';
import '../pages/operation_detail_page.dart';

class DigitalKeyPage extends GetView<DigitalKeyController> {
  const DigitalKeyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数字钥匙'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 设备信息区：设备名称、连接状态、认证状态。
          Container(
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
                    return Text(
                        '连接状态: ${controller.isConnected ? '已连接' : '未连接'}');
                  }),
                  Obx(() {
                    return Text('认证状态: ${controller.message}');
                  }),
                ],
              )),

          SizedBox(
            height: 16,
          ),

          // 控制按钮区：解锁、锁车、寻车、尾箱。
          Container(
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
                  final disabled = controller.authStatus.value == 'success' ||
                      !controller.isConnected;
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
                        controller.startControlCommand('unlock');
                      }),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildControlButton('锁车', () {
                        controller.startControlCommand('lock');
                      }),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildControlButton('寻车', () {
                        controller.startControlCommand('alarm');
                      }),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildControlButton('尾箱', () {
                        controller.startControlCommand('unboot');
                      }),
                    ),
                  ],
                )
              ],
            ),
          ),

          // 操作记录区：操作名称、结果、时间。
          Expanded(
            child: Obx(() {
              if (controller.records.isEmpty) {
                return const Center(child: Text('暂无操作记录'));
              }

              return ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: controller.records.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final record = controller.records[index];
                  final time = record.time;

                  final timeText = '${time.hour.toString().padLeft(2, '0')}:'
                      '${time.minute.toString().padLeft(2, '0')}:'
                      '${time.second.toString().padLeft(2, '0')}';

                  return Obx(() => _buildRecordItem(
                        record.name,
                        record.result.value,
                        timeText,
                        record.exchanges.length,
                        () {
                          Get.to(() => OperationDetailPage(record: record));
                        },
                      ));
                },
              );
            }),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false, // 设置为false,避免底部导航栏覆盖内容
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), // 设置左右内边距
          child: Row(
            children: [
              Obx(() {
                if (!controller.isConnected) {
                  return const SizedBox.shrink(); // 隐藏按钮
                }
                return Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      controller.disconnect();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red), // 设置边框颜色
                      minimumSize: const Size(0, 52), // 设置按钮高度
                      shape: const StadiumBorder(), // 设置按钮形状为圆角矩形
                    ),
                    child: const Text(
                      '断开连接',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                );
              }),
              Obx(() => SizedBox(
                    width: controller.isConnected ? 12 : 0,
                  )),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    controller.onGotoSearch();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white, // 设置按钮文本颜色
                    backgroundColor: const Color(0xFFFF8A15), // 设置按钮背景颜色
                    minimumSize: const Size(0, 52), // 设置按钮高度
                    shape: const StadiumBorder(), // 设置按钮形状为圆角矩形
                  ),
                  child: Obx(() {
                    return Text(
                      controller.isConnected ? '切换设备' : '搜索设备',
                      style: TextStyle(fontSize: 18),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton(String title, VoidCallback onTap) {
    return Container(
      decoration:
          BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05), // 设置阴影颜色
          blurRadius: 8, // 设置阴影模糊程度
          offset: const Offset(0, 2), // 设置阴影偏移量
        ),
      ]),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias, // 防止圆角溢出
        child: InkWell(
            onTap: onTap,
            child: SizedBox(
                height: 50, // 设置按钮高度
                child: Center(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF333333),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ))),
      ),
    );
  }

  Widget _buildRecordItem(
    String name,
    String status,
    String time,
    int number,
    VoidCallback onTap,
  ) {
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
        child: Row(children: [
          Text(
            status,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF333333), fontSize: 16),
          ),
          SizedBox(width: 8),
          Column(children: [
            Text(
              name,
              style: const TextStyle(
                  color: Color(0xFF333333),
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text('$number 条指令',
                style: const TextStyle(color: Color(0xFF999999)))
          ]),
          const Spacer(),
          Text(
            time,
            style: const TextStyle(
              color: Color(0xFF333333),
              fontSize: 16,
            ),
          ),
        ]),
      ),
    );
  }
}
