import 'package:ai_account_book/src/api_client.dart';
import 'package:ai_account_book/src/app_controller.dart';
import 'package:ai_account_book/src/models.dart';
import 'package:ai_account_book/src/screens/budget_screen.dart';
import 'package:ai_account_book/src/screens/home_screen.dart';
import 'package:ai_account_book/src/utils/speech_locale.dart';
import 'package:ai_account_book/src/utils/formatters.dart';
import 'package:ai_account_book/src/widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('formatMoney keeps two decimals and handles null values', () {
    expect(formatMoney(null), '0.00');
    expect(formatMoney(12), '12.00');
    expect(formatMoney(12.345), '12.35');
  });

  test('formatSignedMoney prefixes income and expense amounts', () {
    expect(formatSignedMoney(12, 'income'), '+¥12.00');
    expect(formatSignedMoney(12, 'expense'), '-¥12.00');
    expect(formatSignedMoney(12, null), '¥12.00');
    expect(formatSignedMoney(-12, null), '-¥12.00');
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
    'recordTextBill keeps the created bill for home screen feedback',
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
    'login persists session and restore keeps cached user when refresh fails',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final firstApi = _FakeApiClient();
      final firstController = AppController(api: firstApi, prefs: prefs);

      await firstController.login('13800000000', 'secret123');

      final secondApi = _FakeApiClient()..failDashboard = true;
      final secondController = AppController(api: secondApi, prefs: prefs);
      await secondController.restoreSession();

      expect(firstApi.loginCalls, 1);
      expect(secondApi.loginCalls, 0);
      expect(secondController.isLoggedIn, isTrue);
      expect(secondController.user?.username, '13800000000');
      expect(secondApi.token, 'token-1');
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

  testWidgets('home manual input fallback can submit text to service', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final api = _FakeApiClient();
    final controller = AppController(
      api: api,
      prefs: await SharedPreferences.getInstance(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HomeScreen(controller: controller)),
      ),
    );

    await tester.tap(find.byTooltip('手动输入账单'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '今天打车30元');
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    expect(api.recordedText, '今天打车30元');
    expect(controller.lastRecordedBill?.amount, 25);
  });

  test(
    'recordAudioBill sends recorded audio to backend transcription',
    () async {
      SharedPreferences.setMockInitialValues({});
      final api = _FakeApiClient();
      final controller = AppController(
        api: api,
        prefs: await SharedPreferences.getInstance(),
      );

      await controller.recordAudioBill('voice.m4a');

      expect(api.recordedAudioPath, 'voice.m4a');
      expect(controller.lastRecordedBill?.amount, 25);
      expect(controller.dashboard.monthExpense, 25);
    },
  );

  testWidgets('home hides recent bill list', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final controller = AppController(
      api: _FakeApiClient(),
      prefs: await SharedPreferences.getInstance(),
    );
    await controller.refreshDashboard();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HomeScreen(controller: controller)),
      ),
    );

    expect(find.byType(BillTile), findsNothing);
  });

  testWidgets('budget screen can save a monthly budget amount', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final api = _FakeApiClient();
    final controller = AppController(
      api: api,
      prefs: await SharedPreferences.getInstance(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BudgetScreen(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('budget-amount')), '3000');
    await tester.tap(find.byKey(const ValueKey('save-budget')));
    await tester.pumpAndSettle();

    expect(api.savedBudgetMonth, currentMonth());
    expect(api.savedBudgetAmount, 3000);
    expect(controller.budget.monthBudget, 3000);
  });
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(baseUrl: 'http://example.test');

  final Bill bill = _billFromJson(amount: 25, billType: 'expense');
  String? recordedText;
  String? recordedAudioPath;
  String? savedBudgetMonth;
  double? savedBudgetAmount;
  int loginCalls = 0;
  bool failDashboard = false;

  final UserProfile profileData = const UserProfile(
    id: '10000000000002',
    username: '13800000000',
    nickname: '本地用户',
  );

  @override
  Future<({String token, UserProfile user})> login({
    required String username,
    required String password,
  }) async {
    loginCalls += 1;
    return (token: 'token-1', user: profileData);
  }

  @override
  Future<UserProfile> profile() async {
    return profileData;
  }

  @override
  Future<Bill> recordBillText(String text) async {
    recordedText = text;
    return bill;
  }

  @override
  Future<Bill> recordBillAudio(String audioPath) async {
    recordedAudioPath = audioPath;
    return bill;
  }

  @override
  Future<DashboardStats> dashboard() async {
    if (failDashboard) throw const ApiException('dashboard failed');
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
  Future<BudgetInfo> budget(String month) async {
    return BudgetInfo.fromJson({
      'month': month,
      'month_budget': savedBudgetAmount ?? 2000,
      'spent': 25,
      'remaining': (savedBudgetAmount ?? 2000) - 25,
      'percent': 1.25,
      'over_budget': false,
    });
  }

  @override
  Future<BudgetInfo> saveBudget({
    required String month,
    required double amount,
  }) async {
    savedBudgetMonth = month;
    savedBudgetAmount = amount;
    return BudgetInfo.fromJson({
      'month': month,
      'month_budget': amount,
      'spent': 25,
      'remaining': amount - 25,
      'percent': amount == 0 ? 0 : 25 / amount * 100,
      'over_budget': amount < 25,
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
