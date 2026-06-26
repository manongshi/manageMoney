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
        subtitle: '${_month.text} 月预算',
        action: IconButton.filledTonal(
          tooltip: '刷新预算',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
        children: [
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '设置预算',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _month,
                  decoration: const InputDecoration(labelText: '月份'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('budget-amount'),
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: '本月预算金额',
                    prefixText: '¥ ',
                  ),
                  onSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  key: const ValueKey('save-budget'),
                  onPressed: widget.controller.busy ? null : _save,
                  child: const Text('保存预算'),
                ),
              ],
            ),
          ),
          const SectionGap(),
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        '预算使用',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    Text(
                      '${formatMoney(info.percent)}%',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: info.overBudget
                                ? AppColors.expense
                                : AppColors.primaryDark,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                  backgroundColor: AppColors.border,
                  color: info.overBudget
                      ? AppColors.expense
                      : AppColors.primary,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _BudgetValue(
                        label: '预算',
                        value: formatSignedMoney(info.monthBudget, null),
                      ),
                    ),
                    Expanded(
                      child: _BudgetValue(
                        label: '已支出',
                        value: formatSignedMoney(info.spent, 'expense'),
                        color: AppColors.expense,
                      ),
                    ),
                    Expanded(
                      child: _BudgetValue(
                        label: '剩余',
                        value: formatSignedMoney(info.remaining, null),
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
                    '本月预算已超出',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.expense,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
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
      if (!mounted) return;
      final amount = widget.controller.budget.monthBudget;
      if (_amount.text.trim().isEmpty && amount > 0) {
        _amount.text = formatMoney(amount);
      }
    } catch (error) {
      if (!mounted) return;
      showAppMessage(context, error.toString());
    }
  }

  Future<void> _save() async {
    final month = _month.text.trim();
    final amount = double.tryParse(_amount.text.trim());
    if (month.isEmpty || amount == null || amount < 0) {
      showAppMessage(context, '请填写有效的预算金额');
      return;
    }

    try {
      await widget.controller.saveBudget(month: month, amount: amount);
      if (!mounted) return;
      showAppMessage(context, '预算已保存');
    } catch (error) {
      if (!mounted) return;
      showAppMessage(context, error.toString());
    }
  }
}

class _BudgetValue extends StatelessWidget {
  const _BudgetValue({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color ?? AppColors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
