import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/supabase/store_connection.dart';
import '../../../../core/supabase/supabase_errors.dart';

/// Shared plumbing for every Supabase-backed store repository.
///
/// Two guarantees every call gets for free:
///  * an unconfigured link returns `Left(ServerFailure('store_error_not_configured'))`
///    instead of throwing inside the Supabase client;
///  * any exception is folded into the same `Either`, so blocs never need a
///    try/catch and a dropped Wi-Fi can never crash a screen.
mixin StoreRepositoryBase {
  SupabaseClient? get _client => storeConnection.client;

  /// True when queries may run at all.
  bool get isLinked => storeConnection.isOnline && _client != null;

  /// Runs [body], converting every failure into a localized [ServerFailure].
  Future<Either<Failure, T>> guard<T>(
    Future<T> Function(SupabaseClient client) body,
  ) async {
    final client = _client;
    if (client == null || !storeConnection.isOnline) {
      return Left(
        ServerFailure(
          storeConnection.state == StoreLinkState.notConfigured
              ? SupabaseErrors.notConfigured
              : SupabaseErrors.offline,
        ),
      );
    }
    try {
      return Right(await body(client));
    } catch (error) {
      return Left(ServerFailure(SupabaseErrors.keyOf(error)));
    }
  }

  /// Same as [guard] but hands back a plain list of rows.
  Future<Either<Failure, List<Map<String, dynamic>>>> guardRows(
    Future<List<Map<String, dynamic>>> Function(SupabaseClient client) body,
  ) =>
      guard(body);

  /// Inserts [row]; Postgres returns the stored row (with its generated id).
  Future<Map<String, dynamic>?> insertOne(
    SupabaseClient client,
    String table,
    Map<String, dynamic> row,
  ) async {
    final result = await client.from(table).insert(row).select();
    if (result.isEmpty) return null;
    return Map<String, dynamic>.from(result.first as Map);
  }

  Future<void> upsert(
    SupabaseClient client,
    String table,
    Map<String, dynamic> row, {
    String conflictColumn = 'id',
  }) async {
    await client
        .from(table)
        .upsert(row, onConflict: conflictColumn, ignoreDuplicates: false);
  }
}
