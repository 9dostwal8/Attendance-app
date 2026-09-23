import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/hr_models.dart';
import '../providers/attendance_provider.dart';

Future<void> showPayrollAdjustmentDialog({
  required BuildContext context,
  CompanyEmployee? employee,
  String initialType = 'addition',
  DateTime? initialMonth,
}) async {
  final provider = Provider.of<AttendanceProvider>(context, listen: false);
  final currentUser = provider.currentEmployee;
  final isAllowed = currentUser != null && (
    currentUser.role == 'hr' ||
    currentUser.role == 'admin' ||
    currentUser.email == 'admin@company.com'
  );
  if (!isAllowed) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Access denied. Only HR Managers and Super Admins can add payroll adjustments.'),
      ),
    );
    return;
  }

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Payroll Adjustment',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (ctx, anim1, anim2) {
      return _PayrollAdjustmentDialogContent(
        initialEmployee: employee,
        initialType: initialType,
        initialMonth: initialMonth ?? DateTime.now(),
      );
    },
    transitionBuilder: (ctx, anim, secondAnim, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1.0).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

class _PayrollAdjustmentDialogContent extends StatefulWidget {
  final CompanyEmployee? initialEmployee;
  final String initialType;
  final DateTime initialMonth;

  const _PayrollAdjustmentDialogContent({
    this.initialEmployee,
    required this.initialType,
    required this.initialMonth,
  });

  @override
  State<_PayrollAdjustmentDialogContent> createState() =>
      _PayrollAdjustmentDialogContentState();
}

