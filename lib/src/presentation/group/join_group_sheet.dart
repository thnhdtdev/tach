import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../ledger/ledger_cubit.dart';

/// Mở bảng nhập mã mời. Trả về `true` khi đã vào được nhóm.
///
/// [beforeJoin] chạy trước khi gửi mã, dùng ở màn đăng nhập để tạo tài khoản
/// cho người chưa đăng nhập; nó ném ngoại lệ thì bảng báo không kết nối được.
Future<bool> showJoinGroupSheet(
  BuildContext context, {
  Future<void> Function()? beforeJoin,
}) async {
  final joined = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: TachColors.paper,
    showDragHandle: true,
    // Màn camera dùng theme tối; bảng này là nền sáng.
    builder: (_) => Theme(
      data: tachLightTheme,
      child: _JoinGroupSheet(beforeJoin: beforeJoin),
    ),
  );
  return joined ?? false;
}

class _JoinGroupSheet extends StatefulWidget {
  const _JoinGroupSheet({required this.beforeJoin});

  final Future<void> Function()? beforeJoin;

  @override
  State<_JoinGroupSheet> createState() => _JoinGroupSheetState();
}

class _JoinGroupSheetState extends State<_JoinGroupSheet> {
  static const _offline =
      'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.';

  final _code = TextEditingController();
  var _joining = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final cubit = context.read<LedgerCubit>();
    setState(() {
      _joining = true;
      _error = null;
    });

    JoinGroupResult result;
    try {
      await widget.beforeJoin?.call();
      result = await cubit.joinGroup(_code.text);
    } on Exception {
      result = JoinGroupResult.failed;
    }
    if (!mounted) return;

    switch (result) {
      case JoinGroupResult.joined:
        Navigator.of(context).pop(true);
      case JoinGroupResult.notFound:
        setState(() {
          _joining = false;
          _error = 'Không có nhóm nào dùng mã này. Kiểm tra lại từng ký tự.';
        });
      case JoinGroupResult.failed:
        setState(() {
          _joining = false;
          _error = _offline;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final canJoin = !_joining && _code.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Nhập mã mời', style: text.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Hỏi bạn cùng nhóm mã mời gồm 6 ký tự, có trong mục Mời bạn vào '
            'nhóm.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            autofocus: true,
            enabled: !_joining,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(6),
            ],
            style: text.titleLarge?.copyWith(letterSpacing: 4),
            decoration: InputDecoration(
              hintText: 'Ví dụ K7M2QP',
              hintStyle: text.titleLarge?.copyWith(
                color: TachColors.inkSoft.withValues(alpha: 0.5),
                letterSpacing: 0,
                fontWeight: FontWeight.w400,
              ),
              errorText: _error,
              errorMaxLines: 2,
              filled: true,
              fillColor: TachColors.mintWash.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) {
              if (canJoin) _join();
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: canJoin ? _join : null,
            child: Text(_joining ? 'Đang vào nhóm…' : 'Vào nhóm'),
          ),
        ],
      ),
    );
  }
}
