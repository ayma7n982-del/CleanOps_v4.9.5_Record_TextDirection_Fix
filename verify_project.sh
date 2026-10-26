#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"

python3 - <<'PY'
from pathlib import Path
import json, re, sys, xml.etree.ElementTree as ET
try:
    import yaml
except Exception as exc:
    raise SystemExit(f'PyYAML unavailable: {exc}')

root = Path('.')
lib = root / 'lib'
files = list(lib.rglob('*.dart'))

# 1) Balanced Dart delimiters
pairs = {'(': ')', '[': ']', '{': '}'}
for path in files:
    s = path.read_text(encoding='utf-8')
    stack = []
    i = 0
    state = 'code'
    quote = ''
    while i < len(s):
        ch = s[i]
        nxt = s[i:i+2]
        if state == 'code':
            if nxt == '//':
                nl = s.find('\n', i)
                i = len(s) if nl == -1 else nl + 1
                continue
            elif nxt == '/*':
                end = s.find('*/', i+2)
                if end == -1: raise SystemExit(f'Unterminated comment in {path}')
                i = end + 2
                continue
            elif s.startswith("'''", i) or s.startswith('"""', i):
                quote = s[i:i+3]
                state = 'mstring'
                i += 3
                continue
            elif ch in ('"', "'"):
                quote = ch
                state = 'string'
                i += 1
                continue
            elif ch in pairs:
                stack.append((ch, i))
            elif ch in pairs.values():
                if not stack:
                    raise SystemExit(f'Unmatched closing {ch} in {path} at char {i}')
                op, _ = stack.pop()
                if pairs[op] != ch:
                    raise SystemExit(f'Mismatched {op} and {ch} in {path} at char {i}')
        elif state == 'string':
            if ch == '\\':
                i += 2
                continue
            elif ch == quote:
                state = 'code'
        elif state == 'mstring':
            if s.startswith(quote, i):
                state = 'code'
                i += len(quote)
                continue
        i += 1
    if stack:
        raise SystemExit(f'Unclosed delimiters {stack[-1][0]} in {path}')

# 2) Duplicate classes
classes = {}
for path in files:
    s = path.read_text(encoding='utf-8')
    for m in re.finditer(r'^\s*class\s+([A-Za-z0-9_]+)', s, re.M):
        name = m.group(1)
        classes.setdefault(name, []).append(str(path))
for name, paths in classes.items():
    if len(paths) > 1:
        raise SystemExit(f'Duplicate Dart class {name}: {paths}')

# 3) Unique localization keys
loc = (root / 'lib/core/localization.dart').read_text(encoding='utf-8')
keys = re.findall(r"^\s*'((?:[^'\\]|\\.)*)'\s*:", loc, re.M)
from collections import Counter
for key, count in Counter(keys).items():
    if count > 1:
        raise SystemExit(f'Duplicate localization key: {key}')

# 4) Required feature references in main & login
main = (root / 'lib/main.dart').read_text(encoding='utf-8')
login = (root / 'lib/presentation/screens/enterprise_login.dart').read_text(encoding='utf-8')
auth = (root / 'lib/core/services/auth_service.dart').read_text(encoding='utf-8')

for needle, label in [
    ('WidgetsFlutterBinding.ensureInitialized()', 'Flutter binding init'),
    ('DefaultFirebaseOptions.currentPlatform', 'Firebase options'),
    ('AuthService(store)', 'LocalStore/Auth wiring'),
    ("fontFamily: GoogleFonts.cairo().fontFamily", 'Configured Arabic font'),
]:
    if needle not in main: raise SystemExit(f'Missing {label} in main.dart')

for needle, label in [
    ('enterOffline()', 'Offline login action'),
    ('الدخول أوفلاين', 'Offline button label'),
    ('_AnimatedLogo', 'Login logo animation'),
]:
    if needle not in login: raise SystemExit(f'Missing {label} in enterprise_login.dart')

# 5) PDF code check
for path in lib.rglob('*.dart'):
    s = path.read_text(encoding='utf-8')
    if 'FractionallySizedBox' in s:
        raise SystemExit(f'Flutter PDF widget found: {path}')

# 6) Required service imports
for path in [root / 'lib/main.dart', root / 'lib/presentation/screens/level2_municipality.dart']:
    s = path.read_text(encoding='utf-8')
    if 'ExcelService' in s and "core/services/excel_service.dart" not in s:
        raise SystemExit(f'Missing ExcelService import: {path}')

for path in [root / 'lib/main.dart', root / 'lib/core/services/auth_service.dart']:
    s = path.read_text(encoding='utf-8')
    if 'LocalStore' in s and "local_store.dart" not in s:
        raise SystemExit(f'Missing LocalStore import: {path}')

# 7) YAML / JSON / XML & asset checks
yaml.safe_load((root / 'pubspec.yaml').read_text(encoding='utf-8'))
json.loads((root / 'android/app/google-services.json').read_text(encoding='utf-8'))
ET.parse(root / 'android/app/src/main/AndroidManifest.xml')

for asset in [
    'assets/app_icon.png',
    'assets/brand/cleanops_logo_new.png',
    'assets/brand/cleanops_icon_new.png',
    'assets/fonts/NotoSansArabic-Regular.ttf',
    'assets/fonts/NotoSansArabic-Bold.ttf',
]:
    if not (root / asset).exists():
        raise SystemExit(f'Missing asset: {asset}')

icons = list((root / 'android/app/src/main/res').glob('mipmap-*/ic_launcher.png'))
if len(icons) < 5:
    raise SystemExit('Not all Android launcher densities exist')

print('ALL_STATIC_CHECKS_PASSED')
print(f'Dart files checked: {len(files)}')
print(f'Launcher density icons checked: {len(icons)}')
PY

echo '--- Firebase rules sanity ---'
grep -q "allow delete: if false" "$ROOT/firebase/firestore.rules"
grep -q "donor_manager" "$ROOT/firebase/firestore.rules"
grep -q "municipality_coordinator" "$ROOT/firebase/firestore.rules"
grep -q "jsc_coordinator" "$ROOT/firebase/firestore.rules"
echo 'FIRESTORE_RULES_STATIC_CHECK_PASSED'
