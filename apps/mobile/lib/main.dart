import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'backend/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await VytalSupabaseConfig.ensureInitialized();
  runApp(const ProviderScope(child: VytalApp()));
}
