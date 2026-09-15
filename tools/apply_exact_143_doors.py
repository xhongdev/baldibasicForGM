import json
from pathlib import Path
p=Path(r'D:\Github\baldibasicForGM\datafiles\school_map.json')
d=json.loads(p.read_text(encoding='utf-8'))
# Exact Hall_2Wall door centers from decompiled School.unity, converted to the imported map.
# Room_1Wall doors remain part of the room geometry and are not extra hallway doors.
d['doors']=[
 {'x':8.0,'z':0.0,'side':'n','kind':'swing','lock_start':True},
 {'x':-8.0,'z':0.0,'side':'s','kind':'swing','lock_start':True},
 {'x':0.0,'z':-8.0,'side':'w','kind':'swing','lock_start':True},
 {'x':12.0,'z':-66.0,'side':'n','kind':'swing','lock_start':False},
 {'x':-22.0,'z':-58.0,'side':'n','kind':'swing','lock_start':False},
 {'x':-6.0,'z':-38.0,'side':'n','kind':'swing','lock_start':False},
 {'x':0.0,'z':-4.0,'side':'e','kind':'swing','lock_start':False},
 {'x':6.0,'z':-38.0,'side':'w','kind':'swing','lock_start':False},
 {'x':0.0,'z':-6.0,'side':'w','kind':'class','lock_start':False},
 {'x':22.0,'z':-32.0,'side':'e','kind':'class','lock_start':False},
 {'x':-22.0,'z':-54.0,'side':'e','kind':'class','lock_start':False},
 {'x':-6.0,'z':-48.0,'side':'n','kind':'class','lock_start':False},
 {'x':22.0,'z':-60.0,'side':'class','kind':'class','lock_start':False},
 {'x':12.0,'z':-6.0,'side':'w','kind':'class','lock_start':False},
 {'x':4.0,'z':-26.0,'side':'n','kind':'class','lock_start':False},
 {'x':6.0,'z':-32.0,'side':'e','kind':'class','lock_start':False},
 {'x':22.0,'z':-18.0,'side':'e','kind':'faculty','lock_start':False},
 {'x':6.0,'z':-46.0,'side':'w','kind':'faculty','lock_start':False},
 {'x':-22.0,'z':-32.0,'side':'w','kind':'faculty','lock_start':False},
 {'x':-6.0,'z':-26.0,'side':'n','kind':'faculty','lock_start':False},
 {'x':-16.0,'z':0.0,'side':'s','kind':'faculty','lock_start':False},
]
# Correct the accidental side label on the east class door.
d['doors'][12]['side']='e'
p.write_text(json.dumps(d,indent=2),encoding='utf-8')
print('wrote',len(d['doors']),'doors')
