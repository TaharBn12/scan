import '../cloud/cloud_database.dart';

/// The shop's daily sales target, shown as a live progress bar on the
/// dashboard. 0 = feature off.
class DailyGoal {
  DailyGoal._();

  static const _key = 'daily_goal';

  static double get value =>
      (CloudDatabase.settingsBox.get(_key) as num?)?.toDouble() ?? 0;

  static Future<void> set(double value) =>
      CloudDatabase.settingsBox.put(_key, value < 0 ? 0 : value);
}
