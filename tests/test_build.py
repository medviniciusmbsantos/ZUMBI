"""Artifact checks; these do not simulate the Roblox engine."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("build_place", ROOT / "tools/build_place.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class PlaceBuildTests(unittest.TestCase):
    def test_roundtrip_all_source_and_service_hierarchy(self):
        with tempfile.TemporaryDirectory() as directory:
            output = builder.build(Path(directory) / "game.rbxlx")
            root = ET.parse(output).getroot()
            self.assertEqual(root.attrib["version"], "4")
            scripts = root.findall(".//ProtectedString[@name='Source']")
            sources = [p.read_text() for p in sorted((ROOT / "src").rglob("*.luau"))]
            self.assertCountEqual([s.text for s in scripts], sources)
            service = {n.attrib["class"]: n for n in root.findall("Item")}
            self.assertIn("Workspace", service)
            starter_scripts = service["StarterPlayer"].find("Item")
            self.assertEqual(starter_scripts.attrib["class"], "StarterPlayerScripts")
            self.assertEqual(starter_scripts.find("Item").attrib["class"], "LocalScript")
            server = service["ServerScriptService"].find("Item")
            self.assertEqual(server.attrib["class"], "Folder")
            self.assertEqual(len(server.findall("Item[@class='Script']")), 1)
            self.assertEqual(len(root.findall(".//Item[@class='LocalScript']")), 1)
            refs = [n.attrib["referent"] for n in root.findall(".//Item")]
            self.assertEqual(len(refs), len(set(refs)))

    def test_build_is_deterministic(self):
        with tempfile.TemporaryDirectory() as directory:
            first = builder.build(Path(directory) / "one.rbxlx").read_bytes()
            second = builder.build(Path(directory) / "two.rbxlx").read_bytes()
            self.assertEqual(first, second)

    def test_smoke_place_is_separate_and_isolates_saved_profiles(self):
        with tempfile.TemporaryDirectory() as directory:
            output = builder.build(Path(directory) / "smoke.rbxlx", smoke_test=True)
            root = ET.parse(output).getroot()
            scripts = [s.text for s in root.findall(".//ProtectedString[@name='Source']")]
            self.assertIn((ROOT / "tests/StudioSmoke.server.luau").read_text(), scripts)
            self.assertTrue(any('"ZumbiUltimoVoo_smoke_v1"' in s for s in scripts))
            self.assertFalse(any('"ZumbiUltimoVoo_v1"' in s for s in scripts))


if __name__ == "__main__":
    unittest.main()
