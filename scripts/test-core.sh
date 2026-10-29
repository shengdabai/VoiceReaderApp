#!/usr/bin/env bash
set -euo pipefail

# Run the Foundation-only tests on macOS without resolving iOS dependencies.
# This does not build the app or cover PDF/EPUB, playback, recording, or the UI.
root="$(cd "$(dirname "$0")/.." && pwd)"
harness="$root/.omc/core-tests.nosync"  # ~200MB of build output; .nosync keeps it out of iCloud
mkdir -p "$harness/Sources" "$harness/Tests" "$harness/module-cache" \
  "$harness/cache" "$harness/configuration" "$harness/security"

python3 - "$root" "$harness" <<'PY'
from pathlib import Path
import sys

root, harness = map(Path, sys.argv[1:])
sources = [
    'Models/SpeedPreset.swift',
    'Models/ReadingPosition.swift',
    'Models/ArticleImport.swift',
    'Models/BookFormat.swift',
    'Models/ImportedDocument.swift',
    'Services/Persistence/ReadingProgressStore.swift',
    'Services/Parsing/TextParser.swift',
    'Services/Parsing/TXTTextParser.swift',
    'Services/Parsing/MarkdownTextParser.swift',
    'Services/Import/URLArticleExtractor.swift',
    'Services/Import/DocumentImporter.swift',
]
tests = [
    'SpeedPresetTests.swift',
    'ReadingProgressStoreTests.swift',
    'URLArticleExtractorTests.swift',
    'MarkdownTextParserTests.swift',
]
for names, folder, prefix in [
    (sources, 'Sources', 'App/Sources'),
    (tests, 'Tests', 'App/Tests'),
]:
    for name in names:
        source = root / prefix / name
        link = harness / folder / source.name
        if not link.is_symlink():
            link.symlink_to(source)
        elif link.resolve() != source:
            raise SystemExit(f'Unexpected test harness link: {link}')

(harness / 'Package.swift').write_text('''// swift-tools-version: 5.10
import PackageDescription
let package = Package(name: "VoiceReaderCoreChecks", platforms: [.macOS(.v13)], targets: [
    .target(name: "VoiceReaderApp", path: "Sources"),
    .testTarget(name: "VoiceReaderAppTests", dependencies: ["VoiceReaderApp"], path: "Tests")
])
''')
PY

CLANG_MODULE_CACHE_PATH="$harness/module-cache" \
SWIFT_MODULECACHE_PATH="$harness/module-cache" \
swift test --package-path "$harness" --scratch-path "$harness/.build" \
  --cache-path "$harness/cache" --config-path "$harness/configuration" \
  --security-path "$harness/security" --disable-sandbox "$@"
