import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import './digital_key_page.dart';
import '../controllers/digital_key_controller.dart';

class BleTabPage extends StatefulWidget {
  const BleTabPage({super.key});

  @override
  State<BleTabPage> createState() => _BleTabPageState();
}

class _BleTabPageState extends State<BleTabPage> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
            child: Column(
      children: [
        const SizedBox(height: 20),

        // 顶部分段切换
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
                height: 44,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9EDF2),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(children: [
                  Expanded(
                    child: _buildTabItem(
                      title: 'bb车锁数字钥匙',
                      index: 0,
                    ),
                  ),
                  Expanded(
                    child: _buildTabItem(
                      title: 'Tag防丢器',
                      index: 1,
                    ),
                  ),
                ]))),

        const SizedBox(height: 20),

        // 切换页面
        Expanded(
          child: IndexedStack(
            index: currentIndex,
            children: [BbBbScanPageState(), Text('tag device page')],
          ),
        )
      ],
    )));
  }

  _buildTabItem({required String title, required int index}) {
    final bool selected = currentIndex == index;

    return GestureDetector(
        onTap: () {
          setState(() {
            currentIndex = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFF8A15) : const Color(0xFFE9EDF2),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Text(
            title,
            style: TextStyle(
                color: selected ? Colors.white : Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w500),
          ),
        ));
  }
}

class BbBbScanPageState extends StatefulWidget {
  const BbBbScanPageState({super.key});

  @override
  State<BbBbScanPageState> createState() => _BbBbScanPageStateState();
}

class DeviceCard extends StatelessWidget {
  final String name;
  final String id;
  final int rssi;
  final VoidCallback? onConnect;

  const DeviceCard({
    super.key,
    required this.name,
    required this.id,
    required this.rssi,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: Row(children: [
        // 左侧设备图标
        Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Color(0xFFFFF5E8),
            ),
            child: Center(
                child: Text(
              name,
              style: const TextStyle(
                color: Color(0xFFFF982E),
                fontSize: 13,
                fontWeight: FontWeight.bold,
                height: 1.5, // 1.5 表示行高是字体高度的 1.5 倍
              ),
            ))),

        const SizedBox(width: 14),

        // 中间的设备信息

        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              maxLines: 1, // 设置最大行数为 1
              overflow: TextOverflow.ellipsis, // 设置溢出时显示省略号
              style: const TextStyle(
                color: Color(0xFF252525),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              )),
          const SizedBox(height: 4),
          Text(
            'mac/id: $id',
            maxLines: 1, // 设置最大行数为 1
            overflow: TextOverflow.ellipsis, // 设置溢出时显示省略号
            style: const TextStyle(
              color: Color(0xFF252525),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text('信号强度: $rssi',
              maxLines: 1, // 设置最大行数为 1
              overflow: TextOverflow.ellipsis, // 设置溢出时显示省略号
              style: const TextStyle(
                color: Color(0xFF252525),
                fontSize: 12,
              ))
        ])),

        // 右侧的连接按钮
        const SizedBox(width: 12),

        SizedBox(
          width: 80,
          height: 40,
          child: ElevatedButton(
            onPressed: onConnect,
            style: ElevatedButton.styleFrom(
                elevation: 0, // 设置按钮无阴影
                padding: EdgeInsets.zero, // 设置按钮内边距为 0
                backgroundColor: const Color(0xFFFF8A15),
                foregroundColor: Colors.white, // 设置按钮文本颜色
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22), // 设置按钮圆角
                )),
            child: const Text('连接',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        )
      ]),
    );
  }
}

class _BbBbScanPageStateState extends State<BbBbScanPageState> {
  final BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;

  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  bool _isConnecting = false;
  late StreamSubscription<BluetoothAdapterState> _adapterStateStateSubscription;
  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;

  @override
  void initState() {
    super.initState();

    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        setState(() {
          _scanResults = results;
        });
      }
    });

    FlutterBluePlus.isScanning.listen((scanning) {
      debugPrint('${DateTime.now()} 扫描状态: $scanning');
      if (mounted) {
        setState(() => _isScanning = scanning);
      }

      if (scanning == false && _scanResults.isNotEmpty) {
        debugPrint('====== 本次扫描结束，共 ${_scanResults.length} 台设备 ======');

        for (var i = 0; i < _scanResults.length; i++) {
          final result = _scanResults[i];
          final device = result.device;
          final adv = result.advertisementData;

          debugPrint(
            '[$i] '
            'id=${device.remoteId.str}, '
            'platformName=${device.platformName}, '
            'advName=${adv.advName}, '
            'rssi=${result.rssi}, '
            'connectable=${adv.connectable}, '
            'serviceUuids=${adv.serviceUuids}, '
            'manufacturerData=${adv.manufacturerData}, '
            'serviceData=${adv.serviceData}',
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _adapterStateStateSubscription.cancel();
    _scanResultsSubscription.cancel();
    super.dispose();
  }

  onStartSearch() {
    print('开始扫描=============onStartSearch');
    _startSearch();
  }

  _startSearch() async {
    print('_startSearch');
    final supported = await FlutterBluePlus.isSupported;
    print('查看是否支持蓝牙: $supported');
    if (supported == false) {
      print('当前设备不支持蓝牙');
      return;
    }

    // 这样写有问题吗，要不要改成:
    // final state = await FlutterBluePlus.adapterState.where((s) => s == BluetoothAdapterState.on).first;
    final state = await FlutterBluePlus.adapterState.first;
    print('当前蓝牙状态: $state');

    if (state != BluetoothAdapterState.on) {
      print('请先打开蓝牙');
      if (!kIsWeb && Platform.isAndroid) {
        await FlutterBluePlus.turnOn();
      }
      return;
    }

    print('可以开始扫描');
    debugPrint('${DateTime.now()} 开始扫描');

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 15),
      withServices: [Guid('ffe0')],
    );

    debugPrint('${DateTime.now()} startScan调用完成');
  }

  _onDeviceTap(BluetoothDevice device) async {
    debugPrint('${device.remoteId} _onDeviceTap');
    if (_isConnecting) return;
    _isConnecting = true;
    Get.snackbar('开始连接123', device.remoteId.str);

    try {
      await FlutterBluePlus.stopScan();
      await device.connect(license: License.nonprofit);
    } catch (e) {
      _isConnecting = false;

      if (mounted) {
        Get.snackbar('连接失败', e.toString());
      }
      return;
    }

    _isConnecting = false;
    if (!mounted) return;

    // 单独Binding的写法；还有集中在GetMaterialApp的getPages + Get.toNamed写法
    Get.to(() => const DigitalKeyPage(), binding: BindingsBuilder(() {
      Get.lazyPut<DigitalKeyController>(
        () => DigitalKeyController(device),
      );
    }));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ListView.builder(
              itemCount: _scanResults.length,
              shrinkWrap: true, // 自适应
              itemBuilder: (context, index) {
                final result = _scanResults[index];
                return DeviceCard(
                  name: result.device.platformName,
                  rssi: result.rssi,
                  id: result.device.remoteId.str,
                  onConnect: () => _onDeviceTap(result.device),
                );
              },
            ),
            const SizedBox(height: 48),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8A15),
                  foregroundColor: Colors.white,
                  // textStyle: TextStyle(color: Colors.white),
                ),
                onPressed: () {
                  _isScanning ? FlutterBluePlus.stopScan() : onStartSearch();
                },
                child: _isScanning ? const Text('停止扫描') : const Text('开始扫描'),
              ),
            ),
          ],
        ));
  }
}
