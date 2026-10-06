// trenda_shared/lib/widgets/date_picker.dart
// ============================================================================
// DATE PICKER WIDGETS - Date and time selection components
// ============================================================================

import 'package:flutter/material.dart';

// ============================================================================
// DATE PICKER FIELD
// Text field that opens date picker on tap
// ============================================================================

class DatePickerField extends StatelessWidget {
  final DateTime? value;
  final void Function(DateTime) onChanged;
  final String label;
  final String? hint;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool enabled;
  final String? errorText;
  final TrendaDateFormat dateFormat;

  const DatePickerField({
    super.key,
    this.value,
    required this.onChanged,
    this.label = 'Date',
    this.hint,
    this.firstDate,
    this.lastDate,
    this.enabled = true,
    this.errorText,
    this.dateFormat = TrendaDateFormat.medium,
  });

  String _formatDate(DateTime date) {
    switch (dateFormat) {
      case TrendaDateFormat.short:
        return '${date.month}/${date.day}/${date.year}';
      case TrendaDateFormat.medium:
        return '${_monthName(date.month)} ${date.day}, ${date.year}';
      case TrendaDateFormat.long:
        return '${_dayName(date.weekday)}, ${_monthName(date.month)} ${date.day}, ${date.year}';
      case TrendaDateFormat.iso:
        return date.toIso8601String().split('T')[0];
    }
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  String _dayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? now,
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? DateTime(2100),
    );

    if (picked != null) {
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      readOnly: true,
      enabled: enabled,
      controller: TextEditingController(
        text: value != null ? _formatDate(value!) : '',
      ),
      onTap: enabled ? () => _pickDate(context) : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint ?? 'Select date',
        errorText: errorText,
        suffixIcon: const Icon(Icons.calendar_today),
      ),
    );
  }
}

enum TrendaDateFormat { short, medium, long, iso }

// ============================================================================
// TIME PICKER FIELD
// Text field that opens time picker on tap
// ============================================================================

class TimePickerField extends StatelessWidget {
  final TimeOfDay? value;
  final void Function(TimeOfDay) onChanged;
  final String label;
  final String? hint;
  final bool enabled;
  final String? errorText;
  final bool use24HourFormat;

  const TimePickerField({
    super.key,
    this.value,
    required this.onChanged,
    this.label = 'Time',
    this.hint,
    this.enabled = true,
    this.errorText,
    this.use24HourFormat = false,
  });

  String _formatTime(TimeOfDay time) {
    if (use24HourFormat) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: value ?? TimeOfDay.now(),
    );

    if (picked != null) {
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      readOnly: true,
      enabled: enabled,
      controller: TextEditingController(
        text: value != null ? _formatTime(value!) : '',
      ),
      onTap: enabled ? () => _pickTime(context) : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint ?? 'Select time',
        errorText: errorText,
        suffixIcon: const Icon(Icons.access_time),
      ),
    );
  }
}

// ============================================================================
// DATE RANGE PICKER FIELD
// For selecting start and end dates
// ============================================================================

class DateRangePickerField extends StatelessWidget {
  final DateTimeRange? value;
  final void Function(DateTimeRange) onChanged;
  final String label;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool enabled;

  const DateRangePickerField({
    super.key,
    this.value,
    required this.onChanged,
    this.label = 'Date Range',
    this.firstDate,
    this.lastDate,
    this.enabled = true,
  });

  String _formatRange(DateTimeRange range) {
    final start = '${range.start.month}/${range.start.day}/${range.start.year}';
    final end = '${range.end.month}/${range.end.day}/${range.end.year}';
    return '$start - $end';
  }

  Future<void> _pickRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? DateTime(2100),
      initialDateRange:
          value ??
          DateTimeRange(start: now, end: now.add(const Duration(days: 7))),
    );

    if (picked != null) {
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      readOnly: true,
      enabled: enabled,
      controller: TextEditingController(
        text: value != null ? _formatRange(value!) : '',
      ),
      onTap: enabled ? () => _pickRange(context) : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Select date range',
        suffixIcon: const Icon(Icons.date_range),
      ),
    );
  }
}

// ============================================================================
// DATE TIME PICKER FIELD
// Combined date and time picker
// ============================================================================

class DateTimePickerField extends StatelessWidget {
  final DateTime? value;
  final void Function(DateTime) onChanged;
  final String label;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool enabled;
  final String? errorText;

  const DateTimePickerField({
    super.key,
    this.value,
    required this.onChanged,
    this.label = 'Date & Time',
    this.firstDate,
    this.lastDate,
    this.enabled = true,
    this.errorText,
  });

  String _formatDateTime(DateTime dt) {
    final date = '${dt.month}/${dt.day}/${dt.year}';
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final time =
        '${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $period';
    return '$date $time';
  }

  Future<void> _pickDateTime(BuildContext context) async {
    final now = DateTime.now();

    // First pick date
    final date = await showDatePicker(
      context: context,
      initialDate: value ?? now,
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? DateTime(2100),
    );

    if (date == null || !context.mounted) return;

    // Then pick time
    final time = await showTimePicker(
      context: context,
      initialTime: value != null
          ? TimeOfDay.fromDateTime(value!)
          : TimeOfDay.now(),
    );

    if (time != null) {
      final combined = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      onChanged(combined);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      readOnly: true,
      enabled: enabled,
      controller: TextEditingController(
        text: value != null ? _formatDateTime(value!) : '',
      ),
      onTap: enabled ? () => _pickDateTime(context) : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Select date and time',
        errorText: errorText,
        suffixIcon: const Icon(Icons.event),
      ),
    );
  }
}
