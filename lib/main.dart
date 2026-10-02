import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'pages/scan_page.dart';

void main() {
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
