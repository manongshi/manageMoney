double readDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? 0;
}

int readInt(Object? value) {
  if (value is int) return value;
  return int.tryParse('${value ?? ''}') ?? 0;
}

String readString(Object? value) {
  return value?.toString() ?? '';
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.nickname,
  });

  final String id;
  final String username;
  final String nickname;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: readString(json['id']),
      username: readString(json['username']),
      nickname: readString(json['nickname']),
    );
  }
}

class Category {
  const Category({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.sortOrder,
    this.icon,
    this.color,
  });

  final String id;
  final String userId;
  final String name;
  final String type;
  final int sortOrder;
  final String? icon;
  final String? color;

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: readString(json['id']),
      userId: readString(json['user_id']),
      name: readString(json['name']),
      type: readString(json['type']),
      icon: json['icon']?.toString(),
      color: json['color']?.toString(),
      sortOrder: readInt(json['sort_order']),
    );
  }
}

class Bill {
  const Bill({
    required this.id,
    required this.userId,
    required this.amount,
    required this.categoryId,
    required this.billType,
    required this.billTime,
    required this.createTime,
    required this.category,
    this.remark,
  });

  final String id;
  final String userId;
  final double amount;
  final String categoryId;
  final String billType;
  final String? remark;
  final DateTime billTime;
  final DateTime createTime;
  final Category category;

  factory Bill.fromJson(Map<String, dynamic> json) {
    return Bill(
      id: readString(json['id']),
      userId: readString(json['user_id']),
      amount: readDouble(json['amount']),
      categoryId: readString(json['category_id']),
      billType: readString(json['bill_type']),
      remark: json['remark']?.toString(),
      billTime: DateTime.parse(readString(json['bill_time'])),
      createTime: DateTime.parse(readString(json['create_time'])),
      category: Category.fromJson(
        Map<String, dynamic>.from(json['category'] as Map? ?? {}),
      ),
    );
  }
}

class BillPage {
  const BillPage({required this.total, required this.records});

  final int total;
  final List<Bill> records;

  factory BillPage.fromJson(Map<String, dynamic> json) {
    final records = (json['records'] as List? ?? [])
        .map((item) => Bill.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    return BillPage(total: readInt(json['total']), records: records);
  }
}

class DashboardStats {
  const DashboardStats({
    required this.todayIncome,
    required this.todayExpense,
    required this.monthIncome,
    required this.monthExpense,
    required this.balance,
    required this.continuousDays,
    required this.recentBills,
    required this.budgetPercent,
  });

  final double todayIncome;
  final double todayExpense;
  final double monthIncome;
  final double monthExpense;
  final double balance;
  final int continuousDays;
  final List<Bill> recentBills;
  final double budgetPercent;

  factory DashboardStats.empty() {
    return const DashboardStats(
      todayIncome: 0,
      todayExpense: 0,
      monthIncome: 0,
      monthExpense: 0,
      balance: 0,
      continuousDays: 0,
      recentBills: [],
      budgetPercent: 0,
    );
  }

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      todayIncome: readDouble(json['today_income']),
      todayExpense: readDouble(json['today_expense']),
      monthIncome: readDouble(json['month_income']),
      monthExpense: readDouble(json['month_expense']),
      balance: readDouble(json['balance']),
      continuousDays: readInt(json['continuous_days']),
      recentBills: (json['recent_bills'] as List? ?? [])
          .map((item) => Bill.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      budgetPercent: readDouble(json['budget_percent']),
    );
  }
}

class BudgetInfo {
  const BudgetInfo({
    required this.month,
    required this.monthBudget,
    required this.spent,
    required this.remaining,
    required this.percent,
    required this.overBudget,
  });

  final String month;
  final double monthBudget;
  final double spent;
  final double remaining;
  final double percent;
  final bool overBudget;

  factory BudgetInfo.empty(String month) {
    return BudgetInfo(
      month: month,
      monthBudget: 0,
      spent: 0,
      remaining: 0,
      percent: 0,
      overBudget: false,
    );
  }

  factory BudgetInfo.fromJson(Map<String, dynamic> json) {
    return BudgetInfo(
      month: readString(json['month']),
      monthBudget: readDouble(json['month_budget']),
      spent: readDouble(json['spent']),
      remaining: readDouble(json['remaining']),
      percent: readDouble(json['percent']),
      overBudget: json['over_budget'] == true,
    );
  }
}

class MoneyStats {
  const MoneyStats({
    required this.income,
    required this.expense,
    required this.balance,
    this.month,
  });

  final double income;
  final double expense;
  final double balance;
  final String? month;

  factory MoneyStats.empty() {
    return const MoneyStats(income: 0, expense: 0, balance: 0);
  }

  factory MoneyStats.fromJson(Map<String, dynamic> json) {
    return MoneyStats(
      income: readDouble(json['income']),
      expense: readDouble(json['expense']),
      balance: readDouble(json['balance']),
      month: json['month']?.toString(),
    );
  }
}

class CategoryStat {
  const CategoryStat({required this.name, required this.value});

  final String name;
  final double value;

  factory CategoryStat.fromJson(Map<String, dynamic> json) {
    return CategoryStat(
      name: readString(json['name']),
      value: readDouble(json['value']),
    );
  }
}
