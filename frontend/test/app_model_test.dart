import 'package:ai_account_book/src/models.dart';
import 'package:ai_account_book/src/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatMoney keeps two decimals and handles null values', () {
    expect(formatMoney(null), '0.00');
    expect(formatMoney(12), '12.00');
    expect(formatMoney(12.345), '12.35');
  });

  test('Bill parses backend string ids and nested category data', () {
    final bill = Bill.fromJson({
      'id': '10000000000001',
      'user_id': '10000000000002',
      'amount': 25.5,
      'category_id': '10000000000003',
      'bill_type': 'expense',
      'remark': '午饭',
      'bill_time': '2026-06-26T12:30:00',
      'create_time': '2026-06-26T12:31:00',
      'category': {
        'id': '10000000000003',
        'user_id': '10000000000002',
        'name': '餐饮',
        'type': 'expense',
        'icon': null,
        'color': '#16a34a',
        'sort_order': 1,
      },
    });

    expect(bill.id, '10000000000001');
    expect(bill.categoryId, '10000000000003');
    expect(bill.category.name, '餐饮');
    expect(bill.amount, 25.5);
  });
}
