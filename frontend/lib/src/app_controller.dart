import 'package:flutter/foundation.dart' hide Category;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'models.dart';
import 'utils/formatters.dart';

class AppController extends ChangeNotifier {
  AppController({required this.api, required this.prefs});

  static const _tokenKey = 'auth_token';

  final ApiClient api;
  final SharedPreferences prefs;

  String? token;
  UserProfile? user;
  bool busy = false;
  String? error;

  DashboardStats dashboard = DashboardStats.empty();
  List<Category> categories = [];
  List<Bill> bills = [];
  int billTotal = 0;
  BudgetInfo budget = BudgetInfo.empty(currentMonth());
  MoneyStats dayStats = MoneyStats.empty();
  MoneyStats monthStats = MoneyStats.empty();
  List<CategoryStat> categoryStats = [];
  List<TrendPoint> trendStats = [];

  bool get isLoggedIn => token != null && token!.isNotEmpty;

  List<Category> categoriesByType(String type) {
    return categories.where((item) => item.type == type).toList();
  }

  Future<void> restoreSession() async {
    token = prefs.getString(_tokenKey);
    api.token = token;
    if (isLoggedIn) {
      try {
        await loadProfile();
        await refreshDashboard();
      } catch (_) {
        await clearSession();
      }
    }
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    await _run(() async {
      final result = await api.login(username: username, password: password);
      token = result.token;
      user = result.user;
      api.token = token;
      await prefs.setString(_tokenKey, result.token);
      await refreshDashboard(silent: true);
    });
  }

  Future<void> registerAndLogin({
    required String username,
    required String password,
    required String nickname,
  }) async {
    await _run(() async {
      await api.register(
        username: username,
        password: password,
        nickname: nickname,
      );
      final result = await api.login(username: username, password: password);
      token = result.token;
      user = result.user;
      api.token = token;
      await prefs.setString(_tokenKey, result.token);
      await refreshDashboard(silent: true);
    });
  }

  Future<void> loadProfile() async {
    if (!isLoggedIn) return;
    user = await api.profile();
    notifyListeners();
  }

  Future<void> logout() async {
    await _run(() async {
      try {
        await api.logout();
      } finally {
        await clearSession();
      }
    });
  }

  Future<void> clearSession() async {
    token = null;
    user = null;
    api.token = null;
    await prefs.remove(_tokenKey);
    notifyListeners();
  }

  Future<void> refreshDashboard({bool silent = false}) async {
    await _run(() async {
      dashboard = await api.dashboard();
    }, silent: silent);
  }

  Future<void> loadCategories({String? type}) async {
    categories = await api.categories(type: type);
    notifyListeners();
  }

  Future<void> loadBills({
    String keyword = '',
    String billType = '',
    String categoryId = '',
  }) async {
    await _run(() async {
      if (categories.isEmpty) categories = await api.categories();
      final page = await api.bills(
        keyword: keyword,
        billType: billType,
        categoryId: categoryId,
      );
      bills = page.records;
      billTotal = page.total;
    });
  }

  Future<void> saveBill({
    String? id,
    required double amount,
    required String categoryId,
    required String billType,
    required String remark,
  }) async {
    await _run(() async {
      if (id == null) {
        await api.addBill(
          amount: amount,
          categoryId: categoryId,
          billType: billType,
          remark: remark,
        );
      } else {
        await api.updateBill(
          id: id,
          amount: amount,
          categoryId: categoryId,
          billType: billType,
          remark: remark,
        );
      }
      await loadBills();
      dashboard = await api.dashboard();
    });
  }

  Future<void> deleteBill(String id) async {
    await _run(() async {
      await api.deleteBill(id);
      await loadBills();
      dashboard = await api.dashboard();
    });
  }

  Future<void> recordTextBill(String text) async {
    await _run(() async {
      await api.recordBillText(text);
      dashboard = await api.dashboard();
      final page = await api.bills();
      bills = page.records;
      billTotal = page.total;
    });
  }

  Future<void> loadStatistics({String? month, String range = '7d'}) async {
    final targetMonth = month ?? currentMonth();
    await _run(() async {
      final results = await Future.wait([
        api.dayStats(currentDate()),
        api.monthStats(targetMonth),
        api.categoryStats(month: targetMonth, billType: 'expense'),
        api.trendStats(range),
      ]);
      dayStats = results[0] as MoneyStats;
      monthStats = results[1] as MoneyStats;
      categoryStats = results[2] as List<CategoryStat>;
      trendStats = results[3] as List<TrendPoint>;
    });
  }

  Future<void> loadBudget({String? month}) async {
    final targetMonth = month ?? currentMonth();
    await _run(() async {
      budget = await api.budget(targetMonth);
    });
  }

  Future<void> saveBudget({
    required String month,
    required double amount,
  }) async {
    await _run(() async {
      budget = await api.saveBudget(month: month, amount: amount);
      dashboard = await api.dashboard();
    });
  }

  Future<void> _run(Future<void> Function() task, {bool silent = false}) async {
    if (!silent) {
      busy = true;
      error = null;
      notifyListeners();
    }
    try {
      await task();
    } catch (exception) {
      error = exception.toString();
      rethrow;
    } finally {
      if (!silent) busy = false;
      notifyListeners();
    }
  }
}
