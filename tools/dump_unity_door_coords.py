from pathlib import Path
import re
p=Path(r'D:\baldi_s_basics_in_education_and_learning_143_decompile_15\BALDI\Assets\Scene\Scenes\School.unity')
lines=p.read_text(encoding='utf-8',errors='replace').splitlines()
blocks=[]; cur=None
for line in lines:
    if line.startswith('--- !u!'):
        if cur: blocks.append(cur)
        m=re.match(r'--- !u!(\d+) &(\d+)',line); cur={'type':m.group(1),'id':m.group(2),'lines':[]}
    elif cur: cur['lines'].append(line)
if cur: blocks.append(cur)
def field(b,k):
    for x in b['lines']:
        if x.strip().startswith(k+':'): return x.split(':',1)[1].strip()
    return ''
trs={}; gos={}
for b in blocks:
    if b['type']=='4':
        m=re.search(r'fileID: (\d+)',field(b,'m_GameObject')); pos=field(b,'m_LocalPosition'); rot=field(b,'m_LocalRotation'); fa=field(b,'m_Father')
        pm=re.search(r'x: ([-\d.]+), y: ([-\d.]+), z: ([-\d.]+)',pos)
        rm=re.search(r'x: ([-\d.]+), y: ([-\d.]+), z: ([-\d.]+), w: ([-\d.]+)',rot)
        fm=re.search(r'fileID: (\d+)',fa)
        if pm: trs[b['id']]={'go':m.group(1),'x':float(pm.group(1)),'y':float(pm.group(2)),'z':float(pm.group(3)),'ry':float(rm.group(2)) if rm else 0,'rw':float(rm.group(4)) if rm else 1,'fa':fm.group(1) if fm else '0'}
    if b['type']=='1':
        comps=[x for x in re.findall(r'fileID: (\d+)', '\n'.join(b['lines']))]
        gos[b['id']]={'name':field(b,'m_Name').strip(),'comps':comps}
def world(t,guard=0):
    if t not in trs or guard>20: return (0,0,0)
    q=trs[t]; a=world(q['fa'],guard+1); return a[0]+q['x'],a[1]+q['y'],a[2]+q['z']
def gpos(u): return round((u[0]-5)*.2,3),round((u[2]+5)*-.2+2,3)
for patt in ['Room_1Wall_Door','Room_1Wall_FacultyDoor','Hall_2Wall_Door','Hall_2Wall_FacultyDoor','Hall_SwingDoor','Cafe_Door']:
 print('\n###',patt)
 for g in gos.values():
  if patt not in g['name']: continue
  tids=[x for x in g['comps'] if x in trs]
  if not tids: print('MISS',g['name']); continue
  w=world(tids[0]); print(g['name'], 'g=',gpos(w),'u=',tuple(round(x,2) for x in w))
