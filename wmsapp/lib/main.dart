import 'package:flutter/material.dart';
import 'package:wmsapp/screens/home_screen.dart';
import 'package:wmsapp/services/connectivity_service.dart';
import 'package:wmsapp/services/offline_service.dart';
import 'theme/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // initialize services
  await OfflineService().initialize();
  ConnectivityService().initialize();
  runApp(const WmsApp());
}

class WmsApp extends StatelessWidget {
  const WmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WMS',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}
