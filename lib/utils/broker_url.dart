/// Parses a broker address the user might paste in various forms —
/// `broker.hivemq.cloud`, `broker.hivemq.cloud:8883`,
/// `mqtts://broker.hivemq.cloud:8883` — into a plain host and port.
/// Defaults to 8883 (the standard TLS MQTT port, matching HiveMQ
/// Cloud) when no port is given.
({String host, int port}) parseBrokerUrl(String input) {
  var value = input.trim();
  for (final prefix in ['mqtts://', 'mqtt://', 'ssl://', 'tcp://', 'wss://', 'ws://']) {
    if (value.startsWith(prefix)) {
      value = value.substring(prefix.length);
      break;
    }
  }
  value = value.split('/').first; // drop any trailing path
  final parts = value.split(':');
  final host = parts.first;
  final port = parts.length > 1 ? (int.tryParse(parts[1]) ?? 8883) : 8883;
  return (host: host, port: port);
}
