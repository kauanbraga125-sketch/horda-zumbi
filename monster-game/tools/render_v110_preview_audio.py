"""Mix a preview's soundtrack from the actual cue timestamps emitted by Godot.
The result is an illustrative offline mix of the shipped sounds, not device capture.
"""
import argparse,json,wave
from pathlib import Path
import numpy as np
RATE=32000

def render(events_file:Path, output:Path, seconds:float=13):
    root=Path(__file__).resolve().parents[1]
    events=json.loads(events_file.read_text())
    sources={p.stem:np.frombuffer(p.read_bytes(),dtype='<i2').astype(np.float64)/32768 for p in (root/'assets/audio/results_v110').glob('*.pcm')}
    track=np.zeros(round(seconds*RATE))
    def add(samples,time):
        start=round((time-1/12)*RATE)
        if start<0:samples=samples[-start:];start=0
        n=min(len(samples),len(track)-start)
        if n>0:track[start:start+n]+=samples[:n]
    for i,e in enumerate(events):
        name=e['name'].removeprefix('result_')
        if name=='fill_stop':continue
        source=sources[name]
        if name=='fill':
            stop=next((ev['time'] for ev in events[i+1:] if ev['name']=='result_fill_stop'),seconds)
            duration=max(.01,stop-e['time']);t=np.arange(round(duration*RATE))/RATE
            position=(.94*t+.05*t*t/duration)*RATE
            samples=np.interp(position%len(source),np.arange(len(source)),source)
            gain=10**((-9+np.sin(t/duration*np.pi)*2)/20)
            envelope=np.minimum(1,t/.025)*np.minimum(1,(duration-t)/.025)
            samples*=gain*envelope
        else:
            positions=np.arange(0,len(source),float(e['pitch']))
            samples=np.interp(positions,np.arange(len(source)),source)*10**(float(e['volume'])/20)
        add(samples*.85,e['time'])
    peak=float(np.max(np.abs(track)))
    if peak>.88:track*=.88/peak
    with wave.open(str(output),'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(RATE);w.writeframes(np.round(np.clip(track,-1,1)*32767).astype('<i2').tobytes())
    print(json.dumps({'events':len(events),'seconds':seconds,'peak':peak,'output':str(output)}))
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('events',type=Path);p.add_argument('output',type=Path);p.add_argument('--seconds',type=float,default=13);a=p.parse_args();render(a.events,a.output,a.seconds)
