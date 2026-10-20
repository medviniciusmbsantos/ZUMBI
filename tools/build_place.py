#!/usr/bin/env python3
"""Build a self-contained Roblox XML place from default.project.json, no plugins required.

This intentionally implements only this project's explicit directory/script mappings.
It fails on unknown project properties instead of silently producing an incomplete place.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
SERVICE_CLASSES = {"StarterPlayerScripts"}


def property_value(props: ET.Element, kind: str, name: str, value: str) -> None:
    ET.SubElement(props, kind, {"name": name}).text = value


def item(parent: ET.Element, name: str, cls: str) -> ET.Element:
    element = ET.SubElement(parent, "Item", {"class": cls, "referent": f"RBX{item.counter}"})
    item.counter += 1
    props = ET.SubElement(element, "Properties")
    property_value(props, "string", "Name", name)
    return element


item.counter = 1


def add_script(parent: ET.Element, path: Path, name: str | None = None) -> None:
    suffix = ".server.luau" if path.name.endswith(".server.luau") else ".client.luau" if path.name.endswith(".client.luau") else ".luau"
    cls = "Script" if suffix == ".server.luau" else "LocalScript" if suffix == ".client.luau" else "ModuleScript"
    element = item(parent, name or path.name.removesuffix(suffix), cls)
    props = element.find("Properties")
    property_value(props, "ProtectedString", "Source", path.read_text(encoding="utf-8"))
    if cls != "ModuleScript":
        property_value(props, "bool", "Disabled", "false")


def add_node(parent: ET.Element, name: str, node: dict) -> None:
    unknown = set(k for k in node if k.startswith("$")) - {"$className", "$path"}
    if unknown:
        raise ValueError(f"Unsupported project keys: {unknown}")
    if "$path" in node:
        path = (ROOT / node["$path"]).resolve()
        if not path.is_relative_to(ROOT / "src"):
            raise ValueError(f"Source path escapes src: {path}")
        if path.is_file():
            add_script(parent, path, name)
            return
        if not path.is_dir():
            raise FileNotFoundError(path)
        element = item(parent, name, node.get("$className", "Folder"))
        for source in sorted(path.iterdir()):
            if source.suffix == ".luau":
                add_script(element, source)
            elif source.is_dir():
                add_node(element, source.name, {"$path": str(source.relative_to(ROOT))})
        return
    element = item(parent, name, node.get("$className", name if name in SERVICE_CLASSES or parent.tag == "roblox" else "Folder"))
    for child_name, child_node in node.items():
        if not child_name.startswith("$"):
            add_node(element, child_name, child_node)


def build(output: Path, smoke_test: bool = False) -> Path:
    item.counter = 1
    project = json.loads((ROOT / "default.project.json").read_text())
    root = ET.Element("roblox", {"version": "4"})
    ET.SubElement(root, "External").text = "null"
    ET.SubElement(root, "External").text = "nil"
    workspace = item(root, "Workspace", "Workspace")
    props = workspace.find("Properties")
    property_value(props, "float", "Gravity", "196.2")
    property_value(props, "float", "FallenPartsDestroyHeight", "-70")
    property_value(props, "bool", "StreamingEnabled", "false")
    for name, node in project["tree"].items():
        if not name.startswith("$"):
            add_node(root, name, node)
    item(root, "Lighting", "Lighting")
    item(root, "SoundService", "SoundService")
    if smoke_test:
        server = next(n for n in root.findall("Item") if n.attrib["class"] == "ServerScriptService")
        add_script(server, ROOT / "tests/StudioSmoke.server.luau", "ZumbiStudioSmoke")
        # Smoke purchases/earnings must never share the production profile namespace.
        for module in root.findall(".//Item[@class='ModuleScript']"):
            name = module.find("Properties/string[@name='Name']")
            if name is not None and name.text == "Config":
                source = module.find("Properties/ProtectedString[@name='Source']")
                source.text = source.text.replace('"ZumbiUltimoVoo_v1"', '"ZumbiUltimoVoo_smoke_v1"')
    starter = next(n for n in root.findall("Item") if n.attrib["class"] == "StarterPlayer")
    property_value(starter.find("Properties"), "float", "CameraMaxZoomDistance", "18")
    property_value(starter.find("Properties"), "float", "CameraMinZoomDistance", "0.5")
    ET.indent(root)
    output.parent.mkdir(parents=True, exist_ok=True)
    ET.ElementTree(root).write(output, encoding="utf-8", xml_declaration=True)
    return output


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "build" / "ZUMBI-Ultimo-Voo.rbxlx")
    parser.add_argument("--smoke-test", action="store_true", help="Studio-only engine checks with a separate DataStore namespace")
    args = parser.parse_args()
    result = build(args.output.resolve(), smoke_test=args.smoke_test)
    print(f"Built {result} ({result.stat().st_size:,} bytes)")
