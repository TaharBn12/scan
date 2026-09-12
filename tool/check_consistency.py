#!/usr/bin/env python3
"""Repository consistency checks that do not need the Flutter SDK.

`flutter analyze` remains the authority, but it needs the Dart SDK. This runs
anywhere Python does, and it catches the mistakes that actually break a build:

  1. every `import` resolves to a real file
  2. every localization key used in code exists in en / ar / fr, and the three
     tables agree (mirrors test/widget_test.dart, plus the dynamic key
     families built from enums)
  3. every `context.push/go` target is declared in the router
  4. every Dart file has balanced delimiters (real lexer: strings, raw
     strings, triple quotes and comments are stripped first)
  5. every type name a file refers to is either declared in it (or in a
     `part` of it) or imported — `part of` libraries share their parent's
     imports, so they are resolved as one unit

Usage:  python3 tool/check_consistency.py       (run from the repo root)
Exit code 0 = clean, 1 = findings printed below.
"""
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def strip_code(src: str) -> str:
    """Remove comments and string literals, leaving real code behind."""
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        two = src[i:i + 2]
        if two == '//':
            j = src.find('\n', i); i = n if j < 0 else j; continue
        if two == '/*':
            j = src.find('*/', i + 2); i = n if j < 0 else j + 2; continue
        if c == 'r' and i + 1 < n and src[i + 1] in "'\"":
            q = src[i + 1]; j = src.find(q, i + 2)
            i = n if j < 0 else j + 1; out.append('""'); continue
        if src.startswith("'''", i) or src.startswith('"""', i):
            q = src[i:i + 3]; j = src.find(q, i + 3)
            i = n if j < 0 else j + 3; out.append('""'); continue
        if c in "'\"":
            j = i + 1
            while j < n:
                if src[j] == '\\':
                    j += 2; continue
                if src[j] == c or src[j] == '\n':
                    break
                j += 1
            i = j + 1; out.append('""'); continue
        out.append(c); i += 1
    return ''.join(out)


TYPE_RE = re.compile(
    r'^(?:abstract\s+|final\s+|base\s+|sealed\s+)?'
    r'(?:class|enum|mixin|extension|typedef)\s+([A-Z][A-Za-z0-9_]{3,})', re.M)

# Enum-generated keys: `<prefix><enum member name>`, built by the code as
# `'store_status_$name'` and friends.
DYNAMIC_KEYS = {
    'store_status_': ['pending', 'confirming', 'confirmed', 'packing', 'packed',
                      'shipped', 'delivered', 'cancelled', 'returned', 'refunded'],
    'store_pay_': ['cod', 'card', 'transfer', 'wallet'],
    'store_coupon_': ['percent', 'fixed', 'freeShipping'],
    'store_sort_': ['newest', 'priceAsc', 'priceDesc', 'bestSelling', 'rating', 'name'],
    'sync_reason_': ['missing', 'priceChanged', 'stockChanged', 'renamed', 'identical'],
    'store_link_': ['unknown', 'notConfigured', 'connecting', 'online', 'offline'],
    'unit_': ['piece', 'kg', 'g', 'l', 'ml', 'm', 'box', 'pack'],
}


