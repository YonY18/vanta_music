#!/usr/bin/env bash
set -euo pipefail

if ! command -v g++ >/dev/null 2>&1; then
  echo "g++ was not found; install g++ to run native C++ host tests." >&2
  exit 127
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$repo_root/packages/vanta_audio_engine/android/src/test/cpp"
include_dir="$repo_root/packages/vanta_audio_engine/android/src/main/cpp/native"
build_dir="$repo_root/build/native_cpp_tests"

mkdir -p "$build_dir"

shopt -s nullglob
tests=("$test_dir"/*_test.cpp)
if ((${#tests[@]} == 0)); then
  echo "No native C++ host tests found in $test_dir"
  exit 0
fi

for test_file in "${tests[@]}"; do
  test_name="$(basename "$test_file" .cpp)"
  binary="$build_dir/$test_name"
  echo "[native-cpp] compile $test_name"
  g++ -std=c++17 -Wall -Wextra -Werror -pthread -I"$include_dir" "$test_file" -o "$binary"
  echo "[native-cpp] run $test_name"
  "$binary"
done

echo "[native-cpp] ${#tests[@]} host tests passed."
echo "[native-cpp] Coverage note: host tests protect pure render/output/lifecycle seams; full miniaudio device open/close sequencing remains protected by Android native build/device validation."
