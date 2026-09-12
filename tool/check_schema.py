#!/usr/bin/env python3
"""Checks that every column the app writes really exists in the site's schema.

The storefront's database definitions are committed under `reference/site/`
(copied verbatim from https://github.com/TaharBn12/Ecommerce-site). This tool
parses them, resolves `StoreSchema` / `StoreColumns` to their literal values,
reads the columns each entity's `toMap()` emits, and fails if the app would
send a column Postgres does not have.

That is the failure mode that cannot be caught any other way here: Dart would
compile it, the app would run, and only the server would reject the insert.

    python3 tool/check_schema.py
"""
from __future__ import annotations

import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SQL_GLOB = 'reference/site/*.sql'
SCHEMA = 'lib/core/supabase/store_schema.dart'

# Which entity `toMap()` targets which real table.
WRITES = [
    ('lib/features/store/domain/entities/store_product.dart', 'StoreProduct', 'products'),
    ('lib/features/store/domain/entities/store_order.dart', 'StoreOrder', 'orders'),
    ('lib/features/store/domain/entities/store_customer.dart', 'StoreCustomer', 'customers'),
    ('lib/features/store/domain/entities/store_settings.dart', 'StoreSettings', 'store_settings'),
    ('lib/features/store/domain/entities/store_settings.dart', 'StoreShippingRate', 'shipping_rates'),
]


# ---------------------------------------------------------------- SQL side

def parse_sql() -> dict[str, set[str]]:
    """table -> columns, from CREATE TABLE plus every later ALTER TABLE."""
    tables: dict[str, set[str]] = {}
    for path in sorted(glob.glob(os.path.join(ROOT, SQL_GLOB))):
        sql = open(path, encoding='utf-8', errors='replace').read()
        for match in re.finditer(
            r'CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(?:public\.)?([a-z_]+)\s*\((.*?)\n\);',
            sql, re.S | re.I):
            table, body = match.group(1), match.group(2)
            cols = tables.setdefault(table, set())
            for line in body.split('\n'):
                line = line.strip().rstrip(',')
                if not line or line.startswith('--'):
                    continue
                # Skip table-level constraints.
                if re.match(r'(?i)^(PRIMARY\s+KEY|UNIQUE|CHECK|FOREIGN\s+KEY|CONSTRAINT|EXCLUDE)\b', line):
                    continue
                m = re.match(r'([a-z_][a-z0-9_]*)\s+[A-Za-z]', line)
                if m:
                    cols.add(m.group(1))
        # Every later migration. One ALTER can add several columns
        # (`ADD COLUMN IF NOT EXISTS a TEXT, ADD COLUMN IF NOT EXISTS b TEXT`),
        # so walk each statement block rather than only its first ADD.
        for block in re.finditer(
            r'ALTER\s+TABLE\s+(?:public\.)?([a-z_]+)(.*?);', sql, re.S | re.I):
            table = block.group(1)
            for col in re.finditer(r'ADD\s+COLUMN\s+(?:IF\s+NOT\s+EXISTS\s+)?([a-z_][a-z0-9_]*)',
                                   block.group(2), re.I):
                tables.setdefault(table, set()).add(col.group(1))
    return tables


# ------------------------------------------------------------- Dart side

def const_map() -> dict[str, str]:
    """StoreColumns.NAME -> 'column'."""
    src = open(os.path.join(ROOT, SCHEMA), encoding='utf-8').read()
    at = src.find('class StoreColumns')
    body = src[at:src.find('\nclass ', at + 1)]
    out = {}
    for m in re.finditer(
            r'static\s+const\s+String\s+([A-Za-z_]\w*)\s*=\s*\'([^\']+)\'', body):
        out[m.group(1)] = m.group(2)
    return out


def table_getters() -> dict[str, str]:
    """StoreSchema.name -> 'table' (the default, ignoring runtime overrides)."""
    src = open(os.path.join(ROOT, SCHEMA), encoding='utf-8').read()
    out = {}
    for m in re.finditer(
            r"static\s+String\s+get\s+(\w+)\s*=>\s*_name\('\w+',\s*'([^']+)'\)", src):
        out[m.group(1)] = m.group(2)
    return out


