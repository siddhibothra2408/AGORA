import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/agora_firebase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (safely handles emulator suite or fallback)
  await AgoraFirebaseConfig.initialize();

  runApp(const ProviderScope(child: AgoraApp()));
}
