#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen 未安装，请先执行: brew install xcodegen"
  exit 1
fi

xcodegen generate

echo "工程已生成：$(pwd)/VoiceReaderApp.xcodeproj"
echo "下一步：open VoiceReaderApp.xcodeproj"
