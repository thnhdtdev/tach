import '../../domain/entities/expense.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/settlement.dart';
import '../../domain/logic/split.dart';
import '../../domain/repositories/group_repository.dart';

/// Dữ liệu mẫu trong bộ nhớ để dựng giao diện khi chưa nối Supabase.
///
/// Số tài khoản ngân hàng ở đây là giả, không dùng để chuyển tiền thật.
class SampleGroupRepository implements GroupRepository {
  static const _me = 'u-an';
  static const _minh = 'u-minh';
  static const _lan = 'u-lan';
  static const _hung = 'u-hung';
  static const _everyone = [_me, _minh, _lan, _hung];

  @override
  Future<GroupSnapshot> loadCurrentGroup() async {
    final now = DateTime.now();
    var nextId = 0;

    Expense expense({
      required String payer,
      required int amount,
      required String note,
      required Duration ago,
      String? photo,
      List<String> among = _everyone,
      Map<String, String> reactions = const {},
      List<Comment> comments = const [],
    }) {
      return Expense(
        id: 'e-${nextId++}',
        payerId: payer,
        amount: amount,
        note: note,
        photoUrl: photo,
        splits: splitEqually(
          amount: amount,
          participantIds: among,
          payerId: payer,
        ),
        createdAt: now.subtract(ago),
        reactions: reactions,
        comments: comments,
      );
    }

    return GroupSnapshot(
      group: const Group(
        id: 'g-tro12',
        name: 'Trọ 12',
        code: 'TRO12',
        type: GroupType.room,
        inviteCode: 'K7M2QP',
        members: [
          Member(
            id: _me,
            name: 'An',
            bank: BankAccount(
              bin: '970422',
              bankName: 'MB Bank',
              accountNumber: '0000000001',
              holderName: 'TAI KHOAN MAU AN',
            ),
          ),
          Member(
            id: _minh,
            name: 'Minh',
            bank: BankAccount(
              bin: '970436',
              bankName: 'Vietcombank',
              accountNumber: '0000000002',
              holderName: 'TAI KHOAN MAU MINH',
            ),
          ),
          Member(
            id: _lan,
            name: 'Lan',
            bank: BankAccount(
              bin: '970407',
              bankName: 'Techcombank',
              accountNumber: '0000000003',
              holderName: 'TAI KHOAN MAU LAN',
            ),
          ),
          Member(id: _hung, name: 'Hùng'),
        ],
      ),
      currentUserId: _me,
      expenses: [
        expense(
          payer: _minh,
          amount: 30000,
          note: 'Trứng',
          photo: 'sample:eggs',
          ago: const Duration(minutes: 12),
          reactions: {_lan: '👍', _hung: '😂'},
          comments: [
            Comment(
              id: 'c-0',
              userId: _lan,
              text: 'Trứng hôm nay rẻ ghê',
              createdAt: now.subtract(const Duration(minutes: 9)),
            ),
            Comment(
              id: 'c-1',
              userId: _minh,
              parentId: 'c-0',
              text: 'Mua ở chợ đầu ngõ đó, 30k một chục',
              createdAt: now.subtract(const Duration(minutes: 7)),
            ),
            Comment(
              id: 'c-2',
              userId: _hung,
              text: 'Tối nay ai nấu vậy?',
              createdAt: now.subtract(const Duration(minutes: 4)),
            ),
          ],
        ),
        expense(
          payer: _lan,
          amount: 486000,
          note: 'Tiền điện tháng 10',
          photo: 'sample:meter',
          ago: const Duration(days: 1, hours: 2),
          reactions: {_minh: '😮'},
          comments: [
            Comment(
              id: 'c-3',
              userId: _hung,
              text: 'Tháng này bật điều hòa nhiều quá',
              createdAt: now.subtract(const Duration(days: 1)),
            ),
          ],
        ),
        expense(
          payer: _me,
          amount: 95000,
          note: 'Gạo 5kg',
          photo: 'sample:rice',
          ago: const Duration(days: 2, hours: 5),
        ),
        expense(
          payer: _hung,
          amount: 68000,
          note: 'Nước rửa bát, giấy',
          photo: 'sample:cleaning',
          ago: const Duration(days: 3, hours: 1),
        ),
        expense(
          payer: _minh,
          amount: 220000,
          note: 'Wifi tháng 11',
          ago: const Duration(days: 5),
        ),
        expense(
          payer: _lan,
          amount: 330000,
          note: 'Lẩu cuối tuần',
          photo: 'sample:hotpot',
          among: [_me, _minh, _lan],
          ago: const Duration(days: 6, hours: 3),
          reactions: {_me: '😂', _minh: '👍'},
        ),
        expense(
          payer: _me,
          amount: 25000,
          note: 'Bình nước 20 lít',
          photo: 'sample:water',
          ago: const Duration(days: 8),
        ),
        expense(
          payer: _hung,
          amount: 380000,
          note: 'Đổi bình gas',
          photo: 'sample:gas',
          ago: const Duration(days: 10),
        ),
      ],
      settlements: [
        Settlement(
          id: 's-0',
          fromId: _me,
          toId: _lan,
          amount: 50000,
          transferCode: 'TRO12 AN T${now.month}',
          status: SettlementStatus.confirmed,
          createdAt: now.subtract(const Duration(days: 4)),
        ),
      ],
    );
  }
}
