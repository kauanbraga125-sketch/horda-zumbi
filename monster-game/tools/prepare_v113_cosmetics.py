"""Build frame-specific attachment landmarks and source-UV cuts.

Approved body PNGs remain byte-for-byte unchanged. The runtime caches meshes
and shares the same animation clock and transform as the approved renderer.
"""
from pathlib import Path
import json,math,shutil,struct
import numpy as np
from PIL import Image,ImageDraw
from scipy import ndimage as ndi
from skimage.measure import find_contours
from shapely.geometry import Polygon
from shapely import constrained_delaunay_triangles
import zstandard

ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'assets/art'
OUT=ART/'cosmetics_v113'
OUT.mkdir(exist_ok=True)
ITEMS=[
('coveiro','CARTOLA DO COVEIRO',220,0,'head','legacy',0,'hat',2),
('bruxa','CHAPÉU DA BRUXA',650,0,'head','legacy',1,'hat',3),
('sobrevivente','BONÉ DO SOBREVIVENTE',90,0,'head','legacy',2,'hat',1),
('z_plumber','BONÉ DO ENCANADOR',180,0,'head','zombie_head',0,'hat',1),
('z_straw','CHAPÉU DE PALHA',420,0,'head','zombie_head',1,'hat',2),
('z_adventure','CHAPÉU DO AVENTUREIRO',780,0,'head','zombie_head',2,'hat',3),
('z_nightmare','CHAPÉU DO PESADELO',1900,0,'head','zombie_head',3,'hat',4),
('z_sorcerer','CHAPÉU DO FEITICEIRO',12,0,'head','zombie_head',4,'hat',4),
('z_electric','CAPUZ ELÉTRICO',18,0,'head','zombie_head',5,'helmet',5),
('z_beanie','GORRO DA MADRUGADA',75,0,'head','zombie_head',6,'hat',1),
('z_pirate','TRICÓRNIO PIRATA',1200,0,'head','zombie_head',7,'hat',3),
('z_cyber','ÓCULOS CIBERNÉTICOS',130,0,'face','zombie_style',0,'eyes',1),
('z_goggles','ÓCULOS A VAPOR',650,0,'face','zombie_style',1,'eyes',2),
('z_hockey','MÁSCARA DO GELO',24,0,'face','zombie_style',2,'mask',5),
('z_clown','CABELO DO PALHAÇO',1600,0,'head','zombie_style',3,'hair',4),
('z_scientist','CABELO DO CIENTISTA',950,0,'head','zombie_style',4,'hair',3),
('z_vampire','CAPA DO VAMPIRO',2500,0,'body','zombie_style',5,'cape',4),
('z_scarf','CACHECOL CARMESIM',320,0,'neck','zombie_style',6,'scarf',2),
('z_chain','CORRENTE DO SUBMUNDO',260,0,'neck','zombie_style',7,'chain',2),
('s_chaos','GORRO DO CAOS',480,1,'head','skeleton_head',0,'hat',2),
('s_north','ELMO DO NORTE',1300,1,'head','skeleton_head',1,'hat',3),
('s_wizard','CHAPÉU DAS ESTRELAS',850,1,'head','skeleton_head',2,'hat',3),
('s_striped','CARTOLA LISTRADA',2100,1,'head','skeleton_head',3,'hat',4),
('s_ice','COROA DE GELO',30,1,'head','skeleton_head',4,'hat',5),
('s_ghostpirate','TRICÓRNIO FANTASMA',2800,1,'head','skeleton_head',5,'hat',4),
('s_space','CAPACETE ESPACIAL',22,1,'head','skeleton_head',6,'helmet',5),
('s_crown','COROA DO REI OSSUDO',140,1,'head','skeleton_head',7,'hat',1),
('s_goth','ÓCULOS GÓTICOS',90,1,'face','skeleton_style',0,'eyes',1),
('s_plague','MÁSCARA DA PESTE',1750,1,'face','skeleton_style',1,'mask',4),
('s_comic','MÁSCARA DOS QUADRINHOS',16,1,'face','skeleton_style',2,'eyes',4),
('s_silver','CABELO PRATEADO',1150,1,'head','skeleton_style',3,'hair',3),
('s_punk','CRISTA PUNK',240,1,'head','skeleton_style',4,'hair',2),
('s_vest','COLETE DA MEIA-NOITE',520,1,'body','skeleton_style',5,'vest',2),
('s_bat','CAPA DE MORCEGO',2600,1,'body','skeleton_style',6,'cape',4),
('s_hourglass','AMPULHETA DO ALÉM',7,1,'neck','skeleton_style',7,'chain',3),
]
PREMIUM={'z_sorcerer','z_electric','z_hockey','s_ice','s_space','s_comic','s_hourglass'}
CONTACTS={
 'coveiro':[(.20,.87),(.80,.83)],'bruxa':[(.20,.91),(.80,.94)],'sobrevivente':[(.12,.80),(.82,.84)],
 'z_plumber':[(.18,.92),(.82,.62)],'z_straw':[(.25,.90),(.83,.56)],
 'z_adventure':[(.24,.91),(.83,.68)],'z_nightmare':[(.26,.91),(.83,.71)],
 'z_sorcerer':[(.24,.93),(.83,.71)],'z_electric':[(.54,.60),(.86,.47),(.71,.96)],
 'z_beanie':[(.20,.91),(.80,.69)],'z_pirate':[(.24,.91),(.82,.77)],
 'z_cyber':[(.57,.62),(.90,.38)],'z_goggles':[(.56,.55),(.90,.33)],
 'z_hockey':[(.56,.48),(.90,.40),(.76,.96)],'z_clown':[(.54,.43),(.83,.46)],
 'z_scientist':[(.56,.48),(.82,.50)],'z_vampire':[(.93,.16),(.86,.94),(.12,.62)],
 'z_scarf':[(.71,.08),(.94,.18),(.20,.80)],'z_chain':[(.10,.05),(.88,.08),(.70,.86)],
 's_chaos':[(.32,.92),(.77,.70)],'s_north':[(.30,.92),(.83,.72)],
 's_wizard':[(.23,.91),(.81,.67)],'s_striped':[(.26,.94),(.80,.78)],
 's_ice':[(.28,.91),(.79,.78)],'s_ghostpirate':[(.32,.91),(.84,.71)],
 's_space':[(.51,.41),(.91,.40),(.69,.90)],'s_crown':[(.24,.93),(.83,.82)],
 's_goth':[(.56,.69),(.92,.54)],'s_plague':[(.38,.50),(.62,.40),(.70,.87)],
 's_comic':[(.53,.59),(.91,.48)],'s_silver':[(.62,.33),(.89,.34)],
 's_punk':[(.51,.66),(.80,.59)],'s_vest':[(.24,.09),(.78,.14),(.55,.92)],
 's_bat':[(.91,.10),(.87,.94),(.13,.67)],'s_hourglass':[(.10,.04),(.88,.05),(.77,.84)],
}

