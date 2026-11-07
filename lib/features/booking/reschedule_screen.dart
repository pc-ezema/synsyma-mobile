import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_error.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/sub_page.dart';
import 'booking_models.dart';
import 'booking_repository.dart';
import 'booking_widgets.dart';
import 'confirm_sheet.dart';

/// Pick a new date and time. Opened from the booking screen; pops true when the booking was moved.
class RescheduleScreen extends ConsumerStatefulWidget {
  const RescheduleScreen({super.key, required this.booking, required this.note});
  final Booking booking;
  final String note; // e.g. "You can reschedule once for free."

  @override
  ConsumerState<RescheduleScreen> createState() => _RescheduleScreenState();
}

class _RescheduleScreenState extends ConsumerState<RescheduleScreen> {
  // Keep these the same as config/booking.php on the API.
  static const _minNoticeHours = 24;
  static const _maxDaysAhead = 90;
  static const _firstHour = 8;
  static const _lastHour = 18;

  DateTime? _date;
  DateTime? _slot;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _date = _firstAvailableDay();
  }

  DateTime get _earliest => DateTime.now().add(const Duration(hours: _minNoticeHours));

  List<DateTime> _slotsFor(DateTime day) {
    final out = <DateTime>[];
    for (var h = _firstHour; h <= _lastHour; h++) {
      for (final m in const [0, 30]) {
        if (h == _lastHour && m > 0) continue;
        final t = DateTime(day.year, day.month, day.day, h, m);
        if (!t.isBefore(_earliest) && t != widget.booking.startsAt) out.add(t);
      }
    }
    return out;
  }

  DateTime? _firstAvailableDay() {
    final start = _earliest;
    for (var i = 0; i <= _maxDaysAhead; i++) {
      final d = DateTime(start.year, start.month, start.day).add(Duration(days: i));
      if (_slotsFor(d).isNotEmpty) return d;
    }
    return null;
  }

  Future<void> _pickDate() async {
    final first = _firstAvailableDay();
    if (first == null) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? first,
      firstDate: first,
      lastDate: DateTime.now().add(const Duration(days: _maxDaysAhead)),
    );
    if (picked == null) return;
    setState(() {
      _date = picked;
      _slot = null;
    });
  }

  Future<void> _confirm() async {
    final slot = _slot;
    if (slot == null || _busy) return;
    final yes = await showConfirmSheet(
      context,
      title: 'Move your booking?',
      message: 'New time: ${formatDay(slot)} at ${formatTime(slot)}.${widget.booking.contractorName != null ? ' We will find a contractor for the new time.' : ''}',
      yesLabel: 'Yes, move it',
      noLabel: 'No, cancel',
    );
    if (!yes || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(bookingRepositoryProvider).reschedule(widget.booking.id, slot);
      if (!mounted) return;
      showToast(context, 'Your booking was rescheduled.');
      Navigator.of(context).pop(true);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final slots = _date == null ? const <DateTime>[] : _slotsFor(_date!);

    return SubPageScaffold(
      title: 'Reschedule',
      children: [
        GlassCard(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const IconTile(Icons.event_outlined),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black)),
                const SizedBox(height: 3),
                Text('Now: ${formatDay(b.startsAt)} at ${formatTime(b.startsAt)}', style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280))),
              ]),
            ),
          ]),
        ),
        const SectionLabel('New date and time'),
        if (_date == null)
          const GlassCard(child: Padding(padding: EdgeInsets.all(14), child: Text('No times are available right now.', style: TextStyle(color: Color(0xFF6B7280)))))
        else
          GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(children: [
                    const IconTile(Icons.calendar_today_outlined),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(formatDay(_date!), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black)),
                        const SizedBox(height: 2),
                        const Text('Tap to change the date', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                      ]),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFF6B7280)),
                  ]),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE3E6EE)),
              const SizedBox(height: 14),
              if (slots.isEmpty)
                const Padding(padding: EdgeInsets.only(bottom: 14), child: Text('No start times are left on this day. Pick another date.', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))))
              else
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final t in slots)
                    ChoiceChip(
                      label: Text(formatTime(t)),
                      selected: _slot == t,
                      selectedColor: AppColors.blueDark,
                      backgroundColor: Colors.white,
                      side: BorderSide(color: _slot == t ? AppColors.blueDark : AppColors.fieldBorder),
                      labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _slot == t ? Colors.white : AppColors.navy),
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _slot = t),
                    ),
                ]),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('Start times run from 8:00 AM to 6:00 PM. ${widget.note}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ),
            ]),
          ),
        if (_error != null)
          Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13))),
        const SizedBox(height: 22),
        PrimaryButton(label: 'Confirm new time', busy: _busy, onPressed: _slot == null ? null : _confirm),
      ],
    );
  }
}