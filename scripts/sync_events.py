from __future__ import annotations
from pathlib import Path
import re, sys
try:
    from .simple_yaml import load, save
except ImportError:
    from simple_yaml import load, save

ROOT=Path(__file__).resolve().parents[1]

def semester_year(semester):
    m=re.match(r'^(\d{4})-(SuSe|WiSe)$', str(semester))
    if not m: raise ValueError('course.semester must use YYYY-SuSe or YYYY-WiSe')
    return m.group(1), m.group(2)

def select_handbook_events(data, match, semester):
    year, term=semester_year(semester)
    items=data.get('events', data if isinstance(data, list) else [])
    selected=[]
    for e in items:
        hay=' '.join(str(e.get(k,'')) for k in ('title','name','summary','course','module'))
        sem=str(e.get('semester',''))
        if match.lower() in hay.lower() and (not sem or semester in sem or year in sem): selected.append(e)
    if not selected: raise ValueError(f'No handbook events match {match!r} for {semester}')
    return selected

def sync(course_path=ROOT/'course.yml'):
    course=load(course_path); sched=course.get('schedule') or {}; src=ROOT/sched.get('source_path','data/events.yaml')
    handbook=load(src); selected=select_handbook_events(handbook, sched.get('handbook_event_match',''), course['course']['semester'])
    events=list(course.get('events') or [])
    for i,e in enumerate(events):
        if i>=len(selected): break
        h=selected[i]
        for src_key,dst_key in [('date','date'),('start','start'),('end','end'),('location','location'),('id','source_event_id'),('event_id','source_event_id')]:
            if h.get(src_key) not in (None,''): e[dst_key]=h[src_key]
    course['events']=events
    if 'sessions' in course: del course['sessions']
    save(course_path, course)

def main():
    try: sync()
    except Exception as exc: print(f'error: {exc}', file=sys.stderr); return 1
    return 0
if __name__=='__main__': raise SystemExit(main())
