import tempfile, unittest
from datetime import date
from pathlib import Path
import yaml
from scripts.session_overview import markdown_table, material_title, status, load_events

class SessionOverviewTest(unittest.TestCase):
    def test_statuses(self):
        self.assertEqual(status({'date':'2026-01-01'}, date(2026,1,2)), 'completed')
        self.assertEqual(status({'date':'2026-01-02'}, date(2026,1,2)), 'today')
        self.assertEqual(status({'date':'2026-01-03'}, date(2026,1,2)), 'upcoming')

    def test_loads_events_titles_links_badges_and_missing_fields(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td)
            (root/'slides').mkdir(); (root/'notes').mkdir(); (root/'exercises').mkdir()
            (root/'slides/a.qmd').write_text('---\ntitle: Course\nsubtitle: Intro | Topic\n---\n', encoding='utf-8')
            data={'events':[{'session_id':'session-01','type':'lecture','date':'2026-01-02','section_label':'Intro','title':'Intro','materials':[{'type':'slides','path':'slides/a.html','source':'slides/a.qmd'},{'type':'notes','path':'notes/a.html','source':'notes/a.qmd'},{'type':'assignment','path':'exercises/e_assign.html'},{'type':'solution','path':'exercises/e_solution.html'}]},{'session_id':'presentation','type':'presentation','date':'2026-01-03','materials':[]}]}
            cp=root/'course.yml'; cp.write_text(yaml.safe_dump(data), encoding='utf-8')
            self.assertEqual(len(load_events(cp)), 2)
            self.assertEqual(material_title('slides/a.qmd', root), 'Intro | Topic')
            table=markdown_table(cp, today=date(2026,1,2), root=root)
            self.assertIn('📘 Lecture', table)
            self.assertIn('🎤 Presentation', table)
            self.assertIn('[slides: Intro \\| Topic](slides/a.html)', table)
            self.assertIn('[assignment](exercises/e_assign.html)', table)
            self.assertIn('[solution](exercises/e_solution.html)', table)
            self.assertIn('| TBD | TBD |', table)
