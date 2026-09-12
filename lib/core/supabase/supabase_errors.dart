/// Turns a Supabase/Postgres failure into a localization key the UI can show.
///
/// Repositories call [keyOf] and return `Left(Failure(key))`; pages translate
/// with `context.l10n.t(key)` so the wording stays localised and no raw
/// database message ever reaches a customer.
class SupabaseErrors {
  const SupabaseErrors._();

  static const String notConfigured = 'store_error_not_configured';
  static const String offline = 'store_error_offline';
  static const String denied = 'store_error_denied';
  static const String notFound = 'store_error_not_found';
  static const String conflict = 'store_error_conflict';
  static const String unknown = 'store_error_unknown';

  /// Maps the pieces of an exception into a key. Accepts the loose shape so
  /// the layer keeps compiling even without the supabase types in scope.
  static String keyOf(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('not configured') || text.contains('no project')) {
      return notConfigured;
    }
    if (text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('network') ||
        text.contains('timeout') ||
        text.contains('connection')) {
      return offline;
    }
    if (text.contains('permission denied') ||
        text.contains('row-level security') ||
        text.contains('42501') ||
        text.contains('401') ||
        text.contains('jwt')) {
      return denied;
    }
    if (text.contains('23505') || text.contains('duplicate key')) {
      return conflict;
    }
    if (text.contains('pgrst116') || text.contains('0 rows')) {
      return notFound;
    }
    return unknown;
  }

  /// A short developer-facing hint (logs, the connection screen), never the
  /// only thing a merchant sees.
  static String hintOf(Object error) {
    final text = error.toString();
    return text.length > 220 ? '${text.substring(0, 220)}…' : text;
  }
}
