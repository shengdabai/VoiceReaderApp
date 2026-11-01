#!/usr/bin/env python3
"""Verify XcodeGen preserves app capabilities without modifying the checkout."""
import pathlib
import plistlib
import re
import shutil
import subprocess
import tempfile
import unittest


class ProjectConfigurationTests(unittest.TestCase):
    def test_generation_preserves_app_configuration(self):
        root = pathlib.Path(__file__).resolve().parents[1]
        expected = plistlib.loads((root / "App/Resources/Info.plist").read_bytes())
        self.assertIn("NSMicrophoneUsageDescription", expected)
        self.assertEqual(expected["UIBackgroundModes"], ["audio"])
        self.assertFalse(expected["NSAppTransportSecurity"]["NSAllowsArbitraryLoads"])
        with tempfile.TemporaryDirectory(prefix="voicereader-config-") as temporary:
            copy = pathlib.Path(temporary)
            for folder in ("App/Sources", "App/Tests", "App/Resources"):
                (copy / folder).mkdir(parents=True)
            shutil.copy2(root / "project.yml", copy / "project.yml")
            plist = copy / "App/Resources/Info.plist"
            shutil.copy2(root / "App/Resources/Info.plist", plist)
            for generation in range(2):
                result = subprocess.run([
                    "xcodegen", "generate", "--no-env", "--quiet",
                    "--spec", str(copy / "project.yml"), "--project", str(copy),
                ], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                actual = plistlib.loads(plist.read_bytes())
                for key, value in expected.items():
                    with self.subTest(generation=generation, key=key):
                        self.assertEqual(actual.get(key), value)
            project = (copy / "VoiceReaderApp.xcodeproj/project.pbxproj").read_text()
            source = copy / "LanguageCheck.swift"
            source.write_text("let value = 1\n")
            for version in set(re.findall(r"SWIFT_VERSION = ([^;]+);", project)):
                result = subprocess.run([
                    "xcrun", "swiftc", "-typecheck", "-swift-version", version.strip('"').removesuffix(".0"),
                    "-module-cache-path", str(copy / "cache"), str(source),
                ], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
