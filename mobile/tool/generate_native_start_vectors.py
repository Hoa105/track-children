"""Convert the existing Start SVG artwork to Android VectorDrawable resources.

Run from any directory: python mobile/tool/generate_native_start_vectors.py
Only the SVG features used by these assets are supported; fail on others.
Mascot PNGs and Nunito are loaded directly from Flutter's packaged assets.
"""

from pathlib import Path
import re
import xml.etree.ElementTree as ET

MOBILE = Path(__file__).resolve().parents[1]
SOURCE = MOBILE / "assets/images/scenery/backgrounds/start-assets"
OUTPUT = MOBILE / "android/app/src/main/res/drawable"
ANDROID = "http://schemas.android.com/apk/res/android"
ET.register_namespace("android", ANDROID)
PAINT = {
    "fill": "fillColor",
    "stroke": "strokeColor",
    "stroke-width": "strokeWidth",
    "stroke-linecap": "strokeLineCap",
    "stroke-linejoin": "strokeLineJoin",
}


def key(name):
    return f"{{{ANDROID}}}{name}"


def inherit(node, inherited=None):
    paint = dict(inherited or {})
    paint.update({name: value for name, value in node.attrib.items() if name in PAINT})
    for name, value in paint.items():
        node.set(name, value)
    for child in node:
        inherit(child, paint)


def convert(node, parent):
    tag = node.tag.split("}")[-1]
    # A shape's transform is also significant (e.g. each flower petal).
    for operation, numbers in re.findall(r"(\w+)\(([^)]+)\)", node.get("transform", "")):
        values = re.split(r"[ ,]+", numbers.strip())
        parent = ET.SubElement(parent, "group")
        if operation == "translate":
            attributes = {"translateX": values[0], "translateY": values[1] if len(values) > 1 else "0"}
        elif operation == "scale":
            attributes = {"scaleX": values[0], "scaleY": values[1] if len(values) > 1 else values[0]}
        elif operation == "rotate":
            attributes = {"rotation": values[0]}
            if len(values) == 3:
                attributes.update(pivotX=values[1], pivotY=values[2])
        else:
            raise ValueError(f"Unsupported transform: {operation}")
        for name, value in attributes.items():
            parent.set(key(name), value)
    if tag == "g":
        for child in node:
            convert(child, parent)
        return
    if tag == "path":
        data = node.get("d")
    elif tag == "rect":
        x, y = float(node.get("x", 0)), float(node.get("y", 0))
        width, height = float(node.get("width")), float(node.get("height"))
        data = f"M{x},{y}h{width}v{height}h{-width}Z"
    elif tag in ("circle", "ellipse"):
        x, y = float(node.get("cx", 0)), float(node.get("cy", 0))
        rx = float(node.get("r", node.get("rx", 0)))
        ry = float(node.get("r", node.get("ry", 0)))
        data = f"M{x-rx},{y}a{rx},{ry} 0 1,0 {2*rx},0a{rx},{ry} 0 1,0 {-2*rx},0Z"
    else:
        raise ValueError(f"Unsupported SVG shape: {tag}")
    shape = ET.SubElement(parent, "path", {key("pathData"): data})
    for name, target in PAINT.items():
        value = node.get(name)
        if value is not None:
            shape.set(key(target), "#00000000" if value == "none" else value)
    if node.get("fill") is None:
        shape.set(key("fillColor"), "#000000")
    if node.get("opacity"):
        shape.set(key("fillAlpha"), node.get("opacity"))
        shape.set(key("strokeAlpha"), node.get("opacity"))


for relative in (
    "background/start_background.svg",
    "background/foreground.svg",
    "decorations/underline.svg",
    "decorations/circle.svg",
    "decorations/ground_shadow.svg",
    "decorations/heart.svg",
    "decorations/rays.svg",
    "decorations/jump_marks.svg",
    "decorations/sparkles.svg",
):
    svg = ET.parse(SOURCE / relative).getroot()
    inherit(svg)
    _, _, width, height = svg.get("viewBox").split()
    vector = ET.Element("vector", {
        key("width"): width + "dp", key("height"): height + "dp",
        key("viewportWidth"): width, key("viewportHeight"): height,
    })
    for child in svg:
        convert(child, vector)
    ET.indent(vector)
    destination = OUTPUT / ("start_" + Path(relative).stem + ".xml")
    ET.ElementTree(vector).write(destination, encoding="utf-8", xml_declaration=True)
    print(destination.name)
