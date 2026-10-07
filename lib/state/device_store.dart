import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../cloud/cloud_config.dart';
import '../models/boiler_device.dart';
import '../models/boiler_reading.dart';
import '../models/boiler_parameter.dart';

/// Maps each parameter to the fault name the firmware uses for it under
/// `faults/` in the Realtime Database node (see publishSensorsToFirebase()
/// in the .ino). Parameters with no entry here (voltage, pressure) have no
/// plausibility check in the firmware, so they never show as faulted.
const Map<BoilerParameter, String> _parameterFaultKey = {
  BoilerParameter.temperature: 'temperature',
  BoilerParameter.mainCurrent: 'main_current',
  BoilerParameter.elementCurrent1: 'heater1',
  BoilerParameter.elementCurrent2: 'heater2',
  BoilerParameter.elementCurrent3: 'heater3',
};

/// Single source of truth for which boilers this phone has linked and their
/// latest readings.
///
/// There are no customer accounts: the app holds a silent (anonymous)
/// Firebase session, and the boiler list is saved in the cloud under that
/// session (users/<uid>/boilers). A customer links a boiler by entering its
/// device ID and claim code. If the app is reinstalled the session is new, so
/// the boilers are simply added again. [attach] starts following the list for
/// a session; [detach] clears everything. One Realtime Database listener per
/// boiler (devices/<id>/latest) feeds readings in through [applyReading] --
/// screens never own their own subscription.
class DeviceStore extends ChangeNotifier {
  static const Duration _writeTimeout = Duration(seconds: 15);

  String? _uid;
  StreamSubscription<DatabaseEvent>? _listSub;
  bool _listLoaded = false;
  String? _listError;

  final List<BoilerDevice> _devices = [];
  final Map<String, BoilerReading> _readings = {};
  final Map<String, bool> _online = {};
  final Map<String, String> _connectionErrors = {};

  List<BoilerDevice> get devices => List.unmodifiable(_devices);

  /// False until the first copy of the customer's boiler list has arrived
  /// (so the UI can show a spinner instead of "no boilers yet").
  bool get listLoaded => _listLoaded;

  /// Non-null if the boiler list itself could not be loaded.
  String? get listError => _listError;

  BoilerReading? readingFor(String deviceId) => _readings[deviceId];

  /// Whether this boiler is live: the phone is connected to Firebase AND
  /// the boiler wrote recently. Set by FirebaseConnectionManager.
  bool isOnline(String deviceId) => _online[deviceId] ?? false;

  String? connectionErrorFor(String deviceId) => _connectionErrors[deviceId];

  /// True when the firmware itself flagged this parameter's sensor as
  /// faulted (floating/disconnected) in the most recent reading — not
  /// just reading 0, which can be a genuine value.
  bool hasFault(String deviceId, BoilerParameter param) {
    final faultKey = _parameterFaultKey[param];
    if (faultKey == null) return false;
    return _readings[deviceId]?.faults.contains(faultKey) ?? false;
  }

  void setDeviceOnline(String deviceId, bool online) {
    _online[deviceId] = online;
    if (online) _connectionErrors.remove(deviceId);
    notifyListeners();
  }

  void setConnectionError(String deviceId, String message) {
    _online[deviceId] = false;
    _connectionErrors[deviceId] = message;
    notifyListeners();
  }

  void clearConnectionError(String deviceId) {
    _connectionErrors.remove(deviceId);
    notifyListeners();
  }

  /// Starts following this customer's boiler list. Safe to call repeatedly
  /// with the same uid.
  void attach(String uid) {
    if (_uid == uid) return;
    detach();
    _uid = uid;
    _listSub = appDatabase.ref('users/$uid/boilers').onValue.listen(
      _onBoilerList,
      onError: (Object e) {
        _listError = (e is FirebaseException && e.code == 'permission-denied')
            ? 'Could not load your boilers (access denied).'
            : 'Could not load your boilers. Check your connection.';
        _listLoaded = true;
        notifyListeners();
      },
    );
  }

  /// Forgets everything -- called if the session disappears so stale boilers
  /// are never shown.
  void detach() {
    _listSub?.cancel();
    _listSub = null;
    _uid = null;
    _devices.clear();
    _readings.clear();
    _online.clear();
    _connectionErrors.clear();
    _listLoaded = false;
    _listError = null;
    notifyListeners();
  }

