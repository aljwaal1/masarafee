import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MasroofiSmartApp());
}

class MasroofiSmartApp extends StatelessWidget {
  const MasroofiSmartApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2F7D68);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'مصروفي الذكي',
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFF5F7F2),
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
          surface: const Color(0xFFFCFDF8),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Color(0xFFF5F7F2),
          foregroundColor: Color(0xFF1D2D28),
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
        navigationBarTheme: NavigationBarThemeData(
          indicatorColor: seed.withOpacity(0.14),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFFFCFDF8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFFE6EADF)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFDDE5D8)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFDDE5D8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: seed, width: 1.4),
          ),
        ),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: HomeScreen(),
      ),
    );
  }
}

enum RecordType { income, expense, obligation }

extension RecordTypeText on RecordType {
  String get label {
    switch (this) {
      case RecordType.income:
        return 'دخل';
      case RecordType.expense:
        return 'مصروف';
      case RecordType.obligation:
        return 'التزام';
    }
  }

  String get actionLabel {
    switch (this) {
      case RecordType.income:
        return 'إضافة دخل';
      case RecordType.expense:
        return 'إضافة مصروف';
      case RecordType.obligation:
        return 'إضافة التزام';
    }
  }

  Color get color {
    switch (this) {
      case RecordType.income:
        return const Color(0xFF2F7D68);
      case RecordType.expense:
        return const Color(0xFFB9574F);
      case RecordType.obligation:
        return const Color(0xFF8A6A20);
    }
  }
}

class FinancialRecord {
  const FinancialRecord({
    required this.id,
    required this.type,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    required this.dueDate,
    required this.note,
    required this.paid,
  });

  final String id;
  final RecordType type;
  final String title;
  final double amount;
  final String category;
  final DateTime date;
  final DateTime? dueDate;
  final String note;
  final bool paid;

  FinancialRecord copyWith({bool? paid}) {
    return FinancialRecord(
      id: id,
      type: type,
      title: title,
      amount: amount,
      category: category,
      date: date,
      dueDate: dueDate,
      note: note,
      paid: paid ?? this.paid,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'note': note,
      'paid': paid,
    };
  }

