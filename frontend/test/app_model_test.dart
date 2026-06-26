import 'package:ai_account_book/src/api_client.dart';
import 'package:ai_account_book/src/app_controller.dart';
import 'package:ai_account_book/src/models.dart';
import 'package:ai_account_book/src/utils/speech_locale.dart';
import 'package:ai_account_book/src/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  test(
    'recordTextBill keeps the AI-created bill for home screen feedback',
    () async {
      SharedPreferences.setMockInitialValues({});
      final api = _FakeApiClient();
      final controller = AppController(
        api: api,
        prefs: await SharedPreferences.getInstance(),
      );

      await controller.recordTextBill('今天午饭花了25块');

      expect(controller.lastRecordedBill?.amount, 25);
      expect(controller.lastRecordedBill?.billType, 'expense');
      expect(controller.dashboard.monthExpense, 25);
      expect(controller.billTotal, 1);
    },
  );

  test(
    'speech locale selection prefers available Chinese locale and falls back safely',
    () {
      expect(
        selectSpeechLocale(['en_US', 'zh-Hans-CN', 'ja_JP'], 'en_US'),
        'zh-Hans-CN',
      );
      expect(selectSpeechLocale(['en_US'], 'en_US'), 'en_US');
      expect(selectSpeechLocale([], null), isNull);
    },
  );
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(baseUrl: 'http://example.test');

  final Bill bill = _billFromJson(amount: 25, billType: 'expense');

  @override
  Future<Bill> recordBillText(String text) async => bill;

  @override
  Future<DashboardStats> dashboard() async {
    return DashboardStats.fromJson({
      'today_income': 0,
      'today_expense': 25,
      'month_income': 0,
      'month_expense': 25,
      'balance': -25,
      'continuous_days': 1,
      'recent_bills': [_billJson(amount: 25, billType: 'expense')],
      'budget_percent': 0,
    });
  }

  @override
  Future<BillPage> bills({
    String? keyword,
    String? billType,
    String? categoryId,
    int page = 1,
    int pageSize = 50,
  }) async {
    return BillPage(total: 1, records: [bill]);
  }
}

Bill _billFromJson({required double amount, required String billType}) {
  return Bill.fromJson(_billJson(amount: amount, billType: billType));
}

Map<String, Object?> _billJson({
  required double amount,
  required String billType,
}) {
  return {
    'id': '10000000000001',
    'user_id': '10000000000002',
    'amount': amount,
    'category_id': '10000000000003',
    'bill_type': billType,
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
  };
}
