"""Original procedural mono 32 kHz PCM cues. Deterministic; no external samples."""
from pathlib import Path
import json, hashlib
import numpy as np

root = Path(__file__).resolve().parents[1]/'assets/audio/adventure_v132'
root.mkdir(parents=True, exist_ok=True)
rate = 32000
rng = np.random.default_rng(132)
def write(name, wave):
    wave = np.tanh(wave)*0.68
    wave[:min(300,len(wave))] *= np.linspace(0,1,min(300,len(wave)))
    wave[-min(900,len(wave)):] *= np.linspace(1,0,min(900,len(wave)))
    data = (wave*32767).astype('<i2').tobytes()
    (root/(name+'.pcm')).write_bytes(data)
    return {'file':name+'.pcm','bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}
files=[]
t=np.arange(int(rate*.82))/rate
w=np.zeros_like(t)
for i,f in enumerate([523.25,659.25,783.99,1046.5]):
    a=np.maximum(0,t-i*.105);env=np.exp(-a*7)*(t>=i*.105)
    w+=(np.sin(2*np.pi*f*a)+.2*np.sin(2*np.pi*f*2*a))*env*.24
files.append(write('perfect',w))
for name,length,lo,hi in [('space_dash',.43,150,1100),('space_boost',1.15,80,760)]:
    t=np.arange(int(rate*length))/rate
    phase=2*np.pi*(lo*t+(hi-lo)*t*t/(2*length))
    env=np.sin(np.pi*t/length)**.8
    noise=np.convolve(rng.standard_normal(len(t)),np.ones(9)/9,mode='same')
    files.append(write(name,(np.sin(phase)*.4+noise*.45)*env))
t=np.arange(int(rate*.58))/rate
noise=np.convolve(rng.standard_normal(len(t)),np.ones(7)/7,mode='same')
files.append(write('space_smash',(noise*.8+np.sin(2*np.pi*(84*t-33*t*t))*.5)*np.exp(-t*9)))
t=np.arange(int(rate*.56))/rate
env=np.sin(np.pi*t/.56)**2*(.6+.4*np.sin(2*np.pi*8*t))
noise=np.convolve(rng.standard_normal(len(t)),np.ones(15)/15,mode='same')
files.append(write('creeper_wing',(noise*.7+np.sin(2*np.pi*72*t)*.25)*env))
(root/'manifest.json').write_text(json.dumps({'license':'Original procedural sound effects for Horda Zumbi; no third-party samples.','rate':rate,'format':'PCM signed 16-bit little-endian mono','files':files},indent=2))
print('ADVENTURE_AUDIO_CREATED',len(files))
