import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/boiler_device.dart';
import '../models/boiler_reading.dart';
import '../state/device_store.dart';
import 'cloud_config.dart';

/// Listens to one Realtime Database node per boiler
/// (`devices/<id>/latest`, overwritten by the ESP32 every ~10 s) and feeds
/// DeviceStore. Watches DeviceStore and starts/stops listeners as boilers
/// appear or disappear. Screens never touch Firebase directly. The database
/// rules only allow a listener to read a boiler this phone has claimed with
/// the correct claim code.
///
/// Unlike MQTT, a Realtime Database node keeps its last value after the
/// boiler goes offline -- so "online" here means BOTH:
///   1. this phone is connected to Firebase, and
///   2. the boiler wrote fresh data recently (see [_staleAfter]).
class FirebaseConnectionManager {
  final DeviceStore store;

  /// The firmware writes every 10 s; allow several missed writes before
  /// calling the boiler offline.
  static const Duration _staleAfter = Duration(seconds: 45);

  final FirebaseDatabase _db = appDatabase;
  final Map<String, StreamSubscription<DatabaseEvent>> _subs = {};
  final Map<String, DateTime?> _lastDataAt = {};
  final Map<String, String> _status = {}; // last status pushed to the store, per boiler
  final Set<String> _seen = {};   // boilers whose first snapshot has arrived
  final Set<String> _failed = {}; // boilers whose listener died (e.g. permission denied)

  final DateTime _startedAt = DateTime.now();
  StreamSubscription<DatabaseEvent>? _connSub;
  Timer? _tick;
  bool _ready = false;
  bool _disposed = false;
  bool _cloudConnected = false;

  FirebaseConnectionManager(this.store) {
    store.addListener(_syncSubscriptions);
    _init();
  }

  Future<void> _init() async {
    // Firebase's built-in connection indicator for this phone.
    _connSub = _db.ref('.info/connected').onValue.listen((event) {
      _cloudConnected = event.snapshot.value == true;
      _refreshStatuses();
    });

    _ready = true;
    _syncSubscriptions();

    // Re-evaluate freshness periodically (a boiler going quiet produces no
    // event at all), and retry anything that failed.
    _tick = Timer.periodic(const Duration(seconds: 5), (_) => _onTick());
  }

  int _tickCount = 0;

  Future<void> _onTick() async {
    if (_disposed) return;
    _tickCount++;
    // Retry listeners that died (e.g. permission denied right after the
    // session started) every 30 s -- not on every tick, so a boiler this
    // phone genuinely has no access to doesn't hammer the database.
    if (_failed.isNotEmpty && _tickCount % 6 == 0 && FirebaseAuth.instance.currentUser != null) {
      for (final id in _failed.toList()) {
        _subs.remove(id)?.cancel();
        final matches = store.devices.where((d) => d.id == id);
        if (matches.isNotEmpty) _listen(matches.first);
      }
    }
    _refreshStatuses();
  }

  void _syncSubscriptions() {
    if (!_ready || _disposed) return;

    final currentIds = store.devices.map((d) => d.id).toSet();
    for (final id in _subs.keys.where((id) => !currentIds.contains(id)).toList()) {
      _subs.remove(id)?.cancel();
      _lastDataAt.remove(id);
      _status.remove(id);
      _seen.remove(id);
      _failed.remove(id);
    }
    for (final device in store.devices) {
      if (!_subs.containsKey(device.id)) _listen(device);
    }
  }

  void _listen(BoilerDevice device) {
    final id = device.id;
    _lastDataAt[id] = null;
    _failed.remove(id);
    _subs[id] = _db.ref('devices/$id/latest').onValue.listen(
      (event) => _onData(id, event.snapshot),
      onError: (Object e) {
        _failed.add(id);
        _push(id, 'error', _describe(e));
      },
    );
  }

  void _onData(String id, DataSnapshot snap) {
    _failed.remove(id);
    final raw = snap.value;

    if (raw is! Map) {
      // Node doesn't exist yet -- this boiler has never reported.
      _lastDataAt[id] = null;
      _seen.add(id);
      _refreshStatuses();
      return;
    }

    final json = Map<String, dynamic>.from(raw);
    final now = DateTime.now();
    final firstSnapshot = !_seen.contains(id);
    _seen.add(id);

    // Freshness: prefer the boiler's own timestamp. The very first snapshot
    // after subscribing is whatever was last stored (possibly days old), so
    // without a device timestamp it can't be trusted as fresh. Later
    // snapshots are live writes by definition.
    final deviceTime = BoilerReading.deviceTimeFrom(json);
    DateTime? receivedAt;
    if (deviceTime != null) {
      receivedAt = deviceTime.isAfter(now) ? now : deviceTime; // tolerate a fast device clock
    } else if (!firstSnapshot) {
      receivedAt = now;
    }
    _lastDataAt[id] = receivedAt;

    try {
      store.applyReading(id, BoilerReading.fromFirebase(json, lastUpdate: receivedAt ?? now));
    } catch (_) {
      _push(id, 'error', 'Received data that could not be read');
      return;
    }
    _refreshStatuses();
  }

  void _refreshStatuses() {
    final now = DateTime.now();
    for (final device in store.devices) {
      final id = device.id;
      if (_failed.contains(id)) continue; // keep the listener error message

      if (!_cloudConnected) {
        // Don't flash an error during the first few seconds while the
        // connection is still being established at app start.
        if (now.difference(_startedAt) > const Duration(seconds: 8)) {
          _push(id, 'offline', 'Not connected to the cloud');
        }
      } else if (!_seen.contains(id)) {
        continue; // first snapshot still loading -- nothing to report yet
      } else {
        final last = _lastDataAt[id];
        if (last == null && store.readingFor(id) == null) {
          _push(id, 'nodata', 'Waiting for the boiler to report');
        } else if (last == null || now.difference(last) >= _staleAfter) {
          _push(id, 'stale', 'Boiler is not reporting');
        } else {
          _push(id, 'online', null);
        }
      }
    }
  }

  /// Only touches the store when a boiler's status actually changes, so the
  /// 5 s tick doesn't trigger a UI rebuild every time.
  void _push(String id, String status, String? message) {
    if (_status[id] == status) return;
    _status[id] = status;
    if (status == 'online') {
      store.setDeviceOnline(id, true);
    } else {
      store.setConnectionError(id, message ?? 'Offline');
    }
  }

  String _describe(Object e) {
    if (e is FirebaseException && e.code == 'permission-denied') {
      return 'Access denied - this boiler is no longer linked to this phone. Remove it and add it again with its claim code.';
    }
    return 'Cloud error: $e';
  }

  void dispose() {
    _disposed = true;
    store.removeListener(_syncSubscriptions);
    _tick?.cancel();
    _connSub?.cancel();
    for (final sub in _subs.values) {
      sub.cancel();
    }
    _subs.clear();
  }
}
