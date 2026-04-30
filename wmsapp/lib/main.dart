import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:wmsapp/screens/home_screen.dart';
import 'theme/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const WmsApp());
}

class WmsApp extends StatelessWidget {
  const WmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeProvider,
      builder: (_, themeMode, __) => MaterialApp(
        title: 'WMS',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('th', 'TH'),
          Locale('en', 'US'),
        ],
        locale: const Locale('th', 'TH'),
        home: const HomeScreen(),
      ),
    );
  }
}
