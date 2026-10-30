"""Compile the current Godot sources into a signed Android APK.

The verified 0.10.41 APK supplies ONLY the native Android/Godot 4.5.1 shell.
Every game resource is freshly exported from the selected checkout. Historical
release/restore scripts are not used. Signing credentials never enter Git.
"""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import tempfile
import urllib.request
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED, ZIP_STORED

from apk_format import patch_manifest, replace_pool_string, string_pool, write_entry, verify_android_layout
from refresh_startup_integrity import refresh
from sparse_index import build_index, verify_index

BASE_SHA256 = "bd7581e252a8992b131e17e003feb495323a6e2637512a4a0d862b20ccaf766e"
BASE_URL = "https://github.com/kauanbraga125-sketch/horda-zumbi/releases/download/v0.10.41/Horda-Zumbi-v0.10.41-TESTE-1M-ESGOTO-ARM64.apk"
OFFICIAL_PACKAGE = "com.kauan.noitedahorda.reconstruida"
TEST_PACKAGE = "com.kauan.noitedahorda.github"
OFFICIAL_CERT = "a641a59f39561af0210f2f1cd246f58c5bfd9ab05462bf5b0635e626d681d15d"


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def run(command, log, env=None):
    with log.open("w") as stream:
        result = subprocess.run([str(x) for x in command], stdout=stream, stderr=subprocess.STDOUT, env=env, timeout=900)
    output = log.read_text(errors="replace")
    print(output, flush=True)
    if result.returncode or re.search(r"SCRIPT ERROR|Parse Error|HORDA_BOOT_FAILED|PACKAGED_BOOT_FAILED", output):
        raise SystemExit(f"Falha: {log.name} (código {result.returncode})")
    return output


def sdk_tool(name):
    sdk = Path(os.environ.get("ANDROID_HOME", os.environ.get("ANDROID_SDK_ROOT", "/nonexistent")))
    candidates = list((sdk / "build-tools").glob("*/" + name))
    if candidates:
        return max(candidates, key=lambda p: tuple(int(x) for x in re.findall(r"\d+", p.parent.name)))
    found = shutil.which(name)
    if not found:
        raise SystemExit(f"Instale Android SDK Build-Tools 35.0.0: falta {name}.")
    return Path(found)


def manifest(raw, version, code, mode):
    data, info = patch_manifest(raw, version, code)
    strings, _ = string_pool(data, 8)
    # Update both FileProvider authority strings so test and official coexist.
    for index, value in enumerate(strings):
        replacement = value
        if mode == "teste":
            replacement = replacement.replace(OFFICIAL_PACKAGE, TEST_PACKAGE)
        if value == "Horda Esgoto R41":
            replacement = "Horda GitHub Teste" if mode == "teste" else f"Horda Zumbi {version}"
        if replacement != value:
            data = bytes(replace_pool_string(bytearray(data), 8, index, replacement))
    info["package"] = TEST_PACKAGE if mode == "teste" else OFFICIAL_PACKAGE
    return data, info


def resource_table(raw, mode):
    if mode != "teste":
        return raw
    data = bytearray(raw)
    position = struct.unpack_from("<H", data, 2)[0]
    changed = 0
    while position < len(data):
        kind, _, size = struct.unpack_from("<HHI", data, position)
        assert size >= 8 and position + size <= len(data), "Tabela Android inválida"
        if kind == 0x200:
            name = data[position + 12:position + 268].decode("utf-16le").split("\0")[0]
            if name == OFFICIAL_PACKAGE:
                data[position + 12:position + 268] = TEST_PACKAGE.encode("utf-16le").ljust(256, b"\0")
                changed += 1
        position += size
    assert changed == 1, "Pacote de recursos Android não encontrado"
    return bytes(data)


