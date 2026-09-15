"""Regression anchors for the presentation failures reported during playtesting."""
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class PresentationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.p = json.loads((ROOT / "datafiles/presentation.json").read_text(encoding="utf-8"))
        cls.map = json.loads((ROOT / "datafiles/school_map.json").read_text(encoding="utf-8"))

    def test_wall_text_runs_left_to_right_on_visible_face(self):
        checked = set()
        for q in self.map["quads"]:
            if q["material"] not in ("SchoolRulesPoster", "Math"):
                continue
            v = q["v"]
            a, b = ([v[1][i]-v[0][i] for i in range(3)], [v[2][i]-v[0][i] for i in range(3)])
            normal = (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
            # Camera facing -normal has right vector (normal.z, 0, -normal.x).
            right = (normal[2], 0, -normal[0])
            gradient = sum(sum(p[i]*right[i] for i in range(3))*(p[3]-.5) for p in v)
            self.assertGreater(gradient, 0, q["material"])
            checked.add(q["material"])
        self.assertEqual(checked, {"SchoolRulesPoster", "Math"})

    def test_notebook_covers_match_authored_rooms(self):
        anchors = {"6581": "_nbSalmon.png", "8088": "_nbBlue.png", "9436": "_nbBlack.png",
                   "8166": "_nbRed.png", "5419": "_nbYellow.png", "6499": "_nbGreen.png", "9322": "_nbCyan.png"}
        self.assertEqual(set(self.p["notebooks"]), set(anchors))
        for ident, filename in anchors.items():
            sprite = self.p["notebooks"][ident]
            self.assertTrue(self.p["textures"][sprite["texture"]]["source"].endswith("/"+filename))
            self.assertEqual((sprite["w"], sprite["h"]), (.404, .512))

    def test_inventory_uses_complete_frame_and_three_slots(self):
        hud = self.p["hud"]
        self.assertEqual(hud["ItemSlots"]["rect"], [512, 0, 128, 67])
        for i in range(3):
            x, y, w, h = hud["slot"+str(i)]["rect"]
            self.assertGreaterEqual(x, 512)
            self.assertLessEqual(x+w, 640)
            self.assertEqual((w, h), (32, 32))
        for i in range(1, 11): self.assertIn("item"+str(i), self.p["textures"])

    def test_exit_sign_is_inside_hall_not_exit_trigger(self):
        self.assertEqual(len(self.p["exit_signs"]), 5)
        start = next(s for s in self.p["exit_signs"] if s["entrance"] == "Entrance (0)")
        self.assertEqual((start["x"], start["y"], start["z"]), (0, 1.74, 0))
        trigger = next(e for e in self.map["exits"] if e["name"] == "Entrance (0)")
        self.assertNotEqual(start["z"], trigger["z"])

    def test_think_pad_fields_and_keys_match_source_canvas(self):
        ui = self.p["yctp"]
        self.assertEqual(ui["YCTP"]["rect"], [0, 0, 640, 480])
        self.assertEqual(ui["question"]["rect"], [208.08, 146, 236.8, 140])
        self.assertEqual(ui["Result1"]["rect"], [138.8, 138.8, 42.4, 42.4])
        keys = [rec for name, rec in ui.items() if name.startswith("Button (")]
        self.assertEqual(len(keys), 13)
        for key in keys:
            x, y, w, h = key["rect"]
            self.assertGreater(x, 445)
            self.assertGreaterEqual(y, 0)
            self.assertLessEqual(x+w, 640)
            self.assertLessEqual(y+h, 480)

    def test_think_pad_opaque_layers_and_text_styles(self):
        ui = self.p['yctp']
        self.assertEqual(ui['BG']['colour'], [0, 0, 0, 1])
        self.assertEqual(ui['TextBG']['rect'], [198.4, 146.32, 280, 140])
        self.assertEqual(ui['answerBackground']['colour'], [1, 1, 1, 1])
        self.assertEqual(ui['answer']['rect'], [253.9199, 290.4, 184, 61.6])
        self.assertEqual(ui['question']['font_size'], 24)
        self.assertAlmostEqual(ui['answer']['font_size'], 52.8)
        for name in ('question', 'question2', 'question3', 'answer'):
            self.assertEqual(ui[name]['alignment'], 257)  # TMP TopLeft
            self.assertEqual(ui[name]['colour'], [0, 0, 0, 1])
        self.assertEqual(self.p['yctp_font']['size'], 24)
        self.assertEqual(self.p['yctp_font']['line_height'], 33)
        self.assertTrue(all(str(code) in self.p['yctp_font']['glyphs'] for code in range(32, 127)))

    def test_baldi_feed_uses_authored_face_animation(self):
        self.assertEqual(self.p['yctp']['BaldiFeed']['rect'], [132, 284, 88, 88])
        for name in ('idle', 'talk', 'frown'):
            anim = self.p['yctp_face'][name]
            for frame in anim['frames']:
                source = self.p['textures'][frame['texture']]['source']
                self.assertIn('/Characters/Baldi/MathGame/', source)
            self.assertEqual(sorted(f['time'] for f in anim['frames']), [f['time'] for f in anim['frames']])
        self.assertEqual(self.p['yctp_face']['talk']['duration'], .4)
        self.assertTrue(self.p['yctp_face']['talk']['loop'])
        self.assertEqual(self.p['yctp_face']['frown']['speed'], .5)
        self.assertFalse(self.p['yctp_face']['frown']['loop'])

    def test_exit_walls_and_near_triggers_match_source(self):
        exits = self.p['details']['entrances']
        self.assertEqual(len(exits), 4)
        self.assertEqual(exits[0]['wall_bounds'], [-1, 2, 1, 1, 4, 1])
        self.assertEqual(exits[0]['near'], [-3.5, .1, -.1, 3.5, 1.1, 2.9])
        maps = set()
        for e in exits:
            self.assertIn(e['wall'], self.p['details']['dynamic_ids'])
            self.assertEqual(e['wall_bounds'][1:5:3], [2, 4])
            maps.add(e['map']['texture'])
        self.assertEqual(len(maps), 4)

    def test_props_use_source_shape_and_world_meshes(self):
        self.assertEqual((self.p['props']['41']['w'], self.p['props']['41']['h']), (.744, 2.048))
        machines = [p for p in self.p['details']['props'].values() if p['meshes']]
        self.assertEqual(len(machines), 3)
        for machine in machines:
            self.assertEqual(len(machine['meshes']), 3)
            self.assertEqual(len(machine['colliders']), 1)
            b = machine['colliders'][0]
            self.assertAlmostEqual(b[4]-b[1], 1.6)
            self.assertGreater(b[3]-b[0], .3)
            self.assertGreater(b[5]-b[2], .3)

    def test_effect_hud_matches_original_layout(self):
        hud = self.p['details']['hud']
        self.assertEqual(hud['item_background']['rect'], [530, 0, 110, 50])
        self.assertEqual(hud['boots']['rect'], [220, -235, 200, 200])
        self.assertEqual(hud['detention']['rect'], [120, 215, 400, 50])
        self.assertEqual(hud['detention']['colour'], [1, 0, 0, 1])
        self.assertEqual(hud['detention']['alignment'], 514)
        self.assertEqual(hud['rope_instruction']['text'], 'Time to jump rope!')
        self.assertEqual(hud['rope_count']['rect'], [240, 288, 160, 40])
        self.assertEqual(len(self.p['details']['rope_frames']), 16)


if __name__ == "__main__": unittest.main()
