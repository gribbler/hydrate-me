import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';
import '../services/hydration_calculator.dart';
import '../services/preferences_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  Map<DateTime, double> _totals = {};
  double _goalMl = 2000;
  UnitSystem _units = UnitSystem.metric;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile =
        await PreferencesService.loadProfile() ?? UserProfile.defaults;
    final totals = await DatabaseService.dailyTotals(7);
    if (!mounted) return;
    setState(() {
      _totals = totals;
      _goalMl = HydrationCalculator.dailyGoalMl(profile);
      _units = profile.unitSystem;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Last 7 days')),
      body: _loaded ? _buildChart() : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildChart() {
    final now = DateTime.now();
    final days = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return DateTime(d.year, d.month, d.day);
    });

    final goalDisplay =
        HydrationCalculator.mlToDisplay(_goalMl, _units);

    final bars = days.asMap().entries.map((e) {
      final idx = e.key;
      final day = e.value;
      final ml = _totals[day] ?? 0;
      final display = HydrationCalculator.mlToDisplay(ml, _units);
      final isToday = idx == 6;
      return BarChartGroupData(
        x: idx,
        barRods: [
          BarChartRodData(
            toY: display,
            width: 24,
            borderRadius: BorderRadius.circular(6),
            color: isToday
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.primaryContainer,
          ),
        ],
      );
    }).toList();

    final maxY = (goalDisplay * 1.2).ceilToDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily goal: ${HydrationCalculator.formatMl(_goalMl, _units)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: BarChart(
              BarChartData(
                maxY: maxY,
                barGroups: bars,
                gridData: FlGridData(
                  drawHorizontalLine: true,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      getTitlesWidget: (value, _) => Text(
                        _units == UnitSystem.metric
                            ? '${(value / 1000).toStringAsFixed(1)}L'
                            : '${value.toStringAsFixed(0)}oz',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) {
                        final day = days[value.toInt()];
                        final label = DateFormat('E').format(day);
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(label, style: const TextStyle(fontSize: 11)),
                        );
                      },
                    ),
                  ),
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: goalDisplay,
                      color: Theme.of(context).colorScheme.error,
                      strokeWidth: 2,
                      dashArray: [6, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 10,
                        ),
                        labelResolver: (_) => 'Goal',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Legend(goalMl: _goalMl, totals: _totals, units: _units, days: days),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final double goalMl;
  final Map<DateTime, double> totals;
  final UnitSystem units;
  final List<DateTime> days;

  const _Legend({
    required this.goalMl,
    required this.totals,
    required this.units,
    required this.days,
  });

  @override
  Widget build(BuildContext context) {
    final hits = days.where((d) => (totals[d] ?? 0) >= goalMl).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _LegendStat(label: 'Goal days', value: '$hits / 7'),
            _LegendStat(
              label: 'Best day',
              value: () {
                if (totals.isEmpty) return '—';
                final best =
                    totals.values.reduce((a, b) => a > b ? a : b);
                return HydrationCalculator.formatMl(best, units);
              }(),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendStat extends StatelessWidget {
  final String label;
  final String value;

  const _LegendStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text(label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
      ],
    );
  }
}
