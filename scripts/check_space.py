import os
import shutil
from pathlib import Path

def folder_size(path: Path):
    total = 0
    if not path.exists():
        return None
    for root, dirs, files in os.walk(path):
        for f in files:
            try:
                fp = os.path.join(root, f)
                total += os.path.getsize(fp)
            except Exception:
                pass
    return total

print('Disk usage:')
for d in ['C:', 'D:']:
    try:
        usage = shutil.disk_usage(d+'\\')
        print(f"{d} -> total={usage.total//(1024**3)}GB free={usage.free//(1024**3)}GB")
    except Exception as e:
        print(f"{d} -> error: {e}")

home = Path(os.environ.get('USERPROFILE',''))
paths = {
    '.gradle': home / '.gradle',
    'mobile_build': Path('mobile'),
    'backend': Path('backend'),
}
for name, p in paths.items():
    sz = folder_size(p)
    if sz is None:
        print(f"{name}: not found")
    else:
        print(f"{name}: {sz/(1024**2):.2f} MB")
