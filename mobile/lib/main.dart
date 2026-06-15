import 'package:family_digital_heritage_vault/src/app.dart';
import 'package:family_digital_heritage_vault/src/core/config/supabase_config.dart';
import 'package:family_digital_heritage_vault/src/core/services/service_locator.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  // Initialize API services
  services.initialize();

  runApp(const FamilyVaultApp());
}
