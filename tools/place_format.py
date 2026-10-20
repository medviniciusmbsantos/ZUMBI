"""Strict, local-only serializer for this project's supported Rojo mappings.

Validation checks structure and exact source correspondence. It is NOT an antivirus.
No code from a place, project file, or source module is executed by this module.
"""
from __future__ import annotations

from dataclasses import dataclass
from hashlib import sha256
import json
from pathlib import Path
import os
import tempfile
import xml.etree.ElementTree as ET

MAX_PLACE_BYTES = 10 * 1024 * 1024
ALLOWED_CLASSES = {
    "Workspace", "ReplicatedStorage", "ServerScriptService", "StarterPlayer",
    "StarterPlayerScripts", "Lighting", "SoundService", "Folder",
    "Script", "LocalScript", "ModuleScript",
}
SCRIPT_CLASSES = {"Script", "LocalScript", "ModuleScript"}
SERVICE_CLASSES = {"ReplicatedStorage", "ServerScriptService", "StarterPlayer"}


class FormatError(ValueError):
    """The input exceeds the deliberately narrow supported project format."""


@dataclass(frozen=True)
class Entry:
    class_name: str
    source: str | None = None
    source_path: str | None = None


def property_value(element: ET.Element, kind: str, name: str, value: str) -> None:
    props = element.find("Properties")
    if props is None:
        raise FormatError("Missing Properties")
    ET.SubElement(props, kind, {"name": name}).text = value


def safe_name(name: str) -> None:
    if not name or "/" in name or "\\" in name or any(ord(c) < 32 for c in name):
        raise FormatError(f"Invalid instance name: {name!r}")


def read_source(path: Path) -> str:
    if path.stat().st_size > MAX_PLACE_BYTES:
        raise FormatError(f"Source too large: {path.name}")
    source = path.read_text(encoding="utf-8")
    for character in source:
        code = ord(character)
        if (code < 32 and character not in "\n\r\t") or 0x7F <= code <= 0x9F or 0x202A <= code <= 0x202E or 0x2066 <= code <= 0x2069:
            raise FormatError(f"Nonprinting control character in {path.name}")
    return source


def verify(payload: bytes, inventory: dict[str, Entry]) -> None:
    if len(payload) > MAX_PLACE_BYTES or b"<!DOCTYPE" in payload or b"<!ENTITY" in payload:
        raise FormatError("Unsupported XML size or entity declaration")
    try:
        root = ET.fromstring(payload)
    except ET.ParseError as error:
        raise FormatError("Invalid XML") from error
    if root.tag != "roblox" or root.attrib != {"version": "4"}:
        raise FormatError("Expected Roblox XML version 4")
    seen, referents = set(), set()
    allowed_properties = {("string", "Name"), ("ProtectedString", "Source"), ("bool", "Disabled")}
    extras = {
        "Workspace": {("float", "Gravity"), ("float", "FallenPartsDestroyHeight"), ("bool", "StreamingEnabled")},
        "StarterPlayer": {("float", "CameraMaxZoomDistance"), ("float", "CameraMinZoomDistance")},
    }

    def visit(node: ET.Element, prefix: str) -> None:
        cls = node.get("class")
        if node.tag != "Item" or set(node.attrib) != {"class", "referent"} or cls not in ALLOWED_CLASSES:
            raise FormatError("Unknown item class or attributes")
        referent = node.get("referent")
        if not referent or referent in referents:
            raise FormatError("Duplicate or empty referent")
        referents.add(referent)
        if len(node.findall("Properties")) != 1:
            raise FormatError("Each item needs one Properties section")
        props = node.find("Properties")
        names, properties = set(), {}
        for prop in props:
            name = prop.get("name")
            if name in names or set(prop.attrib) != {"name"} or len(prop):
                raise FormatError("Duplicate or nested property")
            names.add(name)
            if (prop.tag, name) not in allowed_properties | extras.get(cls, set()):
                raise FormatError(f"Unexpected property: {name}")
            properties[name] = prop
        name_prop = properties.get("Name")
        if name_prop is None or name_prop.tag != "string":
            raise FormatError("Missing instance name")
        name = name_prop.text or ""
        safe_name(name)
        path = f"{prefix}/{name}" if prefix else name
        expected = inventory.get(path)
        if path in seen or expected is None or expected.class_name != cls:
            raise FormatError(f"Unexpected or duplicate instance: {path}")
        fixed = {
            "Workspace": {"Gravity": ("float", "196.2"), "FallenPartsDestroyHeight": ("float", "-70"), "StreamingEnabled": ("bool", "false")},
            "StarterPlayer": {"CameraMaxZoomDistance": ("float", "18"), "CameraMinZoomDistance": ("float", "0.5")},
        }
        expected_props = {"Name": ("string", name), **fixed.get(cls, {})}
        if cls in SCRIPT_CLASSES:
            expected_props["Source"] = ("ProtectedString", expected.source)
            if cls != "ModuleScript":
                expected_props["Disabled"] = ("bool", "false")
        if set(properties) != set(expected_props) or any(
            properties[key].tag != kind or properties[key].text != value
            for key, (kind, value) in expected_props.items()
        ):
            raise FormatError(f"Properties differ from supported configuration: {path}")
        seen.add(path)
        source = properties.get("Source")
        if cls in SCRIPT_CLASSES:
            if source is None or source.tag != "ProtectedString" or source.text != expected.source:
                raise FormatError(f"Script differs from source: {path}")
            disabled = properties.get("Disabled")
            if cls != "ModuleScript" and (disabled is None or disabled.tag != "bool" or disabled.text != "false"):
                raise FormatError(f"Unexpected script enabled state: {path}")
        elif source is not None or "Disabled" in properties:
            raise FormatError("Script properties on a non-script item")
        for child in node:
            if child.tag == "Item":
                visit(child, path)
            elif child.tag != "Properties":
                raise FormatError("Unexpected XML element")

    external = []
    for node in root:
        if node.tag == "External" and not node.attrib and not len(node):
            external.append(node.text)
        else:
            visit(node, "")
    if external != ["null", "nil"] or seen != set(inventory):
        raise FormatError("Missing items or unexpected External declarations")


