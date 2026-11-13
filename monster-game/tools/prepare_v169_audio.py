"""Prepare the owner's 2026-11-12 cues. Requires numpy and ffmpeg."""
from pathlib import Path
import subprocess,hashlib,json,numpy as np
ROOT=Path(__file__).resolve().parents[1]
RATE=32000

def decode(p):
 return np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(p),'-ac','1','-ar',str(RATE),'-f','f32le','-']),'<f4').copy()

def prepare(upload):
 out=ROOT/'assets/audio/v169';out.mkdir(parents=True,exist_ok=True);records={}
 sources={**{'perfect_'+str(i):next(upload.glob('A_super_energetic,_f_#'+str(i)+'-*')) for i in range(1,5)},'transform_fly':next(upload.glob('A_charismatic,_energ_#4-*')),'transform_mask':next(upload.glob('A_charismatic,_power_#2-*')),'power_warning':next(upload.glob('Create_a_distinctive_#4-*')),'egg_hatch':next(upload.glob('Create_an_exciting,__#2-*')),'egg_crack':next(upload.glob('Create_a_highly_sati_#2-*'))}
 for key,p in sources.items():
  a=decode(p);frame=64;rms=np.sqrt(np.mean(a[:len(a)//frame*frame].reshape(-1,frame).astype('float64')**2,axis=1));active=np.flatnonzero(rms>max(.00316,float(rms.max())*.06))
  start=max(0,int(active[0])*frame-160);end=min(len(a),int(active[-1]+1)*frame+480)
  if key=='egg_crack':start=0;end=min(len(a),round(.185*RATE))
  a=a[start:end].copy();a[:32]*=np.linspace(0,1,32);n=min(320,len(a)//8);a[-n:]*=np.linspace(1,0,n)
  level=np.sqrt(np.mean(a.astype('float64')**2));gain=min(.75/max(float(np.abs(a).max()),1e-6),10**(-19/20)/max(float(level),1e-6));a*=gain
  b=subprocess.check_output(['ffmpeg','-v','error','-f','f32le','-ar',str(RATE),'-ac','1','-i','-','-c:a','libvorbis','-q:a','5','-f','ogg','-'],input=a.astype('<f4').tobytes());(out/(key+'.bin')).write_bytes(b)
  records[key]={'source':p.name,'source_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'file':key+'.bin','sha256':hashlib.sha256(b).hexdigest(),'seconds':round(len(a)/RATE,4),'trim_start_seconds':start/RATE}
 for p in sorted((ROOT/'assets/audio/v7').glob('v7_ui_03_*.ogg')):
  a=decode(p);frame=32;rms=np.sqrt(np.mean(a[:len(a)//frame*frame].reshape(-1,frame).astype('float64')**2,axis=1));start=max(0,int(np.flatnonzero(rms>.03162)[0])*frame-128)
  b=a[start:].copy();b[:48]*=np.linspace(0,1,48)
  subprocess.run(['ffmpeg','-v','error','-y','-f','f32le','-ar',str(RATE),'-ac','1','-i','-','-c:a','libvorbis','-q:a','6',str(p)],input=b.astype('<f4').tobytes(),check=True)
 for p in sorted((ROOT/'assets/audio').glob('civil_new_*.ogg')):
  a=decode(p);frame=64;rms=np.sqrt(np.mean(a[:len(a)//frame*frame].reshape(-1,frame).astype('float64')**2,axis=1));active=np.flatnonzero(rms>.0126);start=max(0,int(active[0])*frame-128);a=a[start:].copy();a[:32]*=np.linspace(0,1,32)
  gain=min(.75/max(float(np.abs(a).max()),1e-6),.13/max(float(np.sqrt(np.mean(a*a))),1e-6));a*=gain
  subprocess.run(['ffmpeg','-v','error','-y','-f','f32le','-ar',str(RATE),'-ac','1','-i','-','-c:a','libvorbis','-q:a','6',str(p)],input=a.astype('<f4').tobytes(),check=True)
 t=np.arange(int(RATE*.14))/RATE
 a=sum((v*np.sin(2*np.pi*523.251*f*t)*np.exp(-t/d) for f,v,d in [(1,.65,.047),(2,.22,.030),(3,.09,.020),(4.01,.04,.012)]));a[:48]*=np.linspace(0,1,48);a[-128:]*=np.linspace(1,0,128);(out/'coin.pcm').write_bytes((a*27000).astype('<i2').tobytes())
 (out/'manifest.json').write_text(json.dumps({'version':'0.10.69','rate':RATE,'cues':records,'coin':'Original synthesized piano-like C5; short onset, ascending diatonic playback pitch.'},indent=2)+'\n')
 print(json.dumps(records,indent=2))
if __name__=='__main__':
 import argparse
 p=argparse.ArgumentParser();p.add_argument('upload',type=Path);prepare(p.parse_args().upload)
