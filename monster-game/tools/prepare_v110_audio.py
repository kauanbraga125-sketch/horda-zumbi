"""Short, onset-aligned PCM cues derived from the existing game's audio.
No external download, credentials, or new licensing source. Requires ffmpeg/numpy.
"""
from pathlib import Path
import hashlib,json,subprocess
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/audio/results_v110'
RATE=32000

def read(name):
    p=ROOT/'assets/audio'/name
    raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(p),'-ar',str(RATE),'-ac','1','-f','f32le','-'])
    return p,np.frombuffer(raw,dtype='<f4').copy()

def save(name,source,length,loop=False):
    path,a=read(source)
    if loop:
        # Remove the boundary fades and crossfade a full wrap for seamless flow.
        a=a[int(.13*RATE):int((len(a)/RATE-.13)*RATE)]
        n=int(.18*RATE);ramp=np.linspace(0,1,n)
        a=np.concatenate([a[n:-n],a[-n:]*(1-ramp)+a[:n]*ramp])
    else:
        window=max(1,int(.003*RATE))
        rms=np.sqrt(np.convolve(a*a,np.ones(window)/window,mode='valid'))
        active=np.flatnonzero(rms>max(.002,float(rms.max())*.08))
        start=max(0,int(active[0]) if len(active) else 0)
        a=a[max(0,start-int(.002*RATE)):max(0,start-int(.002*RATE))+int(length*RATE)]
        if len(a)<int(length*RATE):a=np.pad(a,(0,int(length*RATE)-len(a)))
        fade=min(int(.025*RATE),len(a)//3);a[-fade:]*=np.linspace(1,0,fade)
        attack=min(90,len(a));a[:attack]*=np.linspace(0,1,attack)
    peak=float(np.max(np.abs(a)))
    if peak:a*=.65/peak
    pcm=np.round(np.clip(a,-1,1)*32767).astype('<i2').tobytes()
    (OUT/(name+'.pcm')).write_bytes(pcm)
    return {'id':name,'file':name+'.pcm','source':str(path.relative_to(ROOT)), 'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'sha256':hashlib.sha256(pcm).hexdigest(),'rate':RATE,'channels':1,'format':'signed 16-bit little-endian PCM','seconds':len(a)/RATE,'loop':loop,'processing':'audible-onset crop; 2.8 ms attack; 25 ms release; normalized -3.74 dBFS peak' if not loop else 'boundary fade removal; 180 ms wrap crossfade; normalized -3.74 dBFS peak'}

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    files=[save('soul','v7/v7_rec_02_1.ogg',.34),save('fill','v7/v7_rit_01_1.ogg',3.5,True),save('full','v7/v7_rit_02_1.ogg',.55),save('coin','v7/v7_rec_01_1.ogg',.18),save('reward','level_up.ogg',1.05)]
    (OUT/'manifest.json').write_text(json.dumps({'version':'0.10.10','provenance':'Derived only from existing project sounds; original files unchanged. Source provenance retained in assets/audio/v7/manifest.json and assets/audio/SOURCES*.json.','files':files},ensure_ascii=False,indent=2))
    print(json.dumps({'files':len(files),'bytes':sum((OUT/f['file']).stat().st_size for f in files),'durations':{f['id']:f['seconds'] for f in files}}))
if __name__=='__main__':main()