def atomic_write(output: Path, payload: bytes) -> None:
    # Do not follow an output symlink or overwrite application source/configuration.
    if output.is_symlink() or any(p.is_symlink() for p in output.parents):
        raise FormatError("Output paths cannot contain symlinks")
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=output.parent, prefix=".zumbi-", delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(payload)
        os.replace(temporary, output)
    finally:
        if temporary and temporary.exists():
            temporary.unlink()


class PlaceBuilder:
    def __init__(self, root: Path):
        self.root = root.resolve()
        self.inventory: dict[str, Entry] = {}
        self.xml = ET.Element("roblox", {"version": "4"})
        ET.SubElement(self.xml, "External").text = "null"
        ET.SubElement(self.xml, "External").text = "nil"

    def item(self, parent: ET.Element, prefix: str, name: str, entry: Entry) -> tuple[ET.Element, str]:
        safe_name(name)
        if entry.class_name not in ALLOWED_CLASSES:
            raise FormatError(f"Unsupported class: {entry.class_name}")
        path = f"{prefix}/{name}" if prefix else name
        if path in self.inventory:
            raise FormatError(f"Duplicate mapped path: {path}")
        self.inventory[path] = entry
        node = ET.SubElement(parent, "Item", {"class": entry.class_name, "referent": f"RBX{len(self.inventory)}"})
        ET.SubElement(node, "Properties")
        property_value(node, "string", "Name", name)
        return node, path

    def source_path(self, relative: str) -> Path:
        original = self.root / relative
        if original.is_symlink() or any(p.is_symlink() for p in original.parents):
            raise FormatError("Source mappings cannot contain symlinks")
        resolved = original.resolve(strict=True)
        if not resolved.is_relative_to(self.root / "src"):
            raise FormatError("Source mapping escapes src")
        return resolved

    def script(self, parent: ET.Element, prefix: str, path: Path, name: str | None = None, source: str | None = None) -> None:
        if path.name.endswith(".server.luau"):
            cls, suffix = "Script", ".server.luau"
        elif path.name.endswith(".client.luau"):
            cls, suffix = "LocalScript", ".client.luau"
        elif path.suffix == ".luau":
            cls, suffix = "ModuleScript", ".luau"
        else:
            raise FormatError("Only Luau source files are supported")
        entry = Entry(cls, read_source(path) if source is None else source, str(path.relative_to(self.root)))
        node, _ = self.item(parent, prefix, name or path.name.removesuffix(suffix), entry)
        property_value(node, "ProtectedString", "Source", entry.source)
        if cls != "ModuleScript":
            property_value(node, "bool", "Disabled", "false")

    def mapping(self, parent: ET.Element, prefix: str, name: str, mapping: dict) -> None:
        if not isinstance(mapping, dict) or set(k for k in mapping if k.startswith("$")) - {"$className", "$path"}:
            raise FormatError("Unknown project mapping keys")
        if not prefix and name in SERVICE_CLASSES and mapping.get("$className", name) != name:
            raise FormatError("A top-level service cannot change class")
        if not prefix and name in SERVICE_CLASSES and "$path" in mapping:
            raise FormatError("Top-level services require explicit inline children")
        if prefix == "StarterPlayer" and name == "StarterPlayerScripts" and mapping.get("$className", name) != name:
            raise FormatError("StarterPlayerScripts must retain its service class")
        if "$path" in mapping:
            if set(mapping) - {"$path", "$className"}:
                raise FormatError("A source mapping cannot also have inline children")
            path = self.source_path(mapping["$path"])
            if path.is_file():
                if "$className" in mapping:
                    raise FormatError("File class is derived from its suffix")
                self.script(parent, prefix, path, name)
                return
            if mapping.get("$className", "Folder") != "Folder":
                raise FormatError("Source directories map only to folders")
            node, current = self.item(parent, prefix, name, Entry("Folder"))
            for child in sorted(path.iterdir()):
                checked = self.source_path(str(child.relative_to(self.root)))
                if checked.is_dir():
                    self.mapping(node, current, child.name, {"$path": str(child.relative_to(self.root))})
                else:
                    self.script(node, current, checked)
            return
        default = name if name in SERVICE_CLASSES | {"StarterPlayerScripts"} else "Folder"
        node, current = self.item(parent, prefix, name, Entry(mapping.get("$className", default)))
        for child_name, child in mapping.items():
            if not child_name.startswith("$"):
                self.mapping(node, current, child_name, child)

    def render(self, smoke_test: bool = False) -> bytes:
        if self.inventory:
            raise FormatError("Use a new builder for each render")
        project = json.loads((self.root / "default.project.json").read_text(encoding="utf-8"))
        tree = project["tree"]
        if tree.get("$className") != "DataModel" or set(k for k in tree if k.startswith("$")) != {"$className"}:
            raise FormatError("Expected a DataModel tree")
        world, _ = self.item(self.xml, "", "Workspace", Entry("Workspace"))
        for kind, name, value in (("float", "Gravity", "196.2"), ("float", "FallenPartsDestroyHeight", "-70"), ("bool", "StreamingEnabled", "false")):
            property_value(world, kind, name, value)
        for name, mapping in tree.items():
            if name.startswith("$"):
                continue
            if name not in SERVICE_CLASSES:
                raise FormatError(f"Unsupported top-level service: {name}")
            self.mapping(self.xml, "", name, mapping)
        for name in ("Lighting", "SoundService"):
            self.item(self.xml, "", name, Entry(name))
        services = {n.find("Properties/string[@name='Name']").text: n for n in self.xml.findall("Item")}
        starter = services["StarterPlayer"]
        property_value(starter, "float", "CameraMaxZoomDistance", "18")
        property_value(starter, "float", "CameraMinZoomDistance", "0.5")
        if smoke_test:
            self.script(services["ServerScriptService"], "ServerScriptService", self.root / "tests/StudioSmoke.server.luau", "ZumbiStudioSmoke")
            for path, entry in list(self.inventory.items()):
                if entry.source_path == "src/shared/Config.luau":
                    old = 'DataStoreName = "ZumbiUltimoVoo_v1"'
                    if entry.source.count(old) != 1:
                        raise FormatError("Cannot isolate the smoke-test DataStore")
                    source = entry.source.replace(old, 'DataStoreName = "ZumbiUltimoVoo_smoke_v1"')
                    self.inventory[path] = Entry(entry.class_name, source, entry.source_path)
                    for node in self.xml.findall(".//Item"):
                        if node.find("Properties/ProtectedString[@name='Source']") is not None:
                            prop = node.find("Properties/ProtectedString[@name='Source']")
                            if prop.text == entry.source:
                                prop.text = source
        ET.indent(self.xml)
        payload = ET.tostring(self.xml, encoding="utf-8", xml_declaration=True)
        verify(payload, self.inventory)
        return payload

    def manifest(self, payload: bytes) -> dict:
        verify(payload, self.inventory)
        return {
            "format_version": 1,
            "place_sha256": sha256(payload).hexdigest(),
            "bytes": len(payload),
            "checks": {"xml_and_exact_source_match": "passed", "antivirus": "not_run", "roblox_engine": "not_run"},
            "security_status": "Defender detection on original package remains unresolved",
            "sources": [
                {"instance": path, "file": entry.source_path, "class": entry.class_name, "sha256": sha256(entry.source.encode("utf-8")).hexdigest()}
                for path, entry in sorted(self.inventory.items()) if entry.source is not None
            ],
        }
