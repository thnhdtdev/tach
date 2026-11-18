import 'package:material_ui/material_ui.dart';

import 'core/theme/app_theme.dart';
import 'presentation/splash/splash_screen.dart';

class TachApp extends StatelessWidget {
  const TachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tach',
      debugShowCheckedModeBanner: false,
      theme: tachTheme,
      home: const SplashScreen(),
    );
  }
}
