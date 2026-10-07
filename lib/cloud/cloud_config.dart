import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

/// Realtime Database URL for the Boiler2026 Firebase project. Must match
/// FB_DATABASE_URL in the firmware (the firmware drops the https://).
const String kDatabaseUrl = 'https://boiler2026-54bc8-default-rtdb.firebaseio.com';

/// The one database instance the whole app uses.
FirebaseDatabase get appDatabase =>
    FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: kDatabaseUrl);
