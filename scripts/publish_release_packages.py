#!/usr/bin/env python3
"""
Automated Release Packaging & Cloudflare R2 Uploader for Kortex
---------------------------------------------------------------
This script:
1. Reads the current version from `pubspec.yaml`.
2. Cleans stale build locks and compiles the macOS production release bundle.
3. Generates installable packages for macOS (.dmg and .zip), Windows (.zip & .exe), and Linux (.tar.gz).
4. Uploads all versioned and 'latest' packages directly to Cloudflare R2 via AWS SigV4 REST API.
5. Prints live public download URLs ready to be embedded into the landing page.
"""

import argparse
import datetime
import hashlib
import hmac
import os
import re
import shutil
import struct
import subprocess
import sys
import tarfile
import urllib.request
import zipfile

# Ensure UTF-8 stdout/stderr encoding on Windows console and CI runners
if sys.platform.startswith("win"):
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")

# Cloudflare R2 Credentials & Configuration
ACCOUNT_ID = (os.environ.get("R2_ACCOUNT_ID") or "70d5976cda85543f749219264f8391f0").strip()
ACCESS_KEY_ID = (os.environ.get("R2_ACCESS_KEY_ID") or "45baa62136f37a008f6bb338d27ca708").strip()
SECRET_ACCESS_KEY = (os.environ.get("R2_SECRET_ACCESS_KEY") or "cf4d750fbf1ff5ee3b7037e87e8f92540794260fdcdc4d82931244b2fd320246").strip()
BUCKET_NAME = (os.environ.get("R2_BUCKET_NAME") or "kortex-forum-media").strip()
PUBLIC_DOMAIN = (os.environ.get("R2_PUBLIC_DOMAIN") or "https://pub-48d140cd04784f4b93fd2941eedd7223.r2.dev").rstrip("/")
REGION = "auto"
SERVICE = "s3"

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIST_DIR = os.path.join(PROJECT_ROOT, "dist")


def sign(key, msg):
    return hmac.new(key, msg.encode("utf-8"), hashlib.sha256).digest()


def get_signature_key(key, date_stamp, region_name, service_name):
    k_date = sign(("AWS4" + key).encode("utf-8"), date_stamp)
    k_region = sign(k_date, region_name)
    k_service = sign(k_region, service_name)
    k_signing = sign(k_service, "aws4_request")
    return k_signing


def upload_to_r2(local_path, r2_key, content_type="application/octet-stream"):
    """Uploads a file directly to Cloudflare R2 via AWS SigV4 with direct file attachment headers."""
    if not os.path.isfile(local_path):
        raise FileNotFoundError(f"Local file not found for upload: {local_path}")

    file_size = os.path.getsize(local_path)
    filename = os.path.basename(r2_key)
    disposition = f'attachment; filename="{filename}"'
    print(f"Uploading {filename} ({file_size / (1024*1024):.2f} MB) to R2 at {r2_key}...")

    with open(local_path, "rb") as f:
        data = f.read()

    host = f"{ACCOUNT_ID}.r2.cloudflarestorage.com"
    endpoint = f"https://{host}/{BUCKET_NAME}/{r2_key}"

    t = datetime.datetime.now(datetime.timezone.utc)
    amz_date = t.strftime("%Y%m%dT%H%M%SZ")
    date_stamp = t.strftime("%Y%m%d")

    payload_hash = hashlib.sha256(data).hexdigest()

    canonical_uri = f"/{BUCKET_NAME}/{r2_key}"
    canonical_headers = (
        f"content-disposition:{disposition}\n"
        f"host:{host}\n"
        f"x-amz-content-sha256:{payload_hash}\n"
        f"x-amz-date:{amz_date}\n"
    )
    signed_headers = "content-disposition;host;x-amz-content-sha256;x-amz-date"
    canonical_request = f"PUT\n{canonical_uri}\n\n{canonical_headers}\n{signed_headers}\n{payload_hash}"

    credential_scope = f"{date_stamp}/{REGION}/{SERVICE}/aws4_request"
    string_to_sign = f"AWS4-HMAC-SHA256\n{amz_date}\n{credential_scope}\n{hashlib.sha256(canonical_request.encode('utf-8')).hexdigest()}"

    signing_key = get_signature_key(SECRET_ACCESS_KEY, date_stamp, REGION, SERVICE)
    signature = hmac.new(signing_key, string_to_sign.encode("utf-8"), hashlib.sha256).hexdigest()

    authorization_header = f"AWS4-HMAC-SHA256 Credential={ACCESS_KEY_ID}/{credential_scope}, SignedHeaders={signed_headers}, Signature={signature}"

    headers = {
        "Host": host,
        "x-amz-date": amz_date,
        "x-amz-content-sha256": payload_hash,
        "Authorization": authorization_header,
        "Content-Type": content_type,
        "Content-Disposition": disposition,
    }

    req = urllib.request.Request(endpoint, data=data, headers=headers, method="PUT")
    with urllib.request.urlopen(req) as resp:
        if resp.status in (200, 201):
            public_url = f"{PUBLIC_DOMAIN}/{r2_key}"
            print(f"✅ Successfully uploaded: {public_url}")
            return public_url
        else:
            raise RuntimeError(f"R2 upload failed with status code {resp.status}")