  factory FinancialRecord.fromJson(Map<String, dynamic> map) {
    return FinancialRecord(
      id: map['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      type: RecordType.values.firstWhere(
        (item) => item.name == map['type'],
        orElse: () => RecordType.expense,
      ),
      title: map['title'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      category: map['category'] as String? ?? 'أخرى',
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      dueDate: DateTime.tryParse(map['dueDate'] as String? ?? ''),
      note: map['note'] as String? ?? '',
      paid: map['paid'] as bool? ?? false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _storageKey = 'masroofi_records_v1';

  final List<FinancialRecord> _records = [];
  int _tab = 0;
  bool _currentMonthOnly = true;
  RecordType? _filterType;
  String? _filterCategory;
  bool _loading = true;

  final List<String> _incomeCategories = const ['راتب', 'عمل حر', 'مبيعات', 'هدية', 'أخرى'];
  final List<String> _expenseCategories = const [
    'طعام',
    'مواصلات',
    'بيت',
    'فواتير',
    'دراسة',
    'صحة',
    'تسوق',
    'أخرى',
  ];
  final List<String> _obligationCategories = const ['إيجار', 'قسط', 'فاتورة', 'دين', 'اشتراك', 'أخرى'];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);
    if (saved != null && saved.isNotEmpty) {
      final decoded = jsonDecode(saved) as List<dynamic>;
      _records
        ..clear()
        ..addAll(decoded.map((item) => FinancialRecord.fromJson(item as Map<String, dynamic>)));
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_records.map((item) => item.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  List<FinancialRecord> get _visibleRecords {
    final list = _records.where((record) {
      final date = record.type == RecordType.obligation ? record.dueDate ?? record.date : record.date;
      final byMonth = !_currentMonthOnly || _sameMonth(date, DateTime.now());
      final byType = _filterType == null || record.type == _filterType;
      final byCategory = _filterCategory == null || record.category == _filterCategory;
      return byMonth && byType && byCategory;
    }).toList();
    list.sort((a, b) {
      final ad = a.type == RecordType.obligation ? a.dueDate ?? a.date : a.date;
      final bd = b.type == RecordType.obligation ? b.dueDate ?? b.date : b.date;
      return bd.compareTo(ad);
    });
    return list;
  }

  List<FinancialRecord> get _monthRecords {
    return _records.where((record) {
      final date = record.type == RecordType.obligation ? record.dueDate ?? record.date : record.date;
      return _sameMonth(date, DateTime.now());
    }).toList();
  }

  double get _incomeTotal => _monthRecords
      .where((record) => record.type == RecordType.income)
      .fold(0, (sum, record) => sum + record.amount);

  double get _expenseTotal => _monthRecords
      .where((record) => record.type == RecordType.expense)
      .fold(0, (sum, record) => sum + record.amount);

  double get _unpaidObligations => _monthRecords
      .where((record) => record.type == RecordType.obligation && !record.paid)
      .fold(0, (sum, record) => sum + record.amount);

  double get _expectedBalance => _incomeTotal - _expenseTotal - _unpaidObligations;

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : IndexedStack(
            index: _tab,
            children: [
              _DashboardView(
                income: _incomeTotal,
                expense: _expenseTotal,
                obligations: _unpaidObligations,
                balance: _expectedBalance,
                recentRecords: _visibleRecords.take(6).toList(),
                onAdd: _openRecordSheet,
                onDelete: _deleteRecord,
                onTogglePaid: _togglePaid,
              ),
              _RecordsView(
                records: _visibleRecords,
                currentMonthOnly: _currentMonthOnly,
                filterType: _filterType,
                filterCategory: _filterCategory,
                categories: _allCategories,
                onMonthChanged: (value) => setState(() => _currentMonthOnly = value),
                onTypeChanged: (value) => setState(() => _filterType = value),
                onCategoryChanged: (value) => setState(() => _filterCategory = value),
                onDelete: _deleteRecord,
                onTogglePaid: _togglePaid,
              ),
              _ObligationsView(
                obligations: _records
                    .where((record) => record.type == RecordType.obligation)
                    .toList()
                  ..sort((a, b) => (a.dueDate ?? a.date).compareTo(b.dueDate ?? b.date)),
                onTogglePaid: _togglePaid,
                onDelete: _deleteRecord,
              ),
            ],
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'مصروفي الذكي',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0),
        ),
        actions: [
          IconButton(
            tooltip: 'إضافة',
            onPressed: () => _openRecordSheet(),
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(child: body),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openRecordSheet(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard_rounded),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'العمليات',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note_rounded),
            label: 'الالتزامات',
          ),
        ],
      ),
    );
  }

  List<String> get _allCategories {
    final values = <String>{..._incomeCategories, ..._expenseCategories, ..._obligationCategories};
    return values.toList()..sort();
  }

  List<String> _categoriesFor(RecordType type) {
    switch (type) {
      case RecordType.income:
        return _incomeCategories;
      case RecordType.expense:
        return _expenseCategories;
      case RecordType.obligation:
        return _obligationCategories;
    }
  }

  Future<void> _openRecordSheet({RecordType initialType = RecordType.expense}) async {
    final record = await showModalBottomSheet<FinancialRecord>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RecordFormSheet(
        initialType: initialType,
        categoriesFor: _categoriesFor,
      ),
    );
    if (record == null) return;
    setState(() => _records.add(record));
    await _saveRecords();
  }

  Future<void> _deleteRecord(FinancialRecord record) async {
    setState(() => _records.removeWhere((item) => item.id == record.id));
    await _saveRecords();
  }

  Future<void> _togglePaid(FinancialRecord record) async {
    final index = _records.indexWhere((item) => item.id == record.id);
    if (index == -1) return;
    setState(() => _records[index] = _records[index].copyWith(paid: !record.paid));
    await _saveRecords();
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView({
    required this.income,
    required this.expense,
    required this.obligations,
    required this.balance,
    required this.recentRecords,
    required this.onAdd,
    required this.onDelete,
    required this.onTogglePaid,
  });

  final double income;
  final double expense;
  final double obligations;
  final double balance;
  final List<FinancialRecord> recentRecords;
  final void Function({RecordType initialType}) onAdd;
  final ValueChanged<FinancialRecord> onDelete;
  final ValueChanged<FinancialRecord> onTogglePaid;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 92),
      children: [
        Text(
          'ملخص هذا الشهر',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: const Color(0xFF1D2D28),
              ),
        ),
        const SizedBox(height: 6),
        const Text(
          'سجل دخلك ومصاريفك والتزاماتك، وشاهد المتبقي المتوقع فورًا.',
          style: TextStyle(color: Color(0xFF64736B), height: 1.45),
        ),
        const SizedBox(height: 16),
        _HeroBalance(balance: balance),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _MetricTile(label: 'الدخل', value: income, color: RecordType.income.color)),
            const SizedBox(width: 8),
            Expanded(child: _MetricTile(label: 'المصروف', value: expense, color: RecordType.expense.color)),
          ],
        ),
        const SizedBox(height: 8),
        _MetricTile(label: 'التزامات غير مدفوعة', value: obligations, color: RecordType.obligation.color),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => onAdd(initialType: RecordType.income),
                icon: const Icon(Icons.trending_up_rounded),
                label: const Text('دخل'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => onAdd(initialType: RecordType.expense),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('مصروف'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => onAdd(initialType: RecordType.obligation),
                icon: const Icon(Icons.event_available_outlined),
                label: const Text('التزام'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          'آخر العمليات',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        if (recentRecords.isEmpty)
          const _EmptyState(
            title: 'لا توجد عمليات بعد',
            subtitle: 'ابدأ بإضافة دخل أو مصروف، وسيظهر ملخصك هنا.',
          )
        else
          ...recentRecords.map(
            (record) => _RecordTile(
              record: record,
              onDelete: onDelete,
              onTogglePaid: onTogglePaid,
            ),
          ),
      ],
    );
  }
}

