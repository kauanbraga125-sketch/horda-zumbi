"""Original synthesized audio for the space power; no third-party samples."""
from pathlib import Path
import json
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/audio/space_v130'
RATE=32000

def save(name, signal, loop=False):
    peak=max(1.0,float(np.max(np.abs(signal)))/0.88)
    data=(np.clip(signal/peak,-1,1)*32767).astype('<i2').tobytes()
    (OUT/(name+'.pcm')).write_bytes(data)
    return {'name':name,'rate':RATE,'loop':loop,'samples':len(signal),'source':'Original mathematical synthesis for Horda Zumbi 0.10.30'}

def tone(length,start,end,gain=.3):
    t=np.arange(round(length*RATE))/RATE
    phase=2*np.pi*(start*t+(end-start)*t*t/(2*length))
    envelope=np.sin(np.minimum(1,t/.04)*np.pi/2)*np.minimum(1,(length-t)/.13)
    return gain*np.sin(phase)*envelope

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    records=[]
    for name,n,a,b in [('beam',1.6,100,980),('hit',.38,160,45),('capture',.55,420,780),('energy',.5,600,1200),('warning',.16,660,660),('return',1.5,720,95),('discovery',1.0,220,880)]:
        signal=tone(n,a,b)
        signal+=tone(n,a*1.5,b*1.5,.09)
        if name=='hit':signal+=np.random.default_rng(130).normal(0,.06,len(signal))*np.exp(-np.arange(len(signal))/RATE*9)
        records.append(save(name,signal))
    seconds=24;time=np.arange(seconds*RATE)/RATE
    music=np.zeros(len(time))
    # Eerie minor arpeggio, soft bass and a quiet pulse; exact 24-second loop.
    notes=[57,64,69,72,57,64,67,71,53,60,65,69,55,62,67,71]
    for i in range(48):
        note=notes[i%len(notes)];freq=440*2**((note-69)/12)
        at=i*.5;local=time-at;active=(local>=0)&(local<1.9)
        envelope=np.maximum(0,np.minimum(1,local/.05))*np.exp(-np.maximum(0,local)*2.2)*active
        music+=.09*(np.sin(2*np.pi*freq*local)+.18*np.sin(2*np.pi*freq*2*local))*envelope
    for freq in [55,82.5,110]:music+=.025*np.sin(2*np.pi*freq*time)*(0.7+0.3*np.sin(2*np.pi*time/12))
    # Tail is crossfaded to the loop head without clicks.
    n=int(.08*RATE);music[-n:]*=np.linspace(1,0,n);music[:n]*=np.linspace(0,1,n)
    records.append(save('music',music,True))
    (OUT/'manifest.json').write_text(json.dumps({'license':'Original project audio; no external sound recordings.','clips':records},indent=2))
    print('SPACE_AUDIO_READY',len(records))

if __name__=='__main__':main()
