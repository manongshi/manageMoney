String formatMoney(num? value) {
  return (value ?? 0).toDouble().toStringAsFixed(2);
}

String currentMonth() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
}

String currentDate() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

String billTypeName(String type) {
  return type == 'income' ? '收入' : '支出';
}
