import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vytal_tek/backend/supabase_config.dart';

/// Global test setup — initializes Supabase once for widget/unit suites.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  try {
    await VytalSupabaseConfig.ensureInitialized();
  } catch (_) {
    // Already initialized in a previous isolate / hot reload.
  }
  await testMain();
}
