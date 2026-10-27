"""Original deterministic flood/engine and metal warning effects, PCM16 mono."""
from pathlib import Path
import math,random,struct,json
ROOT=Path(__file__).resolve().parents[1]/'assets/audio/v137'
RATE=32000
def make(name,seconds,kind):
    rng=random.Random(137+kind);samples=[];brown=0.0;filter1=0.0
    for i in range(round(seconds*RATE)):
        t=i/RATE;n=rng.uniform(-1,1);brown=brown*.982+n*.018;filter1=filter1*.8+n*.2
        if kind==0:
            v=brown*2.7+filter1*.16+math.sin(t*math.tau*76)*.08+math.sin(t*math.tau*133)*.035
            v*=.8+.16*math.sin(t*math.tau/seconds*5)
        else:
            v=(math.sin(t*math.tau*121)+.6*math.sin(t*math.tau*193)+.3*math.sin(t*math.tau*311))*math.exp(-t*5)*.22
            v+=filter1*.22*math.exp(-t*8)
        fade=min(1,t/.012,(seconds-t)/.02)
        samples.append(round(max(-.95,min(.95,v*fade))*32767))
    (ROOT/(name+'.pcm')).write_bytes(struct.pack('<%dh'%len(samples),*samples))
ROOT.mkdir(parents=True,exist_ok=True)
make('sewer_rush',3,0);make('sewer_gate',.9,1)
(ROOT/'manifest.json').write_text(json.dumps({'rate':RATE,'channels':1,'format':'PCM16LE','original':True,'clips':['sewer_rush','sewer_gate']},indent=2)+'\n')
