import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format/money.dart';
import '../../core/format/time_ago.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/settlement.dart';
import '../ledger/ledger_cubit.dart';
import '../widgets/member_avatar.dart';
import '../widgets/section_title.dart';
import 'vietqr_sheet.dart';

class BalanceScreen extends StatelessWidget {
  const BalanceScreen({super.key});

  void _pay(BuildContext context, Transfer transfer) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TachColors.paper,
      showDragHandle: true,
      builder: (_) => BlocProvider.value(
        value: context.read<LedgerCubit>(),
        child: VietQrSheet(transfer: transfer),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cubit = context.read<LedgerCubit>();
    final state = context.watch<LedgerCubit>().state;

    final transfers = state.transfers;
    final toPay = transfers.where((t) => t.fromId == state.meId).toList();
    final toReceive = transfers.where((t) => t.toId == state.meId).toList();
    final others = transfers
        .where((t) => t.fromId != state.meId && t.toId != state.meId)
        .toList();
    final paid =
        state.settlements
            .where((s) => s.status == SettlementStatus.confirmed)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final myNet = state.myNet;
    final headline = myNet < 0
        ? 'Bạn cần trả'
        : myNet > 0
        ? 'Bạn được nhận'
        : 'Bạn không nợ ai';

    return Scaffold(
      appBar: AppBar(title: const Text('Số dư')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(state.group.name, style: text.bodyMedium),
          Text(headline, style: text.titleLarge),
          if (myNet != 0)
            Text(
              formatVnd(myNet.abs()),
              style: text.displayLarge?.copyWith(
                color: myNet < 0 ? TachColors.mint : TachColors.mintDeep,
              ),
            ),
          const SizedBox(height: 6),
          Text(
            transfers.isEmpty
                ? 'Cả nhóm đã sòng phẳng.'
                : 'Đã gộp nợ chéo: cả nhóm chỉ cần ${transfers.length} '
                      'lần chuyển khoản.',
            style: text.bodyMedium,
          ),
          if (toPay.isNotEmpty) ...[
            const SectionTitle('Trả cho ai'),
            for (final t in toPay)
              _PersonRow(
                name: state.member(t.toId).name,
                tone: state.toneOf(t.toId),
                photo: state.member(t.toId).avatarBytes,
                amount: t.amount,
                trailing: state.pendingFor(t) != null
                    ? Text(
                        'Chờ ${state.member(t.toId).name}\nxác nhận',
                        textAlign: TextAlign.right,
                        style: text.bodySmall,
                      )
                    : FilledButton(
                        onPressed: () => _pay(context, t),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(76, 44),
                        ),
                        child: const Text('Trả'),
                      ),
              ),
          ],
          if (toReceive.isNotEmpty) ...[
            const SectionTitle('Sẽ trả cho bạn'),
            for (final t in toReceive)
              _PersonRow(
                name: state.member(t.fromId).name,
                tone: state.toneOf(t.fromId),
                photo: state.member(t.fromId).avatarBytes,
                amount: t.amount,
                caption: state.pendingFor(t) != null
                    ? 'Báo đã chuyển khoản'
                    : null,
                trailing: state.pendingFor(t) == null
                    ? null
                    : OutlinedButton(
                        onPressed: () =>
                            cubit.confirmReceived(state.pendingFor(t)!.id),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(76, 44),
                        ),
                        child: const Text('Đã nhận'),
                      ),
              ),
          ],
          if (others.isNotEmpty) ...[
            const SectionTitle('Trong nhóm'),
            for (final t in others)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${state.member(t.fromId).name} trả '
                        '${state.member(t.toId).name}',
                        style: text.bodyLarge,
                      ),
                    ),
                    Text(
                      formatVnd(t.amount),
                      style: text.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (paid.isNotEmpty) ...[
            const SectionTitle('Đã trả'),
            for (final s in paid)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.done_all,
                      size: 20,
                      color: TachColors.paid,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${state.displayName(s.fromId)} trả '
                        '${s.toId == state.meId ? 'bạn' : state.member(s.toId).name}',
                        style: text.bodyLarge,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatVnd(s.amount),
                          style: text.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: TachColors.paid,
                          ),
                        ),
                        Text(timeAgo(s.createdAt), style: text.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.name,
    required this.tone,
    required this.photo,
    required this.amount,
    this.caption,
    this.trailing,
  });

  final String name;
  final Color tone;
  final Uint8List? photo;
  final int amount;
  final String? caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          MemberAvatar(name: name, tone: tone, photo: photo, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: text.bodyLarge),
                Text(
                  formatVnd(amount),
                  style: text.titleMedium?.copyWith(color: TachColors.mintDeep),
                ),
                if (caption != null) Text(caption!, style: text.bodySmall),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
