import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../theme.dart';
import '../utils/formatters.dart';
import '../widgets/common_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.controller.dashboard;
    return RefreshIndicator(
      onRefresh: widget.controller.refreshDashboard,
      child: PageScaffold(
        title: '今日账本',
        subtitle: '一句话整理消费，支出和预算实时同步',
        action: IconButton.filledTonal(
          tooltip: '刷新首页',
          onPressed: widget.controller.refreshDashboard,
          icon: const Icon(Icons.refresh),
        ),
        children: [
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '本月结余',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                MoneyAmount(value: data.balance, large: true),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Text('收入 ¥${formatMoney(data.monthIncome)}'),
                    Text('支出 ¥${formatMoney(data.monthExpense)}'),
                    Text('预算 ${formatMoney(data.budgetPercent)}%'),
                  ],
                ),
              ],
            ),
          ),
          const SectionGap(),
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.55,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              MetricCard(
                label: '今日支出',
                value: '¥${formatMoney(data.todayExpense)}',
                color: AppColors.expense,
                icon: Icons.arrow_downward,
              ),
              MetricCard(
                label: '今日收入',
                value: '¥${formatMoney(data.todayIncome)}',
                color: AppColors.income,
                icon: Icons.arrow_upward,
              ),
              MetricCard(
                label: '连续记账',
                value: '${data.continuousDays} 天',
                icon: Icons.local_fire_department_outlined,
              ),
              MetricCard(
                label: '本月支出',
                value: '¥${formatMoney(data.monthExpense)}',
                color: AppColors.expense,
                icon: Icons.calendar_month_outlined,
              ),
            ],
          ),
          const SectionGap(),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '智能入账',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '例如：今天买咖啡花了19元，或工资到账8000元。',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _textController,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '输入一句账单',
                    hintText: '今天中午吃麻辣烫花了25块',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: widget.controller.busy ? null : _recordText,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('整理入账'),
                ),
              ],
            ),
          ),
          const SectionGap(),
          Text(
            '最近账单',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (data.recentBills.isEmpty)
            const EmptyState('暂无账单')
          else
            ...data.recentBills.map(
              (bill) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: BillTile(bill: bill),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _recordText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      showAppMessage(context, '请输入账单内容');
      return;
    }
    try {
      await widget.controller.recordTextBill(text);
      _textController.clear();
      if (!mounted) return;
      showAppMessage(context, '已入账');
    } catch (error) {
      if (!mounted) return;
      showAppMessage(context, error.toString());
    }
  }
}
