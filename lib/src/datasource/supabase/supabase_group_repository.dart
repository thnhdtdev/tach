import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/expense.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/settlement.dart';
import '../../domain/repositories/group_repository.dart';
import '../../services/photo/photo_compressor.dart';
import '../../services/photo/photo_loader.dart';

typedef _Row = Map<String, dynamic>;

class SupabaseGroupRepository implements GroupRepository {
  SupabaseGroupRepository(this._client, this._photos);

  static const _profileColumns =
      'id, name, avatar_path, bank_bin, bank_name, bank_account, bank_holder';

  static const _groupColumns =
      'id, name, code, type, invite_code, created_by, '
      'group_members(user_id, joined_at, left_at, profiles($_profileColumns)), '
      'expenses(id, payer_id, amount, note, photo_path, created_at, '
      'expense_splits(user_id, amount), reactions(user_id, emoji), '
      'comments(id, user_id, parent_id, text, created_at)), '
      'settlements(id, from_user, to_user, amount, transfer_code, status, '
      'created_at)';

  final SupabaseClient _client;
  final PhotoLoader _photos;

  final _avatars = <String, Uint8List>{};

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Chưa đăng nhập');
    return user.id;
  }

  @override
  bool get persists => true;

  @override
  Future<LedgerSnapshot> load() async {
    final userId = _userId;
    final results = await Future.wait([
      _client.from('profiles').select(_profileColumns).eq('id', userId),
      _client.from('groups').select(_groupColumns),
    ]);
    final profiles = results[0];
    final groups = results[1];
    if (profiles.isEmpty) throw const AuthException('Không tìm thấy hồ sơ');

    final avatarPaths = <String>{
      ?profiles.first['avatar_path'] as String?,
      for (final group in groups)
        for (final member in group['group_members'] as List)
          ?(member['profiles'] as _Row?)?['avatar_path'] as String?,
    };
    await Future.wait(avatarPaths.map(_loadAvatar));

    DateTime joinedAt(_Row group) {
      for (final member in group['group_members'] as List) {
        if (member['user_id'] == userId) {
          return DateTime.parse(member['joined_at'] as String);
        }
      }
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    final ordered = [...groups]
      ..sort((a, b) => joinedAt(a).compareTo(joinedAt(b)));

    return LedgerSnapshot(
      me: _member(profiles.first),
      groups: [for (final group in ordered) _group(group)],
    );
  }

  Future<void> _loadAvatar(String path) async {
    if (_avatars.containsKey(path)) return;
    try {
      _avatars[path] = await _client.storage.from('avatars').download(path);
    } on Exception {
      // Không tải được thì hiện chữ cái đầu của tên.
    }
  }

  Member _member(_Row profile) {
    final bin = profile['bank_bin'] as String?;
    return Member(
      id: profile['id'] as String,
      name: profile['name'] as String,
      avatarBytes: _avatars[profile['avatar_path']],
      bank: bin == null
          ? null
          : BankAccount(
              bin: bin,
              bankName: profile['bank_name'] as String,
              accountNumber: profile['bank_account'] as String,
              holderName: profile['bank_holder'] as String,
            ),
    );
  }

  GroupSnapshot _group(_Row row) {
    final memberships = [...row['group_members'] as List]
      ..sort(
        (a, b) =>
            (a['joined_at'] as String).compareTo(b['joined_at'] as String),
      );
    List<Member> membersWhere(bool Function(_Row) test) => [
      for (final m in memberships)
        if (m['profiles'] != null && test(m as _Row))
          _member(m['profiles'] as _Row),
    ];

    return GroupSnapshot(
      group: Group(
        id: row['id'] as String,
        name: row['name'] as String,
        code: row['code'] as String,
        type: GroupType.values.byName(row['type'] as String),
        inviteCode: row['invite_code'] as String,
        createdBy: row['created_by'] as String,
        members: membersWhere((m) => m['left_at'] == null),
        formerMembers: membersWhere((m) => m['left_at'] != null),
      ),
      expenses: [for (final e in row['expenses'] as List) _expense(e as _Row)],
      settlements: [
        for (final s in row['settlements'] as List)
          Settlement(
            id: s['id'] as String,
            fromId: s['from_user'] as String,
            toId: s['to_user'] as String,
            amount: s['amount'] as int,
            transferCode: s['transfer_code'] as String,
            status: SettlementStatus.values.byName(s['status'] as String),
            createdAt: DateTime.parse(s['created_at'] as String).toLocal(),
          ),
      ],
    );
  }

  Expense _expense(_Row row) {
    final photoPath = row['photo_path'] as String?;
    return Expense(
      id: row['id'] as String,
      payerId: row['payer_id'] as String,
      amount: row['amount'] as int,
      note: row['note'] as String,
      photoUrl: photoPath == null ? null : '$remotePhotoPrefix$photoPath',
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      splits: {
        for (final s in row['expense_splits'] as List)
          s['user_id'] as String: s['amount'] as int,
      },
      reactions: {
        for (final r in row['reactions'] as List)
          r['user_id'] as String: r['emoji'] as String,
      },
      comments: [
        for (final c in row['comments'] as List)
          Comment(
            id: c['id'] as String,
            userId: c['user_id'] as String,
            parentId: c['parent_id'] as String?,
            text: c['text'] as String,
            createdAt: DateTime.parse(c['created_at'] as String).toLocal(),
          ),
      ],
    );
  }

  @override
  Stream<void> watchGroups(Set<String> groupIds) {
    final channels = <RealtimeChannel>[];
    late final StreamController<void> changes;
    void changed() {
      if (!changes.isClosed) changes.add(null);
    }

    changes = StreamController<void>(
      onListen: () {
        for (final id in groupIds) {
          var joinedBefore = false;
          channels.add(
            _client
                .channel(
                  'group:$id',
                  opts: const RealtimeChannelConfig(private: true),
                )
                .onBroadcast(event: 'changed', callback: (_) => changed())
                .subscribe((status, _) {
                  if (status != RealtimeSubscribeStatus.subscribed) return;
                  // Nối lại sau khi rớt mạng: tín hiệu phát trong lúc mất kết
                  // nối đã lỡ, nên coi như nhóm vừa đổi.
                  if (joinedBefore) changed();
                  joinedBefore = true;
                }),
          );
        }
      },
      onCancel: () async {
        for (final channel in channels) {
          await _client.removeChannel(channel);
        }
        await changes.close();
      },
    );
    return changes.stream;
  }

  @override
  Future<void> createGroup(Group group) {
    return _client.rpc<void>(
      'create_group',
      params: {
        'p_id': group.id,
        'p_name': group.name,
        'p_code': group.code,
        'p_type': group.type.name,
        'p_invite_code': group.inviteCode,
      },
    );
  }

  @override
  Future<String?> joinGroup(String inviteCode) async {
    try {
      return await _client.rpc<String>(
        'join_group',
        params: {'p_invite_code': inviteCode},
      );
    } on PostgrestException catch (error) {
      if (error.message.contains('invite_not_found')) return null;
      rethrow;
    }
  }

  @override
  Future<void> renameGroup(String groupId, String name) {
    return _client.from('groups').update({'name': name}).eq('id', groupId);
  }

  @override
  Future<void> leaveGroup(String groupId) {
    return _client.rpc<void>('leave_group', params: {'p_group': groupId});
  }

  @override
  Future<void> deleteGroup(String groupId) {
    return _client.rpc<void>('delete_group', params: {'p_group': groupId});
  }

  @override
  Future<void> addExpense(String groupId, Expense expense) async {
    String? photoPath;
    final photo = expense.photoBytes;
    if (photo != null) {
      final compressed = await squareJpeg(photo);
      photoPath = '$groupId/${expense.id}.jpg';
      await _client.storage
          .from('photos')
          .uploadBinary(
            photoPath,
            compressed,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
      _photos.remember(photoPath, compressed);
    }

    await _client.rpc<void>(
      'create_expense',
      params: {
        'p_id': expense.id,
        'p_group': groupId,
        'p_amount': expense.amount,
        'p_note': expense.note,
        'p_photo_path': photoPath,
        'p_splits': expense.splits,
      },
    );
  }

  @override
  Future<void> deleteExpense(String groupId, String expenseId) async {
    await _client.rpc<void>('delete_expense', params: {'p_id': expenseId});
    try {
      await _client.storage.from('photos').remove(['$groupId/$expenseId.jpg']);
    } on Exception {
      // Khoản chi đã mất; ảnh sót lại trong kho không ai mở được nữa.
    }
  }

  @override
  Future<void> setReaction(String expenseId, String? emoji) {
    final reactions = _client.from('reactions');
    if (emoji == null) {
      return reactions
          .delete()
          .eq('expense_id', expenseId)
          .eq('user_id', _userId);
    }
    return reactions.upsert({
      'expense_id': expenseId,
      'user_id': _userId,
      'emoji': emoji,
    });
  }

  @override
  Future<void> addComment(String expenseId, Comment comment) {
    return _client.from('comments').insert({
      'id': comment.id,
      'expense_id': expenseId,
      'user_id': _userId,
      'parent_id': comment.parentId,
      'text': comment.text,
    });
  }

  @override
  Future<void> saveProfile(Member me) {
    final bank = me.bank;
    return _client
        .from('profiles')
        .update({
          'name': me.name,
          'bank_bin': bank?.bin,
          'bank_name': bank?.bankName,
          'bank_account': bank?.accountNumber,
          'bank_holder': bank?.holderName,
        })
        .eq('id', _userId);
  }

  @override
  Future<void> setAvatar(Uint8List? bytes) async {
    final userId = _userId;
    final profiles = _client.from('profiles');
    final current = await profiles
        .select('avatar_path')
        .eq('id', userId)
        .single();
    final oldPath = current['avatar_path'] as String?;

    String? newPath;
    if (bytes != null) {
      final compressed = await squareJpeg(bytes, side: 512);
      // Tên file đổi theo thời điểm để máy khác biết đây là ảnh mới.
      newPath = '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _client.storage
          .from('avatars')
          .uploadBinary(
            newPath,
            compressed,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
      _avatars[newPath] = compressed;
    }

    await profiles.update({'avatar_path': newPath}).eq('id', userId);
    if (oldPath != null) {
      _avatars.remove(oldPath);
      await _client.storage.from('avatars').remove([oldPath]);
    }
  }

  @override
  Future<void> addSettlement(String groupId, Settlement settlement) {
    return _client.from('settlements').insert({
      'id': settlement.id,
      'group_id': groupId,
      'from_user': settlement.fromId,
      'to_user': settlement.toId,
      'amount': settlement.amount,
      'transfer_code': settlement.transferCode,
    });
  }

  @override
  Future<void> confirmSettlement(String settlementId) {
    return _client.rpc<void>(
      'confirm_settlement',
      params: {'p_id': settlementId},
    );
  }
}