class _RecordsView extends StatelessWidget {
  const _RecordsView({
    required this.records,
    required this.currentMonthOnly,
    required this.filterType,
    required this.filterCategory,
    required this.categories,
    required this.onMonthChanged,
    required this.onTypeChanged,
    required this.onCategoryChanged,
    required this.onDelete,
    required this.onTogglePaid,
  });

  final List<FinancialRecord> records;
  final bool currentMonthOnly;
  final RecordType? filterType;
  final String? filterCategory;
  final List<String> categories;
  final ValueChanged<bool> onMonthChanged;
  final ValueChanged<RecordType?> onTypeChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<FinancialRecord> onDelete;
  final ValueChanged<FinancialRecord> onTogglePaid;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 92),
      children: [
        Text(
          'العمليات',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              selected: currentMonthOnly,
              onSelected: onMonthChanged,
              label: const Text('هذا الشهر فقط'),
            ),
            FilterChip(
              selected: filterType == null,
              onSelected: (_) => onTypeChanged(null),
              label: const Text('كل الأنواع'),
            ),
            ...RecordType.values.map(
              (type) => FilterChip(
                selected: filterType == type,
                onSelected: (_) => onTypeChanged(type),
                label: Text(type.label),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String?>(
          value: filterCategory,
          decoration: const InputDecoration(labelText: 'التصنيف'),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('كل التصنيفات')),
            ...categories.map((item) => DropdownMenuItem<String?>(value: item, child: Text(item))),
          ],
          onChanged: onCategoryChanged,
        ),
        const SizedBox(height: 16),
        if (records.isEmpty)
          const _EmptyState(
            title: 'لا توجد نتائج',
            subtitle: 'غيّر الفلترة أو أضف عملية جديدة.',
          )
        else
          ...records.map(
            (record) => _RecordTile(
              record: record,
              onDelete: onDelete,
              onTogglePaid: onTogglePaid,
            ),
          ),
      ],
    );
  }
}

class _ObligationsView extends StatelessWidget {
  const _ObligationsView({
    required this.obligations,
    required this.onTogglePaid,
    required this.onDelete,
  });

  final List<FinancialRecord> obligations;
  final ValueChanged<FinancialRecord> onTogglePaid;
  final ValueChanged<FinancialRecord> onDelete;

