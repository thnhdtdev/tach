/// Nội dung chuyển khoản riêng cho từng khoản trả, ví dụ `TRO12 MINH T11`.
library;

const _accented = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

final _plainOf = {
  for (final entry in _accented.entries)
    for (final rune in entry.value.runes) String.fromCharCode(rune): entry.key,
};

/// Bỏ dấu tiếng Việt: "Hùng" thành "Hung".
String removeDiacritics(String text) {
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    final lower = char.toLowerCase();
    final plain = _plainOf[lower];
    if (plain == null) {
      buffer.write(char);
    } else {
      buffer.write(char == lower ? plain : plain.toUpperCase());
    }
  }
  return buffer.toString();
}

String _plainUpper(String text) =>
    removeDiacritics(text).toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

String _short(String text) =>
    text.length <= _maxPartLength ? text : text.substring(0, _maxPartLength);

/// Mỗi phần (mã nhóm, tên) tối đa 8 ký tự để nội dung chuyển khoản luôn ngắn.
const _maxPartLength = 8;

/// Mã nhóm không dấu suy ra từ tên nhóm: "Đà Lạt 2026" thành `DALAT202`.
///
/// Tên không có chữ hay số nào (ví dụ toàn biểu tượng) thì dùng `NHOM`.
String groupCodeFromName(String name) {
  final plain = _short(_plainUpper(name));
  return plain.isEmpty ? 'NHOM' : plain;
}

/// Ghép mã nhóm, tên người trả và tháng thành nội dung chuyển khoản.
///
/// Chỉ giữ chữ cái không dấu và chữ số vì nhiều ngân hàng bỏ ký tự khác.
String buildTransferCode({
  required String groupCode,
  required String payerName,
  required int month,
}) {
  final group = _short(_plainUpper(groupCode));
  final payer = _short(_plainUpper(payerName));
  return '$group $payer T$month';
}
