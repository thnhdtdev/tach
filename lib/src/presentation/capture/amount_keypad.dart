import 'package:material_ui/material_ui.dart';

class AmountKeypad extends StatelessWidget {
  const AmountKeypad({super.key, required this.onKey});

  static const backspace = 'backspace';

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['000', '0', backspace],
  ];

  final ValueChanged<String> onKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in _rows)
          Row(
            children: [
              for (final key in row)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: _Key(value: key, onTap: () => onKey(key)),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.value, required this.onTap});

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isBackspace = value == AmountKeypad.backspace;
    return Semantics(
      button: true,
      label: isBackspace ? 'Xóa' : value,
      excludeSemantics: true,
      child: Material(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: ValueKey('key-$value'),
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            height: 52,
            child: Center(
              child: isBackspace
                  ? const Icon(
                      Icons.backspace_outlined,
                      size: 22,
                      color: Colors.white,
                    )
                  : Text(
                      value,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
