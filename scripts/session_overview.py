from __future__ import annotations
from datetime import date, datetime
from pathlib import Path
import html, re, yaml

ROOT = Path(__file__).resolve().parents[1]
FM_RE = re.compile(r"(?s)\A---\s*\n(.*?)\n---")
BADGES = {"lecture":"📘 Lecture", "exercise":"🧪 Exercise", "presentation":"🎤 Presentation"}
LABELS = {"slides":"slides", "notes":"notes", "exercise":"exercise", "assignment":"assignment", "solution":"solution", "notebook":"notebook", "solution_notebook":"solution notebook"}

def load_course(path: str|Path = ROOT/'course.yml') -> dict:
    return yaml.safe_load(Path(path).read_text(encoding='utf-8')) or {}

def load_events(path: str|Path = ROOT/'course.yml') -> list[dict]:
    return list(load_course(path).get('events') or [])

def material_title(source: str|None, root: str|Path = ROOT) -> str:
    if not source: return ""
    p = Path(root)/source
    if not p.exists(): return ""
    m = FM_RE.match(p.read_text(encoding='utf-8', errors='ignore'))
    if not m: return ""
    data = yaml.safe_load(m.group(1)) or {}
    return str(data.get('subtitle') or data.get('title') or '')

def status(event: dict, today: date|None = None) -> str:
    today = today or date.today()
    d = event.get('date')
    if not d: return "upcoming"
    if isinstance(d, str): d = datetime.fromisoformat(d).date()
    if d < today: return "completed"
    if d == today: return "today"
    return "upcoming"

def esc(s) -> str:
    return html.escape('' if s is None else str(s)).replace('|','\\|')

def link(label: str, href: str) -> str:
    return f"[{esc(label)}]({href})" if href else esc(label)

def material_links(event: dict, root: str|Path = ROOT) -> str:
    parts=[]
    for m in event.get('materials') or []:
        typ=m.get('type','material'); label=LABELS.get(typ, typ.replace('_',' '))
        title=material_title(m.get('source'), root)
        if title and typ in {'slides','notes'}: label=f"{label}: {title}"
        parts.append(link(label, m.get('path','')))
    return '<br>'.join(parts)

def markdown_table(course_path: str|Path = ROOT/'course.yml', today: date|None=None, root: str|Path = ROOT) -> str:
    events=sorted(load_events(course_path), key=lambda e:(str(e.get('date','9999-12-31')), e.get('session_id','')))
    out=[]; current=None
    for e in events:
        sec=e.get('section_label') or 'Sessions'
        if sec != current:
            if current is not None: out.append('')
            out += [f"### {esc(sec)}", "", "| Date | Status | Type | Session | Topic | Time | Location | Materials |", "|---|---|---|---|---|---|---|---|"]
            current=sec
        time=''
        if e.get('start') or e.get('end'): time=f"{e.get('start','')}–{e.get('end','')}".strip('–')
        out.append('| ' + ' | '.join([esc(e.get('date','TBD')), esc(status(e,today)), esc(BADGES.get(e.get('type'), e.get('type',''))), esc(e.get('session_id','')), esc(e.get('title','')), esc(time or 'TBD'), esc(e.get('location','TBD')), material_links(e, root)]) + ' |')
    return '\n'.join(out)