def mesh(mask,clip=None):
    # Marching squares preserves face holes; constrained triangulation avoids
    # filling concavities or bridging eye/arm gaps as a triangle fan would.
    geometry=None
    for contour in find_contours(np.pad(mask.astype('uint8'),1),.5):
        points=contour[:,::-1]-.5
        if len(points)<4:continue
        poly=Polygon(points).simplify(.65,preserve_topology=True)
        if not poly.is_valid:poly=poly.buffer(0)
        if poly.is_empty:continue
        geometry=poly if geometry is None else geometry.symmetric_difference(poly)
    if geometry is None:return {'points':[],'indices':[]}
    if clip is not None:geometry=geometry.intersection(clip)
    points=[];indices=[];lookup={}
    for triangle in constrained_delaunay_triangles(geometry).geoms:
        for point in list(triangle.exterior.coords)[:3]:
            key=tuple(round(float(v),2)for v in point)
            if key not in lookup:lookup[key]=len(points);points.append(key)
            indices.append(lookup[key])
    return {'points':points,'indices':indices}

def components(mask):
    labels,n=ndi.label(mask);result=[]
    for label,box in enumerate(ndi.find_objects(labels),1):
        if box is None:continue
        area=int((labels[box]==label).sum())
        if area<6:continue
        y,x=box;result.append((area,x.start,y.start,x.stop-1,y.stop-1,label))
    return labels,result

