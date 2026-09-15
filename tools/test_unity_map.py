"""Regression anchors independently read from Classic 1.4.3's scene hierarchy."""
import json
from pathlib import Path
import unittest

from import_unity_map import hits_wall, validate, wall_boxes

ROOT = Path(__file__).resolve().parents[1]


class MapGeometryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = json.loads((ROOT / "datafiles/school_map.json").read_text(encoding="utf-8"))
        cls.doors = {d["source_name"]: d for d in cls.data["doors"]}

    def test_spawn_classrooms_use_child_offsets(self):
        # World anchors: Unity (0, 5, 22.5) and (10, 5, 37.5).
        left = self.doors["Hall_2Wall_Door (1)"]
        right = self.doors["Hall_2Wall_Door"]
        self.assertEqual((left["cx"], left["cz"], left["side"]), (-1, -3.5, "w"))
        self.assertEqual((right["cx"], right["cz"], right["side"]), (1, -6.5, "e"))
        walls = wall_boxes(self.data)
        self.assertTrue(hits_wall(-1, -4.5, walls))
        self.assertFalse(hits_wall(-1, -3.5, walls))
        self.assertTrue(hits_wall(1, -5.5, walls))
        self.assertFalse(hits_wall(1, -6.5, walls))

    def test_cafeteria_is_not_two_extra_doors(self):
        self.assertNotIn("Cafe_Door", self.doors)
        self.assertNotIn("Cafe_Door (1)", self.doors)
        self.assertEqual(self.doors["Hall_SwingDoor_Side"]["cx"], 5)
        self.assertEqual(self.doors["Hall_SwingDoor_Side (1)"]["cx"], -21)
        self.assertTrue(any(q["k"] == "ceil" and q["bounds"][1] == 10 for q in self.data["quads"]))
        self.assertFalse(hits_wall(-21, -58, wall_boxes(self.data)))

    def test_missing_faculty_door_and_office(self):
        faculty = self.doors["Room_1Wall_FacultyDoor"]
        office = self.doors["Hall_2Wall_Door (3)"]
        self.assertEqual((faculty["cx"], faculty["cz"]), (-11, -12.5))
        self.assertEqual((office["cx"], office["cz"]), (5, -31.5))

    def test_all_rooms_reachable(self):
        stats = validate(self.data)
        self.assertEqual(stats["reachable_floors"], stats["floors"])
        self.assertEqual(stats["doors"], 23)

    def test_material_uv_scale_and_files(self):
        self.assertEqual(self.data["materials"]["WhiteBrickWall"]["uv"][:2], [2, 2])
        self.assertEqual(self.data["materials"]["WhiteBrickWallThin"]["uv"][:2], [1, 2])
        self.assertEqual(self.data["materials"]["Black"]["colour"], 0)
        for material in self.data["materials"].values():
            self.assertTrue((ROOT / "datafiles" / material["file"]).is_file())


if __name__ == "__main__":
    unittest.main()
