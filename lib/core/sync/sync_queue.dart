import '../data/hive_database.dart';

/// Outbox of local changes that still have to be pushed to the website.
///
/// Every repository write enqueues (entity, id, op). The sync engine drains
/// the queue in order, so the website receives changes even if the phone was
/// offline for days. Entries are keyed "entity:id" so many edits to the same
/// record collapse into one upload of the latest version.
class SyncQueue {
  SyncQueue._();

  static const opUpsert = 'upsert';
  static const opDelete = 'delete';

  static Future<void> enqueue(String entity, String id, String op) async {
    await HiveDatabase.syncQueueBox.put('$entity:$id', {
      'entity': entity,
      'id': id,
      'op': op,
      'queuedAt': DateTime.now().toIso8601String(),
    });
  }

  static List<Map<String, dynamic>> pending() {
    final items = HiveDatabase.syncQueueBox.values
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .toList();
    items.sort((a, b) =>
        (a['queuedAt'] as String).compareTo(b['queuedAt'] as String));
    return items;
  }

  static int get length => HiveDatabase.syncQueueBox.length;

  static Future<void> remove(String entity, String id) async {
    await HiveDatabase.syncQueueBox.delete('$entity:$id');
  }

  static Future<void> clear() async {
    await HiveDatabase.syncQueueBox.clear();
  }
}
