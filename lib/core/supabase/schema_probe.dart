import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cloud/cloud_database.dart';
import 'store_connection.dart';
import 'store_schema.dart';

/// One column found in the live database.
class DiscoveredColumn {
  final String name;
  final String? sample;

  const DiscoveredColumn(this.name, this.sample);

  @override
  String toString() => name;
}

/// One table found in the live database.
class DiscoveredTable {
  final String name;
  final List<DiscoveredColumn> columns;
  final int rowCount;
  final String? error;

  const DiscoveredTable({
    required this.name,
    required this.columns,
    this.rowCount = 0,
    this.error,
  });

  bool get ok => error == null;
  List<String> get columnNames => columns.map((c) => c.name).toList();
}

/// Everything the probe learned about a project.
class DiscoveredSchema {
  final List<DiscoveredTable> tables;
  final DateTime probedAt;

  const DiscoveredSchema({required this.tables, required this.probedAt});

  List<DiscoveredTable> get found => tables.where((t) => t.ok).toList();
  List<String> get missing =>
      tables.where((t) => !t.ok).map((t) => t.name).toList();

  /// True when the project looks like the storefront this module expects.
  bool get looksLikeStorefront =>
      found.any((t) => t.name.contains('product')) &&
      found.any((t) => t.name.contains('order'));

  /// Copy-pasteable report: this is what closes the binding without anyone
  /// having to open the website's source.
  String report() {
    final buffer = StringBuffer()
      ..writeln('# Supabase schema — ${storeConnection.config.projectRef}')
      ..writeln('probed: ${probedAt.toIso8601String()}')
      ..writeln();
    for (final table in found) {
      buffer.writeln('## ${table.name}  (${table.rowCount} rows sampled)');
      for (final column in table.columns) {
        final sample = column.sample;
        buffer.writeln('  - ${column.name}'
            '${sample == null ? '' : '   e.g. $sample'}');
      }
      buffer.writeln();
    }
    if (missing.isNotEmpty) {
      buffer.writeln('## not present');
      buffer.writeln('  ${missing.join(', ')}');
    }
    buffer
      ..writeln()
      ..writeln('## proposed StoreSchema overrides')
      ..writeln(jsonEncode(const SchemaProbe.proposedOverridesRaw()));
    return buffer.toString();
  }
}

/// Reads the real shape of a Supabase project.
///
/// PostgREST does not expose `information_schema`, so this probes instead:
/// it asks each candidate table for one row and takes the column names from
/// the keys that come back. That works with nothing but the anon key, which is
/// why the app can finish binding itself to an unknown storefront.
class SchemaProbe {
  const SchemaProbe._();

  /// Candidate table names, in the order worth trying.
  ///
  /// The first eight are the storefront's real tables, read out of its SQL.
  /// The rest are other spellings, so a project provisioned from a different
  /// copy of the scripts still binds without an override.
  static const List<String> candidates = [
    // The site's own tables (`tables_only.sql`, `shipping_setup.sql`).
    'products', 'orders', 'customers', 'profiles', 'store_settings',
    'shipping_rates', 'platform_admins', 'modules_config',
    // The app's optional extras (`supabase_optional_tables.sql`).
    'store_categories', 'store_order_items', 'store_addresses',
    'store_coupons', 'store_banners', 'store_reviews', 'store_wishlist',
    'store_payouts',
    // Other spellings, so a project set up from a different copy still binds.
    'product', 'items', 'order', 'commandes', 'order_items', 'clients',
    'users', 'addresses', 'categories', 'category', 'settings',
    'shipping', 'shipping_zones', 'delivery_zones', 'cities',
    'algeria_cities', 'wilayas', 'communes', 'coupons', 'banners',
    'reviews', 'wishlists', 'favorites', 'packers', 'confirmers',
    'finance', 'payouts', 'transactions', 'payments', 'campaigns',
  ];

