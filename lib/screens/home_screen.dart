import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/drink_log.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';
import '../services/hydration_calculator.dart';
import '../services/notification_service.dart';
import '../services/preferences_service.dart';
import '../widgets/progress_ring.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  UserProfile? _profile;
  List<DrinkLog> _todayLogs = [];
  double _goalMl = 2000;
  bool _doneForToday = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final profile =
        await PreferencesService.loadProfile() ?? UserProfile.defaults;
    final logs = await DatabaseService.logsForDay(DateTime.now());
    final goal = HydrationCalculator.dailyGoalMl(profile);
    final done = await PreferencesService.isDoneForToday();

    if (!mounted) return;
    setState(() {
      _profile = profile;
      _goalMl = goal;
      _todayLogs = logs;
      _doneForToday = done;
    });
  }

  Future<void> _logDrink() async {
    final profile = _profile;
    if (profile == null) return;

    final id = await DatabaseService.logDrink(DrinkLog(
      timestamp: DateTime.now(),
      amountMl: profile.cupSizeMl,
    ));
    await NotificationService.scheduleTodayReminders(force: true);
    await _load();

    if (!mounted) return;
    final units = profile.unitSystem;
    final label = HydrationCalculator.formatMl(profile.cupSizeMl, units);

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    final controller = messenger.showSnackBar(
      SnackBar(
        content: Text('Logged $label'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await DatabaseService.deleteLog(id);
            await _load();
          },
        ),
      ),
    );
    Future.delayed(const Duration(seconds: 5), controller.close);
  }

  Future<void> _deleteLog(DrinkLog log) async {
    if (log.id == null) return;
    await DatabaseService.deleteLog(log.id!);
    await NotificationService.scheduleTodayReminders(force: true);
    await _load();
  }

  Future<void> _toggleDoneForToday() async {
    if (_doneForToday) {
      await PreferencesService.clearDoneForToday();
      await NotificationService.scheduleTodayReminders(force: true);
    } else {
      await PreferencesService.setDoneForToday();
      await NotificationService.cancelAllReminders();
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final units = profile?.unitSystem ?? UnitSystem.metric;
    final consumed =
        _todayLogs.fold<double>(0, (sum, l) => sum + l.amountMl);
    final progress =
        _goalMl > 0 ? (consumed / _goalMl).clamp(0.0, 1.0) : 0.0;
    final expectedProgress = profile != null
        ? HydrationCalculator.expectedProgressNow(profile)
        : null;
    final expectedMl =
        expectedProgress != null ? expectedProgress * _goalMl : null;
    final consumedLabel = HydrationCalculator.formatMl(consumed, units);
    final goalLabel = HydrationCalculator.formatMl(_goalMl, units);
    final cupLabel = profile != null
        ? HydrationCalculator.formatMl(profile.cupSizeMl, units)
        : '—';
    final cupSizeMl = profile?.cupSizeMl ?? 250;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hydrate Me'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'History',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const HistoryScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()));
              await _load();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Center(
                  child: ProgressRing(
                    progress: progress,
                    expectedProgress: expectedProgress,
                    label: consumedLabel,
                    sublabel: 'of $goalLabel',
                    size: 220,
                  ),
                ),
                const SizedBox(height: 12),
                if (expectedMl != null)
                  _PaceChip(
                    consumed: consumed,
                    expected: expectedMl,
                    cupSizeMl: cupSizeMl,
                    units: units,
                  ),
                const SizedBox(height: 32),
                _StatusCard(
                  consumed: consumed,
                  goal: _goalMl,
                  units: units,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _logDrink,
                  icon: const Icon(Icons.water_drop),
                  label: Text('Log $cupLabel'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _toggleDoneForToday,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: Text(
                    _doneForToday
                        ? 'Resume reminders'
                        : "I'm done for today",
                  ),
                ),
                if (_todayLogs.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  Text(
                    "Today's drinks",
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  _TodayLogList(
                    logs: _todayLogs,
                    units: units,
                    onDelete: _deleteLog,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayLogList extends StatelessWidget {
  final List<DrinkLog> logs;
  final UnitSystem units;
  final Future<void> Function(DrinkLog) onDelete;

  const _TodayLogList({
    required this.logs,
    required this.units,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: logs.reversed
            .toList()
            .asMap()
            .entries
            .map((e) {
              final log = e.value;
              final isLast = e.key == logs.length - 1;
              return Column(
                children: [
                  ListTile(
                    dense: true,
                    leading: Icon(Icons.water_drop,
                        color: Theme.of(context).colorScheme.primary,
                        size: 18),
                    title: Text(
                      HydrationCalculator.formatMl(log.amountMl, units),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    subtitle: Text(
                      DateFormat('h:mm a').format(log.timestamp),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      color: Theme.of(context).colorScheme.error,
                      tooltip: 'Remove',
                      onPressed: () => onDelete(log),
                    ),
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.5),
                    ),
                ],
              );
            })
            .toList(),
      ),
    );
  }
}

class _PaceChip extends StatelessWidget {
  final double consumed;
  final double expected;
  final double cupSizeMl;
  final UnitSystem units;

  const _PaceChip({
    required this.consumed,
    required this.expected,
    required this.cupSizeMl,
    required this.units,
  });

  @override
  Widget build(BuildContext context) {
    final diff = consumed - expected;
    final drinks = (diff.abs() / cupSizeMl);
    final drinksLabel = drinks < 1
        ? 'less than 1 drink'
        : '${drinks.round()} drink${drinks.round() == 1 ? '' : 's'}';

    final bool onTrack = diff >= -0.5 * cupSizeMl;
    final bool ahead = diff > 0.5 * cupSizeMl;

    final (Color bg, Color fg, IconData icon, String text) = ahead
        ? (
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.onPrimaryContainer,
            Icons.trending_up,
            '$drinksLabel ahead',
          )
        : onTrack
            ? (
                Theme.of(context).colorScheme.secondaryContainer,
                Theme.of(context).colorScheme.onSecondaryContainer,
                Icons.check_circle_outline,
                'On track',
              )
            : (
                Theme.of(context).colorScheme.errorContainer,
                Theme.of(context).colorScheme.onErrorContainer,
                Icons.trending_down,
                '$drinksLabel behind',
              );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(text,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: fg)),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final double consumed;
  final double goal;
  final UnitSystem units;

  const _StatusCard({
    required this.consumed,
    required this.goal,
    required this.units,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = (goal - consumed).clamp(0.0, double.infinity);
    final pct = goal > 0 ? ((consumed / goal) * 100).round() : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Stat(
              label: 'Consumed',
              value: HydrationCalculator.formatMl(consumed, units),
            ),
            _Stat(
              label: 'Remaining',
              value: HydrationCalculator.formatMl(remaining, units),
            ),
            _Stat(
              label: 'Progress',
              value: '$pct%',
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
      ],
    );
  }
}
