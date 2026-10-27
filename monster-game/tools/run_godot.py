"""Run the native renderer and its X server in the same process environment.

Use --engine GODOT [--runtime-root EXTRACTED_DEBS] -- GODOT_ARGUMENTS.
Linux CI with a normal Xvfb installation does not need --runtime-root.
The game is rendered by Godot; this is not a screenshot mockup generator.
"""
import argparse, os, shutil, socket, subprocess, sys, time
from pathlib import Path

def main():
    split = sys.argv.index('--')
    p=argparse.ArgumentParser();p.add_argument('--engine',type=Path,required=True);p.add_argument('--runtime-root',type=Path)
    a=p.parse_args(sys.argv[1:split]);env=os.environ.copy()
    if a.runtime_root:
        root=a.runtime_root.resolve();libs=root/'usr/lib/x86_64-linux-gnu'
        env['LD_LIBRARY_PATH']=str(libs)+':'+str(libs/'android')+':'+env.get('LD_LIBRARY_PATH','')
        if (libs/'dri').exists(): env['LIBGL_DRIVERS_PATH']=str(libs/'dri')
        server=str(root/'usr/bin/Xvfb');fonts=str(root/'usr/share/fonts/X11/misc')
    else:
        server=shutil.which('Xvfb');fonts='/usr/share/fonts/X11/misc'
    if not server: raise SystemExit('Xvfb is required for native visual verification')
    number=next((n for n in range(97,180) if not Path('/tmp/.X%d-lock'%n).exists()),None)
    if number is None: raise SystemExit('No free X display')
    env['DISPLAY']='127.0.0.1:'+str(number);env['LIBGL_ALWAYS_SOFTWARE']='1'
    with open(os.devnull,'w') as log:
        xvfb=subprocess.Popen([server,':'+str(number),'-screen','0','1920x1080x24','-listen','tcp','-nolisten','unix','-nolisten','local','-ac','-fp',fonts],env=env,stdout=log,stderr=log)
        try:
            for _ in range(100):
                if xvfb.poll() is not None: raise SystemExit('Xvfb failed during startup')
                try:
                    with socket.create_connection(('127.0.0.1',6000+number),.1): break
                except OSError: time.sleep(.05)
            else: raise SystemExit('Xvfb did not become ready')
            result=subprocess.run([str(a.engine.resolve()),*sys.argv[split+1:]],env=env)
            return result.returncode
        finally:
            xvfb.terminate()
            try: xvfb.wait(timeout=5)
            except subprocess.TimeoutExpired: xvfb.kill();xvfb.wait()

if __name__=='__main__': sys.exit(main())
