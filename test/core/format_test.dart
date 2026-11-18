import 'package:flutter_test/flutter_test.dart';
import 'package:tach/src/core/format/money.dart';
import 'package:tach/src/core/format/time_ago.dart';
import 'package:tach/src/core/format/transfer_code.dart';

void main() {
  test('formatVnd chèn dấu chấm hàng nghìn', () {
    expect(formatVnd(0), '0đ');
    expect(formatVnd(7500), '7.500đ');
    expect(formatVnd(30000), '30.000đ');
    expect(formatVnd(1234567), '1.234.567đ');
    expect(formatVnd(-266000), '-266.000đ');
  });

  test('formatShortVnd rút gọn theo nghìn và triệu', () {
    expect(formatShortVnd(500), '500đ');
    expect(formatShortVnd(30000), '30k');
    expect(formatShortVnd(7500), '7,5k');
    expect(formatShortVnd(486000), '486k');
    expect(formatShortVnd(1200000), '1,2tr');
    expect(formatShortVnd(3000000), '3tr');
  });

  test('removeDiacritics bỏ dấu và giữ hoa thường', () {
    expect(removeDiacritics('Hùng'), 'Hung');
    expect(removeDiacritics('Đặng Thị Huệ'), 'Dang Thi Hue');
    expect(removeDiacritics('Nguyễn Ước'), 'Nguyen Uoc');
  });

  test('buildTransferCode ghép mã nhóm, tên và tháng', () {
    expect(
      buildTransferCode(groupCode: 'TRO12', payerName: 'Minh', month: 11),
      'TRO12 MINH T11',
    );
    expect(
      buildTransferCode(groupCode: 'trọ-12', payerName: 'Hùng', month: 3),
      'TRO12 HUNG T3',
    );
  });

  test('buildTransferCode cắt mã nhóm và tên dài còn 8 ký tự mỗi phần', () {
    expect(
      buildTransferCode(
        groupCode: 'DALATTHANG12',
        payerName: 'Nguyễn Thị Thu Hương',
        month: 12,
      ),
      'DALATTHA NGUYENTH T12',
    );
  });

  test('groupCodeFromName suy mã không dấu từ tên nhóm', () {
    expect(groupCodeFromName('Trọ 12'), 'TRO12');
    expect(groupCodeFromName('Đà Lạt tháng 12'), 'DALATTHA');
    expect(groupCodeFromName('🏠 ♥'), 'NHOM');
  });

  test('timeAgo', () {
    final now = DateTime(2026, 11, 18, 15);
    String ago(Duration d) => timeAgo(now.subtract(d), now: now);
    expect(ago(const Duration(seconds: 20)), 'Vừa xong');
    expect(ago(const Duration(minutes: 12)), '12 phút trước');
    expect(ago(const Duration(hours: 3)), '3 giờ trước');
    expect(ago(const Duration(hours: 20)), 'Hôm qua');
    expect(ago(const Duration(days: 3)), '3 ngày trước');
    expect(ago(const Duration(days: 11)), '07/11');
  });
}
