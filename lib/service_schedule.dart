enum ScheduleType { asap, today, tomorrow, thisWeek, specificDate }

enum SchedulePeriod { morning, afternoon, evening, flexible, custom }

enum UrgencyLevel { immediate, next2Hours, today, normal }

enum ReceiveNow { yes, needToCoordinate, unknown }

class ScheduleDay {
  ScheduleDay({
    required this.date,
    this.period = SchedulePeriod.flexible,
    this.startMinutes,
    this.endMinutes,
  });

  DateTime date;
  SchedulePeriod period;
  int? startMinutes;
  int? endMinutes;

  Map<String, dynamic> toJson() => {
        'date': DateTime(date.year, date.month, date.day).toIso8601String(),
        'period': period.name,
        'startMinutes': startMinutes,
        'endMinutes': endMinutes,
      };

  factory ScheduleDay.fromJson(Map<String, dynamic> json) {
    return ScheduleDay(
      date: DateTime.parse(json['date'] as String),
      period: SchedulePeriod.values.firstWhere(
        (e) => e.name == json['period'],
        orElse: () => SchedulePeriod.flexible,
      ),
      startMinutes: json['startMinutes'] as int?,
      endMinutes: json['endMinutes'] as int?,
    );
  }
}

class ServiceSchedule {
  ServiceSchedule({
    this.type,
    this.urgency = UrgencyLevel.normal,
    this.receiveNow = ReceiveNow.unknown,
    this.startDate,
    this.endDate,
    this.startMinutes,
    this.endMinutes,
    this.flexibleTime = false,
    this.period = SchedulePeriod.flexible,
    List<ScheduleDay>? days,
    String? timezone,
  }) : days = days ?? <ScheduleDay>[],
       timezone = timezone ?? DateTime.now().timeZoneName;

  ScheduleType? type;
  UrgencyLevel urgency;
  ReceiveNow receiveNow;
  DateTime? startDate;
  DateTime? endDate;
  int? startMinutes;
  int? endMinutes;
  bool flexibleTime;
  SchedulePeriod period;
  final List<ScheduleDay> days;
  String timezone;

  void applyJson(Map<String, dynamic> json) {
    final loaded = ServiceSchedule.fromJson(json);
    type = loaded.type;
    urgency = loaded.urgency;
    receiveNow = loaded.receiveNow;
    startDate = loaded.startDate;
    endDate = loaded.endDate;
    startMinutes = loaded.startMinutes;
    endMinutes = loaded.endMinutes;
    flexibleTime = loaded.flexibleTime;
    period = loaded.period;
    timezone = loaded.timezone;
    days
      ..clear()
      ..addAll(loaded.days);
  }

  bool get isComplete {
    switch (type) {
      case null:
        return false;
      case ScheduleType.asap:
        return urgency != UrgencyLevel.normal &&
            receiveNow != ReceiveNow.unknown;
      case ScheduleType.today:
        if (period == SchedulePeriod.custom) {
          return startMinutes != null &&
              endMinutes != null &&
              endMinutes! > startMinutes!;
        }
        return true;
      case ScheduleType.tomorrow:
        return true;
      case ScheduleType.thisWeek:
        return days.isNotEmpty;
      case ScheduleType.specificDate:
        return startDate != null && (flexibleTime || startMinutes != null);
    }
  }

  String get errorText {
    if (type == null) return 'Elige cuándo necesitas el servicio.';
    if (type == ScheduleType.asap && receiveNow == ReceiveNow.unknown) {
      return 'Dinos si puedes recibir al profesional ahora.';
    }
    if (type == ScheduleType.thisWeek && days.isEmpty) {
      return 'Elige al menos un día.';
    }
    if (type == ScheduleType.today &&
        period == SchedulePeriod.custom &&
        (startMinutes == null ||
            endMinutes == null ||
            endMinutes! <= startMinutes!)) {
      return 'La hora final debe ser después de la inicial.';
    }
    if (type == ScheduleType.specificDate && startDate == null) {
      return 'Elige una fecha.';
    }
    return '';
  }

