#!/usr/bin/env python3
"""
Patch MainActivity.smali to force-load Frida Gadget
Adds System.loadLibrary("frida-gadget") at the start of onCreate
"""

import sys
import os
import glob

# Smali code to inject (loads Gadget with error handling)
GADGET_LOADER = """
    .locals 1

    const-string v0, "frida-gadget"
    :try_start
    invoke-static {v0}, Ljava/lang/System;->loadLibrary(Ljava/lang/String;)V
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :catch_block

    goto :end

    :catch_block
    move-exception v0
    invoke-virtual {v0}, Ljava/lang/Throwable;->printStackTrace()V

    :end
"""

def find_mainactivity_smali(work_dir):
    """Find MainActivity.smali file"""
    patterns = [
        f"{work_dir}/smali*/com/fyp/bioshield/bioshield/MainActivity.smali",
        f"{work_dir}/smali/com/fyp/bioshield/bioshield/MainActivity.smali",
        f"{work_dir}/smali*/io/flutter/embedding/android/FlutterActivity.smali"
    ]

    for pattern in patterns:
        matches = glob.glob(pattern)
        if matches:
            return matches[0]

    return None

def patch_smali(smali_path):
    """Add Gadget loader to onCreate method"""
    with open(smali_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Check if already patched
    if 'frida-gadget' in content:
        print("[OK] Already patched (frida-gadget found)")
        return

    # Find onCreate method
    oncreate_pattern = r'(\.method\s+(?:public\s+)?onCreate\(Landroid/os/Bundle;\)V\s*\n)'

    import re
    match = re.search(oncreate_pattern, content)

    if not match:
        print("[WARNING] Could not find onCreate method")
        return

    # Insert Gadget loader right after method declaration
    insertion_point = match.end()
    new_content = content[:insertion_point] + GADGET_LOADER + content[insertion_point:]

    with open(smali_path, 'w', encoding='utf-8') as f:
        f.write(new_content)

    print(f"[OK] Patched {os.path.basename(smali_path)}")

def main(work_dir):
    smali_path = find_mainactivity_smali(work_dir)

    if not smali_path:
        print("ERROR: Could not find MainActivity.smali")
        print("Searched in:")
        print(f"  {work_dir}/smali*/com/fyp/bioshield/bioshield/MainActivity.smali")
        sys.exit(1)

    print(f"Found: {smali_path}")
    patch_smali(smali_path)

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: patch_mainactivity.py <work_dir>")
        sys.exit(1)

    main(sys.argv[1])
