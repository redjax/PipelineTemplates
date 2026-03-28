#!/usr/bin/env bash
set -euo pipefail

TEMPLATE="${1:?template key required}"
VERSION="${2:?version required}"
MANIFEST="manifests/versions.yml"

python3 - <<PY
from pathlib import Path
import yaml

path = Path("$MANIFEST")
data = yaml.safe_load(path.read_text()) or {}
data["$TEMPLATE"] = "$VERSION"
path.write_text(yaml.safe_dump(data, sort_keys=False))
PY

git add "$MANIFEST"
git commit -m "Release ${TEMPLATE} ${VERSION}"
git tag -a "${TEMPLATE}/${VERSION}" -m "${TEMPLATE} ${VERSION}"