  /// Probes every candidate. Never throws: an unreachable project yields an
  /// empty result the UI explains.
  static Future<DiscoveredSchema> discover() async {
    final client = storeConnection.client;
    if (client == null) {
      return DiscoveredSchema(tables: const [], probedAt: DateTime.now());
    }
    final tables = <DiscoveredTable>[];
    for (final name in candidates) {
      tables.add(await _probeTable(client, name));
    }
    // De-duplicate: `orders` and `store_orders` both answering means the
    // project has one of them aliased; keep the first that returned columns.
    final seen = <String>{};
    final unique = <DiscoveredTable>[];
    for (final table in tables) {
      if (!table.ok || table.columns.isEmpty) continue;
      final fingerprint = table.columnNames.join(',');
      if (seen.contains(fingerprint) && _isPrefixedAlias(table.name)) continue;
      seen.add(fingerprint);
      unique.add(table);
    }
    return DiscoveredSchema(tables: unique, probedAt: DateTime.now());
  }

  static bool _isPrefixedAlias(String name) => name.startsWith('store_');

  static Future<DiscoveredTable> _probeTable(
    SupabaseClient client,
    String name,
  ) async {
    try {
      // One round trip gives both a row (for the column names) and the total.
      final response =
          await client.from(name).select('*', count: CountOption.exact).limit(1);
      final rows = response.data;
      if (rows.isEmpty) {
        // The table exists but is empty: it still counts as found, it just
        // cannot tell us its columns until it holds a row.
        return DiscoveredTable(name: name, columns: const [], rowCount: 0);
      }
      final row = Map<String, dynamic>.from(rows.first as Map);
      return DiscoveredTable(
        name: name,
        columns: [
          for (final entry in row.entries)
            DiscoveredColumn(entry.key, _sample(entry.value)),
        ],
        rowCount: response.count ?? rows.length,
      );
    } catch (error) {
      return DiscoveredTable(
        name: name,
        columns: const [],
        error: '$error',
      );
    }
  }

  /// Short, safe preview of a value — never the whole blob, never a secret.
  static String? _sample(Object? value) {
    if (value == null) return null;
    if (value is List) return '[${value.length} items]';
    if (value is Map) return '{${value.length} keys}';
    final text = '$value';
    if (text.length > 48) return '${text.substring(0, 45)}…';
    // Never echo a credential back into a shareable report.
    final lowered = text.toLowerCase();
    if (lowered.startsWith('ey') && text.length > 40) return '<token>';
    return text;
  }

  /// Maps what was found onto this module's logical columns, so a table that
  /// calls it `commandes` and its total `montant` still works.
  static Map<String, Map<String, String>> proposeMapping(DiscoveredSchema schema) {
    final proposal = <String, Map<String, String>>{};
    for (final table in schema.found) {
      final logical = _logicalTable(table.name);
      if (logical == null) continue;
      final columns = <String, String>{};
      for (final entry in StoreColumns.aliases.entries) {
        final match = _bestMatch(entry.key, entry.value, table.columnNames);
        if (match != null) columns[entry.key] = match;
      }
      // Exact hits too (the alias map only lists alternatives).
      for (final column in table.columnNames) {
        if (_knownLogical(column) != null &&
            !columns.containsValue(column)) {
          columns[_knownLogical(column)!] = column;
        }
      }
      if (columns.isNotEmpty) proposal[logical] = columns;
    }
    return proposal;
  }

  static String? _logicalTable(String found) {
    final bare = found.startsWith('store_') ? found.substring(6) : found;
    const byName = {
      'products': 'products', 'product': 'products', 'items': 'products',
      'categories': 'categories', 'category': 'categories',
      'orders': 'orders', 'order': 'orders', 'commandes': 'orders',
      'order_items': 'orderItems', 'order_products': 'orderItems',
      'customers': 'customers', 'clients': 'customers',
      'profiles': 'profiles', 'users': 'profiles', 'members': 'profiles',
      'addresses': 'addresses',
      'packers': 'packers', 'packer': 'packers',
      'confirmers': 'confirmers', 'confirmer': 'confirmers',
      'coupons': 'coupons', 'promo_codes': 'coupons', 'discounts': 'coupons',
      'banners': 'banners', 'sliders': 'banners',
      'reviews': 'reviews',
      'wishlists': 'wishlists', 'favorites': 'wishlists',
      'settings': 'settings', 'user_settings': 'settings',
      'store_profile': 'settings',
      'shipping': 'shippingZones', 'shipping_zones': 'shippingZones',
      'delivery_zones': 'shippingZones',
      'finance': 'payouts', 'payouts': 'payouts', 'transactions': 'payouts',
      'payments': 'payouts',
    };
    return byName[bare];
  }

