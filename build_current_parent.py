#!/usr/bin/env python3
from pathlib import Path
import argparse, hashlib, json, os, platform, shutil, subprocess
ROOT=Path(__file__).resolve().parent
EXPECTED_UPSTREAM='e04f0e05c3f6888a3f7bea50343953d7e22b4c60b1e4344ba4fe03e59178cf19'
EXPECTED_PARENT='9a96131bc01d50020180646caa4e3d93f386e29d4f4c10e8ed563b9d4d628062'
ROM_SIZE=65_536_000

def sha(p):
    h=hashlib.sha256()
    with open(p,'rb') as f:
        for b in iter(lambda:f.read(1<<20),b''): h.update(b)
    return h.hexdigest()

def run(cmd,cwd=None,env=None,log=None):
    p=subprocess.run(cmd,cwd=cwd,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,errors='replace')
    if log: Path(log).write_text(p.stdout)
    if p.returncode:
        print(p.stdout[-12000:])
        raise SystemExit(f'command failed ({p.returncode}): {cmd}')
    return p.stdout

def choose_bass(explicit=None):
    if explicit: return Path(explicit).resolve()
    if os.name=='nt': return ROOT/'assembler/bass.exe'
    return ROOT/'tools/current_parent/bass-linux-x86_64'

def prepare_aliases():
    if os.name=='nt': return []
    mf=ROOT/'tools/current_parent/CASEFOLD-ALIAS-MANIFEST.json'
    items=json.loads(mf.read_text())
    created=[]
    for x in items:
        alias=ROOT/x['alias']; target=ROOT/x['target']
        if os.path.lexists(alias): continue
        alias.parent.mkdir(parents=True,exist_ok=True)
        rel=os.path.relpath(target,alias.parent)
        os.symlink(rel,alias,target_is_directory=(x['type']=='dir'))
        created.append(alias)
    print(f'[INFO] prepared {len(created)} temporary Linux case aliases')
    return created

def cleanup_aliases(created):
    for p in reversed(created):
        try:
            if p.is_symlink(): p.unlink()
        except FileNotFoundError: pass

def bass_build(bass, source, output, sym):
    env=os.environ.copy(); env.setdefault('TERM','xterm')
    run([str(bass),'-o',str(output),str(source),'-sym',str(sym)],cwd=ROOT,env=env,log=str(sym)+'.stdout.txt')

def check_file(p, expected, label):
    if not p.exists(): raise SystemExit(f'{label} missing: {p}')
    if p.stat().st_size!=ROM_SIZE: raise SystemExit(f'{label} wrong size: {p.stat().st_size}')
    got=sha(p)
    if got!=expected:
        raise SystemExit(f'{label} SHA mismatch\n expected {expected}\n got      {got}')
    print(f'[PASS] {label}: {got}')
    return got

def main():
    ap=argparse.ArgumentParser(description='Build exact canonical 2026-09-29 Smash Remix current parent from the full master-style source tree.')
    ap.add_argument('--bass',help='Bass executable override')
    ap.add_argument('--skip-upstream-build',action='store_true',help='reuse build/upstream-master.z64 after exact SHA verification')
    ap.add_argument('--allow-project-diff',action='store_true',help='allow src/Project to intentionally change the output for future development')
    args=ap.parse_args()
    if not (ROOT/'roms/original.z64').exists():
        raise SystemExit('roms/original.z64 is missing. Restore/provide the same input expected by the upstream master source tree.')
    bdir=ROOT/'build'; bdir.mkdir(exist_ok=True)
    adir=ROOT/'audit/CurrentParent'; adir.mkdir(parents=True,exist_ok=True)
    bass=choose_bass(args.bass)
    if os.name!='nt': os.chmod(bass,0o755)
    upstream=bdir/'upstream-master.z64'
    aliases=[]
    try:
        if not args.skip_upstream_build:
            aliases=prepare_aliases()
            bass_build(bass,'main_upstream.asm',upstream,bdir/'upstream-master.sym')
        check_file(upstream,EXPECTED_UPSTREAM,'clean upstream master build')
    finally:
        cleanup_aliases(aliases)
    canonical=bdir/'canonical-parent.z64'
    bass_build(bass,'main_canonical.asm',canonical,bdir/'canonical-parent.sym')
    check_file(canonical,EXPECTED_PARENT,'canonical reconstructed parent')
    final=ROOT/'ssb64asm.z64'
    bass_build(bass,'main.asm',final,bdir/'current-project.sym')
    final_sha=sha(final)
    release=ROOT/'release/SMASH-REMIX-CURRENT-PARENT-2026-09-29.z64'
    check_file(release,EXPECTED_PARENT,'packaged owner-tested release ROM')
    a=canonical.read_bytes(); b=final.read_bytes(); c=release.read_bytes()
    diffs_cp=sum(x!=y for x,y in zip(a,b)); diffs_cr=sum(x!=y for x,y in zip(a,c))
    if not args.allow_project_diff:
        check_file(final,EXPECTED_PARENT,'default project build')
        if diffs_cp or diffs_cr:
            raise SystemExit(f'zero-diff gate failed: canonical_vs_project={diffs_cp} canonical_vs_release={diffs_cr}')
    elif diffs_cr:
        # canonical must always remain exact even when Project intentionally changes.
        raise SystemExit(f'canonical vs packaged release differs by {diffs_cr} bytes')
    report={
      'status':'PASS',
      'upstream_sha256':EXPECTED_UPSTREAM,
      'canonical_parent_sha256':EXPECTED_PARENT,
      'project_output_sha256':final_sha,
      'rom_size':ROM_SIZE,
      'canonical_vs_project_differing_bytes':diffs_cp,
      'canonical_vs_packaged_release_differing_bytes':diffs_cr,
      'project_diff_allowed':bool(args.allow_project_diff),
      'platform':platform.platform(),
      'bass':str(bass),
      'entrypoints':{'upstream':'main_upstream.asm','canonical':'main_canonical.asm','project':'main.asm'}
    }
    (adir/'BUILD-VERIFICATION.json').write_text(json.dumps(report,indent=2)+'\n')
    (adir/'BUILD-VERIFICATION.txt').write_text(
      'FULL MASTER-STYLE CURRENT PARENT BUILD: PASS\n'
      f'Upstream build SHA-256: {EXPECTED_UPSTREAM}\n'
      f'Canonical parent SHA-256: {EXPECTED_PARENT}\n'
      f'Project output SHA-256: {final_sha}\n'
      f'ROM size: {ROM_SIZE}\n'
      f'Canonical vs project differing bytes: {diffs_cp}\n'
      f'Canonical vs packaged release differing bytes: {diffs_cr}\n')
    print(f'[PASS] canonical vs packaged release differing bytes: {diffs_cr}')
    if not args.allow_project_diff: print('[PASS] current project layer is ZERO-DIFF from canonical parent')
    else: print(f'[INFO] future project layer differs from canonical by {diffs_cp} bytes')

if __name__=='__main__': main()
