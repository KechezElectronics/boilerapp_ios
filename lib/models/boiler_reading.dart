/// A live snapshot of sensor values for one boiler, keyed by
/// BoilerDevice.id in DeviceStore.liveReadings. Populated from the
/// Realtime Database node `devices/<id>/latest` -- see
/// FirebaseConnectionManager, which calls DeviceStore.applyReading.
///
/// [voltage] is DC. [elementCurrent1/2/3] are the individual heating
/// element currents, not AC phase legs.
class BoilerReading {
  final double? voltage;
  final double? mainCurrent;
  final double? temperature;
  final double? pressure;
  final double? elementCurrent1;
  final double? elementCurrent2;
  final double? elementCurrent3;

  /// Names of currently-faulted channels (e.g. "temperature",
  /// "main_current", "heater1") -- a channel the firmware judged
  /// implausible (floating/disconnected) rather than a genuine zero.
  /// Only channels with an actual plausibility check in the firmware
  /// ever appear here: temperature and the 4 currents. Pressure/voltage
  /// have no such check, so they never show as faulted even at 0.
  final Set<String> faults;

  final DateTime lastUpdate;

  const BoilerReading({
    this.voltage,
    this.mainCurrent,
    this.temperature,
    this.pressure,
    this.elementCurrent1,
    this.elementCurrent2,
    this.elementCurrent3,
    this.faults = const {},
    required this.lastUpdate,
  });

  /// The boiler's own write time (Unix seconds, UTC, from NTP) as written
  /// by the firmware in the `ts` field, or null if the boiler's clock
  /// wasn't valid when it wrote (then `ts` is absent).
  static DateTime? deviceTimeFrom(Map<String, dynamic> json) {
    final ts = json['ts'];
    if (ts is num && ts > 1700000000) {
      return DateTime.fromMillisecondsSinceEpoch((ts * 1000).round());
    }
    return null;
  }

  /// Keys match what boiler_monitor_firebase.ino writes under
  /// devices/<id>/latest: snake_case main_current and heater1/2/3, plus a
  /// `faults` map of channel name -> true/false. If the firmware's field
  /// names ever change, update this mapping to match.
  factory BoilerReading.fromFirebase(Map<String, dynamic> json, {required DateTime lastUpdate}) {
    return BoilerReading(
      voltage: (json['voltage'] as num?)?.toDouble(),
      mainCurrent: (json['main_current'] as num?)?.toDouble(),
      temperature: (json['temperature'] as num?)?.toDouble(),
      pressure: (json['pressure'] as num?)?.toDouble(),
      elementCurrent1: (json['heater1'] as num?)?.toDouble(),
      elementCurrent2: (json['heater2'] as num?)?.toDouble(),
      elementCurrent3: (json['heater3'] as num?)?.toDouble(),
      faults: _parseFaults(json['faults']),
      lastUpdate: lastUpdate,
    );
  }

  static Set<String> _parseFaults(dynamic raw) {
    if (raw is Map) {
      return raw.entries.where((e) => e.value == true).map((e) => e.key.toString()).toSet();
    }
    if (raw is List) {
      // Old MQTT-style payload: a list of faulted channel names.
      return raw.map((e) => e.toString()).toSet();
    }
    return const {};
  }
}
