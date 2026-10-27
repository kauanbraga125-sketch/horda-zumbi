"""Original short synthesized bird voices, egg cues and water/engine sound."""
import math, random, array, json, hashlib
from pathlib import Path
RATE=32000
OUT=Path(__file__).resolve().parents[1]/'assets/audio/v136'
def make(name,seconds,kind,index=0):
    rng=random.Random(13600+index);low=0.;phase=0.;values=[]
    for n in range(int(seconds*RATE)):
        t=n/RATE;u=t/seconds;noise=rng.uniform(-1,1);low=low*.93+noise*.07
        if kind=='water':
            v=low*.65+noise*.035+math.sin(t*math.tau*103+math.sin(t*math.tau*.75)*2)*.085
            v*=.8+.13*math.sin(t*math.tau*.5)
        elif kind=='splash':v=(noise*.28+low*.8)*math.exp(-u*5)*min(1,t*100)
        elif kind=='crack':v=(noise*.35+math.sin(t*math.tau*85)*.16)*math.exp(-u*13)*min(1,t*1000)
        elif kind=='hatch':
            v=0
            for start,freq in [(0,261.63),(.12,311.13),(.24,392),(.36,523.25),(.57,783.99)]:
                d=t-start
                if d>=0:v+=(math.sin(d*math.tau*freq)+.25*math.sin(d*math.tau*freq*2))*math.exp(-d*3.7)*min(1,d*100)*.19
        else:
            bases=[310,1100,530,370,130];freq=bases[index]*(1+.22*math.sin(u*math.tau*(2 if index==1 else 1))-.2*u)
            phase+=math.tau*freq/RATE
            v=(math.sin(phase+math.sin(phase*.5)*.45)+.16*math.sin(phase*2.03))*.20
            v*=math.sin(min(1,u)*math.pi)**.7
            if index==2:v*=.55+.45*(math.sin(t*math.tau*42)>0)
            if index==4:v+=low*.2*math.sin(u*math.pi)
        fade=min(1,t/.012,(seconds-t)/.03)
        values.append(max(-.88,min(.88,v*max(0,fade))))
    pcm=array.array('h',(int(v*32767) for v in values)).tobytes()
    (OUT/(name+'.pcm')).write_bytes(pcm)
    return {'name':name,'seconds':seconds,'rate':RATE,'bytes':len(pcm),'sha256':hashlib.sha256(pcm).hexdigest(),'original_synthesis':True}
if __name__=='__main__':
    OUT.mkdir(parents=True,exist_ok=True);items=[]
    for i,name in enumerate(['pipoco','fiapo','ferrugem','agourinho','barao']):items.append(make('bird_'+name,.55 if i!=4 else .85,'bird',i))
    for name,seconds,kind in [('sewer_water',4,'water'),('sewer_splash',.7,'splash'),('egg_crack',.3,'crack'),('egg_hatch',1.8,'hatch')]:items.append(make(name,seconds,kind))
    (OUT/'manifest.json').write_text(json.dumps({'sample_format':'s16le_mono','files':items},indent=2)+'\n')
    print(json.dumps({'clips':len(items),'bytes':sum(i['bytes'] for i in items)}))
