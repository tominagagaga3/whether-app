#!/usr/bin/env bash
set -euo pipefail

# 1) Flutterのリリース一覧(JSON)を取得
curl -fsSL -o releases_linux.json \
  https://storage.googleapis.com/flutter_infra/releases/releases_linux.json

# 2) stableの「最新アーカイブパス」をJSONから取り出す（pythonで安全にパース）
ARCHIVE_PATH=$(python3 - <<'PY'
import json
d=json.load(open("releases_linux.json"))
stable_hash=d["current_release"]["stable"]
for r in d["releases"]:
    if r.get("hash")==stable_hash:
        print(r["archive"])
        break
else:
    raise SystemExit("stable archive not found")
PY
)

# 3) Flutter SDKをダウンロード＆展開
BASE_URL=$(python3 - <<'PY'
import json
d=json.load(open("releases_linux.json"))
print(d["base_url"])
PY
)

echo "Downloading Flutter SDK: ${BASE_URL}/${ARCHIVE_PATH}"
curl -fsSL "${BASE_URL}/${ARCHIVE_PATH}" | tar -xJ

# 4) PATHを通してビルド
export PATH="$PWD/flutter/bin:$PATH"
git config --global --add safe.directory "$PWD/flutter"
git config --global --add safe.directory "$PWD"
flutter --version
flutter pub get
flutter build web --release