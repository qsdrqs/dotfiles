---
name: drawio-iterative
description: Iteratively refine drawio code by repeatedly exporting to PNG and visually comparing against a reference image. Use when the user provides a reference image (screenshot, mockup, diagram) and asks to recreate it as a drawio/diagrams.net diagram. Triggers on phrases like "recreate this diagram in drawio", "match this image with drawio", "drawio iterative", user provides an image path + drawio request.
---

# Drawio Iterative Refinement

## Overview

Iteratively refine drawio (diagrams.net) code to match a target reference image. The loop:

1. Write or modify drawio XML code
2. Export to PNG via the drawio CLI
3. Visually compare the exported PNG against the reference image
4. Refine the code based on observed differences
5. Repeat until the match is sufficient (model judges)

Python (via `uv`) is available for programmatic XML manipulation when direct editing is cumbersome.

## Workflow

### Step 1: Read the reference image

Use your `Read` tool to load the reference image the user provides. Study its structure, layout, text, shapes, colors, and connections.

### Step 2: Write the initial drawio code

Write a complete `.drawio` file (an XML file containing an `mxGraphModel`) from scratch. Match the reference as closely as possible in layout, shape types, text content, and connections.

See the [Drawio XML Format](#drawio-xml-format) section below for format details.

### Step 3: Export to PNG

Use the bundled script:

```bash
scripts/drawio-to-png.sh diagram.drawio diagram.png [width]
```

Or directly (not recommended -- the script handles edge cases):

```bash
unset NIXOS_OZONE_WL && drawio -x -f png -o diagram.png --width 1024 diagram.drawio
```

**NixOS requirement**: `NIXOS_OZONE_WL` must be unset before calling drawio CLI, or Electron will fail to initialize the Wayland GPU backend.

**Note**: drawio CLI has a known quirk -- it prints "Error: Export failed" to stderr and emits Electron/GPU warnings even when export succeeds (exit code 0). The bundled script handles this by verifying the output file directly instead of trusting drawio's stderr or exit code.

### Step 4: Visually compare

Use your `Read` tool to load both images side by side (or sequentially):

- **Reference image**: the target (user-provided)
- **Generated PNG**: the current export

Identify specific differences:
- Missing or extra elements
- Position/layout shifts
- Text content or sizing mismatches
- Color/style differences
- Connection routing issues

### Step 5: Modify the code (never rewrite)

Do NOT delete and rewrite the drawio file from scratch. Instead, make targeted modifications:

- **Direct XML editing**: Use `edit` tool on the `.drawio` file to change specific cells, geometries, styles, or labels.
- **Python/UV manipulation** (when direct edits are unwieldy): If you need to relocate many elements, batch-update geometries, or apply complex transforms, use Python with `xml.etree.ElementTree` (stdlib) via `uv run`:
  ```bash
  uv run --script python_script.py
  ```
  No additional package installation needed for basic XML operations.

### Step 6: Loop

Go back to Step 3. Continue the cycle until you judge the generated PNG sufficiently matches the reference.

### Step 7: Deliver

Present the final `.drawio` file path and a summary of what was created.

## Drawio XML Format

A `.drawio` file is XML with this structure:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<mxfile host="Electron" modified="2024-01-01T00:00:00.000Z">
  <diagram id="..." name="Page-1">
    <mxGraphModel dx="0" dy="0" grid="1" gridSize="10" guides="1"
      tooltips="1" connect="1" arrows="1" fold="1" page="1"
      pageScale="1" pageWidth="827" pageHeight="1169" math="0" shadow="0">
      <root>
        <mxCell id="0" />
        <mxCell id="1" parent="0" />
        <!-- Diagram cells go here -->
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
```

### Key cell types

**Rectangle / shape:**
```xml
<mxCell id="2" value="Label" style="rounded=1;whiteSpace=wrap;html=1;" vertex="1" parent="1">
  <mxGeometry x="100" y="100" width="120" height="60" as="geometry" />
</mxCell>
```

**Edge / connector:**
```xml
<mxCell id="3" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;" edge="1" parent="1" source="2" target="4">
  <mxGeometry relative="1" as="geometry" />
</mxCell>
```

### Common styles

| Style string | Effect |
|---|---|
| `rounded=1;whiteSpace=wrap;html=1;` | Rounded rectangle |
| `ellipse;whiteSpace=wrap;html=1;` | Circle/ellipse |
| `rhombus;whiteSpace=wrap;html=1;` | Diamond (decision) |
| `shape=process;whiteSpace=wrap;html=1;` | Process shape |
| `shape=parallelogram;whiteSpace=wrap;html=1;` | Parallelogram (input/output) |
| `shape=hexagon;whiteSpace=wrap;html=1;` | Hexagon |
| `text;html=1;align=center;verticalAlign=middle;` | Plain text |
| `swimlane;whiteSpace=wrap;html=1;` | Swimlane/container |
| `fillColor=#FF0000;strokeColor=#000000;` | Fill + stroke color |
| `fontSize=14;fontColor=#333333;` | Text formatting |
| `dashed=1;` | Dashed edge |
| `edgeStyle=orthogonalEdgeStyle;` | Right-angle connector |
| `edgeStyle=curved;` | Curved connector |
| `arrowStart=open;arrowEnd=block;` | Arrow heads |
| `endFill=1;` | Filled arrow head |

### Cell IDs

Use unique string IDs (e.g., `cell-1`, `cell-2`, ...). They must be unique within the diagram. When modifying code, always use new unique IDs for new cells.

## Python/UV Helper Pattern

When modifying drawio XML programmatically is easier than direct text edits:

```python
#!/usr/bin/env uv run
# /// script
# requires-python = ">=3.10"
# ///
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

input_file = Path(sys.argv[1])
output_file = Path(sys.argv[2])

tree = ET.parse(input_file)
root = tree.getroot()
ns = ""  # drawio files typically have no namespace prefix

# Find all cells in the root
diagram = root.find(".//diagram")
if diagram is None:
    # Try alternate structure
    pass

# Navigate to <root> under <mxGraphModel>
mxgraph = root.find(".//mxGraphModel")
root_node = mxgraph.find("root") if mxgraph is not None else None
if root_node is None:
    print("Could not find mxGraphModel/root")
    sys.exit(1)

# Example: list all vertex cells
for cell in root_node.findall("mxCell"):
    if cell.get("vertex") == "1":
        geo = cell.find("mxGeometry")
        if geo is not None:
            print(f"  Cell {cell.get('id')}: x={geo.get('x')}, y={geo.get('y')}, "
                  f"w={geo.get('width')}, h={geo.get('height')}")

# Write changes
tree.write(output_file, xml_declaration=True, encoding="UTF-8")
```

Run with:

```bash
uv run --script script.py input.drawio output.drawio
```

No additional packages needed -- `xml.etree.ElementTree` is stdlib.

**NixOS shared library fix**: If `uv run` fails with `error while loading shared libraries: libstdc++.so.6`, load the `nix` skill and follow its instructions:

```bash
export LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH:$LD_LIBRARY_PATH
```

Or run the script with the library path pre-set:

```bash
LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH uv run --script script.py ...
```

## Stopping Condition

Stop iterating when you visually judge the generated PNG sufficiently matches the reference. Factors to consider:

- Overall layout and proportions
- Shape types and positions
- Text content and alignment
- Connections and routing
- Color scheme

There is no automated threshold. This is a visual judgment call. When in doubt, do one more iteration.

## Scripts

### scripts/drawio-to-png.sh

Exports a `.drawio` file to PNG. Handles the NixOS environment quirk.

```bash
scripts/drawio-to-png.sh input.drawio output.png [width]
```
