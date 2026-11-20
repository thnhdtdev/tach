import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/core/config/supabase_config.dart';
import 'src/dependency/injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SupabaseClient? supabase;
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
    supabase = Supabase.instance.client;
  }

  configureDependencies(supabase: supabase);
  runApp(const TachApp());
}
