import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../dependency/injection.dart';
import '../../domain/entities/expense.dart';
import '../../services/photo/photo_color.dart';
import '../../services/photo/photo_loader.dart';
import '../widgets/expense_photo.dart';

/// Hai màu nền cùng tông với [photo]. Ảnh càng sáng thì nền càng sáng, nhưng
/// dừng ở mức chữ trắng còn dễ đọc.
({Color top, Color bottom}) photoTint(Color photo) {
  final hsl = HSLColor.fromColor(photo);
  final saturation = math.min(hsl.saturation * 1.4, 0.5);
  Color shade(double lightness) =>
      hsl.withSaturation(saturation).withLightness(lightness).toColor();
  final bottom = 0.10 + 0.24 * hsl.lightness;
  return (top: shade(bottom * 0.6), bottom: shade(bottom));
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

/// Nền của màn chính: ngả theo màu ảnh của khoản chi đang xem, và hòa dần sang
/// màu của khoản kế tiếp khi vuốt. Trang 0 là camera: ngả theo hình đang ngắm
/// hoặc ảnh vừa chụp.
class FeedBackground extends StatelessWidget {
  const FeedBackground({
    super.key,
    required this.pages,
    required this.colors,
    required this.camera,
    required this.expenses,
  });

  final PageController pages;
  final PhotoColors colors;

  /// Màu của khung hình ở trang camera; `null` khi camera chưa có hình.
  final ValueListenable<Color?> camera;

  final List<Expense> expenses;

  ({Color top, Color bottom}) _tintOf(int page) {
    final color = page == 0
        ? camera.value
        : page <= expenses.length
        ? colors.of(expenses[page - 1])
        : null;
    return color == null
        ? (top: TachColors.night, bottom: TachColors.night)
        : photoTint(color);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([pages, colors, camera]),
      builder: (context, _) {
        final position = pages.hasClients && pages.position.haveDimensions
            ? pages.page ?? 0.0
            : 0.0;
        final page = position.floor();
        final from = _tintOf(page);
        // Lấy luôn màu của trang kế tiếp để nó có sẵn trước khi người dùng vuốt.
        final to = _tintOf(page + 1);
        final t = position - page;
        // Chuyển màu trong một nhịp ngắn để nền không giật khi vừa đọc xong màu
        // của một ảnh; ở camera thì chậm hơn vì màu hình đang ngắm đổi liên tục.
        return AnimatedContainer(
          key: const ValueKey('feed-background'),
          duration: Duration(milliseconds: position == 0 ? 600 : 220),
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
