"""Update verified v0.10.13.1 APKs, preserving every texture/audio/native byte."""
from pathlib import Path
from zipfile import ZipFile,ZipInfo,ZIP_DEFLATED,ZIP_STORED
import argparse,hashlib,json,os,subprocess,tempfile,shutil
from apk_format import patch_manifest,replace_pool_string,string_pool,write_entry,verify_android_layout
from sparse_index import build_index,verify_index
VERSION='0.10.14';CODE=117
INPUTS={'2fd477db49e657dfc03b8b5cf5da2f50dbf7e2ad80b9f4698811dc22a12ab35c','cc4961456c2f4110af37cbdc7ff5b44ff618610d27154a507b07a7d592585a88'}
def build(a):
 assert hashlib.sha256(a.input.read_bytes()).hexdigest()in INPUTS,'Unverified input APK'
 with ZipFile(a.input)as base:
  verify_android_layout(base)
  actual={n[7:]:base.read(n)for n in base.namelist()if n.startswith('assets/')and n!='assets/assets.sparsepck'}
  changed=['scripts/cosmetics.gd','scripts/market.gd','assets/art/cosmetics_v113/fitting.bin','assets/art/cosmetics_v113/graphics.json']
  for name in changed:
   assert name in actual;actual[name]=(a.source/name).read_bytes()
  if a.project_binary:actual['project.binary']=a.project_binary.read_bytes();changed.append('project.binary')
  audit=json.loads(actual['startup_integrity.json']);audit['version']=VERSION
  for item in audit['files']:
   data=actual[item['path'][6:]];item['bytes']=len(data);item['sha256']=hashlib.sha256(data).hexdigest()
  actual['startup_integrity.json']=json.dumps(audit,ensure_ascii=False,indent=2).encode()
  actual['assets.sparsepck']=build_index({n:b for n,b in actual.items()if n not in ['_cl_','assets.sparsepck']})
  manifest,_=patch_manifest(base.read('AndroidManifest.xml'),VERSION,CODE)
  strings,_=string_pool(manifest,8)
  for i,value in enumerate(strings):
   if value=='Horda Zumbi R13':manifest=bytes(replace_pool_string(bytearray(manifest),8,i,'Horda Zumbi R14'))
  a.output.parent.mkdir(parents=True,exist_ok=True)
  with tempfile.TemporaryDirectory(prefix='horda-v114-')as temp:
   temp=Path(temp);unsigned=temp/'unsigned.apk';aligned=temp/'aligned.apk';signed=temp/'signed.apk'
   with ZipFile(unsigned,'w',compression=ZIP_DEFLATED,compresslevel=9)as out:
    for info in base.infolist():
     n=info.filename
     if n.startswith('META-INF/'):continue
     data=manifest if n=='AndroidManifest.xml'else actual[n[7:]]if n.startswith('assets/')else base.read(n)
     clean=ZipInfo(n,(2026,10,23,0,0,0));clean.compress_type=ZIP_STORED if n in ['resources.arsc','assets/assets.sparsepck']else info.compress_type;clean._compresslevel=9
     write_entry(out,clean,data)
   subprocess.run([str(a.zipalign),'-f','4',str(unsigned),str(aligned)],check=True)
   env=os.environ.copy();env['HORDA_REBUILD_KEY_PASSWORD']=(a.key.parent/'password.txt').read_text().strip()
   cmd=['java','-cp',str(a.signer),'com.android.apksigner.ApkSignerTool']
   subprocess.run(cmd+['sign','--ks',str(a.key),'--ks-key-alias','horda-reconstruida','--ks-pass','env:HORDA_REBUILD_KEY_PASSWORD','--key-pass','env:HORDA_REBUILD_KEY_PASSWORD','--out',str(signed),str(aligned)],env=env,check=True)
   subprocess.run(cmd+['verify','--verbose','--min-sdk-version','24',str(signed)],check=True)
   with ZipFile(signed)as z:
    assert z.testzip()is None;layout=verify_android_layout(z)
    files={n[7:]:z.read(n)for n in z.namelist()if n.startswith('assets/')and n not in ['assets/assets.sparsepck','assets/_cl_']}
    count=verify_index(z.read('assets/assets.sparsepck'),files)
    textures=[n for n in z.namelist()if n.endswith(('.ctex','.webp','.png','.ogg','.wav','.pcm','.so'))]
    assert all(z.read(n)==base.read(n)for n in textures)
   shutil.copyfile(signed,a.output)
 report=dict(version=VERSION,code=CODE,bytes=a.output.stat().st_size,sha256=hashlib.sha256(a.output.read_bytes()).hexdigest(),layout=layout,index_entries=count,unchanged_media_entries=len(textures),changed=changed,device_tested=False)
 a.output.with_suffix('.json').write_text(json.dumps(report,indent=2));print(json.dumps(report),flush=True)
if __name__=='__main__':
 p=argparse.ArgumentParser()
 for n in ['input','source','output','key','signer','zipalign']:p.add_argument('--'+n,type=Path,required=True)
 p.add_argument('--project-binary',type=Path);build(p.parse_args())