def main() -> int:
    os.chdir(ROOT)
    files = sorted(glob.glob('lib/**/*.dart', recursive=True))
    errors = []
    srcs = {f: open(f, encoding='utf-8').read() for f in files}
    code = {f: strip_code(s) for f, s in srcs.items()}

    # 1 ---------------------------------------------------------- imports
    for f in files:
        if re.search(r"""^\s*part\s+of\s+'""", srcs[f], re.M):
            continue  # a part file may not carry imports
        for spec in re.findall(r"""^\s*import\s+'([^']+)'""", srcs[f], re.M):
            if spec.startswith('package:billing_app/'):
                target = os.path.join('lib', spec[len('package:billing_app/'):])
            elif spec.startswith(('package:', 'dart:')):
                continue
            else:
                target = os.path.normpath(os.path.join(os.path.dirname(f), spec))
            if not os.path.isfile(target):
                errors.append(f'{f}: unresolved import -> {spec}')

    # 2 ------------------------------------------------------------ l10n
    def keys(path):
        return set(re.findall(r"^\s*'([a-zA-Z0-9_]+)':\s*[\"']",
                              open(path, encoding='utf-8').read(), re.M))

    en = keys('lib/core/l10n/strings_en.dart')
    ar = keys('lib/core/l10n/strings_ar.dart')
    fr = keys('lib/core/l10n/strings_fr.dart')
    if en != ar:
        errors.append(f'ar/en key drift: {sorted(en ^ ar)[:8]}')
    if en != fr:
        errors.append(f'fr/en key drift: {sorted(en ^ fr)[:8]}')
    for prefix, members in DYNAMIC_KEYS.items():
        for m in members:
            if prefix + m not in en:
                errors.append(f'missing enum-generated key: {prefix}{m}')
    for f in files:
        for k in re.findall(r"\.t\(\s*'([a-zA-Z0-9_]+)'", srcs[f]):
            if k not in en:
                errors.append(f'{f}: localization key not defined -> {k}')

    def values(path):
        return dict(re.findall(
            r"^\s*'([a-zA-Z0-9_]+)':\s*(\"(?:[^\"\\]|\\.)*\"|'(?:[^'\\]|\\.)*')",
            open(path, encoding='utf-8').read(), re.M))

    ph = re.compile(r'\{[a-zA-Z_]+\}')
    ven, var, vfr = (values('lib/core/l10n/strings_%s.dart' % l) for l in ('en', 'ar', 'fr'))
    for k, v in ven.items():
        if set(ph.findall(v)) != set(ph.findall(var.get(k, ''))) or \
           set(ph.findall(v)) != set(ph.findall(vfr.get(k, ''))):
            errors.append(f'placeholder drift for key: {k}')

    # 3 ----------------------------------------------------------- routes
    stack, routes = [], set()
    for line in open('lib/config/routes/app_routes.dart', encoding='utf-8'):
        m = re.search(r"path:\s*'([^']*)'", line)
        if not m:
            continue
        seg, indent = m.group(1), len(line) - len(line.lstrip())
        while stack and stack[-1][0] >= indent:
            stack.pop()
        parent = stack[-1][1] if stack else ''
        full = (parent.rstrip('/') + '/' + seg.lstrip('/')) if seg else parent
        if not full.startswith('/'):
            full = '/' + full
        routes.add(full.replace('//', '/'))
        stack.append((indent, full))
    for f in files:
        for target in re.findall(
                r"context\.(?:push|go|pushReplacement)\(\s*'(/[^'$]*)'", srcs[f]):
            if target not in routes:
                errors.append(f'{f}: navigation target not routed -> {target}')

    # 4 -------------------------------------------------------- delimiters
    for f in files:
        for o, c in [('{', '}'), ('(', ')'), ('[', ']')]:
            d = code[f].count(o) - code[f].count(c)
            if d:
                errors.append(f'{f}: unbalanced {o}{c} (off by {d})')

    # 5 ------------------------------------------------- type resolution
    #
    # Dart's part / part-of: a `part` file carries no imports of its own and
    # sees the library's; the library sees every declaration in its parts.
    # Both directions are resolved here, otherwise every `part of` file in the
    # repo reports a phantom missing import.
    def resolve_imports(f):
        out = set()
        for spec in re.findall(r"""^\s*import\s+'([^']+)'""", srcs[f], re.M):
            if spec.startswith('package:billing_app/'):
                out.add(os.path.join('lib', spec[len('package:billing_app/'):]))
            elif not spec.startswith(('package:', 'dart:')):
                out.add(os.path.normpath(os.path.join(os.path.dirname(f), spec)))
        return out

    def part_owner(f):
        m = re.search(r"""^\s*part\s+of\s+'([^']+)'""", srcs[f], re.M)
        if not m:
            return None
        owner = m.group(1)
        if owner.startswith('package:billing_app/'):
            return os.path.join('lib', owner[len('package:billing_app/'):])
        return os.path.normpath(os.path.join(os.path.dirname(f), owner))

    def parts_of(f):
        out = set()
        for spec in re.findall(r"""^\s*part\s+'([^']+)'""", srcs[f], re.M):
            if spec.startswith('package:billing_app/'):
                out.add(os.path.join('lib', spec[len('package:billing_app/'):]))
            else:
                out.add(os.path.normpath(os.path.join(os.path.dirname(f), spec)))
        return out

    library_of = {}
    for f in files:
        owner = part_owner(f)
        library_of[f] = owner if (owner and owner in srcs) else f

    index = {}
    for f, s in srcs.items():
        for name in TYPE_RE.findall(s):
            index.setdefault(name, set()).add(library_of[f])

    for f in files:
        lib = library_of[f]
        unit = {lib} | {p for p in parts_of(lib) if p in srcs}
        own = set()
        for member in unit:
            own |= set(TYPE_RE.findall(srcs[member]))
        imported = resolve_imports(lib)
        body = '\n'.join(code[m] for m in unit)
        for name in sorted(set(re.findall(r'\b([A-Z][A-Za-z0-9_]{3,})\b', body))):
            decls = index.get(name)
            if not decls or lib in decls or name in own:
                continue
            if not (decls & imported):
                errors.append(
                    f'{f}: uses type `{name}` without importing {sorted(decls)[0]}')

    print(f'checked {len(files)} dart files, {len(en)} localization keys, '
          f'{len(routes)} routes')
    if errors:
        print(f'\n{len(errors)} finding(s):')
        for e in errors[:80]:
            print('  !', e)
        return 1
    print('clean')
    return 0


if __name__ == '__main__':
    sys.exit(main())