def tomap_body(src: str, owner: str) -> str:
    """The body of `owner`'s `toMap()`, or '' when the class has none."""
    at = src.find('class %s ' % owner)
    if at < 0:
        at = src.find('class %s' % owner)
    if at < 0:
        return ''
    nxt = src.find('\nclass ', at + 1)
    body = src[at:nxt if nxt > 0 else len(src)]
    m = re.search(r'Map<String,\s*dynamic>\s+toMap\(', body)
    if not m:
        return ''
    # Skip the parameter list first — `toMap({String? ownerId})` would
    # otherwise make the extractor return the `{...}` of the arguments and
    # silently report zero columns written.
    at = m.end()
    depth = 1
    while at < len(body) and depth:
        if body[at] == '(':
            depth += 1
        elif body[at] == ')':
            depth -= 1
        at += 1
    if at >= len(body):
        return ''
    start = body.index('{', at)
    depth = 0
    for i in range(start, len(body)):
        if body[i] == '{':
            depth += 1
        elif body[i] == '}':
            depth -= 1
            if depth == 0:
                return body[start:i + 1]
    return body[start:]


def emitted_columns(body: str, cols: dict[str, str]) -> set[str]:
    """Column literals a toMap() body writes, via its StoreColumns constants."""
    found = set()
    for name in re.findall(r'StoreColumns\.(\w+)', body):
        if name in cols:
            found.add(cols[name])
        elif name not in ('read', 'aliases'):
            found.add('<unknown:%s>' % name)
    for literal in re.findall(r"'([a-z_][a-z0-9_]*)'\s*:", body):
        found.add(literal)
    return found


def main() -> int:
    os.chdir(ROOT)
    tables = parse_sql()
    if not tables:
        print('no SQL under reference/site/ — nothing to check against')
        return 1
    cols = const_map()
    getters = table_getters()
    errors: list[str] = []
    checked = 0

    print('site schema: %d tables from %d sql files'
          % (len(tables), len(glob.glob(SQL_GLOB))))
    for table in ('products', 'orders', 'customers', 'store_settings', 'shipping_rates'):
        print('  %-16s %2d columns' % (table, len(tables.get(table, set()))))
    print()

    for path, owner, table in WRITES:
        if not os.path.isfile(path):
            errors.append('%s: missing entity file' % path)
            continue
        body = tomap_body(open(path, encoding='utf-8').read(), owner)
        if not body:
            errors.append('%s: %s has no toMap()' % (path, owner))
            continue
        real = tables.get(table)
        if real is None:
            errors.append('%s: %s writes to `%s`, which the site does not define'
                          % (path, owner, table))
            continue
        written = emitted_columns(body, cols)
        checked += len(written)
        # `updated_at` / `created_at` are declared in the CREATE TABLE, so they
        # are covered; anything else absent is a rejected insert waiting to
        # happen.
        for column in sorted(written):
            if column.startswith('<unknown:'):
                errors.append('%s: %s.toMap() uses %s, which StoreColumns does not declare'
                              % (path, owner, column[9:-1]))
            elif column not in real:
                errors.append('%s: %s.toMap() writes `%s`, not a column of `%s`'
                              % (path, owner, column, table))
        print('%-16s -> %-16s %2d columns written, all present'
              % (owner, table, len(written)))

    # Reverse check: table names the schema map resolves to must exist too.
    print()
    for logical, table in sorted(getters.items()):
        if logical in ('categories', 'orderItems', 'addresses', 'coupons',
                       'banners', 'reviews', 'wishlists', 'payouts'):
            continue  # app-owned extras, created by supabase_optional_tables.sql
        if table not in tables:
            errors.append('StoreSchema.%s resolves to `%s`, which the site does not define'
                          % (logical, table))

    print()
    if errors:
        print('%d finding(s):' % len(errors))
        for e in errors:
            print('  !', e)
        return 1
    print('%d columns checked against the site schema — clean' % checked)
    return 0


if __name__ == '__main__':
    sys.exit(main())
