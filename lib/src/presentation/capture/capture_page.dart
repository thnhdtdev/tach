import 'dart:async';
import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../dependency/injection.dart';
import '../../services/camera/capture_camera.dart';
import '../../services/photo/photo_color.dart';
import '../ledger/ledger_cubit.dart';
import '../widgets/expense_photo.dart';
import '../widgets/member_avatar.dart';
import 'amount_keypad.dart';
import 'zoom_control.dart';

enum _Stage { viewfinder, amount, people }

class CapturePage extends StatefulWidget {
  const CapturePage({
    super.key,
    required this.onBusyChanged,
    required this.onFrameColorChanged,
    required this.onOpenFeed,
    required this.onOpenProfile,
    required this.onOpenGroups,
  });

  final ValueChanged<bool> onBusyChanged;

  /// Màu chủ đạo của hình đang ngắm hoặc ảnh vừa chụp; `null` khi chưa có hình.
  final ValueChanged<Color?> onFrameColorChanged;
  final VoidCallback onOpenFeed;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenGroups;

  @override
  State<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends State<CapturePage> with WidgetsBindingObserver {
  static const _maxDigits = 6;

  static const _sampleMinZoom = 0.5;
  static const _sampleMaxZoom = 6.0;

  final _note = TextEditingController();
  final _noteFocus = FocusNode();

  final CaptureCamera _camera = getIt<CaptureCamera>();
  var _cameraStatus = CameraStatus.starting;
  var _openingCamera = false;
  var _appResumed = true;
  var _routeCurrent = true;
  var _takingPhoto = false;

  var _stage = _Stage.viewfinder;
  String? _photoUrl;
  Uint8List? _photoBytes;

  /// Các chữ số đã gõ, tính theo nghìn đồng: "30" là 30.000đ.
  var _digits = '';
  var _excluded = <String>{};
  var _flashOn = false;

  var _zoom = 1.0;
  var _pinchStartZoom = 1.0;
  var _sendingZoom = false;
  var _captures = 0;
  String? _toast;
  Timer? _toastTimer;

  Timer? _frameColorTimer;
  Color? _viewfinderColor;

  int get _amount => _digits.isEmpty ? 0 : int.parse(_digits) * 1000;

  bool get _useSamplePhoto =>
      kDebugMode && _cameraStatus == CameraStatus.unavailable;

  bool get _canFlip =>
      _cameraStatus == CameraStatus.ready &&
      _camera.canFlip &&
      !_openingCamera &&
      !_takingPhoto;

  bool get _canShoot =>
      !_takingPhoto && (_cameraStatus == CameraStatus.ready || _useSamplePhoto);

  double get _minZoom => switch (_cameraStatus) {
    CameraStatus.ready => _camera.minZoom,
    CameraStatus.unavailable when _useSamplePhoto => _sampleMinZoom,
    _ => 1,
  };

  double get _maxZoom => switch (_cameraStatus) {
    CameraStatus.ready => _camera.maxZoom,
    CameraStatus.unavailable when _useSamplePhoto => _sampleMaxZoom,
    _ => 1,
  };

  bool get _canZoom => _stage == _Stage.viewfinder && _maxZoom > _minZoom;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _noteFocus.addListener(_onNoteFocusChanged);
    _frameColorTimer = Timer.periodic(
      const Duration(milliseconds: 800),
      (_) => _readViewfinderColor(),
    );
  }

  bool get _viewfinderLive =>
      _stage == _Stage.viewfinder &&
      _cameraStatus == CameraStatus.ready &&
      !_takingPhoto;

  Future<void> _readViewfinderColor() async {
    if (!mounted || !_viewfinderLive) return;
    final color = await _camera.previewColor();
    if (!mounted || color == null || !_viewfinderLive) return;
    _viewfinderColor = color;
    widget.onFrameColorChanged(color);
  }

