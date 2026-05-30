import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/hydration_calculator.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/preferences_service.dart';
import 'home_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late UserProfile _profile;
  bool _loaded = false;
  Timer? _ticker;
  DateTime _now = DateTime.now();
  double _consumedMl = 0;
  DateTime? _nextReminderAt;

  // Text controllers for numeric fields
  late TextEditingController _weightCtrl;
  late TextEditingController _heightCtrl;
  late TextEditingController _cupCtrl;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _cupCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final p = await PreferencesService.loadProfile() ?? UserProfile.defaults;
    final logs = await DatabaseService.logsForDay(DateTime.now());
    final consumed = logs.fold<double>(0, (s, l) => s + l.amountMl);

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    final nextAt = await PreferencesService.loadNextReminderAt();

    setState(() {
      _profile = p;
      _loaded = true;
      _consumedMl = consumed;
      _nextReminderAt = nextAt;
      _weightCtrl = TextEditingController(
          text: _displayWeight(p.weightKg, p.unitSystem));
      _heightCtrl = TextEditingController(
          text: _displayHeight(p.heightCm, p.unitSystem));
      _cupCtrl = TextEditingController(
          text: HydrationCalculator.mlToDisplay(p.cupSizeMl, p.unitSystem)
              .toStringAsFixed(0));
    });
  }

  String _displayWeight(double kg, UnitSystem u) => u == UnitSystem.metric
      ? kg.toStringAsFixed(1)
      : (kg * 2.20462).toStringAsFixed(1);

  String _displayHeight(double cm, UnitSystem u) => u == UnitSystem.metric
      ? cm.toStringAsFixed(0)
      : (cm / 2.54).toStringAsFixed(1);

  void _onUnitChange(UnitSystem? units) {
    if (units == null || units == _profile.unitSystem) return;
    setState(() {
      _profile = _profile.copyWith(unitSystem: units);
      _weightCtrl.text = _displayWeight(_profile.weightKg, units);
      _heightCtrl.text = _displayHeight(_profile.heightCm, units);
      _cupCtrl.text = HydrationCalculator.mlToDisplay(_profile.cupSizeMl, units)
          .toStringAsFixed(0);
    });
  }

  Future<void> _save() async {
    // Parse weight → kg
    final weightDisplay = double.tryParse(_weightCtrl.text) ?? 80;
    final weightKg = _profile.unitSystem == UnitSystem.metric
        ? weightDisplay
        : weightDisplay / 2.20462;

    // Parse height → cm
    final heightDisplay = double.tryParse(_heightCtrl.text) ?? 175;
    final heightCm = _profile.unitSystem == UnitSystem.metric
        ? heightDisplay
        : heightDisplay * 2.54;

    // Parse cup size → ml
    final cupDisplay = double.tryParse(_cupCtrl.text) ?? 250;
    final cupMl =
        HydrationCalculator.displayToMl(cupDisplay, _profile.unitSystem);

    final saved = _profile.copyWith(
      weightKg: weightKg,
      heightCm: heightCm,
      cupSizeMl: cupMl,
    );

    await PreferencesService.saveProfile(saved);
    await PreferencesService.markSetupDone();
    await NotificationService.cancelAllReminders();
    await NotificationService.scheduleTodayReminders(force: true);

    if (!mounted) return;
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  TimeOfDay _profileToTime(int hour, int minute) =>
      TimeOfDay(hour: hour, minute: minute);

  Future<void> _pickTime(bool isWake) async {
    final initial = isWake
        ? _profileToTime(_profile.wakeHour, _profile.wakeMinute)
        : _profileToTime(_profile.sleepHour, _profile.sleepMinute);

    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      _profile = isWake
          ? _profile.copyWith(wakeHour: picked.hour, wakeMinute: picked.minute)
          : _profile.copyWith(
              sleepHour: picked.hour, sleepMinute: picked.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isMetric = _profile.unitSystem == UnitSystem.metric;
    final weightUnit = isMetric ? 'kg' : 'lbs';
    final heightUnit = isMetric ? 'cm' : 'inches';
    final cupUnit = isMetric ? 'ml' : 'fl oz';
    final goal = HydrationCalculator.dailyGoalMl(_profile);
    final goalLabel = HydrationCalculator.formatMl(goal, _profile.unitSystem);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader('Units'),
          SegmentedButton<UnitSystem>(
            segments: const [
              ButtonSegment(value: UnitSystem.metric, label: Text('Metric')),
              ButtonSegment(value: UnitSystem.imperial, label: Text('Imperial')),
            ],
            selected: {_profile.unitSystem},
            onSelectionChanged: (s) => _onUnitChange(s.first),
          ),
          const SizedBox(height: 24),
          _SectionHeader('Profile'),
          _SegmentRow<Gender>(
            label: 'Gender',
            segments: const [
              ButtonSegment(value: Gender.male, label: Text('Male')),
              ButtonSegment(value: Gender.female, label: Text('Female')),
            ],
            selected: _profile.gender,
            onChanged: (v) => setState(() => _profile = _profile.copyWith(gender: v)),
          ),
          const SizedBox(height: 16),
          _NumField(
            controller: _weightCtrl,
            label: 'Weight ($weightUnit)',
          ),
          const SizedBox(height: 16),
          _NumField(
            controller: _heightCtrl,
            label: 'Height ($heightUnit)',
          ),
          const SizedBox(height: 24),
          _SectionHeader('Activity level'),
          _SegmentRow<ActivityLevel>(
            label: '',
            segments: const [
              ButtonSegment(
                  value: ActivityLevel.sedentary, label: Text('Sedentary')),
              ButtonSegment(
                  value: ActivityLevel.moderate, label: Text('Moderate')),
              ButtonSegment(value: ActivityLevel.active, label: Text('Active')),
            ],
            selected: _profile.activityLevel,
            onChanged: (v) =>
                setState(() => _profile = _profile.copyWith(activityLevel: v)),
          ),
          const SizedBox(height: 24),
          _SectionHeader('Daily goal (calculated)'),
          ListTile(
            title: Text(goalLabel,
                style: Theme.of(context).textTheme.headlineSmall),
            subtitle: const Text('Based on your profile'),
            leading: const Icon(Icons.water_drop_outlined),
          ),
          const SizedBox(height: 24),
          _SectionHeader('Schedule'),
          ListTile(
            title: const Text('Wake time'),
            subtitle: Text(
                TimeOfDay(hour: _profile.wakeHour, minute: _profile.wakeMinute)
                    .format(context)),
            trailing: const Icon(Icons.edit),
            onTap: () => _pickTime(true),
          ),
          ListTile(
            title: const Text('Sleep time'),
            subtitle: Text(
                TimeOfDay(hour: _profile.sleepHour, minute: _profile.sleepMinute)
                    .format(context)),
            trailing: const Icon(Icons.edit),
            onTap: () => _pickTime(false),
          ),
          const SizedBox(height: 24),
          _SectionHeader('Cup / bottle size'),
          _NumField(
            controller: _cupCtrl,
            label: 'Cup size ($cupUnit)',
          ),
          const SizedBox(height: 24),
          _NextReminderCard(
            profile: _profile,
            now: _now,
            consumedMl: _consumedMl,
            nextReminderAt: _nextReminderAt,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            style:
                FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
            child: const Text('Save settings'),
          ),
        ],
      ),
    );
  }
}

