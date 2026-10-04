import '../models/command_exchange.dart';
import 'package:get/get.dart';

class OperationRecord {
  OperationRecord({
    required this.name,
    required this.time,
  });

  final String name;
  final DateTime time;

  final result = '进行中'.obs;
  final exchanges = <CommandExchange>[].obs;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'time': time.toIso8601String(),
      'result': result.value,
      'exchanges': exchanges.map((e) => e.toJson()).toList(),
    };
  }
}
