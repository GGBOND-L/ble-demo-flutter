import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'services/ble_session_service.dart';
import 'pages/scan_page.dart';

void main() {
  Get.put<BleSessionService>(
    BleSessionService(),
    permanent: true,
  );
  runApp(const BleDemoApp());
}

class BleDemoApp extends StatelessWidget {
  const BleDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'BLE Demo',
      debugShowCheckedModeBanner: false,
      home: const BleTabPage(),
    );
  }
}
