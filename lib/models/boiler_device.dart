import 'boiler_parameter.dart';

/// A single boiler installation the app is monitoring.
///
/// [id] is the device ID derived from the ESP32's MAC address (shown on
/// the HMI's System Info page, see boiler_monitor_firebase.ino) -- it
/// doubles as the Realtime Database key (`devices/<id>/latest`) and the
/// lookup key for live readings in DeviceStore. Adding a new boiler is just
/// adding one of these; no new screen or code is needed.
///
/// There are no connection details to store: every boiler lives in the same
/// Firebase project. This phone's boiler list is saved in the cloud (see
/// DeviceStore), keyed by this id.
class BoilerDevice {
  final String id;
  final String name;
  final String location;
  final Set<BoilerParameter> enabledParameters;
  final DateTime createdAt;

  BoilerDevice({
    required this.id,
    required this.name,
    required this.location,
    required this.enabledParameters,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  BoilerDevice copyWith({
    String? name,
    String? location,
    Set<BoilerParameter>? enabledParameters,
  }) {
    return BoilerDevice(
      id: id,
      name: name ?? this.name,
      location: location ?? this.location,
      enabledParameters: enabledParameters ?? this.enabledParameters,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'location': location,
        'parameters': enabledParameters.map((p) => p.name).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory BoilerDevice.fromJson(Map<String, dynamic> json) {
    return BoilerDevice(
      id: json['id'] as String,
      name: json['name'] as String,
      location: json['location'] as String,
      enabledParameters: (json['parameters'] as List)
          .map((name) => BoilerParameter.values.byName(name as String))
          .toSet(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
