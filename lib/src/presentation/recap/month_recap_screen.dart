import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../dependency/injection.dart';
import '../../domain/logic/recap.dart';
import '../../services/photo/photo_loader.dart';
import '../../services/photo/photo_sharer.dart';
import '../ledger/ledger_cubit.dart';
import 'recap_poster.dart';

/// Xem trước ảnh tổng kết tháng của nhóm đang mở rồi chia sẻ.
class MonthRecapScreen extends StatefulWidget {
  const MonthRecapScreen({super.key, required this.month});

  final DateTime month;

  @override
  State<MonthRecapScreen> createState() => _MonthRecapScreenState();
}

class _MonthRecapScreenState extends State<MonthRecapScreen> {
  final _posterKey = GlobalKey();
  final _photos = <String, Uint8List>{};
  late final MonthRecap _recap;

  var _photosReady = false;
  var _sharing = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<LedgerCubit>().state;
    _recap = monthRecap(expenses: state.expenses, month: widget.month);
    // Giải mã ảnh cần thông tin màn hình, thứ chưa có trong initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadPhotos();
    });
  }

  /// Ảnh phải tải và giải mã xong thì ảnh xuất ra mới không bị ô trống.
  Future<void> _loadPhotos() async {
    final loader = getIt<PhotoLoader>();
    for (final expense in _recap.highlights) {
      final url = expense.photoUrl;
      final bytes =
          expense.photoBytes ??
          (url != null && url.startsWith(remotePhotoPrefix)
              ? await loader.load(url.substring(remotePhotoPrefix.length))
              : null);
      if (bytes == null) continue;
      _photos[expense.id] = bytes;
      if (!mounted) return;
      try {
        await precacheImage(MemoryImage(bytes), context);
      } on Exception {
        _photos.remove(expense.id);
      }
    }
    if (mounted) setState(() => _photosReady = true);
  }

  Future<void> _share() async {
    final messenger = ScaffoldMessenger.of(context);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() => _sharing = true);
    try {
      final boundary =
          _posterKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      // 360×640 điểm, xuất gấp ba thành 1080×1920.
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await getIt<PhotoSharer>().shareImage(
        data!.buffer.asUint8List(),
        fileName: 'tach-thang-${widget.month.month}.png',
        origin: origin,
      );
    } on Exception {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Không mở được bảng chia sẻ. Thử lại nhé.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LedgerCubit>().state;

    return Scaffold(
      appBar: AppBar(title: Text('Tổng kết tháng ${widget.month.month}')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: FittedBox(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: RepaintBoundary(
                      key: _posterKey,
                      child: RecapPoster(
                        state: state,
                        recap: _recap,
                        photos: _photos,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _photosReady && !_sharing ? _share : null,
                  icon: const Icon(Icons.ios_share, size: 20),
                  label: Text(_photosReady ? 'Chia sẻ' : 'Đang tải ảnh…'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
