"""Build a signed 0.10.34 update from the verified 0.10.33 APK."""
import argparse,hashlib,json,os,shutil,subprocess,tempfile
from pathlib import Path
from zipfile import ZipFile,ZipInfo,ZIP_DEFLATED,ZIP_STORED
from apk_format import patch_manifest,replace_pool_string,string_pool,write_entry,verify_android_layout
from sparse_index import build_index,verify_index

VERSION='0.10.34';CODE=137
BASE='b48aa9368244a2ea53f8064cb766e8a3111a74f060ad705ff19557c2ed3cb851'
CERT='a641a59f39561af0210f2f1cd246f58c5bfd9ab05462bf5b0635e626d681d15d'
def digest(data):return hashlib.sha256(data).hexdigest()

def build(a):
    assert digest(a.input.read_bytes())==BASE,'Wrong baseline APK'
    with ZipFile(a.input) as base:
        verify_android_layout(base)
        original={n[7:]:base.read(n) for n in base.namelist() if n.startswith('assets/') and n!='assets/assets.sparsepck'}
        actual=dict(original)
        for p in sorted((a.source/'scripts').iterdir()):
            if p.suffix in ['.gd','.gdshader']:actual['scripts/'+p.name]=p.read_bytes()
        audit=json.loads((a.source/'startup_integrity.json').read_text())
        assert audit['version']==VERSION and audit['class_count']==55
        for e in audit['files']:
            name=e['path'][6:];data=(a.source/name).read_bytes()
            assert len(data)==e['bytes'] and digest(data)==e['sha256'],name
            actual[name]=data
        for folder in ['assets/art/space_v130','assets/audio/space_v130']:
            for p in sorted((a.source/folder).iterdir()):
                if p.is_file() and not p.name.startswith('.') and not p.name.endswith('.import'):actual[folder+'/'+p.name]=p.read_bytes()
        actual['project.godot']=(a.source/'project.godot').read_bytes()
        actual['project.binary']=a.project_binary.read_bytes()
        actual['startup_integrity.json']=(a.source/'startup_integrity.json').read_bytes()
        assert all(actual['scripts/'+p.name]==p.read_bytes() for p in (a.source/'scripts').glob('*.gd'))
        changed=[n for n in sorted(actual) if original.get(n)!=actual[n]]
        actual['assets.sparsepck']=build_index({n:d for n,d in actual.items() if n not in ['_cl_','assets.sparsepck']})
        manifest,metadata=patch_manifest(base.read('AndroidManifest.xml'),VERSION,CODE)
        assert metadata['package']=='com.kauan.noitedahorda.reconstruida' and metadata['previousVersionCode']==136
        strings,_=string_pool(manifest,8)
        manifest=bytes(replace_pool_string(bytearray(manifest),8,strings.index('Horda Espaco R33'),'Horda Espaco R34'))
        a.output.parent.mkdir(parents=True,exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='horda-v134-') as tmp:
            tmp=Path(tmp);unsigned=tmp/'unsigned.apk';aligned=tmp/'aligned.apk';signed=tmp/'signed.apk'
            with ZipFile(unsigned,'w',ZIP_DEFLATED,compresslevel=9) as out:
                written=set()
                for info in base.infolist():
                    name=info.filename
                    if name.startswith('META-INF/'):continue
                    data=manifest if name=='AndroidManifest.xml' else actual[name[7:]] if name.startswith('assets/') else base.read(name)
                    clean=ZipInfo(name,(2026,10,26,0,0,0));clean.compress_type=ZIP_STORED if name in ['resources.arsc','assets/assets.sparsepck'] else info.compress_type;clean._compresslevel=9
                    write_entry(out,clean,data);written.add(name)
                for name in sorted(actual):
                    if 'assets/'+name in written:continue
                    info=ZipInfo('assets/'+name,(2026,10,26,0,0,0));info.compress_type=ZIP_DEFLATED;info._compresslevel=9
                    write_entry(out,info,actual[name])
            env=os.environ.copy();env['HORDA_REBUILD_KEY_PASSWORD']=(a.key.parent/'password.txt').read_text().strip()
            if a.native_lib:env['LD_LIBRARY_PATH']=str(a.native_lib)+':'+str(a.native_lib/'android')+':'+str(a.native_lib.parent)+':'+env.get('LD_LIBRARY_PATH','')
            subprocess.run([str(a.zipalign),'-f','4',str(unsigned),str(aligned)],env=env,check=True)
            cp=str(a.signer)+os.pathsep+str(a.signer.parent/'apksig.jar')
            signer=['java','-cp',cp,'com.android.apksigner.ApkSignerTool']
            subprocess.run(signer+['sign','--ks',str(a.key),'--ks-key-alias','horda-reconstruida','--ks-pass','env:HORDA_REBUILD_KEY_PASSWORD','--key-pass','env:HORDA_REBUILD_KEY_PASSWORD','--out',str(signed),str(aligned)],env=env,check=True)
            result=subprocess.run(signer+['verify','--verbose','--print-certs','--min-sdk-version','24',str(signed)],check=True,text=True,capture_output=True)
            assert CERT in result.stdout
            with ZipFile(signed) as apk:
                assert apk.testzip() is None
                layout=verify_android_layout(apk)
                packed={n[7:]:apk.read(n) for n in apk.namelist() if n.startswith('assets/') and n not in ['assets/assets.sparsepck','assets/_cl_']}
                count=verify_index(apk.read('assets/assets.sparsepck'),packed)
                media=[n for n in base.namelist() if n.endswith(('.ctex','.webp','.png','.ogg','.wav','.pcm','.so','.ttf','.otf'))]
                assert all(apk.read(n)==base.read(n) for n in media),'Prior media changed'
                for e in audit['files']:assert digest(packed[e['path'][6:]])==e['sha256'],e['path']
                assert all(packed['scripts/'+p.name]==p.read_bytes() for p in (a.source/'scripts').glob('*.gd'))
            shutil.copyfile(signed,a.output)
            assert digest(a.output.read_bytes())==digest(signed.read_bytes()),'APK copy mismatch'
    report={'version':VERSION,'code':CODE,'package':metadata['package'],'bytes':a.output.stat().st_size,'sha256':digest(a.output.read_bytes()),'signing_certificate_sha256':CERT,'base_apk_sha256':BASE,'prior_media_entries_preserved':len(media),'original_character_pngs_changed':0,'source_matches_shipped_scripts':True,'startup_files':len(audit['files']),'class_count':audit['class_count'],'sparse_entries':count,'changed':changed,'layout':layout,'physical_device_tested':False}
    a.output.with_suffix('.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))

if __name__=='__main__':
    p=argparse.ArgumentParser()
    for n in ['input','source','output','key','signer','zipalign','project-binary']:p.add_argument('--'+n,type=Path,required=True)
    p.add_argument('--native-lib',type=Path)
    build(p.parse_args())
