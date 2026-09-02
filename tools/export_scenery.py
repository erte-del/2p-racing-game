"""Export the landscape and lake from "Low Poly Scenery Hills and Lake.blend".

Run headlessly:
    blender -b "<path>/Low Poly Scenery Hills and Lake.blend" \
        --python tools/export_scenery.py

The blend is an island diorama: hills rising out of a lake that covers its
whole 2.5-unit footprint, with no flat ground anywhere in it. That is why it
is used as the land *around* the circuit rather than the ground beneath it -
scaled up to sit under a course, the road would run through hillsides and
under the water.

Landscape and lake are exported together and keep their relative positions, so
the water still sits in the terrain exactly as it was authored. The pair is
centred on the origin with the terrain's lowest point at zero, so an instance
can be dropped on the ground plane with no offset.
"""

import bpy
from mathutils import Matrix, Vector

OUT = "/Users/erselinankul/2p-racing-game/assets/models/scenery.glb"
KEEP = {"Landscape": "Landscape", "water": "Lake"}


## The blend's materials drive Base Color from a ColorRamp fed by a Geometry
## node. glTF has no way to express that, so every material exports as plain
## white. Baking the ramp down to one flat colour keeps the artist's palette
## and suits flat-shaded low poly anyway.
BAKE_BIAS = 0.65   # how far towards the ramp's brighter end to land


def bake_flat_colour(material):
    if not material.use_nodes:
        return
    shader = next((n for n in material.node_tree.nodes
                   if n.type == "BSDF_PRINCIPLED"), None)
    if shader is None:
        return
    base = shader.inputs.get("Base Color")
    if base is None or not base.is_linked:
        return
    source = base.links[0].from_node
    if source.type != "VALTORGB":
        return

    stops = source.color_ramp.elements
    dark = stops[0].color
    light = stops[-1].color
    colour = [dark[i] * (1.0 - BAKE_BIAS) + light[i] * BAKE_BIAS for i in range(4)]

    material.node_tree.links.remove(base.links[0])
    base.default_value = colour
    print("[scenery] %-10s baked to (%.2f, %.2f, %.2f)"
          % (material.name, colour[0], colour[1], colour[2]))


def bounds(objects):
    lo = Vector((float("inf"),) * 3)
    hi = Vector((float("-inf"),) * 3)
    for ob in objects:
        for corner in ob.bound_box:
            p = ob.matrix_world @ Vector(corner)
            for i in range(3):
                lo[i] = min(lo[i], p[i])
                hi[i] = max(hi[i], p[i])
    return lo, hi


def main():
    keep = []
    for original, renamed in KEEP.items():
        ob = bpy.data.objects.get(original)
        if ob is None:
            print("[scenery] missing %r" % original)
            continue
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        if ob.parent:
            bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
        if ob.data.users > 1:
            ob.data = ob.data.copy()
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        ob.name = renamed
        keep.append(ob)

    for ob in list(bpy.data.objects):
        if ob not in keep:
            bpy.data.objects.remove(ob, do_unlink=True)
    if not keep:
        return

    for ob in keep:
        for material in ob.data.materials:
            if material:
                bake_flat_colour(material)

    # Shift both by the same amount, so the lake stays where it was cut into
    # the land, and rest the terrain's lowest point on zero.
    lo, hi = bounds(keep)
    shift = Vector(((lo[0] + hi[0]) * 0.5, (lo[1] + hi[1]) * 0.5, lo[2]))
    for ob in keep:
        ob.data.transform(Matrix.Translation(-shift))
        ob.location = (0.0, 0.0, 0.0)
    bpy.context.view_layer.update()

    lo, hi = bounds(keep)
    for ob in keep:
        tris = sum(max(len(p.vertices) - 2, 0) for p in ob.data.polygons)
        print("[scenery] %-10s %5d tris  materials=%s"
              % (ob.name, tris, [m.name for m in ob.data.materials if m]))
    print("[scenery] combined size (%.2f, %.2f, %.2f), base at z=%.3f"
          % (hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2], lo[2]))

    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB",
                              export_apply=True, export_yup=True)
    print("[scenery] wrote %s" % OUT)


main()
