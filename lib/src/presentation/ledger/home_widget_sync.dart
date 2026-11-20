import 'dart:async';
import 'dart:typed_data';

import '../../core/format/money.dart';
import '../../domain/entities/expense.dart';
import '../../services/home_widget/home_widget_updater.dart';
import '../../services/photo/photo_loader.dart';
import 'ledger_cubit.dart';

/// `null` khi chưa có gì để hiện: đang tải (vừa đăng xuất) hoặc chưa có nhóm.
WidgetContent? widgetContentOf(LedgerState state) {
  if (state.isLoading || !state.hasGroup) return null;

  final net = state.myNet;
  final latest = state.expenses.isEmpty ? null : state.expenses.first;
  final payer = latest == null ? null : state.member(latest.payerId);
  final avatar = payer?.avatarBytes;
  final tone = latest == null ? null : state.toneOf(latest.payerId);
  return WidgetContent(
    group: state.group.name,
    balanceLabel: net < 0
        ? 'Bạn cần trả'
        : net > 0
        ? 'Bạn được nhận'
        : 'Bạn đã sòng phẳng',
    balanceAmount: net == 0 ? null : formatVnd(net.abs()),
    balanceTone: net < 0
        ? WidgetBalanceTone.owe
        : net > 0
        ? WidgetBalanceTone.owed
        : WidgetBalanceTone.even,
    expenseId: latest?.id,
    payerInitial: payer == null
        ? null
        : (payer.name.isEmpty ? '?' : payer.name.substring(0, 1).toUpperCase()),
    payerTone: tone == null
        ? null
        : (tone.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0'),
    avatarKey: avatar == null ? null : Object.hashAll(avatar),
    note: latest?.note,
    amountShort: latest == null ? null : formatShortVnd(latest.amount),
    amountFull: latest == null ? null : formatVnd(latest.amount),
    hasPhoto: latest != null && _photoSource(latest) != null,
  );
}

/// Ảnh mẫu (`sample:`) không có dữ liệu ảnh thật để đưa sang widget.
Object? _photoSource(Expense expense) {
  final url = expense.photoUrl;
  if (expense.photoBytes != null) return expense.photoBytes;
  if (url != null && url.startsWith(remotePhotoPrefix)) return url;
  return null;
}

/// Đưa khoản chi mới nhất và số dư của nhóm đang mở lên widget màn hình chính
/// mỗi khi chúng thay đổi.
class HomeWidgetSync {
  HomeWidgetSync(LedgerCubit cubit, this._updater, this._photos) {
    cubit.stream.listen(_onState);
  }

  final HomeWidgetUpdater _updater;
  final PhotoLoader _photos;

  WidgetContent? _shown;
  var _hasShown = false;
  var _queue = Future<void>.value();

  void _onState(LedgerState state) {
    // Tải lỗi thì giữ nguyên những gì widget đang hiện.
    if (state.loadFailed) return;
    final content = widgetContentOf(state);
    if (_hasShown && content == _shown) return;
    _hasShown = true;
    _shown = content;

    final latest = content?.expenseId == null ? null : state.expenses.first;
    final avatar = latest == null
        ? null
        : state.member(latest.payerId).avatarBytes;
    _queue = _queue.then((_) async {
      try {
        await _updater.show(
          content,
          photo: await _photoOf(latest),
          avatar: avatar,
        );
      } on Exception {
        // Widget chỉ là phần hiển thị thêm; lỗi ở đây không được làm hỏng app.
      }
    });
  }

  Future<Uint8List?> _photoOf(Expense? expense) async {
    if (expense == null) return null;
    final source = _photoSource(expense);
    if (source is Uint8List) return source;
    if (source is String) {
      return _photos.load(source.substring(remotePhotoPrefix.length));
    }
    return null;
  }
}
