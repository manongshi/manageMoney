import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/api_client.dart';
import 'src/app_controller.dart';
import 'src/screens/bills_screen.dart';
import 'src/screens/budget_screen.dart';
import 'src/screens/home_screen.dart';
import 'src/screens/login_screen.dart';
import 'src/screens/profile_screen.dart';
import 'src/screens/statistics_screen.dart';
import 'src/theme.dart';

const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://124.221.109.41:8000',
);

void main() {
  runApp(const AccountBookApp());
}

class AccountBookApp extends StatefulWidget {
  const AccountBookApp({super.key});

  @override
  State<AccountBookApp> createState() => _AccountBookAppState();
}

class _AccountBookAppState extends State<AccountBookApp> {
  late final Future<AppController> _controllerFuture;

  @override
  void initState() {
    super.initState();
    _controllerFuture = _createController();
  }

  Future<AppController> _createController() async {
    final prefs = await SharedPreferences.getInstance();
    final controller = AppController(
      api: ApiClient(baseUrl: apiBaseUrl),
      prefs: prefs,
    );
    await controller.restoreSession();
    return controller;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppController>(
      future: _controllerFuture,
      builder: (context, snapshot) {
        final controller = snapshot.data;
        return MaterialApp(
          title: 'Ai记账小助手',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: controller == null
              ? const _BootScreen()
              : AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) {
                    return controller.isLoggedIn
                        ? AccountBookShell(controller: controller)
                        : LoginScreen(controller: controller);
                  },
                ),
        );
      },
    );
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class AccountBookShell extends StatefulWidget {
  const AccountBookShell({required this.controller, super.key});

  final AppController controller;

  @override
  State<AccountBookShell> createState() => _AccountBookShellState();
}

class _AccountBookShellState extends State<AccountBookShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.refreshDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(controller: widget.controller),
      BillsScreen(controller: widget.controller),
      StatisticsScreen(controller: widget.controller),
      BudgetScreen(controller: widget.controller),
      ProfileScreen(controller: widget.controller),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          setState(() => _index = value);
          _refreshForTab(value);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: '账单',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '统计',
          ),
          NavigationDestination(
            icon: Icon(Icons.savings_outlined),
            selectedIcon: Icon(Icons.savings),
            label: '预算',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }

  void _refreshForTab(int index) {
    switch (index) {
      case 0:
        widget.controller.refreshDashboard();
        break;
      case 1:
        widget.controller.loadBills();
        break;
      case 2:
        widget.controller.loadStatistics();
        break;
      case 3:
        widget.controller.loadBudget();
        break;
      case 4:
        widget.controller.loadProfile();
        break;
    }
  }
}
