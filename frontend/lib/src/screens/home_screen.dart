import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as speech;

import '../app_controller.dart';
import '../theme.dart';
import '../models.dart';
import '../utils/formatters.dart';
import '../utils/speech_locale.dart';
import '../widgets/common_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _textController = TextEditingController();
  final _speech = speech.SpeechToText();

  bool _speechReady = false;
  bool _listening = false;
  bool _submittingSpeech = false;
  String _recognizedText = '';

  @override
  void dispose() {
    _speech.cancel();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.controller.dashboard;
    final lastRecordedBill = widget.controller.lastRecordedBill;
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: widget.controller.refreshDashboard,
          child: PageScaffold(
            title: '今日账本',
            subtitle: '语音记一笔，AI 自动拆分收入和支出',
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
                  MetricCard(
                    label: '本月收入',
                    value: '¥${formatMoney(data.monthIncome)}',
                    color: AppColors.income,
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                  MetricCard(
                    label: '预算使用',
                    value: '${formatMoney(data.budgetPercent)}%',
                    icon: Icons.speed_outlined,
                  ),
                ],
              ),
              if (lastRecordedBill != null) ...[
                const SectionGap(),
                _AiResultCard(bill: lastRecordedBill),
              ],
              if (data.recentBills.isNotEmpty) ...[
                const SectionGap(),
                Text(
                  '最近记录',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                ...data.recentBills.map(
                  (bill) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: BillTile(bill: bill),
                  ),
                ),
              ],
              const SizedBox(height: 96),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _VoiceComposer(
            busy: widget.controller.busy || _submittingSpeech,
            listening: _listening,
            recognizedText: _recognizedText,
            onTapVoice: _toggleVoiceInput,
            onSubmit: _recordRecognizedText,
          ),
        ),
      ],
    );
  }

  Future<void> _toggleVoiceInput() async {
    if (widget.controller.busy || _submittingSpeech) return;

    if (_listening) {
      await _speech.stop();
      return;
    }

    try {
      final available =
          _speechReady ||
          await _speech.initialize(
            onStatus: _handleSpeechStatus,
            onError: _handleSpeechError,
            options: [speech.SpeechToText.androidNoBluetooth],
          );
      if (!mounted) return;
      if (!available) {
        showAppMessage(context, '当前设备不可用语音识别');
        return;
      }

      setState(() {
        _speechReady = true;
        _listening = true;
        _recognizedText = '';
      });
      _textController.clear();

      final localeId = await _preferredSpeechLocale();

      await _speech.listen(
        onResult: _handleSpeechResult,
        listenOptions: speech.SpeechListenOptions(
          localeId: localeId,
          listenMode: speech.ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
          autoPunctuation: true,
          enableHapticFeedback: true,
          listenFor: const Duration(seconds: 12),
          pauseFor: const Duration(seconds: 3),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _listening = false);
      showAppMessage(context, '语音识别启动失败：$error');
    }
  }

  Future<String?> _preferredSpeechLocale() async {
    try {
      final locales = await _speech.locales();
      final systemLocale = await _speech.systemLocale();
      return selectSpeechLocale(
        locales.map((locale) => locale.localeId),
        systemLocale?.localeId,
      );
    } catch (_) {
      return null;
    }
  }

  void _handleSpeechResult(SpeechRecognitionResult result) {
    final words = result.recognizedWords.trim();
    if (!mounted || words.isEmpty) return;

    setState(() {
      _recognizedText = words;
      _textController.text = words;
    });

    if (result.finalResult) {
      _recordRecognizedText();
    }
  }

  void _handleSpeechStatus(String status) {
    if (!mounted) return;

    setState(() {
      _listening = status == speech.SpeechToText.listeningStatus;
    });

    if (status == speech.SpeechToText.doneStatus ||
        status == speech.SpeechToText.notListeningStatus) {
      _recordRecognizedText();
    }
  }

  void _handleSpeechError(SpeechRecognitionError error) {
    if (!mounted) return;
    setState(() => _listening = false);
    showAppMessage(context, '语音识别失败：${error.errorMsg}');
  }

  Future<void> _recordRecognizedText() async {
    if (_submittingSpeech) return;
    final text = _textController.text.trim();
    if (text.isEmpty) {
      return;
    }
    setState(() => _submittingSpeech = true);
    try {
      await widget.controller.recordTextBill(text);
      _textController.clear();
      if (!mounted) return;
      setState(() => _recognizedText = '');
      showAppMessage(context, '已入账');
    } catch (error) {
      if (!mounted) return;
      showAppMessage(context, error.toString());
    } finally {
      if (mounted) {
        setState(() => _submittingSpeech = false);
      }
    }
  }
}

class _AiResultCard extends StatelessWidget {
  const _AiResultCard({required this.bill});

  final Bill bill;

  @override
  Widget build(BuildContext context) {
    final isIncome = bill.billType == 'income';
    final color = isIncome ? AppColors.income : AppColors.expense;
    final typeText = isIncome ? '收入' : '支出';
    final remark = bill.remark == null || bill.remark!.trim().isEmpty
        ? bill.category.name
        : bill.remark!.trim();

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.auto_awesome, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI 已识别$typeText ¥${formatMoney(bill.amount)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${bill.category.name} · $remark',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceComposer extends StatelessWidget {
  const _VoiceComposer({
    required this.busy,
    required this.listening,
    required this.recognizedText,
    required this.onTapVoice,
    required this.onSubmit,
  });

  final bool busy;
  final bool listening;
  final String recognizedText;
  final VoidCallback onTapVoice;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final text = recognizedText.isNotEmpty
        ? recognizedText
        : listening
        ? '正在听...'
        : '点击说一笔账';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Row(
          children: [
            IconButton.filled(
              tooltip: listening ? '停止语音输入' : '开始语音输入',
              onPressed: busy ? null : onTapVoice,
              icon: Icon(listening ? Icons.stop : Icons.mic),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: busy ? null : onTapVoice,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: listening
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : const Color(0xFFF5F6F5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: listening ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: listening ? AppColors.primaryDark : AppColors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            if (recognizedText.isNotEmpty && !listening) ...[
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: '发送给 AI',
                onPressed: busy ? null : onSubmit,
                icon: const Icon(Icons.send),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
