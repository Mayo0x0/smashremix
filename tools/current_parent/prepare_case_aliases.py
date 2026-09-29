#!/usr/bin/env python3
from pathlib import Path
import argparse,json,os

def prepare(root:Path, manifest:Path):
    items=json.loads(manifest.read_text())
    created=[]
    for x in items:
        alias=root/x['alias']; target=root/x['target']
        if os.path.lexists(alias):
            continue
        alias.parent.mkdir(parents=True,exist_ok=True)
        rel=os.path.relpath(target,alias.parent)
        os.symlink(rel,alias,target_is_directory=(x['type']=='dir'))
        created.append(alias)
    return created

def cleanup(created):
    for p in reversed(created):
        try:
            if p.is_symlink(): p.unlink()
        except FileNotFoundError: pass

if __name__=='__main__':
    ap=argparse.ArgumentParser()
    ap.add_argument('root')
    ap.add_argument('--manifest',default=str(Path(__file__).with_name('CASEFOLD-ALIAS-MANIFEST.json')))
    ap.add_argument('--cleanup-list')
    a=ap.parse_args(); root=Path(a.root).resolve(); man=Path(a.manifest).resolve()
    c=prepare(root,man)
    print(f'created {len(c)} case aliases')
    if a.cleanup_list: Path(a.cleanup_list).write_text('\n'.join(str(x) for x in c))
