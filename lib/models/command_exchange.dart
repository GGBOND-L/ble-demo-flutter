// 一条发送或接收的数据
class CommandExchange {
  CommandExchange({
    required this.direction,
    required this.bytes,
    required this.time,
  });

  final String direction; // TX：发送，RX：接收
  final List<int> bytes;
  final DateTime time;

  Map<String, dynamic> toJson() {
    return {
      'direction': direction,
      'bytes': bytes,
      'hex': bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(' ')
          .toUpperCase(),
      'time': time.toIso8601String(),
    };
  }
}
