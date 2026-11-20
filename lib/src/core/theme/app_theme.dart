import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

const _family = 'Montserrat';

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

const _title = TextStyle(
  fontFamily: _family,
  fontSize: 17,
  fontWeight: FontWeight.w600,
  color: Colors.white,
);

/// App chỉ có một theme, nền tối, để các màn phụ liền mạch với camera và
/// bảng tin.
final tachTheme = ThemeData(
  brightness: Brightness.dark,
  fontFamily: _family,
  // Chỉ có tác dụng với bộ icon Symbols; nét đậm cho dễ thấy trên nền ảnh.
  iconTheme: const IconThemeData(weight: 700),
  colorScheme:
      ColorScheme.fromSeed(
        seedColor: TachColors.mint,
        brightness: Brightness.dark,
      ).copyWith(
        primary: TachColors.mint,
        onPrimary: TachColors.onMint,
        surface: TachColors.night,
        onSurface: Colors.white,
        onSurfaceVariant: TachColors.soft,
        outline: TachColors.hairline,
        error: TachColors.danger,
      ),
  scaffoldBackgroundColor: TachColors.night,
  textTheme: _textTheme(Colors.white, TachColors.soft),
  appBarTheme: const AppBarTheme(
    backgroundColor: TachColors.night,
    foregroundColor: Colors.white,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
    titleTextStyle: _title,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: _pillButton.copyWith(
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? TachColors.fill
            : TachColors.mint,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? Colors.white.withValues(alpha: 0.4)
            : TachColors.onMint,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: _pillButton.copyWith(
      foregroundColor: const WidgetStatePropertyAll(Colors.white),
      side: const WidgetStatePropertyAll(BorderSide(color: Color(0x4DFFFFFF))),
    ),
  ),
  dividerTheme: const DividerThemeData(
    color: TachColors.hairline,
    thickness: 1,
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: TachColors.mintLight,
      textStyle: const TextStyle(
        fontFamily: _family,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: TachColors.night,
    modalBackgroundColor: TachColors.night,
    surfaceTintColor: Colors.transparent,
    dragHandleColor: Color(0x4DFFFFFF),
  ),
  listTileTheme: const ListTileThemeData(
    iconColor: Colors.white,
    textColor: Colors.white,
  ),
  dialogTheme: const DialogThemeData(
    backgroundColor: TachColors.nightRaised,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(24)),
    ),
    titleTextStyle: TextStyle(
      fontFamily: _family,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.3,
      color: Colors.white,
    ),
    contentTextStyle: TextStyle(
      fontFamily: _family,
      fontSize: 16,
      height: 1.45,
      color: TachColors.soft,
    ),
  ),
);
