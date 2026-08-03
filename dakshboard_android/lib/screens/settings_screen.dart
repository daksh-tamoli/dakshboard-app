// ============================================================
// DAKSHboard — Settings Screen
// Notification preferences, data management
// ============================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _dailyReminder = false;
  bool _weeklySummary = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 7, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _dailyReminder = prefs.getBool('daily_reminder') ?? false;
      _weeklySummary = prefs.getBool('weekly_summary') ?? true;
      final hour = prefs.getInt('reminder_hour') ?? 7;
      final minute = prefs.getInt('reminder_minute') ?? 0;
      _reminderTime = TimeOfDay(hour: hour, minute: minute);
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('daily_reminder', _dailyReminder);
    await prefs.setBool('weekly_summary', _weeklySummary);
    await prefs.setInt('reminder_hour', _reminderTime.hour);
    await prefs.setInt('reminder_minute', _reminderTime.minute);
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: Color(0xFFFC4C02)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _reminderTime = picked);
      await _saveSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Notifications Section ─────────────────────
          _sectionHeader('Notifications'),
          _card([
            SwitchListTile(
              value: _dailyReminder,
              onChanged: (val) {
                setState(() => _dailyReminder = val);
                _saveSettings();
              },
              activeColor: const Color(0xFFFC4C02),
              title: const Text('Daily Run Reminder', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Get reminded to go for your daily run', style: TextStyle(color: Color(0xFF888888), fontSize: 12)),
              secondary: const Icon(Icons.alarm_rounded, color: Color(0xFFFC4C02)),
            ),
            if (_dailyReminder) ...[
              const Divider(color: Color(0xFF2A2A2A), height: 1, indent: 56),
              ListTile(
                leading: const SizedBox(width: 24),
                title: const Text('Reminder Time', style: TextStyle(color: Colors.white)),
                trailing: TextButton(
                  onPressed: _pickReminderTime,
                  child: Text(
                    _reminderTime.format(context),
                    style: const TextStyle(color: Color(0xFFFC4C02), fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
            const Divider(color: Color(0xFF2A2A2A), height: 1, indent: 56),
            SwitchListTile(
              value: _weeklySummary,
              onChanged: (val) {
                setState(() => _weeklySummary = val);
                _saveSettings();
              },
              activeColor: const Color(0xFFFC4C02),
              title: const Text('Weekly Summary', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Get your weekly workout stats every Sunday', style: TextStyle(color: Color(0xFF888888), fontSize: 12)),
              secondary: const Icon(Icons.bar_chart_rounded, color: Color(0xFFFC4C02)),
            ),
          ]),

          const SizedBox(height: 20),

          // ── About Section ─────────────────────────────
          _sectionHeader('About'),
          _card([
            const ListTile(
              leading: Icon(Icons.info_outline_rounded, color: Color(0xFFAAAAAA)),
              title: Text('Version', style: TextStyle(color: Colors.white)),
              trailing: Text('1.0.0', style: TextStyle(color: Color(0xFF888888))),
            ),
            const Divider(color: Color(0xFF2A2A2A), height: 1, indent: 56),
            ListTile(
              leading: const Icon(Icons.code_rounded, color: Color(0xFFAAAAAA)),
              title: const Text('Built with DAKSHboard', style: TextStyle(color: Colors.white)),
              trailing: const Text('🏃‍♂️', style: TextStyle(fontSize: 20)),
              onTap: () {},
            ),
          ]),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF888888),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(children: children),
    );
  }
}
