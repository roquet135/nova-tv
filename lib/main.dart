import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/storage.dart';
import 'theme/nova_theme.dart';
import 'screens/portals_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Storage.init();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const NovaApp());
}

class NovaApp extends StatelessWidget {
  const NovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NOVA TV',
      debugShowCheckedModeBanner: false,
      theme: NovaTheme.build(),
      home: const PortalsScreen(),
    );
  }
}