  void _reportViewfinderColor() {
    widget.onFrameColorChanged(switch (_cameraStatus) {
      CameraStatus.ready => _viewfinderColor,
      CameraStatus.unavailable when _useSamplePhoto => ExpensePhoto.sampleColor(
        'sample:viewfinder',
      ),
      _ => null,
    });
  }

  void _onNoteFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeCurrent = ModalRoute.isCurrentOf(context) ?? true;
    _syncCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    _syncCamera();
  }

  Future<void> _syncCamera() async {
    final wanted = _appResumed && _routeCurrent;
    if (!wanted) {
      // Đang mở dở (ví dụ hộp xin quyền đang hiện) thì để yên; mở xong sẽ tự
      // kiểm tra lại bên dưới.
      if (_cameraStatus != CameraStatus.ready) return;
      setState(() {
        _cameraStatus = CameraStatus.starting;
        _zoom = 1;
      });
      await _camera.close();
      return;
    }
    if (_openingCamera || _cameraStatus == CameraStatus.ready) return;
    await _openWith(_camera.open);
  }

  Future<void> _flipCamera() async {
    if (!_canFlip) return;
    setState(() {
      _cameraStatus = CameraStatus.starting;
      _zoom = 1;
    });
    await _openWith(_camera.flip);
  }

  Future<void> _openWith(Future<CameraStatus> Function() action) async {
    _openingCamera = true;
    final status = await action();
    _openingCamera = false;
    if (!mounted) return;

    // Trong lúc mở, màn này có thể đã bị che hoặc app đã xuống nền.
    if (!(_appResumed && _routeCurrent)) {
      await _camera.close();
      return;
    }
    setState(() {
      _cameraStatus = status;
      _zoom = 1;
    });
    if (_stage == _Stage.viewfinder) _reportViewfinderColor();
    _readViewfinderColor();

    if (status == CameraStatus.ready && _flashOn) {
      // Camera trước thường không có đèn flash; khi đó tắt nút flash theo.
      final applied = await _camera.setFlash(true);
      if (!applied && mounted) setState(() => _flashOn = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera.close();
    _toastTimer?.cancel();
    _frameColorTimer?.cancel();
    _note.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  void _setStage(_Stage stage) {
    final wasBusy = _stage != _Stage.viewfinder;
    final isBusy = stage != _Stage.viewfinder;
    setState(() => _stage = stage);
    if (wasBusy != isBusy) widget.onBusyChanged(isBusy);
    if (!isBusy) _reportViewfinderColor();
  }

  void _start({String? photoUrl, Uint8List? photoBytes}) {
    setState(() {
      _photoUrl = photoUrl;
      _photoBytes = photoBytes;
      _digits = '';
      _excluded = {};
      _note.clear();
    });
    _setStage(_Stage.amount);
    _reportPhotoColor(photoUrl, photoBytes);
  }

  Future<void> _reportPhotoColor(String? url, Uint8List? bytes) async {
    if (bytes == null) {
      if (url != null) {
        widget.onFrameColorChanged(ExpensePhoto.sampleColor(url));
      }
      return;
    }
    final shot = _captures;
    final color = await averagePhotoColor(bytes);
    final stillThisShot = shot == _captures && _stage != _Stage.viewfinder;
    if (mounted && stillThisShot && color != null) {
      widget.onFrameColorChanged(color);
    }
  }

  Future<void> _shoot() async {
    if (!_canShoot) return;
    if (_useSamplePhoto) {
      setState(() => _captures++);
      _start(photoUrl: 'sample:viewfinder');
      return;
    }

    setState(() {
      _takingPhoto = true;
      _captures++;
    });
    try {
      final bytes = await _camera.takePhoto();
      if (mounted) _start(photoBytes: bytes);
    } on Exception {
      if (mounted) _showToast('Không chụp được ảnh. Thử lại nhé.');
    } finally {
      if (mounted) setState(() => _takingPhoto = false);
    }
  }

  Future<void> _toggleFlash() async {
    final wanted = !_flashOn;
    if (_cameraStatus == CameraStatus.ready) {
      final applied = await _camera.setFlash(wanted);
      if (!mounted) return;
      if (!applied) {
        _showToast('Camera này không có đèn flash.');
        return;
      }
    }
    setState(() => _flashOn = wanted);
  }

  /// Nút zoom xoay vòng 1× → 2× → 0,5× → 1×. Máy không có ống kính góc siêu
  /// rộng thì bỏ qua mức 0,5×. Mức lẻ do chụm hai ngón tay tính như mức gần nó:
  /// trên 1× thì coi như 2×, dưới 1× thì coi như 0,5×.
  void _toggleZoom() {
    final atOne = formatZoom(_zoom) == '1×';
    if (atOne && _maxZoom > 1) {
      _setZoom(math.min(2, _maxZoom));
    } else if ((atOne || _zoom > 1) && _minZoom < 1) {
      _setZoom(_minZoom);
    } else {
      _setZoom(1);
    }
  }

  void _setZoom(double value) {
    final zoom = value.clamp(_minZoom, _maxZoom).toDouble();
    if (zoom == _zoom) return;
    setState(() => _zoom = zoom);
    _sendZoom();
  }

  /// Gửi mức zoom mới nhất xuống camera, mỗi lúc một lệnh: chụm hai ngón tay
  /// phát ra nhiều mức hơn camera kịp nhận, và qua mốc 1× camera còn phải đổi
  /// ống kính.
  Future<void> _sendZoom() async {
    if (_sendingZoom) return;
    _sendingZoom = true;
    double? sent;
    while (mounted && _cameraStatus == CameraStatus.ready && sent != _zoom) {
      sent = _zoom;
      final status = await _camera.setZoom(sent);
      if (!mounted || _cameraStatus != CameraStatus.ready) break;
      // Vẽ lại vì hình xem trực tiếp có thể vừa chuyển sang ống kính khác.
      setState(() => _cameraStatus = status);
    }
    _sendingZoom = false;

    // Ngón tay đã dừng: nút zoom hiện đúng mức camera đang dùng, ví dụ 1× khi
    // người dùng thu nhỏ chưa đủ để sang ống kính góc siêu rộng.
    if (mounted &&
        _cameraStatus == CameraStatus.ready &&
        sent == _zoom &&
        _camera.zoom != _zoom) {
      setState(() => _zoom = _camera.zoom);
    }
  }

  void _showToast(String message) {
    setState(() => _toast = message);
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  void _cancel() {
    _noteFocus.unfocus();
    _setStage(_Stage.viewfinder);
  }

  void _onKey(String key) {
    setState(() {
      if (key == AmountKeypad.backspace) {
        if (_digits.isNotEmpty) {
          _digits = _digits.substring(0, _digits.length - 1);
        }
        return;
      }
      if (_digits.isEmpty && key.startsWith('0')) return;
      final next = _digits + key;
      if (next.length <= _maxDigits) _digits = next;
    });
  }

  void _send(LedgerCubit cubit) {
    final state = cubit.state;
    final participants = [
      for (final m in state.group.members)
        if (!_excluded.contains(m.id)) m.id,
    ];
    final expense = cubit.addExpense(
      amount: _amount,
      note: _note.text.trim(),
      participantIds: participants,
      photoUrl: _photoUrl,
      photoBytes: _photoBytes,
    );

    final others = participants.where((id) => id != state.meId).length;
    final owedToMe = expense.amount - (expense.splits[state.meId] ?? 0);
    _showToast(
      others == 0
          ? 'Đã gửi'
          : 'Đã gửi. $others người nợ bạn ${formatVnd(owedToMe)}',
    );
    _setStage(_Stage.viewfinder);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LedgerCubit>();
    final state = context.watch<LedgerCubit>().state;
    final typingNote = _noteFocus.hasFocus;

    return SafeArea(
      child: Column(
        children: [
          SizedBox(height: 56, child: _topBar(state)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: PinchZoomDetector(
                      enabled: _canZoom,
                      onStart: () => _pinchStartZoom = _zoom,
                      onScale: (scale) => _setZoom(_pinchStartZoom * scale),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_stage != _Stage.viewfinder)
                            ExpensePhoto(
                              photoUrl: _photoUrl,
                              photoBytes: _photoBytes,
                            )
                          else if (_cameraStatus == CameraStatus.ready)
                            _camera.preview()
                          else
                            Transform.scale(
                              scale: _useSamplePhoto
                                  ? _zoom / _sampleMinZoom
                                  : 1,
                              child: const ExpensePhoto(
                                photoUrl: 'sample:viewfinder',
                              ),
                            ),
                          if (_stage == _Stage.viewfinder) ...[
                            const _FocusBrackets(),
                            if (_cameraNotice() case final notice?)
                              _CameraNotice(notice: notice),
                            if (_canZoom)
                              Positioned(
                                top: 30,
                                right: 30,
                                child: ZoomButton(
                                  zoom: _zoom,
                                  onPressed: _toggleZoom,
                                ),
                              ),
                          ],
                          if (_stage != _Stage.viewfinder)
                            _amountOnPhoto(context),
                          if (_captures > 0)
                            IgnorePointer(
                              // Khóa đặt ở widget ngoài cùng để hiệu ứng chớp
                              // không chạy lại khi các lớp khác trong Stack đổi
                              // chỗ.
                              key: ValueKey(_captures),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.85, end: 0),
                                duration: const Duration(milliseconds: 260),
                                builder: (_, opacity, _) => ColoredBox(
                                  color: Colors.white.withValues(
                                    alpha: opacity,
                                  ),
                                ),
                              ),
                            ),
                          if (_toast != null)
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: _Toast(message: _toast!),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: switch (_stage) {
              _Stage.viewfinder => _viewfinderControls(state),
              _Stage.amount => _amountControls(typingNote: typingNote),
              _Stage.people => _peopleControls(cubit, state),
            },
          ),
        ],
      ),
    );
  }

  ({String title, String body})? _cameraNotice() {
    return switch (_cameraStatus) {
      CameraStatus.ready || CameraStatus.starting => null,
      CameraStatus.denied => (
        title: 'Tach chưa được dùng camera',
        body:
            'Mở Cài đặt của máy, chọn Tach rồi bật Camera. '
            'Trong lúc đó bạn vẫn ghi được khoản không cần ảnh.',
      ),
      CameraStatus.unavailable => (
        title: 'Máy này không có camera',
        body: _useSamplePhoto
            ? 'Bản thử nghiệm: bấm nút chụp để dùng ảnh mẫu.'
            : 'Bạn vẫn ghi được khoản không cần ảnh.',
      ),
    };
  }

  Widget _topBar(LedgerState state) {
    final text = Theme.of(context).textTheme;
    switch (_stage) {
      case _Stage.viewfinder:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const SizedBox(width: 44),
              Expanded(
                child: Center(
                  child: Tooltip(
                    message: 'Đổi nhóm',
                    child: Material(
                      color: TachColors.nightRaised,
                      borderRadius: BorderRadius.circular(22),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: widget.onOpenGroups,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 11, 10, 11),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  state.group.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.labelLarge,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${state.group.members.length} người',
                                style: text.bodySmall,
                              ),
                              Icon(
                                Icons.keyboard_arrow_down,
                                size: 20,
                                color: Colors.white.withValues(alpha: 0.62),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Tooltip(
                message: 'Hồ sơ',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: widget.onOpenProfile,
                  child: SizedBox.square(
                    dimension: 44,
                    child: Center(
                      child: MemberAvatar(
                        name: state.member(state.meId).name,
                        tone: state.toneOf(state.meId),
                        photo: state.member(state.meId).avatarBytes,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      case _Stage.amount:
      case _Stage.people:
        return Center(
          child: Text(
            _stage == _Stage.amount ? 'Bao nhiêu tiền?' : 'Chia cho ai?',
            style: text.titleMedium,
          ),
        );
    }
  }

  Widget _amountOnPhoto(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final editing = _stage == _Stage.amount;
    const shadow = [Shadow(color: Color(0x99000000), blurRadius: 18)];
    final big = text.displayLarge!.copyWith(shadows: shadow);
    final dim = big.copyWith(color: Colors.white.withValues(alpha: 0.55));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _noteFocus.unfocus,
      child: DecoratedBox(
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.28)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Semantics(
                container: true,
                label: 'Số tiền ${formatVnd(_amount)}',
                excludeSemantics: true,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _digits.isEmpty
                      ? Text('0đ', style: dim)
                      : Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: formatThousands(int.parse(_digits)),
                                style: big,
                              ),
                              TextSpan(text: '.000đ', style: dim),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              if (editing)
                Container(
                  constraints: const BoxConstraints(maxWidth: 260),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: TextField(
                    controller: _note,
                    focusNode: _noteFocus,
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [LengthLimitingTextInputFormatter(40)],
                    style: text.titleMedium,
                    cursorColor: TachColors.mintLight,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 11,
                      ),
                      hintText: 'Thêm ghi chú',
                      hintStyle: text.titleMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                )
              else if (_note.text.trim().isNotEmpty)
                Text(
                  _note.text.trim(),
                  textAlign: TextAlign.center,
                  style: text.titleLarge?.copyWith(shadows: shadow),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _viewfinderControls(LedgerState state) {
    final text = Theme.of(context).textTheme;
    final latest = state.expenses.isEmpty ? null : state.expenses.first;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton.icon(
            onPressed: _start,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white.withValues(alpha: 0.85),
              minimumSize: const Size(64, 44),
            ),
            icon: const Icon(Icons.edit_note, size: 20),
            label: const Text('Ghi không cần ảnh'),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: _toggleFlash,
                tooltip: _flashOn ? 'Tắt đèn flash' : 'Bật đèn flash',
                iconSize: 26,
                icon: Icon(
                  _flashOn ? Icons.flash_on : Icons.flash_off,
                  color: Colors.white,
                ),
              ),
              _ShutterButton(onPressed: _canShoot ? _shoot : null),
              IconButton(
                onPressed: _canFlip ? _flipCamera : null,
                tooltip: _camera.isFront
                    ? 'Đổi sang camera sau'
                    : 'Đổi sang camera trước',
                iconSize: 26,
                color: Colors.white,
                disabledColor: Colors.white.withValues(alpha: 0.35),
                icon: const Icon(Icons.cameraswitch_outlined),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: widget.onOpenFeed,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (latest != null)
                    Text(
                      '${state.displayName(latest.payerId)} vừa ghi '
                      '${latest.note.isEmpty ? 'một khoản' : latest.note} '
                      '${formatShortVnd(latest.amount)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall,
                    )
                  else
                    Text('Chưa có khoản chi nào', style: text.bodySmall),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 22,
                    color: Colors.white.withValues(alpha: 0.62),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountControls({required bool typingNote}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!typingNote) ...[
            Row(
              children: [
                for (final quick in const ['15', '20', '50'])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: OutlinedButton(
                        onPressed: () => setState(() => _digits = quick),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          foregroundColor: TachColors.mintLight,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                          shape: const StadiumBorder(),
                        ),
                        child: Text('${quick}k'),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            AmountKeypad(onKey: _onKey),
            const SizedBox(height: 4),
          ],
          _ActionRow(
            leading: IconButton(
              onPressed: _cancel,
              tooltip: 'Hủy',
              iconSize: 28,
              icon: const Icon(Icons.close, color: Colors.white),
            ),
            action: _RoundAction(
              label: 'Tiếp',
              icon: Icons.arrow_forward_rounded,
              size: 56,
              onPressed: _amount == 0
                  ? null
                  : () {
                      _noteFocus.unfocus();
                      _setStage(_Stage.people);
                    },
            ),
            trailing: typingNote
                ? null
                : IconButton(
                    onPressed: _noteFocus.requestFocus,
                    tooltip: 'Thêm ghi chú',
                    iconSize: 26,
                    icon: const Icon(Icons.text_fields, color: Colors.white),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _peopleControls(LedgerCubit cubit, LedgerState state) {
    final text = Theme.of(context).textTheme;
    final members = state.group.members;
    final count = members.length - _excluded.length;
    final share = count == 0 ? 0 : _amount ~/ count;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count == 0
                ? 'Chọn ít nhất một người'
                : 'Chia đều $count người, mỗi người ${formatVnd(share)}',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 10,
            children: [
              for (final m in members)
                _PersonToggle(
                  name: state.displayName(m.id),
                  initialOf: m.name,
                  tone: state.toneOf(m.id),
                  photo: m.avatarBytes,
                  selected: !_excluded.contains(m.id),
                  onTap: () => setState(() {
                    if (!_excluded.remove(m.id)) _excluded.add(m.id);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _ActionRow(
            leading: IconButton(
              onPressed: () => _setStage(_Stage.amount),
              tooltip: 'Sửa số tiền',
              iconSize: 28,
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            action: _RoundAction(
              label: 'Gửi',
              icon: CupertinoIcons.paperplane,
              onPressed: count == 0 ? null : () => _send(cubit),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.leading,
    required this.action,
    this.trailing,
  });

  final Widget leading;
  final Widget action;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Center(child: leading)),
        action,
        Expanded(child: Center(child: trailing)),
      ],
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.size = 78,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: enabled ? TachColors.mint : Colors.white.withValues(alpha: 0.1),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: size,
            child: Icon(
              icon,
              size: size * 0.44,
              color: enabled
                  ? TachColors.onMint
                  : Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null,
      label: 'Chụp',
      child: GestureDetector(
        onTap: onPressed,
        child: Opacity(
          opacity: onPressed == null ? 0.35 : 1,
          child: Container(
            width: 78,
            height: 78,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraNotice extends StatelessWidget {
  const _CameraNotice({required this.notice});

  final ({String title, String body}) notice;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.no_photography_outlined,
              size: 36,
              color: Colors.white.withValues(alpha: 0.85),
            ),
            const SizedBox(height: 12),
            Text(
              notice.title,
              textAlign: TextAlign.center,
              style: text.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              notice.body,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonToggle extends StatelessWidget {
  const _PersonToggle({
    required this.name,
    required this.initialOf,
    required this.tone,
    required this.photo,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String initialOf;
  final Color tone;
  final Uint8List? photo;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 140),
          opacity: selected ? 1 : 0.35,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  MemberAvatar(
                    name: initialOf,
                    tone: tone,
                    photo: photo,
                    size: 52,
                  ),
                  if (selected)
                    Positioned(
                      right: -3,
                      bottom: -3,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: TachColors.mint,
                          shape: BoxShape.circle,
                          border: Border.all(color: TachColors.night, width: 2),
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 14,
                          color: TachColors.onMint,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(name, style: text.bodySmall?.copyWith(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              size: 18,
              color: TachColors.mintLight,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusBrackets extends StatelessWidget {
  const _FocusBrackets();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Padding(
        padding: EdgeInsets.all(22),
        child: CustomPaint(painter: _BracketPainter()),
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  const _BracketPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const arm = 22.0;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (final corner in [
      (Offset.zero, 1.0, 1.0),
      (Offset(size.width, 0), -1.0, 1.0),
      (Offset(0, size.height), 1.0, -1.0),
      (Offset(size.width, size.height), -1.0, -1.0),
    ]) {
      final (origin, dx, dy) = corner;
      canvas.drawPath(
        Path()
          ..moveTo(origin.dx + arm * dx, origin.dy)
          ..lineTo(origin.dx, origin.dy)
          ..lineTo(origin.dx, origin.dy + arm * dy),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BracketPainter oldDelegate) => false;
}
