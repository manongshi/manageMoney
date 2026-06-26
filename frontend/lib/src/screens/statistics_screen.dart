import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models.dart';
import '../theme.dart';
import '../utils/formatters.dart';
import '../widgets/common_widgets.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final _month = TextEditingController(text: currentMonth());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _month.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return RefreshIndicator(
      onRefresh: _load,
      child: PageScaffold(
        title: '统计',
        subtitle: '${_month.text} 月度概览',
        action: IconButton.filledTonal(
          tooltip: '刷新统计',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
        children: [
          AppCard(
            child: TextField(
              controller: _month,
              decoration: const InputDecoration(labelText: '月份'),
              onSubmitted: (_) => _load(),
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
                label: '月收入',
                value: formatSignedMoney(
                  controller.monthStats.income,
                  'income',
                ),
                color: AppColors.income,
              ),
              MetricCard(
                label: '月支出',
                value: formatSignedMoney(
                  controller.monthStats.expense,
                  'expense',
                ),
                color: AppColors.expense,
              ),
              MetricCard(
                label: '月结余',
                value: formatSignedMoney(controller.monthStats.balance, null),
              ),
              MetricCard(
                label: '今日结余',
                value: formatSignedMoney(controller.dayStats.balance, null),
              ),
            ],
          ),
          const SectionGap(),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '支出分类',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                if (controller.categoryStats.isEmpty)
                  const Text('暂无支出数据')
                else
                  ...controller.categoryStats.map(
                    (item) => _CategoryBar(
                      item: item,
                      maxValue: controller.categoryStats
                          .map((e) => e.value)
                          .fold<double>(0, (a, b) => math.max(a, b).toDouble()),
                    ),
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
      await widget.controller.loadStatistics(month: _month.text.trim());
    } catch (error) {
      if (!mounted) return;
      showAppMessage(context, error.toString());
    }
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.item, required this.maxValue});

  final CategoryStat item;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    final value = maxValue <= 0 ? 0.0 : item.value / maxValue;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(item.name)),
              Text(formatSignedMoney(item.value, 'expense')),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: value,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
            backgroundColor: AppColors.border,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