  @override
  Widget build(BuildContext context) {
    final unpaid = obligations.where((record) => !record.paid).toList();
    final paid = obligations.where((record) => record.paid).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 92),
      children: [
        Text(
          'الالتزامات',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        const Text(
          'تابع الإيجار والأقساط والفواتير والديون القادمة.',
          style: TextStyle(color: Color(0xFF64736B), height: 1.45),
        ),
        const SizedBox(height: 16),
        if (obligations.isEmpty)
          const _EmptyState(
            title: 'لا توجد التزامات',
            subtitle: 'أضف الالتزامات القادمة حتى لا تضيع عليك مواعيدها.',
          )
        else ...[
          if (unpaid.isNotEmpty) ...[
            const _SectionLabel('غير مدفوعة'),
            ...unpaid.map(
              (record) => _RecordTile(
                record: record,
                onDelete: onDelete,
                onTogglePaid: onTogglePaid,
              ),
            ),
          ],
          if (paid.isNotEmpty) ...[
            const SizedBox(height: 14),
            const _SectionLabel('مدفوعة'),
            ...paid.map(
              (record) => _RecordTile(
                record: record,
                onDelete: onDelete,
                onTogglePaid: onTogglePaid,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _RecordFormSheet extends StatefulWidget {
  const _RecordFormSheet({
    required this.initialType,
    required this.categoriesFor,
  });

  final RecordType initialType;
  final List<String> Function(RecordType type) categoriesFor;

  @override
  State<_RecordFormSheet> createState() => _RecordFormSheetState();
}

class _RecordFormSheetState extends State<_RecordFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  late RecordType _type;
  late String _category;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _category = widget.categoriesFor(_type).first;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFCFDF8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE4E9DF)),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _type.actionLabel,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<RecordType>(
                  value: _type,
                  decoration: const InputDecoration(labelText: 'النوع'),
                  items: RecordType.values
                      .map((type) => DropdownMenuItem(value: type, child: Text(type.label)))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _type = value;
                      _category = widget.categoriesFor(_type).first;
                    });
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'العنوان', hintText: 'مثال: راتب، غداء، فاتورة كهرباء'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'اكتب عنوان العملية';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: const InputDecoration(labelText: 'المبلغ', suffixText: 'د.أ'),
                  validator: (value) {
                    final number = double.tryParse(value ?? '');
                    if (number == null || number <= 0) return 'اكتب مبلغًا صحيحًا';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(labelText: 'التصنيف'),
                  items: widget
                      .categoriesFor(_type)
                      .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                      .toList(),
                  onChanged: (value) => setState(() => _category = value ?? _category),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(_type == RecordType.obligation
                      ? 'موعد الاستحقاق: ${formatDate(_date)}'
                      : 'تاريخ العملية: ${formatDate(_date)}'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'ملاحظة اختيارية'),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('حفظ'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final record = FinancialRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: _type,
      title: _titleController.text.trim(),
      amount: double.parse(_amountController.text),
      category: _category,
      date: _type == RecordType.obligation ? DateTime.now() : _date,
      dueDate: _type == RecordType.obligation ? _date : null,
      note: _noteController.text.trim(),
      paid: false,
    );
    Navigator.pop(context, record);
  }
}

class _HeroBalance extends StatelessWidget {
  const _HeroBalance({required this.balance});

  final double balance;

  @override
  Widget build(BuildContext context) {
    final positive = balance >= 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1F332D),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'الصافي المتوقع بعد الالتزامات',
            style: TextStyle(color: Color(0xFFC9D7D0), fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            formatMoney(balance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            positive ? 'وضعك ضمن الحدود لهذا الشهر.' : 'انتبه، الالتزامات والمصاريف أعلى من الدخل.',
            style: TextStyle(color: positive ? const Color(0xFFBFE8D8) : const Color(0xFFFFD7D2)),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF64736B), fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              formatMoney(value),
              style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.record,
    required this.onDelete,
    required this.onTogglePaid,
  });

  final FinancialRecord record;
  final ValueChanged<FinancialRecord> onDelete;
  final ValueChanged<FinancialRecord> onTogglePaid;

  @override
  Widget build(BuildContext context) {
    final date = record.type == RecordType.obligation ? record.dueDate ?? record.date : record.date;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: record.type.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_iconFor(record.type), color: record.type.color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          record.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1D2D28)),
                        ),
                      ),
                      if (record.type == RecordType.obligation)
                        _StatusPill(paid: record.paid),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${record.type.label} · ${record.category} · ${formatDate(date)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF64736B), fontSize: 12),
                  ),
                  if (record.note.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      record.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF7B867F), fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatMoney(record.amount),
                  style: TextStyle(color: record.type.color, fontWeight: FontWeight.w900),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (record.type == RecordType.obligation)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: record.paid ? 'إلغاء الدفع' : 'تحديد كمدفوع',
                        onPressed: () => onTogglePaid(record),
                        icon: Icon(record.paid ? Icons.undo_rounded : Icons.done_rounded, size: 20),
                      ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'حذف',
                      onPressed: () => onDelete(record),
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.paid});

  final bool paid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: paid ? const Color(0xFFE8F3EE) : const Color(0xFFFFF5DA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        paid ? 'مدفوع' : 'بانتظار الدفع',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: paid ? const Color(0xFF2F7D68) : const Color(0xFF8A6A20),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(Icons.inbox_outlined, size: 34, color: Color(0xFF8A9990)),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64736B), height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
      ),
    );
  }
}

IconData _iconFor(RecordType type) {
  switch (type) {
    case RecordType.income:
      return Icons.south_west_rounded;
    case RecordType.expense:
      return Icons.north_east_rounded;
    case RecordType.obligation:
      return Icons.event_available_rounded;
  }
}

bool _sameMonth(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month;
}

String formatMoney(double value) {
  final sign = value < 0 ? '-' : '';
  final absValue = value.abs();
  final number = absValue == absValue.roundToDouble()
      ? absValue.toStringAsFixed(0)
      : absValue.toStringAsFixed(2);
  return '$sign$number د.أ';
}

String formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}