def frame_info(key,file,rect,anchor,height,kind,outline=None,patch=None):
    full=Image.open(ART/file).convert('RGBA');x,y,cw,ch=map(int,rect)
    im=full.crop((x,y,x+cw,y+ch));p=np.asarray(im).astype(float);r,g,b,a=p.transpose(2,0,1)
    yy,xx=np.mgrid[:ch,:cw]
    skin=((a>80)&(g>60)&(g>r*1.02)&(g>b*1.2))if kind==0 else((a>80)&(r>140)&(g>115)&(b<g*.91)&(r>g*1.02))
    labels,parts=components(skin&(yy<ch*.63))
    candidates=[v for v in parts if v[3]-v[1]>cw*.08 and v[4]-v[2]>ch*.06]
    if not candidates:raise ValueError(('missing head',key,parts))
    head=max(candidates,key=lambda v:v[0]/(1+max(0,v[2]-ch*.25)/ch*5))
    _,l,t,rr,bb,label=head;w=float(rr-l+1);h=float(bb-t+1)
    near=np.array([l+(.59 if kind==0 else .46)*w,t+(.49*h if kind==0 else .70*h)])
    far=np.array([l+(.94 if kind==0 else .82)*w,t+(.55*h if kind==0 else .79*h)])
    if kind==0:eye=(a>100)&(r>160)&(g>120)&(b<g*.87)&(r>g*.95)&(yy>t+h*.28)&(yy<t+h*.66)&(xx>l+w*.42)
    else:eye=(a>100)&(g>75)&(b>70)&(r<g*.8)&(yy>t+h*.45)&(yy<t+h*.98)&(xx>l+w*.25)
    el,eyes=components(eye)
    for which,expected,condition in [('near',near,lambda cx:cx<l+w*.76),('far',far,lambda cx:cx>l+w*.78)]:
        opts=[v for v in eyes if condition((v[1]+v[3])/2)]
        if opts:
            found=min(opts,key=lambda v:np.linalg.norm(np.array([(v[1]+v[3])/2,(v[2]+v[4])/2])-expected))
            ys,xs=np.where(el==found[-1]);loc=np.array([xs.mean(),ys.mean()])
            if which=='near':near=loc
            else:far=loc
    angle=float(np.clip(math.atan2(far[1]-near[1],far[0]-near[0]),-.12,.45))
    right=np.array([math.cos(angle),math.sin(angle)]);down=np.array([-right[1],right[0]])
    scalp=np.array([l+.48*w,t+.18*w]);chin=np.array([l+.68*w,bb-.02*w if kind==0 else t+1.17*w])
    neck=np.array([l+(.27 if kind==0 else .16)*w,bb+.02*h if kind==0 else t+1.16*w])
    torso_angle=.15
    if kind==1:
        gold=(a>80)&(r>140)&(g>85)&(g<r*.9)&(b<g*.72)&(yy>t+1.4*w)&(yy<t+2.35*w)&(xx>l-.85*w)&(xx<l+.55*w)
        _,buckles=components(gold)
        if buckles:
            goldbox=max(buckles,key=lambda v:v[0]);belt=np.array([(goldbox[1]+goldbox[3])/2,(goldbox[2]+goldbox[4])/2]);d=belt-neck;torso_angle=math.atan2(-d[0],d[1])
    else:
        shirt=(a>100)&(r>g*1.3)&(b>g*1.2)&(yy>bb)&(yy<bb+w*.8)&(xx>l-w*.3)&(xx<rr)
        sy,sx=np.where(shirt)
        if len(sx):d=np.array([np.median(sx),np.median(sy)])-neck;torso_angle=math.atan2(-d[0],d[1])
    torso_angle=float(np.clip(torso_angle,-.12,.85));td=np.array([-math.sin(torso_angle),math.cos(torso_angle)]);tr=np.array([td[1],-td[0]])
    hip=neck+td*(.67 if kind==0 else .80)*w
    landmarks=dict(near=near,far=far,scalp=scalp,chin=chin,neck=neck,
        rim_l=scalp-right*.57*w-down*.08*w,rim_r=scalp+right*.52*w-down*.08*w,
        neck_back=neck-right*.22*w-down*.055*w,throat=neck+right*.24*w+down*.025*w,
        shoulder_back=neck-tr*.30*w,shoulder_front=neck+tr*.29*w,
        hip=hip,pendant=neck+td*.38*w+tr*.06*w,cape_tip=hip-tr*.12*w,cape_tail=neck-right*1.08*w+down*.45*w)
    face_roi=(xx>l-.17*w)&(xx<rr+.16*w)&(yy>t-.03*w)&(yy<t+1.30*w)
    face=ndi.binary_dilation(ndi.binary_fill_holes(ndi.binary_closing(skin&face_roi,iterations=2)),iterations=max(2,round(w*.025)))&face_roi
    head_region=((xx>l-.64*w)&(xx<rr+.30*w)&(yy<t+.84*w))if kind==0 else((xx>l-.96*w)&(xx<rr+.28*w)&(yy<t+1.12*w)&(yy<t+.70*w+(xx-(l-.75*w))*.44))
    keep=(~head_region)|face
    def cleanup(k):
        opaque=k&(a>5);lab,comps=components(opaque);discard=np.zeros_like(k)
        for area,lx,ty,rx,by,num in comps:
            if area<max(10,.015*w*w)and ty<t+1.25*w:discard|=lab==num
        return k&~ndi.binary_dilation(discard,iterations=1)
    keep=cleanup(keep)
    body_guard=(np.abs((xx-neck[0])*tr[0]+(yy-neck[1])*tr[1])<.38*w)&(((xx-neck[0])*td[0]+(yy-neck[1])*td[1])>-.12*w)&(((xx-neck[0])*td[0]+(yy-neck[1])*td[1])<1.30*w)
    magenta=(a>20)&(r>g*1.7)&(b>g*1.5)&(r>b*.5)
    cape_area=(xx<neck[0]+(yy-neck[1])*td[0]/max(.1,td[1])-.12*w)&(yy<t+2.2*w)
    remove=ndi.binary_dilation(magenta&cape_area,iterations=7)&~ndi.binary_dilation(skin,iterations=4)&~body_guard
    bare_cape=cleanup(keep&~remove)
    arm_region=(yy>t+.7*w)&(yy<t+2.45*w)&~face_roi
    arms=ndi.binary_dilation(skin&arm_region,iterations=2)&arm_region
    clip=Polygon(outline)if outline else None
    alpha=ndi.binary_dilation(a>0,iterations=2)
    meshes={name:mesh(value&alpha,clip)for name,value in [('bare',keep),('bare_cape',bare_cape),('face',face),('arms',arms)]}
    color=np.median(p[(skin)&face_roi,:3],axis=0)/255 if np.any(skin&face_roi)else np.array([.5,.7,.2])
    info=dict(file=file,rect=rect,anchor=anchor,height=height,kind=kind,box=[l,t,rr,bb],landmarks={k:np.round(v,3).tolist()for k,v in landmarks.items()},head_width=w,right=right.tolist(),down=down.tolist(),skin=color.tolist(),meshes=meshes)
    if patch:info['expression']=patch
    return info