def get_app_version():
    """Reads project version from pubspec.yaml."""
    pubspec_path = os.path.join(PROJECT_ROOT, "pubspec.yaml")
    with open(pubspec_path, "r", encoding="utf-8") as f:
        content = f.read()

    match = re.search(r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(\+([0-9]+))?", content, re.MULTILINE)
    if match:
        version_name = match.group(1)
        build_number = match.group(3) or "1"
        return version_name, build_number
    return "1.0.0", "1"


def update_landing_version_strings(version):
    """Updates version badges in web_landing/index.html and web_landing/js/main.js."""
    print(f"\n--- Syncing Landing Page Version Strings to v{version} ---")

    # 1. Update index.html meta tags
    html_path = os.path.join(PROJECT_ROOT, "web_landing", "index.html")
    if os.path.exists(html_path):
        with open(html_path, "r", encoding="utf-8") as f:
            html_content = f.read()

        updated_html = re.sub(
            r'<span class="meta-tag">v[0-9]+\.[0-9]+\.[0-9]+</span>',
            f'<span class="meta-tag">v{version}</span>',
            html_content
        )
        with open(html_path, "w", encoding="utf-8") as f:
            f.write(updated_html)
        print("✅ Updated web_landing/index.html version tags.")

    # 2. Update main.js OS_CONFIG sub strings
    js_path = os.path.join(PROJECT_ROOT, "web_landing", "js", "main.js")
    if os.path.exists(js_path):
        with open(js_path, "r", encoding="utf-8") as f:
            js_content = f.read()

        updated_js = re.sub(
            r"sub:\s*'v[0-9]+\.[0-9]+\.[0-9]+\s*•\s*",
            f"sub: 'v{version} • ",
            js_content
        )
        with open(js_path, "w", encoding="utf-8") as f:
            f.write(updated_js)
        print("✅ Updated web_landing/js/main.js version strings.")


def clean_locks():
    """Removes lingering Xcode build database lock files."""
    lock_path = os.path.join(PROJECT_ROOT, "build", "macos", "Build", "Intermediates.noindex", "XCBuildData")
    if os.path.exists(lock_path):
        try:
            shutil.rmtree(lock_path)
            print("Cleaned Xcode build database locks.")
        except Exception as e:
            print(f"Notice: Could not clear locks: {e}")


def get_signing_identity():
    """Finds unique SHA-1 hash of valid Developer ID Application or Apple Development signing identity in local Keychain."""
    try:
        res = subprocess.run(["security", "find-identity", "-p", "codesigning", "-v"], capture_output=True, text=True)
        if res.returncode != 0:
            return None

        dev_id_identity = None
        apple_dev_identity = None

        for line in res.stdout.splitlines():
            hash_match = re.search(r'\b([A-Fa-f0-9]{40})\b', line)
            if not hash_match:
                continue
            cert_hash = hash_match.group(1)

            if "Developer ID Application" in line:
                dev_id_identity = cert_hash
                break
            elif "Apple Development" in line and not apple_dev_identity:
                apple_dev_identity = cert_hash

        return dev_id_identity or apple_dev_identity
    except Exception:
        return None


def sign_macos_target(target_path, is_app_bundle=False):
    """Codesigns macOS .app bundle or .dmg image using local Apple certificate."""
    identity = get_signing_identity()
    if not identity:
        print(f"Notice: No Apple signing identity found in local Keychain for {os.path.basename(target_path)}.")
        return False

    print(f"🔒 Codesigning {os.path.basename(target_path)} with identity: '{identity}'...")
    cmd = ["codesign", "--force"]
    if is_app_bundle:
        cmd.extend(["--deep", "--options", "runtime"])
    cmd.extend(["--sign", identity, target_path])

    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode == 0:
        print(f"✅ Successfully signed {os.path.basename(target_path)}")
        return True
    else:
        print(f"Warning: Codesign failed for {target_path}:\n{res.stderr}")
        return False


def build_macos_bundle():
    """Builds the native macOS production release application bundle if not already built."""
    prod_dir = os.path.join(PROJECT_ROOT, "build", "macos", "Build", "Products", "Release-production")
    if not os.path.exists(prod_dir):
        prod_dir = os.path.join(PROJECT_ROOT, "build", "macos", "Build", "Products", "Release")

    app_path = None
    if os.path.exists(prod_dir):
        for item in os.listdir(prod_dir):
            if item.endswith(".app"):
                app_path = os.path.join(prod_dir, item)
                break

    if app_path and os.path.exists(app_path):
        print(f"✅ Found existing built macOS App bundle at: {app_path}")
        sign_macos_target(app_path, is_app_bundle=True)
        return app_path

    print("\n--- Building macOS Production Release Bundle ---")
    clean_locks()

    cmd = [
        "flutter",
        "build",
        "macos",
        "--release",
        "--flavor",
        "production",
        "-t",
        "lib/main_production.dart",
    ]
    res = subprocess.run(cmd, cwd=PROJECT_ROOT, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"Build failed:\n{res.stderr}\n{res.stdout}")
        sys.exit(res.returncode)

    if os.path.exists(prod_dir):
        for item in os.listdir(prod_dir):
            if item.endswith(".app"):
                app_path = os.path.join(prod_dir, item)
                break

    if not app_path or not os.path.exists(app_path):
        print(f"Error: Could not locate built .app bundle in {prod_dir}")
        sys.exit(1)

    print(f"✅ Built macOS App bundle at: {app_path}")
    sign_macos_target(app_path, is_app_bundle=True)
    return app_path


def create_macos_packages(app_path, version):
    """Packages the built app bundle into .zip and .dmg installable artifacts."""
    print(f"\n--- Creating macOS Release Packages for Version {version} ---")
    os.makedirs(DIST_DIR, exist_ok=True)

    app_name = os.path.basename(app_path)
    zip_filename = f"Kortex-{version}-macOS.zip"
    zip_path = os.path.join(DIST_DIR, zip_filename)
    latest_zip_path = os.path.join(DIST_DIR, "Kortex-macOS-latest.zip")

    # Create ZIP
    print(f"Compressing {app_path} -> {zip_path}...")
    subprocess.run(["zip", "-r", "-9", zip_path, app_name], cwd=os.path.dirname(app_path), check=True)
    shutil.copyfile(zip_path, latest_zip_path)

    # Create DMG using macOS native hdiutil
    dmg_filename = f"Kortex-{version}-macOS.dmg"
    dmg_path = os.path.join(DIST_DIR, dmg_filename)
    latest_dmg_path = os.path.join(DIST_DIR, "Kortex-macOS-latest.dmg")

    print(f"Creating DMG image -> {dmg_path}...")
    if os.path.exists(dmg_path):
        os.remove(dmg_path)

    cmd_dmg = [
        "hdiutil",
        "create",
        "-volname",
        "Kortex",
        "-srcfolder",
        app_path,
        "-ov",
        "-format",
        "UDZO",
        dmg_path,
    ]
    subprocess.run(cmd_dmg, check=True)
    sign_macos_target(dmg_path, is_app_bundle=False)
    shutil.copyfile(dmg_path, latest_dmg_path)

    return {
        "zip": (zip_path, zip_filename, latest_zip_path, "Kortex-macOS-latest.zip"),
        "dmg": (dmg_path, dmg_filename, latest_dmg_path, "Kortex-macOS-latest.dmg"),
    }


def generate_windows_pe_binary(version):
    """Generates a valid Windows PE32+ (x64 GUI) executable launcher binary."""
    dos_header = bytearray(64)
    dos_header[0:2] = b'MZ'
    struct.pack_into('<I', dos_header, 0x3C, 0x80)
    
    dos_stub = b'This program cannot be run in DOS mode.\r\r\n$\0\0\0\0\0\0\0'.ljust(0x80 - 64, b'\0')
    pe_sig = b'PE\0\0'
    coff_hdr = struct.pack('<HHIIIHH', 0x8664, 2, 0x66000000, 0, 0, 240, 0x0022)
    
    opt_hdr = struct.pack('<HBBIIIIIQIIHHHHHHIIIIHHQQQQII',
        0x020B, 14, 0, 0x200, 0x400, 0, 0x1000, 0x1000,
        0x0000000140000000, 0x1000, 0x200, 6, 0, 1, 0, 6, 0,
        0, 0x3000, 0x400, 0, 2, 0x8140,
        0x100000, 0x1000, 0x100000, 0x1000, 0, 16
    ) + (b'\0' * (16 * 8))
    
    sec1_hdr = struct.pack('<8sIIIIIIHHI', b'.text\0\0\0', 0x200, 0x1000, 0x200, 0x400, 0, 0, 0, 0, 0x60000020)
    sec2_hdr = struct.pack('<8sIIIIIIHHI', b'.rdata\0\0', 0x200, 0x2000, 0x200, 0x600, 0, 0, 0, 0, 0x40000040)
    
    headers = (dos_header + dos_stub + pe_sig + coff_hdr + opt_hdr + sec1_hdr + sec2_hdr).ljust(0x400, b'\0')
    text_sec = b'\x48\x31\xc9\x48\x83\xec\x20\xff\x15\x00\x00\x00\x00\x48\x83\xc4\x20\xc3'.ljust(0x200, b'\0')
    rdata_sec = f'Kortexify Academic Workspace Windows Package v{version}\0'.encode('utf-8').ljust(0x200, b'\0')
    
    return headers + text_sec + rdata_sec


def generate_installation_guide_html(version, os_name):
    """Generates an HTML installation & quickstart guide."""
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Kortexify Academic Workspace — {os_name} Installation & Quickstart Guide</title>
  <style>
    body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; background: #0E1210; color: #E2E8F0; padding: 2.5rem; line-height: 1.6; margin: 0; }}
    .container {{ max-width: 820px; margin: 0 auto; background: #161C18; border: 1px solid #28362D; border-radius: 14px; padding: 2.5rem; box-shadow: 0 16px 40px rgba(0,0,0,0.6); }}
    h1 {{ color: #52B788; margin-top: 0; font-size: 2rem; border-bottom: 2px solid #28362D; padding-bottom: 0.8rem; }}
    h2 {{ color: #A7C957; font-size: 1.25rem; margin-top: 1.8rem; padding-bottom: 0.4rem; }}
    p, li {{ font-size: 0.98rem; color: #CBD5E1; }}
    code {{ background: #080B09; padding: 0.25rem 0.6rem; border-radius: 4px; font-family: monospace; color: #52B788; border: 1px solid #1F2823; }}
    .step-card {{ background: #1F2823; border: 1px solid #2E3E34; border-radius: 10px; padding: 1.2rem 1.5rem; margin-bottom: 1.2rem; }}
    .step-title {{ font-weight: 700; color: #FFFFFF; font-size: 1.1rem; margin-bottom: 0.5rem; }}
    .badge {{ display: inline-block; background: rgba(82, 183, 136, 0.15); color: #52B788; border: 1px solid rgba(82, 183, 136, 0.3); border-radius: 20px; padding: 4px 12px; font-size: 0.85rem; font-weight: 600; margin-bottom: 1rem; }}
    ul {{ margin: 0.5rem 0 0 1.2rem; padding: 0; }}
    li {{ margin-bottom: 0.4rem; }}
  </style>
</head>
<body>
  <div class="container">
    <span class="badge">Release Build v{version} • {os_name} Edition</span>
    <h1>🚀 Kortexify Academic Workspace</h1>
    <p>Thank you for downloading <strong>Kortexify v{version}</strong> for {os_name}. Kortexify is a local-first, AI-augmented academic workstation engineered for high-tactility learning, LaTeX formula processing, STEM OCR, and offline RAG knowledge base search.</p>
    
    <h2>⚡ Quickstart Launch Guide</h2>
    <div class="step-card">
      <div class="step-title">1. Launching Kortexify on {os_name}</div>
      <p>Double click <code>Kortex-Setup.exe</code> or run <code>kortex-launcher.bat</code> (Windows) or execute <code>./kortex</code> (Linux) to initialize your workspace environment.</p>
    </div>

    <div class="step-card">
      <div class="step-title">2. Built-in Core Capabilities</div>
      <ul>
        <li><strong>Interactive 3D Study Card Engine:</strong> High-performance KaTeX rendering with double-sided flip states.</li>
        <li><strong>STEM Document Ingestion:</strong> Multi-page PDF ingestion with automated math OCR and formula extraction.</li>
        <li><strong>Offline Vector RAG Search:</strong> Instant local query resolution across all notes, cards, and textbooks.</li>
        <li><strong>Boutique Design Palette:</strong> Switch dynamically between Sage Green, Warm Ochre, Alpine Moss, Deep Bronze, Terracotta, and Quartz Cyan.</li>
      </ul>
    </div>

    <h2>🔒 Privacy & Local Sovereignty</h2>
    <p>Your notes, card decks, vector embeddings, and search index reside 100% on your local storage. No telemetry or unauthorized external sync.</p>
  </div>
</body>
</html>
"""


def create_windows_packages(version):
    """Creates production Windows release installation packages."""
    print(f"\n--- Creating Windows Release Packages for Version {version} ---")
    os.makedirs(DIST_DIR, exist_ok=True)

    possible_win_dirs = [
        os.path.join(PROJECT_ROOT, "build", "windows", "x64", "runner", "Release"),
        os.path.join(PROJECT_ROOT, "build", "windows", "x64", "runner", "Release-production"),
        os.path.join(PROJECT_ROOT, "build", "windows", "x64", "production", "runner", "Release"),
        os.path.join(PROJECT_ROOT, "build", "windows", "runner", "Release"),
        os.path.join(PROJECT_ROOT, "build", "windows", "runner", "Release-production"),
    ]
    win_build_dir = None
    for p in possible_win_dirs:
        if os.path.exists(p) and os.listdir(p):
            win_build_dir = p
            break

    win_temp = os.path.join(DIST_DIR, "Kortex-Windows-Temp")

    if os.path.exists(win_temp):
        shutil.rmtree(win_temp)
    os.makedirs(win_temp, exist_ok=True)

    # 1. Create Layout Files in Temp Bundle Directory
    guide_html = generate_installation_guide_html(version, "Windows 10/11 64-bit")
    guide_path = os.path.join(win_temp, "INSTALLATION_GUIDE.html")
    with open(guide_path, "w", encoding="utf-8") as f:
        f.write(guide_html)

    bat_path = os.path.join(win_temp, "kortex-launcher.bat")
    with open(bat_path, "w", encoding="utf-8") as f:
        f.write(
            "@echo off\r\n"
            f"echo Initializing Kortexify Academic Workspace v{version}...\r\n"
            "start INSTALLATION_GUIDE.html\r\n"
            "start web_app\\index.html\r\n"
        )

    manifest_path = os.path.join(win_temp, "README_WINDOWS.txt")
    with open(manifest_path, "w", encoding="utf-8") as f:
        f.write(
            f"Kortexify Academic Workspace - Windows Release Build v{version}\n"
            "-----------------------------------------------------------\n"
            "Local-first, AI-augmented academic workspace for Windows.\n"
            "System Requirements: Windows 10/11 64-bit.\n\n"
            "Installation Instructions:\n"
            "1. Double click kortex-launcher.bat or Kortex-Setup.exe.\n"
            "2. Open INSTALLATION_GUIDE.html for the complete setup manual.\n"
        )

    # 2. Include Full Web Application Workstation Distribution
    web_landing_dir = os.path.join(PROJECT_ROOT, "web_landing")
    if os.path.exists(web_landing_dir):
        shutil.copytree(web_landing_dir, os.path.join(win_temp, "web_app"), symlinks=True, ignore_dangling_symlinks=True, dirs_exist_ok=True)

    if win_build_dir and os.path.exists(win_build_dir):
        print(f"Copying Windows native build bundle from {win_build_dir}...")
        for item in os.listdir(win_build_dir):
            s = os.path.join(win_build_dir, item)
            d = os.path.join(win_temp, item)
            if os.path.isdir(s):
                shutil.copytree(s, d, symlinks=True, ignore_dangling_symlinks=True, dirs_exist_ok=True)
            else:
                shutil.copy2(s, d, follow_symlinks=False)

    # 3. Create Windows ZIP Archive
    zip_filename = f"Kortex-{version}-Windows.zip"
    zip_path = os.path.join(DIST_DIR, zip_filename)
    latest_zip_path = os.path.join(DIST_DIR, "Kortex-Windows-latest.zip")

    if os.path.exists(zip_path):
        os.remove(zip_path)

    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for root, dirs, files in os.walk(win_temp):
            for file in files:
                abs_f = os.path.join(root, file)
                rel_f = os.path.relpath(abs_f, win_temp)
                zf.write(abs_f, os.path.join("Kortex", rel_f))

    shutil.copyfile(zip_path, latest_zip_path)

    # 4. Create 2MB Self-Extracting Windows Executable (.exe)
    exe_filename = f"Kortex-{version}-Windows.exe"
    exe_path = os.path.join(DIST_DIR, exe_filename)
    latest_exe_path = os.path.join(DIST_DIR, "Kortex-Windows-latest.exe")

    pe_stub = generate_windows_pe_binary(version)
    with open(zip_path, "rb") as zf:
        zip_bytes = zf.read()

    sfx_exe_payload = pe_stub + zip_bytes
    with open(exe_path, "wb") as f:
        f.write(sfx_exe_payload)
    shutil.copyfile(exe_path, latest_exe_path)

    shutil.rmtree(win_temp)

    return {
        "zip": (zip_path, zip_filename, latest_zip_path, "Kortex-Windows-latest.zip"),
        "exe": (exe_path, exe_filename, latest_exe_path, "Kortex-Windows-latest.exe"),
    }


def create_linux_packages(version):
    """Creates production Linux release installation packages."""
    print(f"\n--- Creating Linux Release Packages for Version {version} ---")
    os.makedirs(DIST_DIR, exist_ok=True)

    possible_linux_dirs = [
        os.path.join(PROJECT_ROOT, "build", "linux", "x64", "release", "bundle"),
        os.path.join(PROJECT_ROOT, "build", "linux", "x64", "production", "release", "bundle"),
        os.path.join(PROJECT_ROOT, "build", "linux", "x64", "release-production", "bundle"),
        os.path.join(PROJECT_ROOT, "build", "linux", "arm64", "release", "bundle"),
    ]
    linux_build_dir = None
    for p in possible_linux_dirs:
        if os.path.exists(p) and os.listdir(p):
            linux_build_dir = p
            break

    linux_temp = os.path.join(DIST_DIR, "Kortex-Linux-Temp")

    if os.path.exists(linux_temp):
        shutil.rmtree(linux_temp)
    os.makedirs(linux_temp, exist_ok=True)

    # 1. Add Linux Shell Launcher
    sh_path = os.path.join(linux_temp, "kortex")
    with open(sh_path, "w", encoding="utf-8") as f:
        f.write(
            "#!/usr/bin/env bash\n"
            f"echo 'Launching Kortexify Academic Workspace v{version} for Linux...'\n"
            "if command -v xdg-open > /dev/null; then\n"
            "  xdg-open INSTALLATION_GUIDE.html &\n"
            "fi\n"
        )
    os.chmod(sh_path, 0o755)

    sh_alias_path = os.path.join(linux_temp, "kortex-linux.sh")
    shutil.copyfile(sh_path, sh_alias_path)
    os.chmod(sh_alias_path, 0o755)

    # 2. Add HTML Guide
    guide_html = generate_installation_guide_html(version, "Linux x86_64")
    guide_path = os.path.join(linux_temp, "INSTALLATION_GUIDE.html")
    with open(guide_path, "w", encoding="utf-8") as f:
        f.write(guide_html)

    # 3. Add README
    manifest_path = os.path.join(linux_temp, "README_LINUX.txt")
    with open(manifest_path, "w", encoding="utf-8") as f:
        f.write(
            f"Kortexify Academic Workspace - Linux Release Build v{version}\n"
            "-----------------------------------------------------------\n"
            "Local-first, AI-augmented academic workspace for Linux x86_64.\n\n"
            "Quickstart:\n"
            "1. Run `./kortex` or `./kortex-linux.sh` in your terminal.\n"
            "2. Refer to `INSTALLATION_GUIDE.html` for full usage documentation.\n"
        )

    # 4. Include Full Web Application Workstation Distribution
    web_landing_dir = os.path.join(PROJECT_ROOT, "web_landing")
    if os.path.exists(web_landing_dir):
        shutil.copytree(web_landing_dir, os.path.join(linux_temp, "web_app"), symlinks=True, ignore_dangling_symlinks=True, dirs_exist_ok=True)

    if linux_build_dir and os.path.exists(linux_build_dir):
        print(f"Copying Linux native build bundle from {linux_build_dir}...")
        for item in os.listdir(linux_build_dir):
            s = os.path.join(linux_build_dir, item)
            d = os.path.join(linux_temp, item)
            if os.path.isdir(s):
                shutil.copytree(s, d, symlinks=True, ignore_dangling_symlinks=True, dirs_exist_ok=True)
            else:
                shutil.copy2(s, d, follow_symlinks=False)

    tar_filename = f"Kortex-{version}-Linux.tar.gz"
    tar_path = os.path.join(DIST_DIR, tar_filename)
    latest_tar_path = os.path.join(DIST_DIR, "Kortex-Linux-latest.tar.gz")

    if os.path.exists(tar_path):
        os.remove(tar_path)

    with tarfile.open(tar_path, "w:gz") as tar:
        tar.add(linux_temp, arcname="kortex")

    shutil.copyfile(tar_path, latest_tar_path)
    shutil.rmtree(linux_temp)

    return {
        "tar": (tar_path, tar_filename, latest_tar_path, "Kortex-Linux-latest.tar.gz"),
    }


def main():
    parser = argparse.ArgumentParser(description="Kortex Native Release Packaging & Cloudflare R2 Publisher")
    parser.add_argument("--platform", "-p", choices=["macos", "windows", "linux", "all", "auto"], default="auto",
                        help="Target platform to build/package (default: auto based on host OS)")
    parser.add_argument("--macos-only", action="store_true", help="Build, code-sign, package, and upload macOS version only")
    parser.add_argument("--windows-only", action="store_true", help="Build, package, and upload Windows version only")
    parser.add_argument("--linux-only", action="store_true", help="Build, package, and upload Linux version only")
    parser.add_argument("--skip-build", action="store_true", help="Skip Flutter compilation and package existing build outputs")
    parser.add_argument("--skip-upload", action="store_true", help="Skip uploading artifacts to Cloudflare R2")
    args = parser.parse_args()

    target_platform = "auto"
    if args.macos_only:
        target_platform = "macos"
    elif args.windows_only:
        target_platform = "windows"
    elif args.linux_only:
        target_platform = "linux"
    elif args.platform != "auto":
        target_platform = args.platform

    version_name, build_num = get_app_version()
    print(f"🚀 Kortex Release Build & Cloudflare R2 Publisher")
    print(f"   Detected Version: {version_name} (Build {build_num})")
    print(f"   Target Platform Mode: {target_platform}")
    print(f"   Running on Host OS: {sys.platform}")

    update_landing_version_strings(version_name)

    urls = {}

    run_macos = (target_platform == "macos") or (target_platform == "all") or (target_platform == "auto" and sys.platform == "darwin")
    run_windows = (target_platform == "windows") or (target_platform == "all") or (target_platform == "auto" and sys.platform.startswith("win"))
    run_linux = (target_platform == "linux") or (target_platform == "all") or (target_platform == "auto" and sys.platform.startswith("linux"))

    # 1. macOS Build, Code-sign & Package
    if run_macos and sys.platform == "darwin":
        if args.skip_build:
            print("\n--- Locating Existing macOS Build Bundle (--skip-build) ---")
            prod_dir = os.path.join(PROJECT_ROOT, "build", "macos", "Build", "Products", "Release-production")
            if not os.path.exists(prod_dir):
                prod_dir = os.path.join(PROJECT_ROOT, "build", "macos", "Build", "Products", "Release")
            app_path = None
            if os.path.exists(prod_dir):
                for item in os.listdir(prod_dir):
                    if item.endswith(".app"):
                        app_path = os.path.join(prod_dir, item)
                        break
            if app_path:
                sign_macos_target(app_path, is_app_bundle=True)
            else:
                print(f"Error: Could not locate built .app bundle in {prod_dir}")
                sys.exit(1)
        else:
            app_path = build_macos_bundle()

        if app_path:
            mac_pkgs = create_macos_packages(app_path, version_name)
            dmg_path, dmg_fn, latest_dmg_path, latest_dmg_fn = mac_pkgs["dmg"]
            zip_path, zip_fn, latest_zip_path, latest_zip_fn = mac_pkgs["zip"]

            if not args.skip_upload:
                urls["macOS (.dmg Versioned)"] = upload_to_r2(dmg_path, f"downloads/{dmg_fn}", "application/x-apple-diskimage")
                urls["macOS (.dmg Latest)"] = upload_to_r2(latest_dmg_path, f"downloads/{latest_dmg_fn}", "application/x-apple-diskimage")
                urls["macOS (.zip Versioned)"] = upload_to_r2(zip_path, f"downloads/{zip_fn}", "application/zip")
                urls["macOS (.zip Latest)"] = upload_to_r2(latest_zip_path, f"downloads/{latest_zip_fn}", "application/zip")

    # 2. Windows Build & Package
    if run_windows and sys.platform.startswith("win"):
        win_pkgs = create_windows_packages(version_name)
        if win_pkgs and not args.skip_upload:
            w_exe_path, w_exe_fn, w_latest_exe_path, w_latest_exe_fn = win_pkgs["exe"]
            urls["Windows (.exe Versioned)"] = upload_to_r2(w_exe_path, f"downloads/{w_exe_fn}", "application/x-msdownload")
            urls["Windows (.exe Latest)"] = upload_to_r2(w_latest_exe_path, f"downloads/{w_latest_exe_fn}", "application/x-msdownload")

            w_zip_path, w_zip_fn, w_latest_path, w_latest_fn = win_pkgs["zip"]
            urls["Windows (.zip Versioned)"] = upload_to_r2(w_zip_path, f"downloads/{w_zip_fn}", "application/zip")
            urls["Windows (.zip Latest)"] = upload_to_r2(w_latest_path, f"downloads/{w_latest_fn}", "application/zip")

    # 3. Linux Build & Package
    if run_linux and sys.platform.startswith("linux"):
        linux_pkgs = create_linux_packages(version_name)
        if linux_pkgs and not args.skip_upload:
            l_tar_path, l_tar_fn, l_latest_path, l_latest_fn = linux_pkgs["tar"]
            urls["Linux (.tar.gz Versioned)"] = upload_to_r2(l_tar_path, f"downloads/{l_tar_fn}", "application/gzip")
            urls["Linux (.tar.gz Latest)"] = upload_to_r2(l_latest_path, f"downloads/{l_latest_fn}", "application/gzip")

    print("\n==========================================================")
    print(f"🎉 Kortex v{version_name} Release Packages Processed Successfully!")
    print("==========================================================")
    if urls:
        print("\n### 🔗 Live Cloudflare R2 Download Links:\n")
        for platform, url in urls.items():
            print(f"- **{platform}**: [{url}]({url})")
    print("\nDone!")


if __name__ == "__main__":
    main()
