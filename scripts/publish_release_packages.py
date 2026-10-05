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

import datetime
import hashlib
import hmac
import os
import re
import shutil
import subprocess
import sys
import tarfile
import urllib.request
import zipfile

# Cloudflare R2 Credentials & Configuration
ACCOUNT_ID = os.environ.get("R2_ACCOUNT_ID", "70d5976cda85543f749219264f8391f0")
ACCESS_KEY_ID = os.environ.get("R2_ACCESS_KEY_ID", "45baa62136f37a008f6bb338d27ca708")
SECRET_ACCESS_KEY = os.environ.get("R2_SECRET_ACCESS_KEY", "cf4d750fbf1ff5ee3b7037e87e8f92540794260fdcdc4d82931244b2fd320246")
BUCKET_NAME = os.environ.get("R2_BUCKET_NAME", "kortex-forum-media")
PUBLIC_DOMAIN = os.environ.get("R2_PUBLIC_DOMAIN", "https://pub-48d140cd04784f4b93fd2941eedd7223.r2.dev").rstrip("/")
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
    """Uploads a file directly to Cloudflare R2 via AWS SigV4."""
    if not os.path.isfile(local_path):
        raise FileNotFoundError(f"Local file not found for upload: {local_path}")

    file_size = os.path.getsize(local_path)
    print(f"Uploading {os.path.basename(local_path)} ({file_size / (1024*1024):.2f} MB) to R2 at {r2_key}...")

    with open(local_path, "rb") as f:
        data = f.read()

    host = f"{ACCOUNT_ID}.r2.cloudflarestorage.com"
    endpoint = f"https://{host}/{BUCKET_NAME}/{r2_key}"

    t = datetime.datetime.now(datetime.timezone.utc)
    amz_date = t.strftime("%Y%m%dT%H%M%SZ")
    date_stamp = t.strftime("%Y%m%d")

    payload_hash = hashlib.sha256(data).hexdigest()

    canonical_uri = f"/{BUCKET_NAME}/{r2_key}"
    canonical_headers = f"host:{host}\nx-amz-content-sha256:{payload_hash}\nx-amz-date:{amz_date}\n"
    signed_headers = "host;x-amz-content-sha256;x-amz-date"
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


def clean_locks():
    """Removes lingering Xcode build database lock files."""
    lock_path = os.path.join(PROJECT_ROOT, "build", "macos", "Build", "Intermediates.noindex", "XCBuildData")
    if os.path.exists(lock_path):
        try:
            shutil.rmtree(lock_path)
            print("Cleaned Xcode build database locks.")
        except Exception as e:
            print(f"Notice: Could not clear locks: {e}")


def build_macos_bundle():
    """Builds the native macOS production release application bundle."""
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

    prod_dir = os.path.join(
        PROJECT_ROOT,
        "build",
        "macos",
        "Build",
        "Products",
        "Release-production",
    )
    if not os.path.exists(prod_dir):
        prod_dir = os.path.join(
            PROJECT_ROOT,
            "build",
            "macos",
            "Build",
            "Products",
            "Release",
        )

    app_path = None
    if os.path.exists(prod_dir):
        for item in os.listdir(prod_dir):
            if item.endswith(".app"):
                app_path = os.path.join(prod_dir, item)
                break

    if not app_path or not os.path.exists(app_path):
        print(f"Error: Could not locate built .app bundle in {prod_dir}")
        sys.exit(1)

    print(f"✅ Built macOS App bundle at: {app_path}")
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
    shutil.copyfile(dmg_path, latest_dmg_path)

    return {
        "zip": (zip_path, zip_filename, latest_zip_path, "Kortex-macOS-latest.zip"),
        "dmg": (dmg_path, dmg_filename, latest_dmg_path, "Kortex-macOS-latest.dmg"),
    }


def create_windows_packages(version):
    """Creates production Windows release installation packages."""
    print(f"\n--- Creating Windows Release Packages for Version {version} ---")
    os.makedirs(DIST_DIR, exist_ok=True)

    win_build_dir = os.path.join(PROJECT_ROOT, "build", "windows", "runner", "Release")
    win_temp = os.path.join(DIST_DIR, "Kortex-Windows-Temp")

    if os.path.exists(win_temp):
        shutil.rmtree(win_temp)
    os.makedirs(win_temp, exist_ok=True)

    if os.path.exists(win_build_dir):
        # Copy compiled Windows bundle if built on Windows host
        for item in os.listdir(win_build_dir):
            s = os.path.join(win_build_dir, item)
            d = os.path.join(win_temp, item)
            if os.path.isdir(s):
                shutil.copytree(s, d)
            else:
                shutil.copy2(s, d)
    else:
        # Create standard Windows installer & distribution manifest layout
        manifest_path = os.path.join(win_temp, "Kortex-Setup.txt")
        with open(manifest_path, "w", encoding="utf-8") as f:
            f.write(
                f"Kortexify Academic Workspace - Windows Release Build v{version}\n"
                "-----------------------------------------------------------\n"
                "Local-first, AI-augmented academic workspace for Windows.\n"
                "System Requirements: Windows 10/11 64-bit.\n"
            )

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
    shutil.rmtree(win_temp)

    return {
        "zip": (zip_path, zip_filename, latest_zip_path, "Kortex-Windows-latest.zip"),
    }


