import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({required String baseUrl}) : baseUrl = _normalizeBaseUrl(baseUrl);

  final String baseUrl;
  String? token;

  static String _normalizeBaseUrl(String value) {
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

  Future<UserProfile> register({
    required String username,
    required String password,
    required String nickname,
  }) async {
    final data = await _request(
      '/auth/register',
      method: 'POST',
      body: {'username': username, 'password': password, 'nickname': nickname},
    );
    return UserProfile.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<({String token, UserProfile user})> login({
    required String username,
    required String password,
  }) async {
    final data = await _request(
      '/auth/login',
      method: 'POST',
      body: {'username': username, 'password': password},
    );
    final map = Map<String, dynamic>.from(data as Map);
    return (
      token: readString(map['token']),
      user: UserProfile.fromJson(Map<String, dynamic>.from(map['user'] as Map)),
    );
  }

  Future<UserProfile> profile() async {
    final data = await _request('/user/me');
    return UserProfile.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> logout() async {
    await _request('/auth/logout', method: 'POST');
  }

  Future<List<Category>> categories({String? type}) async {
    final data = await _request(
      '/category/list',
      query: {if (type != null && type.isNotEmpty) 'type': type},
    );
    return (data as List? ?? [])
        .map(
          (item) => Category.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<BillPage> bills({
    String? keyword,
    String? billType,
    String? categoryId,
    int page = 1,
    int pageSize = 50,
  }) async {
    final data = await _request(
      '/bill/list',
      query: {
        'page': '$page',
        'page_size': '$pageSize',
        if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
        if (billType != null && billType.isNotEmpty) 'bill_type': billType,
        if (categoryId != null && categoryId.isNotEmpty)
          'category_id': categoryId,
      },
    );
    return BillPage.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<Bill> addBill({
    required double amount,
    required String categoryId,
    required String billType,
    required String remark,
  }) async {
    final data = await _request(
      '/bill/add',
      method: 'POST',
      body: {
        'amount': amount,
        'category_id': int.parse(categoryId),
        'bill_type': billType,
        'remark': remark,
      },
    );
    return Bill.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<Bill> updateBill({
    required String id,
    required double amount,
    required String categoryId,
    required String billType,
    required String remark,
  }) async {
    final data = await _request(
      '/bill/update/$id',
      method: 'PUT',
      body: {
        'amount': amount,
        'category_id': int.parse(categoryId),
        'bill_type': billType,
        'remark': remark,
      },
    );
    return Bill.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> deleteBill(String id) async {
    await _request('/bill/delete/$id', method: 'DELETE');
  }

  Future<DashboardStats> dashboard() async {
    final data = await _request('/statistics/dashboard');
    return DashboardStats.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<MoneyStats> dayStats(String date) async {
    final data = await _request('/statistics/day', query: {'date': date});
    return MoneyStats.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<MoneyStats> monthStats(String month) async {
    final data = await _request('/statistics/month', query: {'month': month});
    return MoneyStats.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<List<CategoryStat>> categoryStats({
    required String month,
    required String billType,
  }) async {
    final data = await _request(
      '/statistics/category',
      query: {'month': month, 'bill_type': billType},
    );
    return (data as List? ?? [])
        .map(
          (item) =>
              CategoryStat.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<List<TrendPoint>> trendStats(String range) async {
    final data = await _request('/statistics/trend', query: {'range': range});
    return (data as List? ?? [])
        .map(
          (item) => TrendPoint.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<BudgetInfo> budget(String month) async {
    final data = await _request('/budget/info', query: {'month': month});
    return BudgetInfo.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<BudgetInfo> saveBudget({
    required String month,
    required double amount,
  }) async {
    final data = await _request(
      '/budget/save',
      method: 'POST',
      body: {'month': month, 'month_budget': amount},
    );
    return BudgetInfo.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<Bill> recordBillText(String text) async {
    final data = await _request(
      '/ai/record',
      method: 'POST',
      body: {'text': text},
    );
    final map = Map<String, dynamic>.from(data as Map);
    return Bill.fromJson(Map<String, dynamic>.from(map['bill'] as Map));
  }

  Future<dynamic> _request(
    String path, {
    String method = 'GET',
    Map<String, String>? query,
    Map<String, Object?>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final headers = {
      'Content-Type': 'application/json',
      if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
    };
    final encodedBody = body == null ? null : jsonEncode(body);

    final response = switch (method) {
      'POST' => await http.post(uri, headers: headers, body: encodedBody),
      'PUT' => await http.put(uri, headers: headers, body: encodedBody),
      'DELETE' => await http.delete(uri, headers: headers),
      _ => await http.get(uri, headers: headers),
    };

    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw ApiException('接口返回不是有效 JSON：${response.statusCode}');
    }

    if (decoded is! Map) {
      throw ApiException('接口返回格式不正确');
    }
    final map = Map<String, dynamic>.from(decoded);
    if (response.statusCode == 401) token = null;
    if (map['code'] == 200) return map['data'];
    throw ApiException(
      readString(map['msg']).isEmpty ? '请求失败' : readString(map['msg']),
    );
  }
}
