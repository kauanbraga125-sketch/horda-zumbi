"""Reproducible ARM64 reconstruction using the verified v0.10.3 native shell.

The original signing key is not available. This package installs beside the old
game. No files or scripts are inherited from the old APK's asset directory.
"""
from pathlib import Path
from zipfile import ZipFile,ZipInfo,ZIP_DEFLATED,ZIP_STORED
import argparse,hashlib,json,re,struct,subprocess,tempfile,os,shutil
from PIL import Image
from apk_format import patch_manifest,replace_pool_string,string_pool,write_entry,verify_android_layout
from sparse_index import build_index,verify_index

VERSION='0.10.13.1';CODE=116
PACKAGE='com.kauan.noitedahorda.reconstruida'
BASE_SHA='d8cd026d8676f069e8195912dafa5911eb2876bc8f69c10b0126559a4f14652f'

def assets(resources,source,cache):
    actual={}
    with ZipFile(resources)as z:
        for name in z.namelist():
            if name.endswith('/')or name.startswith(('tests/','tools/','validation/','.godot/editor/','.godot/exported/')):continue
            if name.endswith(('.gdc','.gd.remap'))or name in ['boot.tscn.remap','main.tscn.remap']:continue
            actual[name]=z.read(name)
    for p in (source/'scripts').iterdir():
        if p.suffix in ['.gd','.gdshader']:actual[p.relative_to(source).as_posix()]=p.read_bytes()
    for name in ['boot.tscn','main.tscn','.godot/global_script_class_cache.cfg']:
        actual[name]=(source/name).read_bytes()
    for folder,suffixes in [('assets/art/results_v110',['.webp','.json']),('assets/audio/results_v110',['.pcm','.json']),('assets/art/cosmetics_v113',['.json','.bin'])]:
        for p in (source/folder).iterdir():
            if p.suffix in suffixes:actual[p.relative_to(source).as_posix()]=p.read_bytes()
    # These resources are decoded directly once. Shipping their imported
    # texture as well wastes space. The Android launcher icons are in res/.
    direct={'assets/art/results_v110/souls.png','assets/art/results_v110/souls.webp','assets/icon-monsters-v51.png'}
    for rel in direct:
        if rel+'.import'in actual:
            text=actual.pop(rel+'.import').decode().rstrip('\x00')
            found=re.search(r'path="res://([^"]+)"',text)
            if found:actual.pop(found.group(1),None)
        if rel!='assets/art/results_v110/souls.webp':actual.pop(rel,None)
    actual.pop('assets/_cl_',None)
    changed=[]
    for name,content in list(actual.items()):
        if not name.endswith('.import')or not name[:-7].endswith('.png'):continue
        rel=name[:-7];webp=cache/(rel+'.webp')
        if not webp.is_file():raise FileNotFoundError(webp)
        data=webp.read_bytes();im=Image.open(webp);width,height=im.size
        text=content.decode().rstrip('\x00')
        imported=re.search(r'path="res://([^"]+)"',text).group(1)
        previous=actual[imported]
        assert previous[:4]==b'GST2'
        # Godot 4.5.1 CompressedTexture2D format, verified against engine source.
        header=struct.pack('<4s8I',b'GST2',1,width,height,0,0xffffffff,0,0,0)
        image_header=struct.pack('<IHHIII',2,width,height,0,5,len(data))
        actual[imported]=header+image_header+data
        changed.append(dict(source=rel,imported=imported,original=len(previous),optimized=len(actual[imported])))
    # Regenerate hashes only after all bytes are final; sparse lengths and MD5
    # must describe the actual packaged files rather than earlier source data.
    audit=json.loads((source/'startup_integrity.json').read_text())
    paths=[entry['path'][6:]for entry in audit['files']]
    audit['version']=VERSION
    audit['class_count']=len(re.findall(rb'"class":',actual['.godot/global_script_class_cache.cfg']))
    audit['files']=[dict(path='res://'+n,bytes=len(actual[n]),sha256=hashlib.sha256(actual[n]).hexdigest())for n in paths]
    actual['startup_integrity.json']=json.dumps(audit,ensure_ascii=False,indent=2).encode()
    assert not any(n.endswith(('.gdc','.gd.remap'))for n in actual)
    return actual,changed

