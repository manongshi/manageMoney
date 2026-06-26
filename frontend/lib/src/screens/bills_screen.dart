import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models.dart';
import '../utils/formatters.dart';
import '../widgets/common_widgets.dart';

class BillsScreen extends StatefulWidget {
  const BillsScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  final _keyword = TextEditingController();
  String _billType = '';
  String _categoryId = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _keyword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bills = widget.controller.bills;
    return RefreshIndicator(
      onRefresh: _load,
      child: PageScaffold(
        title: '账单',
        subtitle: '共 ${widget.controller.billTotal} 条记录',
        action: IconButton.filled(
          tooltip: '补记账单',
          onPressed: () => _openBillForm(),
          icon: const Icon(Icons.add),
        ),
        children: [
          AppCard(
            child: Column(
              children: [
                TextField(
                  controller: _keyword,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _load(),
                  decoration: const InputDecoration(
                    labelText: '搜索备注或分类',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _billType,
                        decoration: const InputDecoration(labelText: '类型'),
                        items: const [
                          DropdownMenuItem(value: '', child: Text('全部')),
                          DropdownMenuItem(value: 'expense', child: Text('支出')),
                          DropdownMenuItem(value: 'income', child: Text('收入')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _billType = value ?? '';
                            _categoryId = '';
                          });
                          _load();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _categoryId,
                        decoration: const InputDecoration(labelText: '分类'),
                        items: [
                          const DropdownMenuItem(value: '', child: Text('全部')),
                          ..._filterCategories.map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _categoryId = value ?? '');
                          _load();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SectionGap(),
          if (bills.isEmpty)
            const EmptyState('暂无账单')
          else
            ...bills.map(
              (bill) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: BillTile(
                  bill: bill,
                  onEdit: () => _openBillForm(bill: bill),
                  onDelete: () => _confirmDelete(bill),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Category> get _filterCategories {
    final categories = widget.controller.categories;
    if (_billType.isEmpty) return categories;
    return categories.where((item) => item.type == _billType).toList();
  }

  Future<void> _load() async {
    try {
      await widget.controller.loadBills(
        keyword: _keyword.text.trim(),
        billType: _billType,
        categoryId: _categoryId,
      );
    } catch (error) {
      if (!mounted) return;
      showAppMessage(context, error.toString());
    }
  }

  Future<void> _openBillForm({Bill? bill}) async {
    if (widget.controller.categories.isEmpty) {
      try {
        await widget.controller.loadCategories();
      } catch (error) {
        if (!mounted) return;
        showAppMessage(context, error.toString());
        return;
      }
    }
    if (!mounted) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          BillFormSheet(controller: widget.controller, bill: bill),
    );
    if (saved == true) await _load();
  }

  Future<void> _confirmDelete(Bill bill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除账单'),
        content: Text('确认删除「${bill.remark ?? bill.category.name}」？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.controller.deleteBill(bill.id);
      if (!mounted) return;
      showAppMessage(context, '已删除');
    } catch (error) {
      if (!mounted) return;
      showAppMessage(context, error.toString());
    }
  }
}

class BillFormSheet extends StatefulWidget {
  const BillFormSheet({required this.controller, this.bill, super.key});

  final AppController controller;
  final Bill? bill;

  @override
  State<BillFormSheet> createState() => _BillFormSheetState();
}

class _BillFormSheetState extends State<BillFormSheet> {
  final _amount = TextEditingController();
  final _remark = TextEditingController();
  late String _billType;
  String _categoryId = '';

  @override
  void initState() {
    super.initState();
    final bill = widget.bill;
    _billType = bill?.billType ?? 'expense';
    _categoryId = bill?.categoryId ?? _firstCategoryId();
    _amount.text = bill == null ? '' : formatMoney(bill.amount);
    _remark.text = bill?.remark ?? '';
    if (_categoryId.isEmpty && _categories.isNotEmpty) {
      _categoryId = _categories.first.id;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _remark.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.bill == null ? '补记一笔' : '编辑账单',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'expense', label: Text('支出')),
                ButtonSegment(value: 'income', label: Text('收入')),
              ],
              selected: {_billType},
              onSelectionChanged: (value) {
                setState(() {
                  _billType = value.first;
                  _categoryId = _firstCategoryId();
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '金额'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: '分类'),
              items: _categories
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.id,
                      child: Text(item.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _categoryId = value ?? ''),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _remark,
              decoration: const InputDecoration(labelText: '备注'),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: widget.controller.busy ? null : _save,
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  List<Category> get _categories {
    return widget.controller.categoriesByType(_billType);
  }

  String _firstCategoryId() {
    return _categories.isEmpty ? '' : _categories.first.id;
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0 || _categoryId.isEmpty) {
      showAppMessage(context, '请填写金额和分类');
      return;
    }
    try {
      await widget.controller.saveBill(
        id: widget.bill?.id,
        amount: amount,
        categoryId: _categoryId,
        billType: _billType,
        remark: _remark.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      showAppMessage(context, error.toString());
    }
  }
}