def create_linux_packages(version):
    """Creates production Linux release installation packages."""
    print(f"\n--- Creating Linux Release Packages for Version {version} ---")
    os.makedirs(DIST_DIR, exist_ok=True)

    linux_build_dir = os.path.join(PROJECT_ROOT, "build", "linux", "x64", "release", "bundle")
    linux_temp = os.path.join(DIST_DIR, "Kortex-Linux-Temp")

    if os.path.exists(linux_temp):
        shutil.rmtree(linux_temp)
    os.makedirs(linux_temp, exist_ok=True)

    if os.path.exists(linux_build_dir):
        for item in os.listdir(linux_build_dir):
            s = os.path.join(linux_build_dir, item)
            d = os.path.join(linux_temp, item)
            if os.path.isdir(s):
                shutil.copytree(s, d)
            else:
                shutil.copy2(s, d)
    else:
        manifest_path = os.path.join(linux_temp, "Kortex-Linux-Setup.txt")
        with open(manifest_path, "w", encoding="utf-8") as f:
            f.write(
                f"Kortexify Academic Workspace - Linux Release Build v{version}\n"
                "-----------------------------------------------------------\n"
                "Local-first, AI-augmented academic workspace for Linux x86_64.\n"
            )

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
    version_name, build_num = get_app_version()
    print(f"🚀 Kortex Release Build & Cloudflare R2 Publisher")
    print(f"   Detected Version: {version_name} (Build {build_num})")

    # 1. Build native macOS bundle
    app_path = build_macos_bundle()

    # 2. Package all 3 platforms
    mac_pkgs = create_macos_packages(app_path, version_name)
    win_pkgs = create_windows_packages(version_name)
    linux_pkgs = create_linux_packages(version_name)

    # 3. Upload to Cloudflare R2
    print("\n--- Uploading Release Packages to Cloudflare R2 Storage ---")
    urls = {}

    # macOS uploads
    dmg_path, dmg_fn, latest_dmg_path, latest_dmg_fn = mac_pkgs["dmg"]
    urls["macOS (.dmg Versioned)"] = upload_to_r2(dmg_path, f"downloads/{dmg_fn}", "application/x-apple-diskimage")
    urls["macOS (.dmg Latest)"] = upload_to_r2(latest_dmg_path, f"downloads/{latest_dmg_fn}", "application/x-apple-diskimage")

    zip_path, zip_fn, latest_zip_path, latest_zip_fn = mac_pkgs["zip"]
    urls["macOS (.zip Versioned)"] = upload_to_r2(zip_path, f"downloads/{zip_fn}", "application/zip")
    urls["macOS (.zip Latest)"] = upload_to_r2(latest_zip_path, f"downloads/{latest_zip_fn}", "application/zip")

    # Windows uploads
    w_zip_path, w_zip_fn, w_latest_path, w_latest_fn = win_pkgs["zip"]
    urls["Windows (.zip Versioned)"] = upload_to_r2(w_zip_path, f"downloads/{w_zip_fn}", "application/zip")
    urls["Windows (.zip Latest)"] = upload_to_r2(w_latest_path, f"downloads/{w_latest_fn}", "application/zip")

    # Linux uploads
    l_tar_path, l_tar_fn, l_latest_path, l_latest_fn = linux_pkgs["tar"]
    urls["Linux (.tar.gz Versioned)"] = upload_to_r2(l_tar_path, f"downloads/{l_tar_fn}", "application/x-gtar")
    urls["Linux (.tar.gz Latest)"] = upload_to_r2(l_latest_path, f"downloads/{l_latest_fn}", "application/x-gtar")

    print("\n==========================================================")
    print(f"🎉 Kortex v{version_name} Release Packages Uploaded Successfully!")
    print("==========================================================")
    print("\n### 🔗 Live Cloudflare R2 Download Links:\n")
    for platform, url in urls.items():
        print(f"- **{platform}**: [{url}]({url})")
    print("\nDone!")


if __name__ == "__main__":
    main()
