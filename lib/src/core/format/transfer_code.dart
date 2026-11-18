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

/// Ghép mã nhóm, tên người trả và tháng thành nội dung chuyển khoản.
///
/// Chỉ giữ chữ cái không dấu và chữ số vì nhiều ngân hàng bỏ ký tự khác.
String buildTransferCode({
  required String groupCode,
  required String payerName,
  required int month,
}) {
  String clean(String text) =>
      removeDiacritics(text).toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
  return '${clean(groupCode)} ${clean(payerName)} T$month';
}
