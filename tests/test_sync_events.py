import tempfile, unittest
from pathlib import Path
import yaml
from scripts.sync_events import select_handbook_events, sync

class SyncEventsTest(unittest.TestCase):
    def test_select_handbook_events(self):
        data={'events':[{'title':'Analytics & Big Data','semester':'2026-SuSe','date':'2026-04-01'}]}
        self.assertEqual(len(select_handbook_events(data, 'Analytics & Big Data', '2026-SuSe')), 1)
        with self.assertRaises(ValueError):
            select_handbook_events({'events':[]}, 'Analytics & Big Data', '2026-SuSe')

    def test_sync_preserves_manual_fields_and_replaces_sessions(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td); (root/'data').mkdir()
            course={'course':{'semester':'2026-SuSe'},'schedule':{'handbook_event_match':'Analytics & Big Data','source_path':'data/events.yaml'},'sessions':{'legacy':True},'events':[{'session_id':'session-01','type':'lecture','section_label':'Intro','materials':[{'type':'slides','path':'slides/a.html'}]}]}
            (root/'course.yml').write_text(yaml.safe_dump(course, sort_keys=False), encoding='utf-8')
            (root/'data/events.yaml').write_text(yaml.safe_dump({'events':[{'title':'Analytics & Big Data','semester':'2026-SuSe','date':'2026-04-14','start':'09:00','end':'10:30','location':'Room A','id':'abc'}]}), encoding='utf-8')
            # run from repo-independent cwd by monkeypatching source_path relative behavior
            import scripts.sync_events as se
            old=se.ROOT; se.ROOT=root
            try: sync(root/'course.yml')
            finally: se.ROOT=old
            updated=yaml.safe_load((root/'course.yml').read_text())
            ev=updated['events'][0]
            self.assertNotIn('sessions', updated)
            self.assertEqual(ev['session_id'], 'session-01')
            self.assertEqual(ev['type'], 'lecture')
            self.assertEqual(ev['section_label'], 'Intro')
            self.assertEqual(ev['materials'][0]['path'], 'slides/a.html')
            self.assertEqual(ev['date'], '2026-04-14')
            self.assertEqual(ev['source_event_id'], 'abc')