def build(a):
    assert hashlib.sha256(a.base.read_bytes()).hexdigest()==BASE_SHA,'Base APK changed'
    actual,changed=assets(a.resources,a.source,a.cache)
    with ZipFile(a.base)as base:
        if '_cl_'not in actual:actual['_cl_']=base.read('assets/_cl_')
        manifest,_=patch_manifest(base.read('AndroidManifest.xml'),VERSION,CODE)
        strings,_=string_pool(manifest,8)
        for i,value in enumerate(strings):
            replacement=value.replace('com.kauan.noitedahorda.playtest091',PACKAGE)
            if value.startswith('Horda Zumbi 0.'):replacement='Horda Zumbi R13'
            if replacement!=value:
                manifest=bytes(replace_pool_string(bytearray(manifest),8,i,replacement));strings,_=string_pool(manifest,8)
        # Android's drawable table can share one exact icon file across two
        # density aliases. Rewrite only equal-byte resources; no icon resizing.
        aliases={};seen={}
        for info in base.infolist():
            if not info.filename.startswith('res/')or not info.filename.endswith('.png'):continue
            digest=hashlib.sha256(base.read(info)).digest()
            if digest in seen:aliases[info.filename]=seen[digest]
            else:seen[digest]=info.filename
        resource_table=base.read('resources.arsc');strings,_=string_pool(resource_table,12)
        for i,value in enumerate(strings):
            if value in aliases:resource_table=bytes(replace_pool_string(bytearray(resource_table),12,i,aliases[value]))
        # Android resource-name lookup uses the manifest package name. Update
        # ResTable_package's fixed UTF-16 field for the separate installation.
        resource_table=bytearray(resource_table);offset=12;package_chunks=0
        while offset<len(resource_table):
            kind,header,size=struct.unpack_from('<HHI',resource_table,offset)
            if kind==0x200:
                encoded=PACKAGE.encode('utf-16le');assert len(encoded)<256
                resource_table[offset+12:offset+268]=encoded+bytes(256-len(encoded));package_chunks+=1
            assert size>=8
            offset+=size
        assert package_chunks==1 and offset==len(resource_table)
        resource_table=bytes(resource_table)
        a.output.parent.mkdir(parents=True,exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='horda-v113-')as temp:
            temp=Path(temp);unsigned=temp/'unsigned.apk';aligned=temp/'aligned.apk';signed=temp/'signed.apk'
            with ZipFile(unsigned,'w',compression=ZIP_DEFLATED,compresslevel=9)as out:
                for info in base.infolist():
                    name=info.filename
                    if name.startswith('assets/')or name.startswith('META-INF/')or name.startswith('lib/armeabi-v7a/')or name in aliases:continue
                    data=manifest if name=='AndroidManifest.xml'else resource_table if name=='resources.arsc'else base.read(info)
                    # Android 11+ requires the resource table to be stored and
                    # 4-byte aligned. Compression here causes a parse failure
                    # even when the APK passes zipalign and signature checks.
                    clean=ZipInfo(name,(2026,10,23,0,0,0));clean.compress_type=ZIP_STORED if name=='resources.arsc' else ZIP_DEFLATED;clean._compresslevel=9
                    write_entry(out,clean,data)
                themed='res/mipmap-anydpi-v26/themed_icon.xml'
                if themed not in base.namelist():
                    # The recovered template declared this drawable without
                    # its file. Use the valid adaptive icon for that alias.
                    info=ZipInfo(themed,(2026,10,23,0,0,0));info.compress_type=ZIP_DEFLATED
                    write_entry(out,info,base.read('res/mipmap-anydpi-v26/icon.xml'))
                for name,data in sorted(actual.items()):
                    info=ZipInfo('assets/'+name,(2026,10,23,0,0,0));info.compress_type=ZIP_DEFLATED;info._compresslevel=9
                    write_entry(out,info,data)
                index=build_index({n:b for n,b in actual.items()if n!='_cl_'})
                info=ZipInfo('assets/assets.sparsepck',(2026,10,23,0,0,0));info.compress_type=ZIP_STORED;write_entry(out,info,index)
            subprocess.run([str(a.zipalign),'-f','4',str(unsigned),str(aligned)],check=True)
            password=(a.key.parent/'password.txt').read_text().strip();env=os.environ.copy();env['HORDA_REBUILD_KEY_PASSWORD']=password
            cmd=['java','-cp',str(a.signer),'com.android.apksigner.ApkSignerTool']
            subprocess.run(cmd+['sign','--ks',str(a.key),'--ks-key-alias','horda-reconstruida','--ks-pass','env:HORDA_REBUILD_KEY_PASSWORD','--key-pass','env:HORDA_REBUILD_KEY_PASSWORD','--out',str(signed),str(aligned)],env=env,check=True)
            subprocess.run(cmd+['verify','--verbose',str(signed)],check=True)
            with ZipFile(signed)as z:
                assert z.testzip()is None
                install_layout=verify_android_layout(z)
                files={n[7:]:z.read(n)for n in z.namelist()if n.startswith('assets/')and n not in ['assets/assets.sparsepck','assets/_cl_']}
                count=verify_index(z.read('assets/assets.sparsepck'),files)
                native=[n for n in z.namelist()if n.startswith('lib/')]
                assert all(base.read(n)==z.read(n)for n in native)
                assert not any('armeabi-v7a'in n for n in native)
            staged=a.output.with_suffix('.complete.apk');shutil.copyfile(signed,staged);os.replace(staged,a.output)
    report=dict(version=VERSION,version_code=CODE,package=PACKAGE,bytes=a.output.stat().st_size,sha256=hashlib.sha256(a.output.read_bytes()).hexdigest(),textures=len(changed),index_entries=count,native=native,original_pngs_unmodified=True,cache=str(a.cache),install_layout=install_layout)
    a.output.with_suffix('.json').write_text(json.dumps(report,indent=2));print(json.dumps(report),flush=True)
    if a.fixture:
        a.fixture.mkdir(parents=True,exist_ok=True)
        for name,data in actual.items():
            p=a.fixture/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)

if __name__=='__main__':
    p=argparse.ArgumentParser()
    for field in ['base','resources','source','cache','output','key','signer','zipalign']:p.add_argument('--'+field,type=Path,required=True)
    p.add_argument('--fixture',type=Path)
    build(p.parse_args())
