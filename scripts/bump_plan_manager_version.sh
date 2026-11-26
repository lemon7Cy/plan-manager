#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$PROJECT_ROOT" "$@" <<'PY'
from decimal import Decimal
from pathlib import Path
import plistlib
import re
import sys

root = Path(sys.argv[1])
args = sys.argv[2:]
if args not in ([], ['--check']):
    raise SystemExit('Usage: scripts/bump_plan_manager_version.sh [--check]')

plist_path = root / 'Plan Manager/Plan Manager/Info.plist'
project_path = root / 'Plan Manager/Plan Manager.xcodeproj/project.pbxproj'
spec_path = root / 'Plan Manager/project.yml'
plist = plistlib.loads(plist_path.read_bytes())
project = project_path.read_text()
spec = spec_path.read_text()
current = plist['CFBundleShortVersionString']
if not re.fullmatch(r'\d+\.\d{2}', current):
    raise SystemExit('Marketing version must use X.YY format')
project_versions = re.findall(r'MARKETING_VERSION = ([^;]+);', project)
spec_versions = re.findall(r'(?:MARKETING_VERSION|CFBundleShortVersionString): "([^"]+)"', spec)
if not project_versions or len(spec_versions) != 2 or set(project_versions + spec_versions) != {current}:
    raise SystemExit('Version fields are inconsistent; synchronize Info.plist, project.pbxproj and project.yml first')
if args == ['--check']:
    print(f'Version fields consistent: {current}')
    raise SystemExit(0)

next_version = f'{Decimal(current) + Decimal("0.01"):.2f}'
plist['CFBundleShortVersionString'] = next_version
project = re.sub(r'MARKETING_VERSION = [^;]+;', f'MARKETING_VERSION = {next_version};', project)
spec = re.sub(r'((?:MARKETING_VERSION|CFBundleShortVersionString): ")[^"]+(")',
              lambda match: match[1] + next_version + match[2], spec)
plist_path.write_bytes(plistlib.dumps(plist, sort_keys=False))
project_path.write_text(project)
spec_path.write_text(spec)
print(f'Marketing version: {current} -> {next_version}')
PY
