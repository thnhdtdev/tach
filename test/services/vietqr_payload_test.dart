import 'package:flutter_test/flutter_test.dart';
import 'package:tach/src/services/vietqr/vietqr_payload.dart';

void main() {
  test('crc16 khớp giá trị kiểm tra chuẩn của CRC-16/CCITT-FALSE', () {
    expect(crc16('123456789'), 0x29B1);
  });

  test('payload có đủ các trường VietQR theo đúng thứ tự', () {
    final payload = buildVietQrPayload(
      bankBin: '970407',
      accountNumber: '0000000003',
      amount: 266000,
      content: 'TRO12 AN T11',
    );

    expect(
      payload,
      startsWith(
        '000201' // phiên bản
        '010212' // mã động, dùng một lần
        '38540010A000000727' // định danh NAPAS
        '01240006970407' // mã ngân hàng
        '01100000000003' // số tài khoản
        '0208QRIBFTTA' // chuyển nhanh tới tài khoản
        '5303704' // VND
        '5406266000' // số tiền
        '5802VN'
        '62160812TRO12 AN T11' // nội dung chuyển khoản
        '6304',
      ),
    );
  });

  test('bốn ký tự cuối là CRC của phần đứng trước', () {
    final payload = buildVietQrPayload(
      bankBin: '970436',
      accountNumber: '0000000002',
      amount: 64000,
      content: 'TRO12 MINH T11',
    );
    final body = payload.substring(0, payload.length - 4);
    final checksum = payload.substring(payload.length - 4);
    expect(
      checksum,
      crc16(body).toRadixString(16).toUpperCase().padLeft(4, '0'),
    );
  });
}