class _NextReminderCard extends StatelessWidget {
  final UserProfile profile;
  final DateTime now;
  final double consumedMl;
  final DateTime? nextReminderAt;

  const _NextReminderCard({
    required this.profile,
    required this.now,
    required this.consumedMl,
    required this.nextReminderAt,
  });

  @override
  Widget build(BuildContext context) {
    final goal = HydrationCalculator.dailyGoalMl(profile);
    final count = HydrationCalculator.reminderCount(profile, goal);
    final next = nextReminderAt;

    final interval = goal > 0
        ? Duration(
            minutes: (DateTime(now.year, now.month, now.day,
                            profile.sleepHour, profile.sleepMinute)
                        .difference(DateTime(now.year, now.month, now.day,
                            profile.wakeHour, profile.wakeMinute))
                        .inMinutes /
                    (count + 1))
                .round())
        : Duration.zero;

    final String intervalLabel = _formatDuration(interval);
    final String countdownLabel = next != null
        ? _formatDuration(next.difference(now))
        : 'No more today';

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reminder schedule',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    )),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SchedStat(
                    label: 'Reminders today',
                    value: '$count',
                    icon: Icons.notifications_outlined,
                  ),
                ),
                Expanded(
                  child: _SchedStat(
                    label: 'Every',
                    value: intervalLabel,
                    icon: Icons.schedule,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _SchedStat(
              label: 'Next reminder in',
              value: countdownLabel,
              icon: Icons.timer_outlined,
              highlight: true,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return '—';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }
}

class _SchedStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  const _SchedStat({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final colour = highlight
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        Icon(icon, size: 18, color: colour),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colour,
                    )),
            Text(label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
          ],
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _NumField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _SegmentRow<T> extends StatelessWidget {
  final String label;
  final List<ButtonSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  const _SegmentRow({
    required this.label,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<T>(
      segments: segments,
      selected: {selected},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}
