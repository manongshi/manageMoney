import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../theme.dart';
import '../utils/formatters.dart';
import '../widgets/common_widgets.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final _month = TextEditingController(text: currentMonth());
  final _amount = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _month.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.controller.budget;
    final progress = (info.percent / 100).clamp(0.0, 1.0);
    return RefreshIndicator(
      onRefresh: _load,
      child: PageScaffold(
        title: '预算',
        subtitle: '${_month.text} 月预算状态',
        action: IconButton.filledTonal(
          tooltip: '刷新预算',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
        children: [
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '预算使用率',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                Text(
                  '${formatMoney(info.percent)}%',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: info.overBudget
                        ? AppColors.expense
                        : AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 12,
                  borderRadius: BorderRadius.circular(8),
                  backgroundColor: AppColors.border,
                  color: info.overBudget
                      ? AppColors.expense
                      : AppColors.primary,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: MetricCard(
                        label: '已消费',
                        value: '¥${formatMoney(info.spent)}',
                        color: AppColors.expense,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MetricCard(
                        label: '剩余',
                        value: '¥${formatMoney(info.remaining)}',
                        color: info.remaining < 0
                            ? AppColors.expense
                            : AppColors.income,
                      ),
                    ),
                  ],
                ),
                if (info.overBudget) ...[
                  const SizedBox(height: 12),
                  Text(
                    '已超过本月预算',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.expense,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SectionGap(),
          AppCard(
            child: Column(
              children: [
                TextField(
                  controller: _month,
                  decoration: const InputDecoration(labelText: '月份'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: '月预算'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: widget.controller.busy ? null : _save,
                  child: const Text('保存预算'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    try {
      await widget.controller.loadBudget(month: _month.text.trim());
      _amount.text = formatMoney(widget.controller.budget.monthBudget);
    } catch (error) {
      if (!mounted) return;
      showAppMessage(context, error.toString());
    }
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount < 0) {
      showAppMessage(context, '请填写正确预算金额');
      return;
    }
    try {
      await widget.controller.saveBudget(
        month: _month.text.trim(),
        amount: amount,
      );
      if (!mounted) return;
      showAppMessage(context, '预算已保存');
    } catch (error) {
      if (!mounted) return;
      showAppMessage(context, error.toString());
    }
  }
}
