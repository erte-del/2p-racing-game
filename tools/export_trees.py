"""Export the five trees from "Low Poly trees pack.blend".

Run headlessly:
    blender -b "<path>/Low Poly trees pack.blend" \
        --python tools/export_trees.py

Each tree in the pack is a collection of loose parts - a trunk plus a pile of
leaf planes or spheres - laid out side by side in one scene. Scattering them
one part at a time would be hopeless, so every collection is joined into a
single mesh named Tree1..Tree5.

The rock collection ("Kamenje") and the pack's lights and camera are dropped:
the game scatters trees, and the ground already has its own scenery.

Each tree is moved to stand on the origin - centred across its trunk's
footprint, with its lowest point at zero - so an instance can be dropped on
the ground plane with no offset. Materials in this pack are already flat
colours, so unlike the scenery blend nothing has to be baked down for glTF.
"""

import bpy
from mathutils import Matrix, Vector

OUT = "/Users/erselinankul/2p-racing-game/assets/models/trees.glb"
TREES = {
    "Drvo 1": "Tree1",
    "Drvo 2": "Tree2",
    "Drvo 3": "Tree3",
    "Drvo 4": "Tree4",
    "Drvo 5": "Tree5",
}


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


def join(collection, name):
    parts = [ob for ob in collection.objects if ob.type == "MESH"]
    if not parts:
        print("[trees] %s has no meshes" % collection.name)
        return None

    bpy.ops.object.select_all(action="DESELECT")
    for ob in parts:
        # Several leaf planes share one mesh between them, so give each part
        # its own copy before the transforms are baked into the vertices.
        if ob.data.users > 1:
            ob.data = ob.data.copy()
        ob.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(parts) > 1:
        bpy.ops.object.join()

    tree = bpy.context.view_layer.objects.active
    tree.name = name
    return tree


def stand_on_origin(tree):
    ## Centre on the widest part of the canopy rather than on the trunk: the
    ## bounding box is what the scatter keeps clear of the road, so what
    ## matters is that the canopy sits over the point it is planted on.
    lo, hi = bounds([tree])
    shift = Vector(((lo[0] + hi[0]) * 0.5, (lo[1] + hi[1]) * 0.5, lo[2]))
    tree.data.transform(Matrix.Translation(-shift))
    tree.location = (0.0, 0.0, 0.0)


def main():
    keep = []
    for original, renamed in TREES.items():
        collection = bpy.data.collections.get(original)
        if collection is None:
            print("[trees] missing collection %r" % original)
            continue
        tree = join(collection, renamed)
        if tree is not None:
            keep.append(tree)

    for ob in list(bpy.data.objects):
        if ob not in keep:
            bpy.data.objects.remove(ob, do_unlink=True)
    if not keep:
        return

    bpy.context.view_layer.update()
    for tree in keep:
        stand_on_origin(tree)
    bpy.context.view_layer.update()

    for tree in keep:
        lo, hi = bounds([tree])
        tris = sum(max(len(p.vertices) - 2, 0) for p in tree.data.polygons)
        print("[trees] %-6s %5d tris  size (%.2f, %.2f, %.2f)"
              % (tree.name, tris, hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]))

    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB",
                              export_apply=True, export_yup=True)
    print("[trees] wrote %s" % OUT)


main()
