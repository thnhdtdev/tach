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

const _maxPartLength = 8;

String groupCodeFromName(String name) {
  final plain = _short(_plainUpper(name));
  return plain.isEmpty ? 'NHOM' : plain;
}

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
