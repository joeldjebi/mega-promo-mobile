String formatCurrencyAmount(num value, {String zeroLabel = 'Prix surprise'}) {
  final rounded = value.round();
  if (rounded <= 0) return zeroLabel;
  return '${formatThousands(rounded)} FCFA';
}

String formatThousands(num value) {
  final rounded = value.round();
  final sign = rounded < 0 ? '-' : '';
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();

  for (var index = 0; index < digits.length; index += 1) {
    final remaining = digits.length - index;
    buffer.write(digits[index]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(' ');
    }
  }

  return '$sign$buffer';
}