def build(args):
    source = args.project.resolve()
    output = args.out.resolve()
    output.mkdir(parents=True, exist_ok=True)
    version = re.search(r'^config/version="([\d.]+)"$', (source / "project.godot").read_text(), re.M).group(1)
    code = int(re.search(r"^version/code=(\d+)$", (source / "export_presets.cfg").read_text(), re.M).group(1))
    name = f"Horda-Zumbi-v{version}-GitHub-{'TESTE' if args.mode == 'teste' else 'OFICIAL'}-ARM64.apk"
    apk_path = output / name
    engine = args.engine.resolve()
    engine_version = subprocess.check_output([str(engine), "--version"], text=True).strip()
    assert engine_version.startswith("4.5.1.stable"), "Use Godot 4.5.1 stable com esta base nativa"
    signer, aligner = sdk_tool("apksigner"), sdk_tool("zipalign")

    with tempfile.TemporaryDirectory(prefix="horda-source-build-") as temporary:
        temporary = Path(temporary)
        base = args.base.resolve() if args.base else temporary / "native-base.apk"
        if not args.base:
            print("Obtendo a base nativa verificada 0.10.41…", flush=True)
            urllib.request.urlretrieve(BASE_URL, base)
        assert sha(base) == BASE_SHA256, "SHA256 da base Android não confere"
        project = temporary / "project"
        shutil.copytree(source, project, ignore=shutil.ignore_patterns(".godot", ".git", "build", "validation", "__pycache__", "*.pyc", "*.keystore", "*.jks", "*.apk", "*.idsig"))
        env = os.environ.copy()
        env["XDG_DATA_HOME"] = str(temporary / "user-data")
        run([engine, "--headless", "--path", project, "--editor", "--import"], output / "importacao.log", env)
        refresh(project)
        boot_log = run([engine, "--headless", "--audio-driver", "Dummy", "--path", project, "--script", "res://tests/verify_packaged_boot.gd"], output / "abertura-fontes.log", env)
        assert "PACKAGED_BOOT_OK" in boot_log, "Abertura dos fontes não confirmada"
        exported = temporary / "resources.zip"
        run([engine, "--headless", "--path", project, "--export-pack", "Android", exported], output / "exportacao.log", env)
        with ZipFile(exported) as package:
            resources = {n: package.read(n) for n in package.namelist() if not n.endswith("/")}
        assert "project.binary" in resources, "Configuração exportada ausente"
        assert not any(n.endswith((".gdc", ".gd.remap")) for n in resources), "Exporte scripts em texto"
        assert not any(n.startswith(("tools/", "tests/")) for n in resources), "Ferramentas de edição não pertencem ao app"
        # Keep non-imported files such as JSON/PCM/BIN. Imported PNG/OGG/fonts
        # already have their exported runtime resource; the startup audit below
        # adds originals for art that is decoded directly with FileAccess.
        for path in (project / "assets").rglob("*"):
            if path.is_file() and path.suffix.lower() not in (".import", ".png", ".ogg", ".ttf", ".otf", ".svg"):
                resources[path.relative_to(project).as_posix()] = path.read_bytes()
        for path in (project / "scripts").iterdir():
            if path.suffix in (".gd", ".gdshader"):
                resources[path.relative_to(project).as_posix()] = path.read_bytes()
        audit = json.loads((project / "startup_integrity.json").read_text())
        for entry in audit["files"]:
            relative = entry["path"][6:]
            resources[relative] = (project / relative).read_bytes()
        for relative in ("boot.tscn", "main.tscn", "project.godot", "startup_integrity.json"):
            resources[relative] = (project / relative).read_bytes()
            resources.pop(relative + ".remap", None)
        resources.pop("assets.sparsepck", None)
        unsigned, aligned = temporary / "unsigned.apk", temporary / "aligned.apk"
        with ZipFile(base) as native, ZipFile(unsigned, "w", ZIP_DEFLATED, compresslevel=6) as target:
            android_manifest, android_info = manifest(native.read("AndroidManifest.xml"), version, code, args.mode)
            for info in native.infolist():
                if info.filename.startswith(("assets/", "META-INF/")):
                    continue
                data = native.read(info)
                if info.filename == "AndroidManifest.xml":
                    data = android_manifest
                elif info.filename == "resources.arsc":
                    data = resource_table(data, args.mode)
                write_entry(target, info, data)
            if "assets/_cl_" in native.namelist():
                resources["_cl_"] = native.read("assets/_cl_")
            resources["assets.sparsepck"] = build_index({n: d for n, d in resources.items() if n != "_cl_"})
            for relative, data in sorted(resources.items()):
                info = ZipInfo("assets/" + relative)
                info.compress_type = ZIP_STORED if relative == "assets.sparsepck" else ZIP_DEFLATED
                write_entry(target, info, data)
        subprocess.run([str(aligner), "-P", "16", "-f", "4", str(unsigned), str(aligned)], check=True)
        if args.mode == "oficial":
            required = ("HORDA_ANDROID_KEYSTORE_BASE64", "HORDA_ANDROID_KEY_ALIAS", "HORDA_ANDROID_KEYSTORE_PASSWORD")
            missing = [key for key in required if not os.environ.get(key)]
            if missing:
                raise SystemExit("Configure estes Secrets do GitHub para assinatura oficial: " + ", ".join(missing))
            key = temporary / "official.keystore"
            key.write_bytes(base64.b64decode(os.environ[required[0]], validate=True))
            key.chmod(0o600)
            alias = os.environ[required[1]]
            env["HORDA_CI_STORE_PASS"] = os.environ[required[2]]
            env["HORDA_CI_KEY_PASS"] = os.environ.get("HORDA_ANDROID_KEY_PASSWORD") or env["HORDA_CI_STORE_PASS"]
        else:
            key = Path(os.environ.get("HORDA_TEST_KEYSTORE", str(source / ".godot/github-test.keystore"))).resolve()
            key.parent.mkdir(parents=True, exist_ok=True)
            alias = "androiddebugkey"
            env["HORDA_CI_STORE_PASS"] = env["HORDA_CI_KEY_PASS"] = "android"
            if not key.exists():
                subprocess.run(["keytool", "-genkeypair", "-noprompt", "-keystore", str(key), "-alias", alias, "-storepass", "android", "-keypass", "android", "-keyalg", "RSA", "-keysize", "2048", "-validity", "10000", "-dname", "CN=Horda GitHub Teste"], check=True, capture_output=True)
            key.chmod(0o600)
        subprocess.run([str(signer), "sign", "--ks", str(key), "--ks-key-alias", alias, "--ks-pass", "env:HORDA_CI_STORE_PASS", "--key-pass", "env:HORDA_CI_KEY_PASS", "--out", str(apk_path), str(aligned)], env=env, check=True)
        certificate = run([signer, "verify", "--verbose", "--print-certs", apk_path], output / "assinatura.txt", env)
        if args.mode == "oficial":
            assert OFFICIAL_CERT in certificate, "Use a chave original do proprietário para preservar as atualizações"
        subprocess.run([str(aligner), "-c", "-P", "16", "4", str(apk_path)], check=True, stdout=subprocess.DEVNULL)
        runtime = temporary / "runtime"
        runtime.mkdir()
        with ZipFile(apk_path) as built:
            assert built.testzip() is None
            layout = verify_android_layout(built)
            packed = {n[7:]: built.read(n) for n in built.namelist() if n.startswith("assets/") and n not in ("assets/assets.sparsepck", "assets/_cl_")}
            entries = verify_index(built.read("assets/assets.sparsepck"), packed)
            assert packed == {n: d for n, d in resources.items() if n not in ("assets.sparsepck", "_cl_")}
            for relative, data in packed.items():
                path = runtime / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
        (runtime / "tests").mkdir()
        shutil.copyfile(project / "tests/verify_packaged_boot.gd", runtime / "tests/verify_packaged_boot.gd")
        env["XDG_DATA_HOME"] = str(temporary / "packed-user-data")
        packed_log = run([engine, "--headless", "--audio-driver", "Dummy", "--path", runtime, "--script", "res://tests/verify_packaged_boot.gd"], output / "abertura-apk.log", env)
        assert "PACKAGED_BOOT_OK" in packed_log, "Abertura dos arquivos extraídos do APK não confirmada"
        report = {"version": version, "engine": engine_version, "mode": args.mode, "commit": os.environ.get("GITHUB_SHA", "local"), "apk": name, "bytes": apk_path.stat().st_size, "sha256": sha(apk_path), "android": android_info, "layout": layout, "startup_files": len(audit["files"]), "classes": audit["class_count"], "resource_entries": entries, "fresh_source_export": True, "all_game_resources_replaced": True, "source_boot_verified": True, "packaged_boot_verified": True, "physical_device_tested": False, "native_base_sha256": BASE_SHA256}
        (output / "compilacao.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
        (output / "SHA256SUMS.txt").write_text(f"{report['sha256']}  {name}\n")
        print(json.dumps(report, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--engine", type=Path, required=True)
    parser.add_argument("--base", type=Path, help="APK 0.10.41 verificado; baixa automaticamente quando omitido")
    parser.add_argument("--out", type=Path, default=Path("dist/android"))
    parser.add_argument("--mode", choices=("teste", "oficial"), default="teste")
    build(parser.parse_args())
