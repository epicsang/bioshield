#!/usr/bin/env python3
"""
Patch AndroidManifest.xml to add extractNativeLibs="true"
"""

import sys
import re

def patch_manifest(manifest_path):
    with open(manifest_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Check if already has extractNativeLibs
    if 'android:extractNativeLibs' in content:
        print("[OK] extractNativeLibs already present")
        return

    # Add extractNativeLibs="true" to <application> tag
    pattern = r'(<application[^>]*?)>'
    replacement = r'\1\n        android:extractNativeLibs="true">'

    new_content = re.sub(pattern, replacement, content)

    if new_content == content:
        print("[WARNING] Could not find <application> tag")
        return

    with open(manifest_path, 'w', encoding='utf-8') as f:
        f.write(new_content)

    print("[OK] Added android:extractNativeLibs=\"true\"")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: patch_manifest.py <AndroidManifest.xml>")
        sys.exit(1)

    patch_manifest(sys.argv[1])
