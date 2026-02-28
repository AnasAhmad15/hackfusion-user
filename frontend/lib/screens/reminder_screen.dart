import 'package:flutter/material.dart';
import '../models/reminder_model.dart';
import '../services/reminder_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/design_tokens.dart';
import '../widgets/pharmaco_button.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/empty_state.dart';

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({Key? key}) : super(key: key);

  @override
  _ReminderScreenState createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  final _service = ReminderService();
  List<MedicineReminder> _reminders = [];
  bool _isLoading = true;

  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    try {
      final reminders = await _service.getReminders();
      setState(() {
        _reminders = reminders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addReminder() async {
    if (_nameController.text.isEmpty || _dosageController.text.isEmpty) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final reminder = MedicineReminder(
      id: '',
      userId: userId,
      medicineName: _nameController.text,
      dosage: _dosageController.text,
      scheduleTime: '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
    );

    await _service.addReminder(reminder);
    _nameController.clear();
    _dosageController.clear();
    _loadReminders();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Medicine Reminders')),
      body: _isLoading
          ? Padding(
              padding: const EdgeInsets.all(PharmacoTokens.space16),
              child: SkeletonLayouts.cardList(),
            )
          : Column(
              children: [
                // Add reminder section
                Container(
                  padding: const EdgeInsets.all(PharmacoTokens.space16),
                  margin: const EdgeInsets.all(PharmacoTokens.space16),
                  decoration: BoxDecoration(
                    color: isDark ? PharmacoTokens.darkSurface : PharmacoTokens.white,
                    borderRadius: PharmacoTokens.borderRadiusCard,
                    boxShadow: isDark ? null : PharmacoTokens.shadowZ1(),
                    border: isDark ? Border.all(color: PharmacoTokens.darkBorder) : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add Reminder', style: theme.textTheme.titleMedium),
                      const SizedBox(height: PharmacoTokens.space12),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          hintText: 'Medicine Name',
                          prefixIcon: Icon(Icons.medication_outlined),
                        ),
                      ),
                      const SizedBox(height: PharmacoTokens.space12),
                      TextField(
                        controller: _dosageController,
                        decoration: const InputDecoration(
                          hintText: 'Dosage (e.g. 1 pill)',
                          prefixIcon: Icon(Icons.format_list_numbered_rounded),
                        ),
                      ),
                      const SizedBox(height: PharmacoTokens.space12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: PharmacoTokens.primarySurface,
                            borderRadius: PharmacoTokens.borderRadiusSmall,
                          ),
                          child: const Icon(Icons.access_time_rounded, color: PharmacoTokens.primaryBase),
                        ),
                        title: Text('Schedule: ${_selectedTime.format(context)}',
                            style: theme.textTheme.bodyMedium),
                        trailing: TextButton(
                          onPressed: () async {
                            final time = await showTimePicker(context: context, initialTime: _selectedTime);
                            if (time != null) setState(() => _selectedTime = time);
                          },
                          child: const Text('Change'),
                        ),
                      ),
                      const SizedBox(height: PharmacoTokens.space12),
                      PharmacoButton(
                        label: 'Add Reminder',
                        onPressed: _addReminder,
                        icon: Icons.add_alarm_rounded,
                      ),
                    ],
                  ),
                ),

                // Reminders list
                Expanded(
                  child: _reminders.isEmpty
                      ? const EmptyState(
                          icon: Icons.alarm_off_rounded,
                          title: 'No reminders yet',
                          subtitle: 'Add a reminder to stay on track',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: PharmacoTokens.space16),
                          itemCount: _reminders.length,
                          separatorBuilder: (_, __) => const SizedBox(height: PharmacoTokens.space8),
                          itemBuilder: (context, index) {
                            final r = _reminders[index];
                            return Container(
                              decoration: BoxDecoration(
                                color: isDark ? PharmacoTokens.darkSurface : PharmacoTokens.white,
                                borderRadius: PharmacoTokens.borderRadiusCard,
                                boxShadow: isDark ? null : PharmacoTokens.shadowZ1(),
                                border: isDark ? Border.all(color: PharmacoTokens.darkBorder) : null,
                              ),
                              child: ListTile(
                                shape: RoundedRectangleBorder(borderRadius: PharmacoTokens.borderRadiusCard),
                                leading: Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(
                                    color: PharmacoTokens.primarySurface,
                                    borderRadius: PharmacoTokens.borderRadiusSmall,
                                  ),
                                  child: const Icon(Icons.alarm_rounded, color: PharmacoTokens.primaryBase),
                                ),
                                title: Text(r.medicineName, style: theme.textTheme.titleSmall),
                                subtitle: Text('${r.dosage} at ${r.scheduleTime}',
                                    style: theme.textTheme.bodySmall?.copyWith(color: PharmacoTokens.neutral500)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: PharmacoTokens.error),
                                  onPressed: () async {
                                    await _service.deleteReminder(r.id);
                                    _loadReminders();
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
