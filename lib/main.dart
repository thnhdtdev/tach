import 'package:material_ui/material_ui.dart';

/// Màu thương hiệu chính của Tach (cam đất).
const tachCoral = Color(0xFFD85A30);

void main() {
  runApp(const TachApp());
}

class TachApp extends StatelessWidget {
  const TachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tach',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: tachCoral),
      ),
      home: const SplashScreen(),
    );
  }
}

/// Màn hình tạm thời cho tới khi có màn camera đầu tiên.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: tachCoral,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tach',
              style: textTheme.displayMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Chụp là ghi, tách là xong.',
              style: textTheme.titleMedium?.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
