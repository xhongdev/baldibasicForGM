"""Read Unity text scenes with complete parent transforms and stable file IDs."""
from functools import lru_cache
from pathlib import Path
import re

from import_unity_gameplay import field, ref, vector


class UnityScene:
    def __init__(self, path):
        self.path = Path(path)
        text = self.path.read_text(encoding="utf-8-sig")
        self.blocks = {m[2]: (int(m[1]), m[3]) for m in re.finditer(
            r"^--- !u!(\d+) &(-?\d+)[^\n]*\n(.*?)(?=^--- !u!|\Z)", text, re.M | re.S)}
        self.transforms = {ref(field(b, "m_GameObject")): ident for ident, (kind, b) in self.blocks.items() if kind in (4, 224)}
        self.children = {}
        for tid in self.transforms.values():
            self.children.setdefault(ref(field(self.blocks[tid][1], "m_Father")), []).append(tid)

    def name(self, tid):
        return field(self.blocks[ref(field(self.blocks[tid][1], "m_GameObject"))][1], "m_Name")

    def components(self, tid, kind=None):
        go = self.blocks[ref(field(self.blocks[tid][1], "m_GameObject"))][1]
        ids = re.findall(r"component: \{fileID: (-?\d+)\}", go)
        return [(ident, self.blocks[ident][0], self.blocks[ident][1]) for ident in ids
                if ident in self.blocks and (kind is None or self.blocks[ident][0] == kind)]

    @lru_cache(None)
    def matrix(self, tid):
        if tid == "0":
            return ((1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 1, 0), (0, 0, 0, 1))
        b = self.blocks[tid][1]
        x, y, z, w = vector(b, "m_LocalRotation", (0, 0, 0, 1))
        s = vector(b, "m_LocalScale", (1, 1, 1))
        p = vector(b, "m_LocalPosition", (0, 0, 0))
        rot = ((1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)),
               (2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)),
               (2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)))
        local = tuple(tuple(rot[i][j]*s[j] for j in range(3)) + (p[i],) for i in range(3)) + ((0, 0, 0, 1),)
        parent = self.matrix(ref(field(b, "m_Father")))
        return tuple(tuple(sum(parent[i][k]*local[k][j] for k in range(4)) for j in range(4)) for i in range(4))

    def point(self, tid, p=(0, 0, 0)):
        m = self.matrix(tid)
        return tuple(sum(m[i][j]*p[j] for j in range(3)) + m[i][3] for i in range(3))

    @lru_cache(None)
    def active(self, tid):
        if tid == "0":
            return True
        b = self.blocks[tid][1]
        go = self.blocks[ref(field(b, "m_GameObject"))][1]
        return field(go, "m_IsActive", "1") != "0" and self.active(ref(field(b, "m_Father")))

    def ancestry(self, tid):
        result = []
        while tid != "0":
            result.append(self.name(tid))
            tid = ref(field(self.blocks[tid][1], "m_Father"))
        return list(reversed(result))

    def descendants(self, tid):
        yield tid
        for child in self.children.get(tid, []):
            yield from self.descendants(child)


def gm_point(p):
    return (round((p[0]-5)*0.2, 5), round(p[1]*0.2, 5), round(1-p[2]*0.2, 5))


if __name__ == "__main__":
    import argparse
    from import_unity_gameplay import DEFAULT_UNITY
    parser = argparse.ArgumentParser()
    parser.add_argument("names", nargs="*")
    args = parser.parse_args()
    scene = UnityScene(DEFAULT_UNITY / "Assets/Scene/Scenes/School.unity")
    names = args.names or ["Hall_2Wall_Door (1)", "Hall_2Wall_Door", "Hall_SwingDoor (2)", "Room_1Wall_Door"]
    for tid in scene.transforms.values():
        if scene.name(tid) not in names:
            continue
        for child in scene.descendants(tid):
            print(child, "/".join(scene.ancestry(child)), "world", gm_point(scene.point(child)), "active", scene.active(child))
            for ident, kind, block in scene.components(child):
                if kind == 4:
                    print("  local", field(block, "m_LocalPosition"), "rotation", field(block, "m_LocalRotation"), "scale", field(block, "m_LocalScale"))
                elif kind in (23, 33, 64, 65, 114):
                    print(" ", ident, kind, {k: field(block, k) for k in ("m_Enabled", "m_Mesh", "m_Size", "m_Center", "m_Script") if field(block, k)})
