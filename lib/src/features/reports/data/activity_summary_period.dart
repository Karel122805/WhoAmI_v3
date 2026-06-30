enum ActivitySummaryPeriod {
  week,
  fifteenDays,
  month,
}

extension ActivitySummaryPeriodX on ActivitySummaryPeriod {
  String get label {
    switch (this) {
      case ActivitySummaryPeriod.week:
        return 'Última semana';
      case ActivitySummaryPeriod.fifteenDays:
        return 'Últimos 15 días';
      case ActivitySummaryPeriod.month:
        return 'Último mes';
    }
  }

  String get shortLabel {
    switch (this) {
      case ActivitySummaryPeriod.week:
        return 'Semana';
      case ActivitySummaryPeriod.fifteenDays:
        return '15 días';
      case ActivitySummaryPeriod.month:
        return 'Mes';
    }
  }

  int get days {
    switch (this) {
      case ActivitySummaryPeriod.week:
        return 7;
      case ActivitySummaryPeriod.fifteenDays:
        return 15;
      case ActivitySummaryPeriod.month:
        return 30;
    }
  }

  DateTime get startDate {
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days));
  }

  DateTime get endDate {
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
      23,
      59,
      59,
    );
  }
}