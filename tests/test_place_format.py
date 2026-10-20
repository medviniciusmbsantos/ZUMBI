"""Tampering and filesystem-boundary tests. These are not malware detection tests."""
from copy import deepcopy
from io import BytesIO
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from build_place import build
from package_candidate import package
from place_format import FormatError, PlaceBuilder, verify


class PlaceValidationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.builder = PlaceBuilder(ROOT)
        cls.payload = cls.builder.render()

    def reject(self, mutate):
        tree = ET.fromstring(self.payload)
        mutate(tree)
        with self.assertRaises(FormatError):
            verify(ET.tostring(tree), self.builder.inventory)

    def test_changed_script_is_rejected(self):
        self.reject(lambda t: setattr(t.find(".//ProtectedString[@name='Source']"), "text", "return 123"))

    def test_additional_script_is_rejected(self):
        def mutate(tree):
            script = deepcopy(tree.find(".//Item[@class='Script']"))
            script.set("referent", "UNEXPECTED")
            script.find("Properties/string[@name='Name']").text = "Unexpected"
            tree.find("Item[@class='ServerScriptService']").append(script)
        self.reject(mutate)

    def test_duplicate_source_property_is_rejected(self):
        def mutate(tree):
            props = tree.find(".//Item[@class='Script']/Properties")
            props.append(deepcopy(props.find("ProtectedString")))
        self.reject(mutate)

    def test_duplicate_referent_is_rejected(self):
        self.reject(lambda t: t.findall(".//Item")[1].set("referent", t.find(".//Item").get("referent")))

    def test_external_references_are_rejected(self):
        self.reject(lambda t: ET.SubElement(t, "External").__setattr__("text", "file:///outside"))

    def test_unexpected_property_is_rejected(self):
        def mutate(tree):
            prop = ET.SubElement(tree.find(".//Item[@class='Script']/Properties"), "string", {"name": "LinkedSource"})
            prop.text = "unexpected"
        self.reject(mutate)

    def test_wrong_class_is_rejected(self):
        self.reject(lambda t: t.find(".//Item[@class='Script']").set("class", "ModuleScript"))

    def test_changed_physics_and_missing_properties_are_rejected(self):
        self.reject(lambda t: setattr(t.find(".//float[@name='Gravity']"), "text", "nan"))
        self.reject(lambda t: t.find("Item[@class='Workspace']/Properties").remove(t.find(".//float[@name='Gravity']")))

    def test_entities_and_oversized_xml_are_rejected(self):
        for payload in (b'<!DOCTYPE roblox [<!ENTITY x "abc">]><roblox version="4"/>', b"x" * (10 * 1024 * 1024 + 1)):
            with self.assertRaises(FormatError):
                verify(payload, self.builder.inventory)

    def test_manifest_reports_integrity_without_antivirus_clearance(self):
        manifest = self.builder.manifest(self.payload)
        self.assertEqual(manifest["checks"]["antivirus"], "not_run")
        self.assertEqual(len(manifest["sources"]), len(list((ROOT / "src").rglob("*.luau"))))
        self.assertTrue(all(len(s["sha256"]) == 64 for s in manifest["sources"]))


class FilesystemBoundaryTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / "project"
        self.root.mkdir()
        shutil.copytree(ROOT / "src", self.root / "src")
        shutil.copyfile(ROOT / "default.project.json", self.root / "default.project.json")

    def edit_project(self, transform):
        path = self.root / "default.project.json"
        project = json.loads(path.read_text())
        transform(project)
        path.write_text(json.dumps(project))

    def test_symlink_outside_source_is_rejected(self):
        other = Path(self.temporary.name) / "outside.luau"
        other.write_text("return 1")
        (self.root / "src/shared/outside.luau").symlink_to(other)
        with self.assertRaises(FormatError):
            PlaceBuilder(self.root).render()

    def test_name_collisions_are_rejected(self):
        (self.root / "src/server/Boot.luau").write_text("return {}")
        with self.assertRaises(FormatError):
            PlaceBuilder(self.root).render()

    def test_unsupported_files_are_not_silently_packaged(self):
        (self.root / "src/shared/unexpected.bin").write_bytes(b"unexpected")
        with self.assertRaises(FormatError):
            PlaceBuilder(self.root).render()

    def test_source_controls_are_rejected(self):
        (self.root / "src/shared/Controls.luau").write_text("-- \u202ehidden")
        with self.assertRaises(FormatError):
            PlaceBuilder(self.root).render()

    def test_path_mapping_cannot_hide_inline_children(self):
        self.edit_project(lambda p: p["tree"]["ReplicatedStorage"]["ZumbiShared"].update({"Ignored": {"$className": "Script"}}))
        with self.assertRaises(FormatError):
            PlaceBuilder(self.root).render()

    def test_source_paths_cannot_escape_project(self):
        self.edit_project(lambda p: p["tree"]["ReplicatedStorage"]["ZumbiShared"].update({"$path": "../outside"}))
        Path(self.temporary.name, "outside").mkdir()
        with self.assertRaises(FormatError):
            PlaceBuilder(self.root).render()

    def test_service_class_cannot_be_replaced_by_a_folder(self):
        self.edit_project(lambda p: p["tree"]["StarterPlayer"].update({"$className": "Folder"}))
        with self.assertRaises(FormatError):
            PlaceBuilder(self.root).render()

    def test_invalid_build_does_not_replace_existing_output(self):
        out = self.root / "review/place.rbxlx"
        build(out, project_root=self.root)
        before = out.read_bytes()
        (self.root / "src/shared/unexpected.bin").write_bytes(b"unexpected")
        with self.assertRaises(FormatError):
            build(out, project_root=self.root)
        self.assertEqual(out.read_bytes(), before)

    def test_output_symlink_is_not_followed(self):
        target = self.root / "original.rbxlx"
        target.write_bytes(b"original")
        output = self.root / "linked.rbxlx"
        output.symlink_to(target)
        with self.assertRaises(FormatError):
            build(output, project_root=self.root)
        self.assertEqual(target.read_bytes(), b"original")

    def test_candidate_zip_contents_are_explicit_and_deterministic(self):
        out = self.root / "review/candidate.zip"
        first_report = package(out, self.root)
        first = out.read_bytes()
        second_report = package(out, self.root)
        self.assertEqual(first, out.read_bytes())
        self.assertEqual(first_report, second_report)
        with ZipFile(BytesIO(first)) as z:
            self.assertEqual(z.namelist(), ["ZUMBI-Ultimo-Voo.rbxlx", "MANIFEST.json", "READ-ME.txt"])
            self.assertIsNone(z.testzip())
            self.assertEqual(json.loads(z.read("MANIFEST.json"))["checks"]["antivirus"], "not_run")
            self.assertIn(b"NOT CLEARED BY ANTIVIRUS", z.read("READ-ME.txt"))


if __name__ == "__main__":
    unittest.main()
