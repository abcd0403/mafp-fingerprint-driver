#!/usr/bin/env bash
set -euo pipefail

LP="${1:-/tmp/libfprint-src/libfprint-v1.94.10}"
PATCH="$(cd "$(dirname "$0")/.." && pwd)/patches/0001-libfprint-add-microarray-3274-8012-driver.patch"

if [[ ! -d "$LP" ]]; then
  echo "libfprint source tree not found: $LP" >&2
  exit 1
fi

echo "[1/5] apply patch"
cd "$LP"
patch -p1 < "$PATCH"

echo "[2/5] configure"
rm -rf build-microarray
meson setup build-microarray -Ddoc=false -Dgtk-examples=false -Dintrospection=false

echo "[3/5] build"
meson compile -C build-microarray

echo "[4/5] install"
sudo install -m 0755 build-microarray/libfprint/libfprint-2.so.2.0.0 /usr/lib64/libfprint-2.so.2.0.0

# Important: do not keep backup .bak file under /usr/lib64
sudo ldconfig

echo "[5/5] restart fprintd"
sudo systemctl restart fprintd

echo "done. run: fprintd-list \$USER"
