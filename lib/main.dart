import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'ui/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ScrapScanApp());
}

class ScrapScanApp extends StatelessWidget {
  const ScrapScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ScrapScan',
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
    );
  }
}
