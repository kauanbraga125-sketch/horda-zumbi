"""Preserve the 0.9.3 native APK, overlay text sources/resources, regenerate indices.
No export-time script token buffers and no reused sparse directory lengths.
"""
import argparse,hashlib,json,os,re,subprocess,sys
from pathlib import Path
from zipfile import ZipFile,ZipInfo,ZIP_STORED
from apk_format import patch_manifest,replace_pool_string,string_pool,write_entry
from sparse_index import build_index,verify_index

def build(base,resources,source,output,signing_zip,signer):
 output.parent.mkdir(parents=True,exist_ok=True)
 overlays={}
 with ZipFile(resources) as z:
  for name in z.namelist():
   if name.endswith('/') or name.startswith(('validation/','.godot/editor/','.godot/exported/','tests/','tools/')):continue
   if name.endswith(('.gdc','.gd.remap')) or name in ['main.tscn.remap','boot.tscn.remap']:continue
   overlays[name]=z.read(name)
 for p in (source/'scripts').iterdir():
  if p.suffix in ['.gd','.gdshader']:overlays['scripts/'+p.name]=p.read_bytes()
 for name in ['main.tscn','boot.tscn','.godot/global_script_class_cache.cfg']:
  overlays[name]=(source/name).read_bytes()
 assert 'project.binary' in overlays
 startup=['.godot/global_script_class_cache.cfg','boot.tscn','main.tscn']+sorted(n for n in overlays if n.startswith('scripts/') and n.endswith(('.gd','.gdshader')))
 startup+=sorted(n for n in overlays if n.startswith(('assets/art/soldier_v100/','assets/art/polish_v101/')) and n.endswith('.json'))
 integrity={'version':'0.10.1','class_count':len(re.findall(rb'"class":',overlays['.godot/global_script_class_cache.cfg'])),
  'files':[{'path':'res://'+n,'bytes':len(overlays[n]),'sha256':hashlib.sha256(overlays[n]).hexdigest()}for n in startup]}
 overlays['startup_integrity.json']=json.dumps(integrity,ensure_ascii=False,indent=2).encode()
 (source/'startup_integrity.json').write_bytes(overlays['startup_integrity.json'])
 actual={}
 with ZipFile(base) as z:
  for name in z.namelist():
   if not name.startswith('assets/') or name.endswith('/'):continue
   rel=name[7:]
   if rel=='assets.sparsepck' or rel.endswith(('.gdc','.gd.remap')) or rel in ['main.tscn.remap','boot.tscn.remap']:continue
   if rel.startswith(('.godot/editor/','.godot/exported/','validation/')):continue
   actual[rel]=z.read(name)
 actual.update(overlays)
 assert not any(n.endswith('.gdc')for n in actual)
 unsigned=output.with_suffix('.unsigned.apk')
 with ZipFile(base) as z,ZipFile(unsigned,'w') as out:
  manifest,metadata=patch_manifest(z.read('AndroidManifest.xml'),'0.10.1',101)
  strings,_=string_pool(manifest,8)
  for value in strings:
   if value.startswith('Horda Zumbi 0.'):
    manifest=bytes(replace_pool_string(bytearray(manifest),8,strings.index(value),'Horda Zumbi 0.10.1'));break
  for info in z.infolist():
   n=info.filename
   if n.startswith('assets/') or n.startswith('META-INF/') and (n.endswith(('.RSA','.SF','.DSA','.EC')) or n=='META-INF/MANIFEST.MF'):continue
   write_entry(out,info,manifest if n=='AndroidManifest.xml' else z.read(info))
  for name,data in sorted(actual.items()):
   info=ZipInfo('assets/'+name,(2026,10,20,0,0,0));info.compress_type=ZIP_STORED;write_entry(out,info,data)
  indexed={n:b for n,b in actual.items() if n!='_cl_'}
  index=build_index(indexed)
  info=ZipInfo('assets/assets.sparsepck',(2026,10,20,0,0,0));info.compress_type=ZIP_STORED;write_entry(out,info,index)
 private=output.parent.parent/'private-signing';private.mkdir(mode=0o700,exist_ok=True)
 with ZipFile(signing_zip) as z:z.extractall(private);instructions=z.read('LEIA-ME.txt').decode()
 password=re.search(r'^Senha[^:]*:\s*(.+)$',instructions,re.M).group(1).strip()
 alias=re.search(r'^Alias:\s*(.+)$',instructions,re.M).group(1).strip()
 env=os.environ.copy();env['HORDA_SIGNING_PASSWORD']=password
 cmd=['java','-cp',str(signer),'com.android.apksigner.ApkSignerTool']
 subprocess.run(cmd+['sign','--ks',str(private/'playtest091.keystore'),'--ks-key-alias',alias,'--ks-pass','env:HORDA_SIGNING_PASSWORD','--key-pass','env:HORDA_SIGNING_PASSWORD','--out',str(output),str(unsigned)],env=env,check=True)
 subprocess.run(cmd+['verify','--verbose',str(output)],check=True)
 with ZipFile(output)as z,ZipFile(base)as b:
  assert z.testzip() is None
  files={n[7:]:z.read(n)for n in z.namelist()if n.startswith('assets/') and n not in ['assets/assets.sparsepck','assets/_cl_']}
  count=verify_index(z.read('assets/assets.sparsepck'),files)
  native=[n for n in b.namelist() if n.startswith('lib/')]
  assert all(b.read(n)==z.read(n) for n in native)
 report={'apk':str(output),'sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'bytes':output.stat().st_size,'plain_scripts':len([n for n in files if n.endswith('.gd')]),'classes':integrity['class_count'],'verified_index_entries':count,'preserved_native_libraries':native,**metadata}
 output.with_suffix('.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
 unsigned.unlink()

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--base',type=Path,required=True);p.add_argument('--resources',type=Path,required=True);p.add_argument('--source',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--signing-zip',type=Path,required=True);p.add_argument('--signer-jar',type=Path,required=True)
 a=p.parse_args();build(a.base,a.resources,a.source,a.output,a.signing_zip,a.signer_jar)
