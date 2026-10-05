import 'dart:math' as math;

import '../models/cemetery_models.dart';

class OccupancyEstimate {
  final DateTime date;
  final int projectedOccupied;
  final double occupancy;

  const OccupancyEstimate(this.date, this.projectedOccupied, this.occupancy);
}

class DemandForecast {
  final int observedBurials;
  final int occupiedNow;
  final int capacity;
  final double monthlyBurials;
  final List<OccupancyEstimate> yearly;

  const DemandForecast({
    required this.observedBurials,
    required this.occupiedNow,
    required this.capacity,
    required this.monthlyBurials,
    required this.yearly,
  });

  OccupancyEstimate? get nearCapacity {
    for (final estimate in yearly) {
      if (estimate.occupancy >= 0.9) return estimate;
    }
    return null;
  }
}

/// A restrained linear trend of monthly burials in the last 24 months.
/// Requires 12 dated burials across at least six months. The extrapolated
/// monthly rate is capped at twice the observed average to avoid runaway
/// estimates from small data sets.
DemandForecast? forecastDemand(List<Grave> graves, {DateTime? asOf}) {
  final today = asOf ?? DateTime.now();
  if (graves.isEmpty) return null;
  final currentMonth = DateTime(today.year, today.month);
  final firstMonth = DateTime(currentMonth.year, currentMonth.month - 23);
  final monthly = List<int>.filled(24, 0);
  for (final grave in graves) {
    final date = grave.buriedAt;
    if (grave.status != 'occupied' ||
        date == null ||
        date.isAfter(today) ||
        date.isBefore(firstMonth)) {
      continue;
    }
    final monthIndex =
        (date.year - firstMonth.year) * 12 + date.month - firstMonth.month;
    if (monthIndex >= 0 && monthIndex < monthly.length) {
      monthly[monthIndex]++;
    }
  }
  final observed = monthly.fold<int>(0, (sum, count) => sum + count);
  if (observed < 12 || monthly.where((count) => count > 0).length < 6) {
    return null;
  }

  final mean = observed / monthly.length;
  const meanX = 11.5;
  var covariance = 0.0;
  var variance = 0.0;
  for (var index = 0; index < monthly.length; index++) {
    covariance += (index - meanX) * (monthly[index] - mean);
    variance += math.pow(index - meanX, 2).toDouble();
  }
  final slope = variance == 0 ? 0.0 : covariance / variance * 0.25;
  final occupied = graves.where((grave) => grave.status == 'occupied').length;
  var projected = occupied.toDouble();
  final estimates = <OccupancyEstimate>[];
  for (var month = 1; month <= 60; month++) {
    final x = 23 + month;
    final rate = (mean + slope * (x - meanX)).clamp(
      0.0,
      math.max(1.0, mean * 2),
    );
    projected = math.min(graves.length.toDouble(), projected + rate);
    if (month % 12 == 0) {
      final date = DateTime(currentMonth.year, currentMonth.month + month);
      estimates.add(
        OccupancyEstimate(date, projected.round(), projected / graves.length),
      );
    }
  }
  final nextMonthRate = (mean + slope * (24 - meanX)).clamp(
    0.0,
    math.max(1.0, mean * 2),
  );
  return DemandForecast(
    observedBurials: observed,
    occupiedNow: occupied,
    capacity: graves.length,
    monthlyBurials: nextMonthRate.toDouble(),
    yearly: estimates,
  );
}
