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
  String _range = '7d';

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
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _month,
                    decoration: const InputDecoration(labelText: '月份'),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 120,
                  child: DropdownButtonFormField<String>(
                    initialValue: _range,
                    decoration: const InputDecoration(labelText: '趋势'),
                    items: const [
                      DropdownMenuItem(value: '7d', child: Text('7天')),
                      DropdownMenuItem(value: '30d', child: Text('30天')),
                      DropdownMenuItem(value: '12m', child: Text('12月')),
                    ],
                    onChanged: (value) {
                      setState(() => _range = value ?? '7d');
                      _load();
                    },
                  ),
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
                label: '月收入',
                value: '¥${formatMoney(controller.monthStats.income)}',
                color: AppColors.income,
              ),
              MetricCard(
                label: '月支出',
                value: '¥${formatMoney(controller.monthStats.expense)}',
                color: AppColors.expense,
              ),
              MetricCard(
                label: '月结余',
                value: '¥${formatMoney(controller.monthStats.balance)}',
              ),
              MetricCard(
                label: '今日结余',
                value: '¥${formatMoney(controller.dayStats.balance)}',
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
          const SectionGap(),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '趋势',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 150,
                  child: TrendChart(points: controller.trendStats),
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
      await widget.controller.loadStatistics(
        month: _month.text.trim(),
        range: _range,
      );
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
              Text('¥${formatMoney(item.value)}'),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: value,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            backgroundColor: AppColors.border,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class TrendChart extends StatelessWidget {
  const TrendChart({required this.points, super.key});

  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Center(child: Text('暂无趋势数据'));
    }
    return CustomPaint(
      painter: _TrendPainter(points),
      child: const SizedBox.expand(),
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter(this.points);

  final List<TrendPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = points
        .expand((point) => [point.income, point.expense])
        .fold<double>(1, math.max);
    final incomePaint = Paint()
      ..color = AppColors.income
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;
    final expensePaint = Paint()
      ..color = AppColors.expense
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;
    final gridPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;

    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    Path pathFor(double Function(TrendPoint) pick) {
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final x = points.length == 1
            ? 0.0
            : size.width * i / (points.length - 1);
        final y = size.height - (pick(points[i]) / maxValue * size.height);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      return path;
    }

    canvas.drawPath(pathFor((point) => point.income), incomePaint);
    canvas.drawPath(pathFor((point) => point.expense), expensePaint);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
