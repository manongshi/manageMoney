import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../app_controller.dart';
import '../theme.dart';
import '../models.dart';
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
  final _recorder = AudioRecorder();

  bool _listening = false;
  bool _submittingSpeech = false;
  bool _manualInput = false;
  String _recognizedText = '';
  String? _recordingPath;
  String? _voiceStatus;

  @override
  void dispose() {
    unawaited(_recorder.dispose());
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
            manualInput: _manualInput,
            recognizedText: _recognizedText,
            statusText: _voiceStatus,
            textController: _textController,
            onTapVoice: _toggleVoiceInput,
            onToggleManual: _toggleManualInput,
            onSubmit: _recordRecognizedText,
          ),
        ),
      ],
    );
  }

  Future<void> _toggleVoiceInput() async {
    if (widget.controller.busy || _submittingSpeech) return;

    if (_listening) {
      await _stopVoiceRecording();
      return;
    }

    try {
      final hasPermission = await _recorder.hasPermission();
      if (!mounted) return;
      if (!hasPermission) {
        _showVoiceStatus('请允许麦克风权限后再录音');
        return;
      }

      final supportsAac = await _recorder.isEncoderSupported(
        AudioEncoder.aacLc,
      );
      final extension = supportsAac ? 'm4a' : 'wav';
      final tempDir = await getTemporaryDirectory();
      final audioPath =
          '${tempDir.path}${Platform.pathSeparator}voice_${DateTime.now().millisecondsSinceEpoch}.$extension';

      await _recorder.start(
        RecordConfig(
          encoder: supportsAac ? AudioEncoder.aacLc : AudioEncoder.wav,
          bitRate: 64000,
          sampleRate: 16000,
          numChannels: 1,
          autoGain: true,
          noiseSuppress: true,
        ),
        path: audioPath,
      );
      if (!mounted) return;
      setState(() {
        _manualInput = false;
        _listening = true;
        _recognizedText = '';
        _recordingPath = audioPath;
        _voiceStatus = '正在录音，点击停止并分析';
      });
      _textController.clear();
    } catch (error) {
      if (!mounted) return;
      setState(() => _listening = false);
      _showVoiceStatus('录音启动失败：$error');
    }
  }

  Future<void> _stopVoiceRecording() async {
    String? audioPath = _recordingPath;
    try {
      audioPath = await _recorder.stop() ?? audioPath;
    } finally {
      if (mounted) {
        setState(() {
          _listening = false;
          _recordingPath = null;
        });
      }
    }

    if (audioPath == null || audioPath.trim().isEmpty) {
      _showVoiceStatus('没有生成录音文件，请重新录制');
      return;
    }
    await _recordAudioFile(audioPath);
  }

  Future<void> _toggleManualInput() async {
    final audioPath = _recordingPath;
    if (_listening) {
      final stoppedPath = await _recorder.stop();
      await _deleteLocalAudioFile(stoppedPath ?? audioPath ?? '');
    }
    setState(() {
      _listening = false;
      _recordingPath = null;
      _manualInput = !_manualInput;
      _voiceStatus = null;
      if (!_manualInput) {
        _recognizedText = '';
        _textController.clear();
      }
    });
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
      setState(() {
        _manualInput = false;
        _recognizedText = '';
        _voiceStatus = null;
      });
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

  Future<void> _recordAudioFile(String audioPath) async {
    if (_submittingSpeech) return;
    setState(() {
      _submittingSpeech = true;
      _voiceStatus = '正在识别并分析账单';
    });
    try {
      await widget.controller.recordAudioBill(audioPath);
      if (!mounted) return;
      setState(() {
        _manualInput = false;
        _recognizedText = '';
        _voiceStatus = null;
      });
      showAppMessage(context, '已入账');
    } catch (error) {
      if (!mounted) return;
      _showVoiceStatus(error.toString());
    } finally {
      await _deleteLocalAudioFile(audioPath);
      if (mounted) {
        setState(() => _submittingSpeech = false);
      }
    }
  }

  Future<void> _deleteLocalAudioFile(String audioPath) async {
    if (audioPath.trim().isEmpty) return;
    try {
      final file = File(audioPath);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best-effort cleanup for temporary recordings.
    }
  }

  void _showVoiceStatus(String message, {bool showManualInput = false}) {
    setState(() {
      _voiceStatus = message;
      if (showManualInput) _manualInput = true;
    });
    showAppMessage(context, message);
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
    required this.manualInput,
    required this.recognizedText,
    required this.statusText,
    required this.textController,
    required this.onTapVoice,
    required this.onToggleManual,
    required this.onSubmit,
  });

  final bool busy;
  final bool listening;
  final bool manualInput;
  final String recognizedText;
  final String? statusText;
  final TextEditingController textController;
  final VoidCallback onTapVoice;
  final VoidCallback onToggleManual;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final text = statusText != null && statusText!.isNotEmpty
        ? statusText!
        : recognizedText.isNotEmpty
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
              tooltip: manualInput
                  ? '切换语音输入'
                  : listening
                  ? '停止语音输入'
                  : '开始语音输入',
              onPressed: busy ? null : onTapVoice,
              icon: Icon(
                manualInput
                    ? Icons.mic
                    : listening
                    ? Icons.stop
                    : Icons.mic,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: manualInput
                  ? SizedBox(
                      height: 48,
                      child: TextField(
                        controller: textController,
                        enabled: !busy,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => busy ? null : onSubmit(),
                        decoration: InputDecoration(
                          hintText: '输入一句账单',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          suffixIcon: IconButton(
                            tooltip: '发送给 AI',
                            onPressed: busy ? null : onSubmit,
                            icon: const Icon(Icons.send),
                          ),
                        ),
                      ),
                    )
                  : InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: busy ? null : onTapVoice,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: statusText != null && statusText!.isNotEmpty
                              ? AppColors.expense.withValues(alpha: 0.08)
                              : listening
                              ? AppColors.primary.withValues(alpha: 0.08)
                              : const Color(0xFFF5F6F5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: statusText != null && statusText!.isNotEmpty
                                ? AppColors.expense
                                : listening
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                        child: Text(
                          text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color:
                                    statusText != null && statusText!.isNotEmpty
                                    ? AppColors.expense
                                    : listening
                                    ? AppColors.primaryDark
                                    : AppColors.text,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ),
            ),
            if (!manualInput) ...[
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: '手动输入账单',
                onPressed: busy ? null : onToggleManual,
                icon: const Icon(Icons.keyboard),
              ),
            ],
            if (recognizedText.isNotEmpty && !listening && !manualInput) ...[
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
