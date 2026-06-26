import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../theme.dart';
import '../widgets/common_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
  final _nickname = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;

  @override
  void dispose() {
    _username.dispose();
    _nickname.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 28),
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.account_balance_wallet,
                color: Colors.white,
                size: 34,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Ai记账小助手',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '记录收支、预算和每天的账。',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 28),
            AppCard(
              child: Column(
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('登录')),
                      ButtonSegment(value: true, label: Text('注册')),
                    ],
                    selected: {_register},
                    onSelectionChanged: (value) {
                      setState(() => _register = value.first);
                    },
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _username,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: '手机号'),
                  ),
                  if (_register) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nickname,
                      decoration: const InputDecoration(labelText: '昵称'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: '密码'),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: widget.controller.busy ? null : _submit,
                    child: Text(
                      widget.controller.busy
                          ? '处理中'
                          : _register
                          ? '注册并登录'
                          : '登录',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final username = _username.text.trim();
    final password = _password.text.trim();
    final nickname = _nickname.text.trim();
    if (username.isEmpty || password.isEmpty) {
      showAppMessage(context, '请填写手机号和密码');
      return;
    }
    try {
      if (_register) {
        await widget.controller.registerAndLogin(
          username: username,
          password: password,
          nickname: nickname.isEmpty ? username : nickname,
        );
      } else {
        await widget.controller.login(username, password);
      }
    } catch (error) {
      if (!mounted) return;
      showAppMessage(context, error.toString());
    }
  }
}
