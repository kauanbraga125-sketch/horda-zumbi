"""Build a separate Android test app from the verified 0.10.60 native package.

Preserve every original texture/audio resource; replace the edited text scripts,
project settings, startup audit and sparse PCK directory. No signing credentials
from the official game are read or included.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import struct
import subprocess
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED, ZIP_STORED

from apk_format import patch_manifest, replace_pool_string, string_pool, write_entry, verify_android_layout
from sparse_index import build_index, verify_index

BASE_SHA256 = "944132b54c758bd053351bb1e25d8b6b93b5717845eb5f709b3c50fc7472c8b7"
SOURCE_PACKAGE = "com.kauan.noitedahorda.github"
TEST_PACKAGE = "com.kauan.noitedahorda.rotas"


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def resource_table(raw):
    data = bytearray(raw)
    offset = struct.unpack_from("<H",data,2)[0]
    changed = 0
    while offset<len(data):
        kind,_,size = struct.unpack_from("<HHI",data,offset)
        assert size>=8 and offset+size<=len(data)
        if kind==0x200 and data[offset+12:offset+268].decode("utf-16le").split("\0")[0]==SOURCE_PACKAGE:
            data[offset+12:offset+268] = TEST_PACKAGE.encode("utf-16le").ljust(256,b"\0")
            changed += 1
        offset += size
    assert changed==1,"Unexpected resource package"
    return bytes(data)


def build(args):
    project = args.project.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    assert digest(args.base) == BASE_SHA256, "Use the original 0.10.60 APK"
    version = re.search(r'^config/version="([^"]+)"', (project/"project.godot").read_text(), re.M).group(1)
    code = int(re.search(r'^version/code=(\d+)', (project/"export_presets.cfg").read_text(), re.M).group(1))
    settings = output/"project.binary"
    subprocess.run([str(args.engine), "--headless", "--path", str(project), "--script", "res://tools/save_runtime_config.gd", "--", str(settings)], check=True, timeout=90)
    with ZipFile(args.base) as original:
        resources = {n[7:]: original.read(n) for n in original.namelist() if n.startswith("assets/") and not n.endswith("/") and n not in ["assets/_cl_", "assets/assets.sparsepck"]}
        old_audit = json.loads(resources["startup_integrity.json"])
        for path in (project/"scripts").iterdir():
            if path.suffix in [".gd", ".gdshader"]: resources[path.relative_to(project).as_posix()] = path.read_bytes()
        for name in ["boot.tscn", "main.tscn", "project.godot", "ASSETS.md"]:
            resources[name] = (project/name).read_bytes()
        resources["project.binary"] = settings.read_bytes()
        paths = {e["path"][6:] for e in old_audit["files"]}
        paths.update(n for n in resources if n.startswith("scripts/") and n.endswith((".gd", ".gdshader")))
        audit = {"version": version, "class_count": old_audit["class_count"], "files": []}
        for name in sorted(paths):
            data = resources[name]
            audit["files"].append({"path":"res://"+name,"bytes":len(data),"sha256":hashlib.sha256(data).hexdigest()})
        resources["startup_integrity.json"] = json.dumps(audit, ensure_ascii=False, indent=2).encode()
        index = build_index(resources)
        unsigned = output/"unsigned.apk"
        with ZipFile(unsigned, "w", ZIP_DEFLATED, compresslevel=6) as target:
            manifest, metadata = patch_manifest(original.read("AndroidManifest.xml"), version, code)
            assert code > metadata["previousVersionCode"], "Android version code must increase"
            strings, _ = string_pool(manifest, 8)
            for i, value in enumerate(strings):
                replacement = value.replace(SOURCE_PACKAGE, TEST_PACKAGE)
                if value.startswith("Horda "): replacement = "Horda Teste " + version
                if replacement != value: manifest = bytes(replace_pool_string(bytearray(manifest), 8, i, replacement))
            for info in original.infolist():
                if info.filename.startswith(("assets/", "META-INF/")): continue
                data = original.read(info)
                if info.filename == "AndroidManifest.xml": data = manifest
                elif info.filename == "resources.arsc": data = resource_table(data)
                write_entry(target, info, data)
            for name, data in sorted({**resources,"assets.sparsepck":index,"_cl_":original.read("assets/_cl_")}.items()):
                info = ZipInfo("assets/"+name)
                info.compress_type = ZIP_STORED if name == "assets.sparsepck" else ZIP_DEFLATED
                write_entry(target, info, data)
    aligned = output/"aligned.apk"
    subprocess.run([str(args.build_tools/"zipalign"), "-P", "16", "-f", "4", str(unsigned), str(aligned)], check=True)
    key = project/".godot/v161-test.keystore"
    if not key.exists():
        subprocess.run(["keytool","-genkeypair","-noprompt","-keystore",str(key),"-alias","androiddebugkey","-storepass","android","-keypass","android","-keyalg","RSA","-keysize","2048","-validity","10000","-dname","CN=Horda Teste"],check=True,capture_output=True)
        key.chmod(0o600)
    apk = output/("Horda-v"+version+"-Teste-Android.apk")
    subprocess.run([str(args.build_tools/"apksigner"),"sign","--ks",str(key),"--ks-key-alias","androiddebugkey","--ks-pass","pass:android","--key-pass","pass:android","--out",str(apk),str(aligned)],check=True)
    subprocess.run([str(args.build_tools/"apksigner"),"verify","--verbose",str(apk)],check=True)
    subprocess.run([str(args.build_tools/"zipalign"),"-c","-P","16","4",str(apk)],check=True)
    runtime = output/"packaged-runtime"
    runtime.mkdir(exist_ok=True)
    with ZipFile(apk) as package:
        assert package.testzip() is None
        layout = verify_android_layout(package)
        packed = {n[7:]:package.read(n) for n in package.namelist() if n.startswith("assets/") and n not in ["assets/_cl_","assets/assets.sparsepck"]}
        verify_index(package.read("assets/assets.sparsepck"), packed)
        assert packed == resources
        for name, data in packed.items():
            path = runtime/name
            path.parent.mkdir(parents=True,exist_ok=True)
            path.write_bytes(data)
    report = {"version":version,"version_code":code,"base_sha256":BASE_SHA256,"sha256":digest(apk),"package":TEST_PACKAGE,"audit_files":len(audit["files"]),"resource_count":len(resources),"android_layout":layout,"physical_device_tested":False}
    (output/"build.json").write_text(json.dumps(report,indent=2))
    unsigned.unlink()
    aligned.unlink()
    print("V161_APK_OK",apk,flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--project",type=Path,default=Path(__file__).resolve().parents[1])
    parser.add_argument("--base",type=Path,required=True)
    parser.add_argument("--output",type=Path,required=True)
    parser.add_argument("--engine",type=Path,required=True)
    parser.add_argument("--build-tools",type=Path,required=True)
    build(parser.parse_args())