  String get summary {
    switch (type) {
      case null:
        return '';
      case ScheduleType.asap:
        return '🔥 Lo antes posible — ${_urgencyLabel()}';
      case ScheduleType.today:
        if (period == SchedulePeriod.custom && startMinutes != null && endMinutes != null) {
          return 'Hoy — Entre ${_hhmm(startMinutes!)} y ${_hhmm(endMinutes!)}';
        }
        return 'Hoy — ${_periodLabel(period)}';
      case ScheduleType.tomorrow:
        return 'Mañana — ${_periodLabel(period)}';
      case ScheduleType.thisWeek:
        if (days.isEmpty) return 'Esta semana';
        final ordered = [...days]..sort((a, b) => a.date.compareTo(b.date));
        final names = ordered.map((d) => _weekday(d.date)).toList();
        final list = names.length == 1
            ? names.first
            : '${names.sublist(0, names.length - 1).join(', ')} o ${names.last}';
        return '$list — ${_periodLabel(period)}';
      case ScheduleType.specificDate:
        final date = startDate!;
        final when = flexibleTime
            ? 'Horario flexible'
            : (startMinutes == null ? '' : _hhmm(startMinutes!));
        return '${_longDate(date)}${when.isEmpty ? '' : ' — $when'}';
    }
  }

  String _urgencyLabel() {
    switch (urgency) {
      case UrgencyLevel.immediate:
        return 'Ahora mismo';
      case UrgencyLevel.next2Hours:
        return 'En las próximas 2 horas';
      case UrgencyLevel.today:
        return 'Durante el día';
      case UrgencyLevel.normal:
        return '';
    }
  }

  static String _periodLabel(SchedulePeriod period) {
    switch (period) {
      case SchedulePeriod.morning:
        return 'Por la mañana';
      case SchedulePeriod.afternoon:
        return 'Por la tarde';
      case SchedulePeriod.evening:
        return 'Por la noche';
      case SchedulePeriod.flexible:
        return 'Horario flexible';
      case SchedulePeriod.custom:
        return 'Horario personalizado';
    }
  }

  static const _days = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
  static const _daysLong = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];
  static const _months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  static String _weekday(DateTime date) => _days[date.weekday - 1];

  static String weekdayShort(DateTime date) {
    final name = _days[date.weekday - 1];
    return '${name[0].toUpperCase()}${name.substring(1)} ${date.day}';
  }

  static String _longDate(DateTime date) {
    final w = _daysLong[date.weekday - 1];
    return '${w[0].toUpperCase()}${w.substring(1)}, ${date.day} de ${_months[date.month - 1]}';
  }

  static String _hhmm(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  Map<String, dynamic> toJson() => {
        'type': type?.name,
        'urgency': urgency.name,
        'receiveNow': receiveNow.name,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'startMinutes': startMinutes,
        'endMinutes': endMinutes,
        'flexibleTime': flexibleTime,
        'period': period.name,
        'days': days.map((d) => d.toJson()).toList(),
        'timezone': timezone,
        'summary': summary,
      };

  factory ServiceSchedule.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String?;
    return ServiceSchedule(
      type: typeName == null
          ? null
          : ScheduleType.values.firstWhere(
              (e) => e.name == typeName,
              orElse: () => ScheduleType.today,
            ),
      urgency: UrgencyLevel.values.firstWhere(
        (e) => e.name == json['urgency'],
        orElse: () => UrgencyLevel.normal,
      ),
      receiveNow: ReceiveNow.values.firstWhere(
        (e) => e.name == json['receiveNow'],
        orElse: () => ReceiveNow.unknown,
      ),
      startDate: json['startDate'] == null
          ? null
          : DateTime.tryParse(json['startDate'] as String),
      endDate: json['endDate'] == null
          ? null
          : DateTime.tryParse(json['endDate'] as String),
      startMinutes: json['startMinutes'] as int?,
      endMinutes: json['endMinutes'] as int?,
      flexibleTime: json['flexibleTime'] as bool? ?? false,
      period: SchedulePeriod.values.firstWhere(
        (e) => e.name == json['period'],
        orElse: () => SchedulePeriod.flexible,
      ),
      days: [
        for (final item in (json['days'] as List? ?? [])
            .cast<Map<String, dynamic>>())
          ScheduleDay.fromJson(item),
      ],
      timezone: json['timezone'] as String?,
    );
  }

  static ScheduleType? recommend({
    String? categoryId,
    String text = '',
    String specialty = '',
  }) {
    final t = '${text.toLowerCase()} ${specialty.toLowerCase()}';
    if (categoryId == 'belleza' || t.contains('corte') || t.contains('uñas')) {
      return ScheduleType.specificDate;
    }
    if (categoryId == 'pintura') return ScheduleType.thisWeek;
    if (categoryId == 'plomeria' ||
        t.contains('fuga') ||
        t.contains('agua') ||
        t.contains('humedad') ||
        t.contains('dejó de funcionar') ||
        t.contains('dejo de funcionar')) {
      return ScheduleType.asap;
    }
    return null;
  }
}
