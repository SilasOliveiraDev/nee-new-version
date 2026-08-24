import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../service_schedule.dart';
import '../theme.dart';

class SchedulePicker extends StatefulWidget {
  const SchedulePicker({
    super.key,
    required this.schedule,
    required this.onChanged,
    this.recommended,
  });

  final ServiceSchedule schedule;
  final ValueChanged<ServiceSchedule> onChanged;
  final ScheduleType? recommended;

  @override
  State<SchedulePicker> createState() => _SchedulePickerState();
}

class _SchedulePickerState extends State<SchedulePicker> {
  ServiceSchedule get schedule => widget.schedule;

  void _emit() {
    widget.onChanged(schedule);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('nee_schedule_draft', jsonEncode(schedule.toJson()));
    });
  }

  void _selectType(ScheduleType type) {
    setState(() {
      schedule.type = type;
      if (type == ScheduleType.asap) {
        schedule.urgency = UrgencyLevel.immediate;
      } else {
        schedule.urgency = UrgencyLevel.normal;
      }
      if (type == ScheduleType.today || type == ScheduleType.tomorrow) {
        final now = DateTime.now();
        final day = type == ScheduleType.today
            ? now
            : now.add(const Duration(days: 1));
        schedule.startDate = DateTime(day.year, day.month, day.day);
        schedule.endDate = schedule.startDate;
      }
      if (type == ScheduleType.thisWeek && schedule.days.isEmpty) {
        // keep empty until user taps days
      }
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _typeCard(
          ScheduleType.asap,
          '🔥',
          'Lo antes posible',
          child: schedule.type == ScheduleType.asap ? _asap() : null,
        ),
        _typeCard(
          ScheduleType.today,
          '☀️',
          'Hoy',
          child: schedule.type == ScheduleType.today ? _today() : null,
        ),
        _typeCard(
          ScheduleType.tomorrow,
          '🌤',
          'Mañana',
          child: schedule.type == ScheduleType.tomorrow ? _periodOnly() : null,
        ),
        _typeCard(
          ScheduleType.thisWeek,
          '📆',
          'Esta semana',
          child: schedule.type == ScheduleType.thisWeek ? _week() : null,
        ),
        _typeCard(
          ScheduleType.specificDate,
          '🗓',
          'Elegir fecha',
          child: schedule.type == ScheduleType.specificDate ? _calendar() : null,
        ),
        if (schedule.errorText.isNotEmpty && schedule.type != null) ...[
          const SizedBox(height: 8),
          Text(
            schedule.errorText,
            style: const TextStyle(color: NeeColors.waiting, fontWeight: FontWeight.w700),
          ),
        ],
      ],
    );
  }

  Widget _typeCard(
    ScheduleType type,
    String emoji,
    String label, {
    Widget? child,
  }) {
    final selected = schedule.type == type;
    final recommended = widget.recommended == type;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected ? NeeColors.vest : NeeColors.chalk,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: NeeColors.soot,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _selectType(type),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (recommended)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: NeeColors.soot,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Recomendado',
                          style: TextStyle(
                            color: NeeColors.vest,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (child != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: child,
              ),
          ],
        ),
      ),
    );
  }

  Widget _chipRow(List<(String, bool, VoidCallback)> items) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          ChoiceChip(
            label: Text(item.$1),
            selected: item.$2,
            selectedColor: NeeColors.vest,
            labelStyle: TextStyle(
              color: NeeColors.soot,
              fontWeight: FontWeight.w700,
            ),
            onSelected: (_) => item.$3(),
          ),
      ],
    );
  }

  Widget _asap() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '¿Qué tan urgente es?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        _chipRow([
          (
            'Ahora mismo',
            schedule.urgency == UrgencyLevel.immediate,
            () {
              setState(() => schedule.urgency = UrgencyLevel.immediate);
              _emit();
            },
          ),
          (
            'En las próximas 2 horas',
            schedule.urgency == UrgencyLevel.next2Hours,
            () {
              setState(() => schedule.urgency = UrgencyLevel.next2Hours);
              _emit();
            },
          ),
          (
            'Durante el día',
            schedule.urgency == UrgencyLevel.today,
            () {
              setState(() => schedule.urgency = UrgencyLevel.today);
              _emit();
            },
          ),
        ]),
        const SizedBox(height: 14),
        const Text(
          '¿Puedes recibir al profesional inmediatamente?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        _chipRow([
          (
            'Sí',
            schedule.receiveNow == ReceiveNow.yes,
            () {
              setState(() => schedule.receiveNow = ReceiveNow.yes);
              _emit();
            },
          ),
          (
            'Necesito coordinar',
            schedule.receiveNow == ReceiveNow.needToCoordinate,
            () {
              setState(() => schedule.receiveNow = ReceiveNow.needToCoordinate);
              _emit();
            },
          ),
        ]),
      ],
    );
  }

  void _setPeriod(SchedulePeriod period) {
    setState(() {
      schedule.period = period;
      for (final day in schedule.days) {
        day.period = period;
      }
    });
    _emit();
  }

  Widget _periodChips({bool includeAny = false, bool includeFlexible = false}) {
    return _chipRow([
      (
        '🌅 Mañana',
        schedule.period == SchedulePeriod.morning,
        () => _setPeriod(SchedulePeriod.morning),
      ),
      (
        '☀️ Tarde',
        schedule.period == SchedulePeriod.afternoon,
        () => _setPeriod(SchedulePeriod.afternoon),
      ),
      (
        '🌙 Noche',
        schedule.period == SchedulePeriod.evening,
        () => _setPeriod(SchedulePeriod.evening),
      ),
      if (includeAny)
        (
          '🕐 Cualquier horario',
          schedule.period == SchedulePeriod.flexible,
          () => _setPeriod(SchedulePeriod.flexible),
        ),
      if (includeFlexible)
        (
          '✨ Soy flexible',
          schedule.period == SchedulePeriod.flexible,
          () => _setPeriod(SchedulePeriod.flexible),
        ),
    ]);
  }

  Widget _today() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '¿En qué horario te viene mejor?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        _periodChips(includeAny: true),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            setState(() => schedule.period = SchedulePeriod.custom);
            _emit();
          },
          child: const Text('Definir una ventana (desde / hasta)'),
        ),
        if (schedule.period == SchedulePeriod.custom) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickMinutes(true),
                  child: Text(
                    schedule.startMinutes == null
                        ? 'Desde'
                        : 'Desde ${_fmt(schedule.startMinutes!)}',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickMinutes(false),
                  child: Text(
                    schedule.endMinutes == null
                        ? 'Hasta'
                        : 'Hasta ${_fmt(schedule.endMinutes!)}',
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _periodOnly() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '¿Qué horario prefieres?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        _periodChips(includeFlexible: true),
      ],
    );
  }

  Widget _week() {
    final now = DateTime.now();
    final options = [
      for (var i = 0; i < 5; i++)
        DateTime(now.year, now.month, now.day).add(Duration(days: i)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '¿Qué días te vienen mejor?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final day in options)
              FilterChip(
                label: Text(ServiceSchedule.weekdayShort(day)),
                selected: schedule.days.any((d) => _sameDay(d.date, day)),
                selectedColor: NeeColors.vest,
                labelStyle: const TextStyle(
                  color: NeeColors.soot,
                  fontWeight: FontWeight.w700,
                ),
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      schedule.days.add(ScheduleDay(date: day, period: schedule.period));
                    } else {
                      schedule.days.removeWhere((d) => _sameDay(d.date, day));
                    }
                  });
                  _emit();
                },
              ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          '¿En qué horario?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        _periodChips(includeFlexible: true),
      ],
    );
  }

  Widget _calendar() {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CalendarDatePicker(
          initialDate: schedule.startDate ?? first,
          firstDate: first,
          lastDate: first.add(const Duration(days: 90)),
          onDateChanged: (date) {
            setState(() => schedule.startDate = date);
            _emit();
          },
        ),
        const Text(
          '¿A qué hora?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var h = 8; h <= 20; h++)
              ChoiceChip(
                label: Text('${h.toString().padLeft(2, '0')}:00'),
                selected: !schedule.flexibleTime && schedule.startMinutes == h * 60,
                onSelected: (_) {
                  setState(() {
                    schedule.flexibleTime = false;
                    schedule.startMinutes = h * 60;
                  });
                  _emit();
                },
              ),
            FilterChip(
              label: const Text('Tengo flexibilidad con el horario'),
              selected: schedule.flexibleTime,
              onSelected: (value) {
                setState(() {
                  schedule.flexibleTime = value;
                  if (value) schedule.startMinutes = null;
                });
                _emit();
              },
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickMinutes(bool start) async {
    final initial = TimeOfDay(
      hour: ((start ? schedule.startMinutes : schedule.endMinutes) ?? 14) ~/ 60,
      minute: 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final minutes = picked.hour * 60 + picked.minute;
    setState(() {
      if (start) {
        schedule.startMinutes = minutes;
      } else {
        schedule.endMinutes = minutes;
      }
    });
    _emit();
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _fmt(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }
}
