import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

const _family = 'BeVietnamPro';

/// Cỡ chữ chung. Chiều cao dòng rộng hơn mặc định để dấu tiếng Việt
/// (ví dụ "ễ", "ậ") không chạm dòng trên.
TextTheme _textTheme(Color color, Color soft) {
  TextStyle style(
    double size,
    FontWeight weight,
    double height, {
    double spacing = 0,
    Color? c,
  }) {
    return TextStyle(
      fontFamily: _family,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: spacing,
      color: c ?? color,
    );
  }

  return TextTheme(
    displayLarge: style(56, FontWeight.w700, 1.1, spacing: -1.5),
    displaySmall: style(40, FontWeight.w700, 1.15, spacing: -1),
    headlineMedium: style(28, FontWeight.w700, 1.25, spacing: -0.4),
    titleLarge: style(20, FontWeight.w600, 1.3, spacing: -0.2),
    titleMedium: style(17, FontWeight.w600, 1.35),
    bodyLarge: style(16, FontWeight.w400, 1.45),
    bodyMedium: style(14, FontWeight.w400, 1.45, c: soft),
    bodySmall: style(13, FontWeight.w400, 1.4, c: soft),
    labelLarge: style(15, FontWeight.w600, 1.2),
  );
}

final _pillButton = ButtonStyle(
  minimumSize: const WidgetStatePropertyAll(Size(64, 52)),
  shape: const WidgetStatePropertyAll(StadiumBorder()),
  textStyle: const WidgetStatePropertyAll(
    TextStyle(fontFamily: _family, fontSize: 16, fontWeight: FontWeight.w600),
  ),
);

/// Theme sáng cho các màn sổ sách: lưới tháng, số dư, đăng nhập.
final tachLightTheme = ThemeData(
  brightness: Brightness.light,
  fontFamily: _family,
  colorScheme: ColorScheme.fromSeed(seedColor: TachColors.mint).copyWith(
    primary: TachColors.mint,
    onPrimary: TachColors.onMint,
    surface: TachColors.paper,
    onSurface: TachColors.ink,
    outline: TachColors.line,
  ),
  scaffoldBackgroundColor: TachColors.paper,
  textTheme: _textTheme(TachColors.ink, TachColors.inkSoft),
  appBarTheme: const AppBarTheme(
    backgroundColor: TachColors.paper,
    foregroundColor: TachColors.ink,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(
      fontFamily: _family,
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: TachColors.ink,
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(style: _pillButton),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: _pillButton.copyWith(
      foregroundColor: const WidgetStatePropertyAll(TachColors.ink),
      side: const WidgetStatePropertyAll(BorderSide(color: TachColors.line)),
    ),
  ),
  dividerTheme: const DividerThemeData(color: TachColors.line, thickness: 1),
);

/// Theme tối cho camera và bảng tin, nơi ảnh là nội dung chính.
final tachNightTheme = ThemeData(
  brightness: Brightness.dark,
  fontFamily: _family,
  colorScheme:
      ColorScheme.fromSeed(
        seedColor: TachColors.mint,
        brightness: Brightness.dark,
      ).copyWith(
        primary: TachColors.mint,
        onPrimary: TachColors.onMint,
        surface: TachColors.night,
        onSurface: Colors.white,
      ),
  scaffoldBackgroundColor: TachColors.night,
  textTheme: _textTheme(Colors.white, Colors.white.withValues(alpha: 0.62)),
  filledButtonTheme: FilledButtonThemeData(style: _pillButton),
);