  static const Set<String> _logicalNames = {
    'id', 'name', 'name_ar', 'name_fr', 'slug', 'description',
    'description_ar', 'price', 'compare_at_price', 'cost_price', 'stock',
    'sku', 'barcode', 'category_id', 'image', 'images', 'published',
    'featured', 'active', 'rating', 'sold_count', 'unit', 'created_at',
    'updated_at', 'order_number', 'status', 'payment_method',
    'payment_status', 'subtotal', 'discount', 'shipping_fee', 'total',
    'customer_name', 'customer_phone', 'customer_email', 'address', 'city',
    'wilaya', 'notes', 'coupon_code', 'items', 'courier_id', 'shop_id',
    'source', 'code', 'type', 'value', 'min_spend', 'usage_limit',
    'used_count', 'expires_at', 'image_url', 'link', 'position',
    'product_id', 'order_id', 'customer_id', 'comment', 'approved', 'label',
    'is_default', 'phone', 'full_name', 'fee', 'free_above',
  };

  static String? _knownLogical(String column) =>
      _logicalNames.contains(column) ? column : null;

  /// Picks the alias that best matches a real column: exact, then ignoring
  /// case and separators, then prefix.
  static String? _bestMatch(
    String logical,
    List<String> aliases,
    List<String> available,
  ) {
    if (available.contains(logical)) return logical;
    for (final alias in aliases) {
      if (available.contains(alias)) return alias;
    }
    final foldedAvailable = {for (final a in available) _fold(a): a};
    final foldedLogical = _fold(logical);
    if (foldedAvailable.containsKey(foldedLogical)) {
      return foldedAvailable[foldedLogical];
    }
    for (final alias in aliases) {
      final hit = foldedAvailable[_fold(alias)];
      if (hit != null) return hit;
    }
    for (final entry in foldedAvailable.entries) {
      if (entry.key.startsWith(foldedLogical) && entry.key.length - foldedLogical.length <= 4) {
        return entry.value;
      }
    }
    return null;
  }

  static String _fold(String raw) =>
      raw.toLowerCase().replaceAll(RegExp('[_\\-\\s]'), '');

  /// The table-name half of the proposal, as plain data — used by the report
  /// and by `applyProposal`.
  static Map<String, String> proposedTableNames(DiscoveredSchema schema) {
    final out = <String, String>{};
    for (final table in schema.found) {
      final logical = _logicalTable(table.name);
      if (logical != null && !out.containsKey(logical)) {
        out[logical] = table.name;
      }
    }
    return out;
  }

  /// Kept const-callable for the report header; the real proposal needs the
  /// live schema, so this returns the mapping currently in force.
  static Map<String, String> proposedOverridesRaw() => StoreSchema.currentOverrides;
}

/// Applies a proposal and keeps it across restarts.
class SchemaBinder {
  const SchemaBinder._();

  static const _settingsKey = 'supabase_table_map';

  /// Restores the mapping saved by a previous session. Call before the first
  /// query, right after the connection is up.
  static void restore() {
    final decoded = _decode(_read() ?? '');
    if (decoded != null && decoded.isNotEmpty) {
      StoreSchema.applyOverrides(decoded);
      debugPrint('[store] restored ${decoded.length} table overrides');
    }
  }

  static Future<void> apply(Map<String, String> tableNames) async {
    StoreSchema.applyOverrides(tableNames);
    await _write(jsonEncode(tableNames));
    debugPrint('[store] applied ${tableNames.length} table overrides');
  }

  static Future<void> clear() async {
    StoreSchema.applyOverrides(const {});
    await _write('');
  }

  /// The map lives in the same key-value box as the connection details, so a
  /// shop that reinstalls and re-enters its URL also re-enters the mapping.
  static String? _read() {
    try {
      return CloudDatabase.settingsBox.get(_settingsKey) as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _write(String value) async {
    try {
      await CloudDatabase.settingsBox.put(_settingsKey, value);
    } catch (error) {
      debugPrint('[store] could not persist the schema map: $error');
    }
  }

  static Map<String, String>? _decode(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return decoded.map((k, v) => MapEntry('$k', '$v'));
    } catch (_) {
      return null;
    }
  }
}