def generate():
    # The four art sheets are user-authorized replacements for lost equipment.
    sources={'zombie_head':'exec-c0e11774-2676-45d1-8594-aed1bc5c7136.png','zombie_style':'exec-78db5ad6-6676-4e17-b98c-9b3e2b01f860.png','skeleton_head':'exec-8691e7f4-04cc-4ec8-b43e-a7421151f9c2.png','skeleton_style':'exec-becedc66-41a7-45e3-be34-1e240b394eff.png'}
    generated=ROOT.parents[1]/'generated_images'
    for group,name in sources.items():
        dest=OUT/(group+'.png')
        if not dest.exists():shutil.copyfile(generated/name,dest)
    catalog=[];graphics={}
    legacy=json.loads((ART/'polish_v101/runtime.json').read_text())
    for id,name,price,kind,slot,group,index,fit,rarity in ITEMS:
        catalog.append(dict(id=id,name=name,price=price,kind=kind,slot=slot,group=group,icon=index,fit=fit,rarity=rarity,currency='eyes'if id in PREMIUM else'coins'))
        file='polish_v101/props.png'if group=='legacy'else'cosmetics_v113/'+group+'.png'
        im=Image.open(ART/file).convert('RGBA')
        if group=='legacy':
            rect=[index%3*512/3,0,512/3,256] # replaced with exact legacy rectangles below
            # Original polish props: the first row is the three head items.
            rect=legacy['sets']['props']['entries'][index]['region']
        else:
            cellw=im.width/4;cellh=im.height/2;x0=round(index%4*cellw);y0=round(index//4*cellh);x1=round((index%4+1)*cellw);y1=round((index//4+1)*cellh)
            alpha=np.asarray(im)[y0:y1,x0:x1,3];lab,comps=components(alpha>10);largest=max(comps,key=lambda v:v[0]);mask=ndi.binary_dilation(lab==largest[-1],iterations=2)
            ys,xs=np.where(mask);rect=[x0+int(xs.min()),y0+int(ys.min()),int(xs.max()-xs.min()+1),int(ys.max()-ys.min()+1)]
        x,y,w,h=map(int,rect);crop=np.asarray(im)[y:y+h,x:x+w];mask=crop[:,:,3]>0
        graphics[id]=dict(file=file,rect=rect,contacts=CONTACTS[id],mesh=mesh(mask))
    (OUT/'catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2))
    (OUT/'graphics.json').write_text(json.dumps(graphics,separators=(',',':')))
    frames={}
    for group,layoutfile in [('z_run','zombie-run-drawn-v78.json'),('z_other','zombie-fluid-v73.json')]:
        layout=json.loads((ART/layoutfile).read_text())
        for i,f in enumerate(layout['frames']):
            patch={k:f[k]for k in ['eye_patch','mouth_patch']if k in f}
            if patch:patch['sheets']={k:layout['sheets'][k]for k in ['expression','mouth']}
            frames[f'{group}_{i}']=frame_info(f'{group}_{i}',layout['sheets'][f['sheet']],f['region'],f['anchor'],f['height'],0,f.get('outline'),patch)
            if i%20==0:print(group,i,flush=True)
    specs={'run':('corrida.png',36,181,178),'jump':('pulo_pouso.png',30,176,185),'push':('quebrar_veiculos.png',36,205,185),'capture':('captura.png',35,280,192),'idle':('idle.png',15,181,192),'panic':('panic.png',15,181,192)}
    feet_run=[240,242,245,249,245,242,248,252,249,249,241,249,248,249,249,243,246,255,246,247,241,247,248,249,234,235,241,241,242,241,232,238,239,238,236,230]
    for clip,(file,count,height,center)in specs.items():
        for i in range(count):
            foot=feet_run[i]if clip=='run'else 278 if clip=='push'else 276 if clip=='capture'else 241 if clip=='jump'else 244
            frames[f's_{clip}_{i}']=frame_info(f's_{clip}_{i}','esqueleto_aprovado/'+file,[i%6*384,i//6*288,384,288],[center,foot],height,1)
        print('skeleton',clip,count,flush=True)
    payload=json.dumps(frames,separators=(',',':')).encode();packed=zstandard.ZstdCompressor(level=19).compress(payload)
    (OUT/'fitting.bin').write_bytes(struct.pack('<I',len(payload))+packed)
    print('frames',len(frames),'raw',len(payload),'zstd',len(packed),flush=True)
    # Measurement boards for inspection. These are development reports only.
    keys=list(frames)[::6];board=Image.new('RGB',(8*240,math.ceil(len(keys)/8)*300),(40,32,51));draw=ImageDraw.Draw(board)
    for n,key in enumerate(keys):
        f=frames[key];im=Image.open(ART/f['file']).convert('RGBA');x,y,w,h=f['rect'];im=im.crop((x,y,x+w,y+h));scale=min(220/w,260/h);im=im.resize((round(w*scale),round(h*scale)));ox=n%8*240;oy=n//8*300;board.paste(im,(ox,oy),im)
        for name,color in [('near','cyan'),('far','blue'),('scalp','yellow'),('neck','red'),('hip','lime')]:
            px,py=f['landmarks'][name];px=ox+px*scale;py=oy+py*scale;draw.ellipse((px-2,py-2,px+2,py+2),fill=color)
        draw.text((ox+5,oy+275),key,fill='white')
    report=ROOT.parents[1]/'horda-build/reports';board.save(report/'landmarks.jpg')

if __name__=='__main__':generate()
