import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../dependency/injection.dart';
import '../../domain/entities/expense.dart';
import '../../services/photo/photo_color.dart';
import '../../services/photo/photo_loader.dart';
import '../widgets/expense_photo.dart';

/// Hai màu nền tối, cùng tông với [photo], đủ tối để chữ trắng vẫn dễ đọc.
({Color top, Color bottom}) photoTint(Color photo) {
  final hsl = HSLColor.fromColor(photo);
  final saturation = math.min(hsl.saturation * 1.4, 0.5);
  Color shade(double lightness) =>
      hsl.withSaturation(saturation).withLightness(lightness).toColor();
  return (top: shade(0.08), bottom: shade(0.17));
}

/// Màu chủ đạo của ảnh từng khoản chi; báo cho người nghe khi đọc xong một ảnh.
class PhotoColors extends ChangeNotifier {
  final _colors = <String, Color>{};
  final _reading = <String>{};
  var _disposed = false;

  /// `null` khi ảnh còn đang tải hoặc không đọc được.
  Color? of(Expense expense) {
    final known = _colors[expense.id];
    if (known != null) return known;

    final url = expense.photoUrl;
    final remote = url != null && url.startsWith(remotePhotoPrefix);
    if (expense.photoBytes == null && !remote) {
      return _colors[expense.id] = url == null
          ? TachColors.mintDeep
          : ExpensePhoto.sampleColor(url);
    }
    if (_reading.add(expense.id)) _read(expense);
    return null;
  }

  Future<void> _read(Expense expense) async {
    final bytes =
        expense.photoBytes ??
        await getIt<PhotoLoader>().load(
          expense.photoUrl!.substring(remotePhotoPrefix.length),
        );
    if (bytes == null) return;
    final color = await averagePhotoColor(bytes);
    if (color == null || _disposed) return;
    _colors[expense.id] = color;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Nền của bảng tin: ngả theo màu ảnh của khoản chi đang xem, và hòa dần sang
/// màu của khoản kế tiếp khi vuốt. Trang 0 là camera, nền đen.
class FeedBackground extends StatelessWidget {
  const FeedBackground({
    super.key,
    required this.pages,
    required this.colors,
    required this.expenses,
  });

  final PageController pages;
  final PhotoColors colors;
  final List<Expense> expenses;

  ({Color top, Color bottom}) _tintOf(int page) {
    const black = (top: TachColors.night, bottom: TachColors.night);
    if (page < 1 || page > expenses.length) return black;
    final color = colors.of(expenses[page - 1]);
    return color == null ? black : photoTint(color);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([pages, colors]),
      builder: (context, _) {
        final position = pages.hasClients && pages.position.haveDimensions
            ? pages.page ?? 0.0
            : 0.0;
        final page = position.floor();
        final from = _tintOf(page);
        // Lấy luôn màu của trang kế tiếp để nó có sẵn trước khi người dùng vuốt.
        final to = _tintOf(page + 1);
        final t = position - page;
        return DecoratedBox(
          key: const ValueKey('feed-background'),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(from.top, to.top, t)!,
                Color.lerp(from.bottom, to.bottom, t)!,
              ],
            ),
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}
