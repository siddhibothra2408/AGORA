import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/agora_theme.dart';
import 'router/agora_router.dart';

/// Root Agora Application Widget
class AgoraApp extends ConsumerWidget {
  const AgoraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(agoraRouterProvider);

    return MaterialApp.router(
      title: 'Agora',
      debugShowCheckedModeBanner: false,
      theme: AgoraTheme.lightTheme,
      routerConfig: router,
    );
  }
}
