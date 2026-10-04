import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/operation_record.dart';

class OperationDetailPage extends StatelessWidget {
  const OperationDetailPage({
    super.key,
    required this.record,
  });

  final OperationRecord record;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(record.name)),
      body: Obx(() {
        return ListView.builder(
          itemCount: record.exchanges.length,
          itemBuilder: (context, index) {
            final exchange = record.exchanges[index];

            final hex = exchange.bytes
                .map((b) => b.toRadixString(16).padLeft(2, '0'))
                .join(' ')
                .toUpperCase();

            return ListTile(
              title: Text('${index + 1} · ${exchange.direction}'),
              subtitle: SelectableText(hex),
            );
          },
        );
      }),
    );
  }
}