  void _onBoilerList(DatabaseEvent event) {
    final raw = event.snapshot.value;
    final parsed = <BoilerDevice>[];
    if (raw is Map) {
      raw.forEach((key, value) {
        if (value is! Map) return;
        final device = _deviceFromCloud(key.toString(), Map<String, dynamic>.from(value));
        if (device != null) parsed.add(device);
      });
    }
    parsed.sort((a, b) {
      final byDate = a.createdAt.compareTo(b.createdAt);
      return byDate != 0 ? byDate : a.name.compareTo(b.name);
    });

    _devices
      ..clear()
      ..addAll(parsed);

    // Forget live state for boilers that are no longer in the list.
    final ids = parsed.map((d) => d.id).toSet();
    _readings.removeWhere((id, _) => !ids.contains(id));
    _online.removeWhere((id, _) => !ids.contains(id));
    _connectionErrors.removeWhere((id, _) => !ids.contains(id));

    _listLoaded = true;
    _listError = null;
    notifyListeners();
  }

  BoilerDevice? _deviceFromCloud(String id, Map<String, dynamic> json) {
    final name = json['name'];
    final location = json['location'];
    if (name is! String || location is! String) return null;

    final rawParams = json['parameters'];
    final Iterable<dynamic> paramNames =
        rawParams is List ? rawParams : (rawParams is Map ? rawParams.values : const []);
    final byName = BoilerParameter.values.asNameMap();
    final params = paramNames.map((n) => byName[n.toString()]).whereType<BoilerParameter>().toSet();

    return BoilerDevice(
      id: id,
      name: name,
      location: location,
      enabledParameters: params,
      createdAt: DateTime.tryParse('${json['createdAt']}') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  /// Links a boiler to this phone's session.
  ///
  /// Step 1 proves the customer has the boiler's claim code: the database
  /// rules only accept the write devices/<id>/owners/<uid> if the value
  /// equals the secret claim code stored for that boiler. Step 2 saves the
  /// customer's own name/location/parameter choices.
  ///
  /// Returns null on success or a user-readable error message.
  Future<String?> addDevice(BoilerDevice device, String claimCode) async {
    final uid = _uid;
    if (uid == null) return 'Not connected to the cloud yet. Please try again.';
    final db = appDatabase;

    try {
      await db.ref('devices/${device.id}/owners/$uid').set(claimCode).timeout(_writeTimeout);
    } on TimeoutException {
      return 'No connection - check your internet and try again.';
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return 'Wrong device ID or claim code.';
      return 'Could not link the boiler (${e.code}).';
    }

    try {
      await db.ref('users/$uid/boilers/${device.id}').set({
        'name': device.name,
        'location': device.location,
        'parameters': device.enabledParameters.map((p) => p.name).toList(),
        'createdAt': device.createdAt.toIso8601String(),
      }).timeout(_writeTimeout);
    } on TimeoutException {
      return 'No connection - check your internet and try again.';
    } on FirebaseException catch (e) {
      return 'Could not save the boiler (${e.code}).';
    }
    return null;
  }

  /// Unlinks the boiler from this customer: removes it from their list and
  /// removes their ownership, so they can no longer read its data.
  /// Best effort -- the live list listener shows whatever actually happened.
  Future<void> removeDevice(String deviceId) async {
    final uid = _uid;
    if (uid == null) return;
    final db = appDatabase;
    try {
      await db.ref('users/$uid/boilers/$deviceId').remove().timeout(_writeTimeout);
      await db.ref('devices/$deviceId/owners/$uid').remove().timeout(_writeTimeout);
    } catch (_) {}
  }

  @override
  void dispose() {
    _listSub?.cancel();
    super.dispose();
  }

  /// Called by FirebaseConnectionManager whenever a boiler's
  /// devices/<id>/latest node changes.
  void applyReading(String deviceId, BoilerReading reading) {
    _readings[deviceId] = reading;
    notifyListeners();
  }

  double? valueFor(String deviceId, BoilerParameter param) {
    final r = _readings[deviceId];
    if (r == null) return null;
    switch (param) {
      case BoilerParameter.voltage:
        return r.voltage;
      case BoilerParameter.mainCurrent:
        return r.mainCurrent;
      case BoilerParameter.temperature:
        return r.temperature;
      case BoilerParameter.pressure:
        // Firmware computes and writes pressure in kPa directly
        // (see readSensors() in the .ino) -- no conversion needed here.
        return r.pressure;
      case BoilerParameter.elementCurrent1:
        return r.elementCurrent1;
      case BoilerParameter.elementCurrent2:
        return r.elementCurrent2;
      case BoilerParameter.elementCurrent3:
        return r.elementCurrent3;
    }
  }
}
