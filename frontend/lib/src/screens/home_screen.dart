import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as speech;

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
                ],
              ),
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

      await _speech.listen(
        onResult: _handleSpeechResult,
        listenOptions: speech.SpeechListenOptions(
          localeId: 'zh_CN',
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