class _PayrollAdjustmentDialogContentState
    extends State<_PayrollAdjustmentDialogContent> {
  late String _type; // 'addition' or 'deduction'
  late String _category;
  CompanyEmployee? _selectedEmployee;
  late DateTime _selectedDate;
  late String _currency;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  static const List<String> _additionCategories = [
    'Bonus',
    'Commission / Incentive',
    'Overtime Adjustment',
    'Special Allowance',
    'Housing Allowance',
    'Food Allowance',
    'Other Addition',
  ];

  static const List<String> _deductionCategories = [
    'Loan Repayment',
    'Fine / Penalty',
    'Salary Advance',
    'Equipment / Damage',
    'Absence / Deficit Adjustment',
    'Insurance / Tax',
    'Other Deduction',
  ];

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _category = _type == 'addition'
        ? _additionCategories.first
        : _deductionCategories.first;

    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    final availableEmps = provider.employees;

    if (widget.initialEmployee != null) {
      _selectedEmployee = widget.initialEmployee;
    } else if (availableEmps.isNotEmpty) {
      _selectedEmployee = availableEmps.first;
    }

    _currency = _selectedEmployee?.salaryCurrency ?? 'USD';

    // Default date within target month
    final now = DateTime.now();
    if (widget.initialMonth.year == now.year &&
        widget.initialMonth.month == now.month) {
      _selectedDate = now;
    } else {
      _selectedDate = DateTime(widget.initialMonth.year, widget.initialMonth.month, 1);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _onTypeChanged(String newType) {
    if (_type == newType) return;
    setState(() {
      _type = newType;
      _category = _type == 'addition'
          ? _additionCategories.first
          : _deductionCategories.first;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: _type == 'addition'
                  ? const Color(0xFF00C853)
                  : const Color(0xFFFF5252),
              brightness: Theme.of(context).brightness,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEmployee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an employee.')),
      );
      return;
    }

    final double amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount greater than 0.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final monthStr = DateFormat('yyyy-MM').format(_selectedDate);

    final adjustment = PayrollAdjustment(
      id: 'adj_${DateTime.now().millisecondsSinceEpoch}',
      employeeId: _selectedEmployee!.id,
      type: _type,
      category: _category,
      amount: amount,
      currency: _currency,
      date: dateStr,
      month: monthStr,
      reason: _reasonController.text.trim(),
      createdBy: provider.currentEmployee?.name ?? 'Admin',
      createdAt: DateTime.now(),
    );

    await provider.addPayrollAdjustment(adjustment);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _type == 'addition'
              ? const Color(0xFF10B981)
              : const Color(0xFFEF4444),
          content: Text(
            '${_type == 'addition' ? 'Addition' : 'Deduction'} of ${_currency == 'USD' ? '\$$amount' : '$amount $_currency'} recorded for ${_selectedEmployee!.name}.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = Provider.of<AttendanceProvider>(context);
    final employees = provider.employees;

    final isAddition = _type == 'addition';
    final accentColor = isAddition
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);
    final bgGlowColor = isAddition
        ? const Color(0xFF10B981).withValues(alpha: 0.15)
        : const Color(0xFFEF4444).withValues(alpha: 0.15);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 540),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: isDark ? const Color(0xFF1A1F2C) : Colors.white,
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 36,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: bgGlowColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: accentColor.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Icon(
                                isAddition
                                    ? Icons.trending_up_rounded
                                    : Icons.trending_down_rounded,
                                color: accentColor,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isAddition
                                        ? 'Employee Monthly Addition'
                                        : 'Employee Monthly Deduction',
                                    style: TextStyle(
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      fontSize: 19,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isAddition
                                        ? 'Record bonus, incentive, allowance, or adjustment'
                                        : 'Record loan repayment, fine, penalty, or deduction',
                                    style: TextStyle(
                                      color: isDark ? Colors.white60 : Colors.black54,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: Icon(
                                Icons.close_rounded,
                                color: isDark ? Colors.white60 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Type Switcher Tabs (Addition vs Deduction)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => _onTypeChanged('addition'),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isAddition
                                          ? const Color(0xFF10B981)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: isAddition
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_circle_outline_rounded,
                                          size: 16,
                                          color: isAddition
                                              ? Colors.white
                                              : (isDark ? Colors.white70 : Colors.black87),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Addition / Bonus',
                                          style: TextStyle(
                                            color: isAddition
                                                ? Colors.white
                                                : (isDark ? Colors.white70 : Colors.black87),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () => _onTypeChanged('deduction'),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: !isAddition
                                          ? const Color(0xFFEF4444)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: !isAddition
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.remove_circle_outline_rounded,
                                          size: 16,
                                          color: !isAddition
                                              ? Colors.white
                                              : (isDark ? Colors.white70 : Colors.black87),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Deduction / Loan / Fine',
                                          style: TextStyle(
                                            color: !isAddition
                                                ? Colors.white
                                                : (isDark ? Colors.white70 : Colors.black87),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Employee Selection Dropdown
                        Text(
                          'Employee',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<CompanyEmployee>(
                              value: _selectedEmployee,
                              isExpanded: true,
                              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                              hint: const Text('Select Employee'),
                              items: employees.map((emp) {
                                return DropdownMenuItem<CompanyEmployee>(
                                  value: emp,
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: accentColor.withValues(alpha: 0.2),
                                        child: Text(
                                          emp.name.isNotEmpty
                                              ? emp.name[0].toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            color: accentColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              emp.name,
                                              style: TextStyle(
                                                color: isDark ? Colors.white : Colors.black87,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              emp.position,
                                              style: TextStyle(
                                                color: isDark ? Colors.white54 : Colors.black54,
                                                fontSize: 11,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (emp) {
                                if (emp != null) {
                                  setState(() {
                                    _selectedEmployee = emp;
                                    _currency = emp.salaryCurrency.isNotEmpty
                                        ? emp.salaryCurrency
                                        : 'USD';
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Category Dropdown
                        Text(
                          isAddition ? 'Addition Type / Reason' : 'Deduction Type / Reason',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _category,
                              isExpanded: true,
                              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                              items: (isAddition ? _additionCategories : _deductionCategories)
                                  .map((cat) {
                                return DropdownMenuItem<String>(
                                  value: cat,
                                  child: Row(
                                    children: [
                                      Icon(
                                        _getCategoryIcon(cat),
                                        size: 18,
                                        color: accentColor,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        cat,
                                        style: TextStyle(
                                          color: isDark ? Colors.white : Colors.black87,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (cat) {
                                if (cat != null) {
                                  setState(() {
                                    _category = cat;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Amount and Currency Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Amount',
                                    style: TextStyle(
                                      color: isDark ? Colors.white70 : Colors.black87,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _amountController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: TextStyle(
                                      color: isDark ? Colors.white : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '0.00',
                                      prefixIcon: Icon(
                                        Icons.attach_money_rounded,
                                        color: accentColor,
                                        size: 20,
                                      ),
                                      filled: true,
                                      fillColor: isDark
                                          ? Colors.white.withValues(alpha: 0.05)
                                          : const Color(0xFFF8FAFC),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: isDark
                                              ? Colors.white.withValues(alpha: 0.1)
                                              : const Color(0xFFCBD5E1),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: isDark
                                              ? Colors.white.withValues(alpha: 0.1)
                                              : const Color(0xFFCBD5E1),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: accentColor, width: 1.5),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'Required';
                                      }
                                      final num = double.tryParse(val.trim());
                                      if (num == null || num <= 0) {
                                        return 'Enter > 0';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Currency',
                                    style: TextStyle(
                                      color: isDark ? Colors.white70 : Colors.black87,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    height: 48,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.05)
                                          : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.1)
                                            : const Color(0xFFCBD5E1),
                                      ),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _currency,
                                        isExpanded: true,
                                        dropdownColor:
                                            isDark ? const Color(0xFF1E293B) : Colors.white,
                                        items: const [
                                          DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                                          DropdownMenuItem(value: 'IQD', child: Text('IQD')),
                                        ],
                                        onChanged: (curr) {
                                          if (curr != null) {
                                            setState(() => _currency = curr);
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Date Selector
                        Text(
                          'Effective Date',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 18,
                                  color: accentColor,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  DateFormat('MMMM d, yyyy').format(_selectedDate),
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black87,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.edit_calendar_rounded,
                                  size: 16,
                                  color: isDark ? Colors.white54 : Colors.black45,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Description / Notes
                        Text(
                          'Notes / Description (Optional)',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _reasonController,
                          maxLines: 2,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText: isAddition
                                ? 'e.g. Q3 Sales performance bonus, outstanding achievement'
                                : 'e.g. Monthly loan repayment installment 2/6, damaged office chair',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontSize: 12.5,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : const Color(0xFFCBD5E1),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : const Color(0xFFCBD5E1),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: accentColor, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Action Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.black54,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _isSaving ? null : _submit,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(
                                      isAddition
                                          ? Icons.add_circle_rounded
                                          : Icons.remove_circle_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                              label: Text(
                                isAddition ? 'Save Addition' : 'Save Deduction',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                                shadowColor: accentColor.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Bonus':
        return Icons.star_rounded;
      case 'Commission / Incentive':
        return Icons.paid_rounded;
      case 'Overtime Adjustment':
        return Icons.more_time_rounded;
      case 'Special Allowance':
      case 'Housing Allowance':
      case 'Food Allowance':
        return Icons.card_giftcard_rounded;
      case 'Loan Repayment':
        return Icons.account_balance_rounded;
      case 'Fine / Penalty':
        return Icons.gavel_rounded;
      case 'Salary Advance':
        return Icons.price_change_rounded;
      case 'Equipment / Damage':
        return Icons.handyman_rounded;
      case 'Absence / Deficit Adjustment':
        return Icons.event_busy_rounded;
      case 'Insurance / Tax':
        return Icons.shield_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }
}

/// Modal dialog to view and manage existing payroll adjustments for a month
Future<void> showManageAdjustmentsDialog({
  required BuildContext context,
  required DateTime targetMonth,
  CompanyEmployee? filterEmployee,
}) async {
  final provider = Provider.of<AttendanceProvider>(context, listen: false);
  final currentUser = provider.currentEmployee;
  final isAllowed = currentUser != null && (
    currentUser.role == 'hr' ||
    currentUser.role == 'admin' ||
    currentUser.email == 'admin@company.com'
  );
  if (!isAllowed) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Access denied. Only HR Managers and Super Admins can manage payroll adjustments.'),
      ),
    );
    return;
  }

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Manage Adjustments',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (ctx, anim1, anim2) {
      return _ManageAdjustmentsDialogContent(
        targetMonth: targetMonth,
        filterEmployee: filterEmployee,
      );
    },
    transitionBuilder: (ctx, anim, secondAnim, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1.0).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

class _ManageAdjustmentsDialogContent extends StatelessWidget {
  final DateTime targetMonth;
  final CompanyEmployee? filterEmployee;

  const _ManageAdjustmentsDialogContent({
    required this.targetMonth,
    this.filterEmployee,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = Provider.of<AttendanceProvider>(context);
    final targetMonthStr = DateFormat('yyyy-MM').format(targetMonth);

    final monthAdjustments = provider.payrollAdjustments.where((adj) {
      final matchesMonth = adj.month == targetMonthStr ||
          (adj.date.length >= 7 && adj.date.substring(0, 7) == targetMonthStr);
      if (!matchesMonth) return false;
      if (filterEmployee != null) {
        return adj.employeeId.trim().toLowerCase() == filterEmployee!.id.trim().toLowerCase();
      }
      return true;
    }).toList();

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 620, maxHeight: 600),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: isDark ? const Color(0xFF1A1F2C) : Colors.white,
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 36,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 22, 20, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2E65FF), Color(0xFF8236FE)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Monthly Adjustments (${DateFormat('MMMM yyyy').format(targetMonth)})',
                                style: TextStyle(
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                filterEmployee != null
                                    ? 'Showing adjustments for ${filterEmployee!.name}'
                                    : '${monthAdjustments.length} records found',
                                style: TextStyle(
                                  color: isDark ? Colors.white60 : Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(
                            Icons.close_rounded,
                            color: isDark ? Colors.white60 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // List of adjustments
                  Expanded(
                    child: monthAdjustments.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 48,
                                  color: (isDark ? Colors.white30 : Colors.black26),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'No Adjustments for This Month',
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : Colors.black87,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Add bonuses, loans, fines, or other additions/deductions.',
                                  style: TextStyle(
                                    color: isDark ? Colors.white38 : Colors.black38,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            itemCount: monthAdjustments.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final adj = monthAdjustments[index];
                              final isAdd = adj.type == 'addition';
                              final color = isAdd
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444);
                              final emp = provider.employees.firstWhere(
                                (e) =>
                                    e.id == adj.employeeId ||
                                    e.name.toLowerCase() == adj.employeeId.toLowerCase(),
                                orElse: () => CompanyEmployee(
                                  id: adj.employeeId,
                                  name: adj.employeeId,
                                  email: '',
                                  position: 'Employee',
                                ),
                              );

                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.04)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: color.withValues(alpha: 0.3),
                                    width: 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        isAdd
                                            ? Icons.add_circle_outline_rounded
                                            : Icons.remove_circle_outline_rounded,
                                        color: color,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                emp.name,
                                                style: TextStyle(
                                                  color: isDark ? Colors.white : Colors.black87,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13.5,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: color.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  adj.category,
                                                  style: TextStyle(
                                                    color: color,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (adj.reason.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              adj.reason,
                                              style: TextStyle(
                                                color: isDark ? Colors.white60 : Colors.black54,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 3),
                                          Text(
                                            'Date: ${adj.date}',
                                            style: TextStyle(
                                              color: isDark ? Colors.white38 : Colors.black38,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${isAdd ? '+' : '-'}${adj.currency == 'USD' ? '\$${adj.amount.toStringAsFixed(2)}' : '${adj.amount.toStringAsFixed(0)} ${adj.currency}'}',
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.redAccent,
                                        size: 20,
                                      ),
                                      onPressed: () async {
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (c) => AlertDialog(
                                            title: const Text('Delete Adjustment?'),
                                            content: Text(
                                              'Are you sure you want to remove this ${adj.type} (${adj.category}) of ${adj.amount} for ${emp.name}?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(c).pop(false),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.of(c).pop(true),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                ),
                                                child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirmed == true) {
                                          await provider.deletePayrollAdjustment(adj.id);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  // Bottom Action bar
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'Close',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            showPayrollAdjustmentDialog(
                              context: context,
                              employee: filterEmployee,
                              initialMonth: targetMonth,
                            );
                          },
                          icon: const Icon(Icons.add, size: 18, color: Colors.white),
                          label: const Text('Add Adjustment', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E65FF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
