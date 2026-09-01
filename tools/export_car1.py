"""Export the Low Poly Car .blend into a game-ready car1.glb for Godot.

Run headlessly:
    blender -b "<path>/Low Poly Car.blend" --python tools/export_car1.py

What it does:
  * drops the Camera / Floor / Sun (scene dressing we don't want in-game)
  * applies modifiers (the body has a Mirror) so the mesh is final
  * rescales the car to a realistic length and orients it to face Blender +Y,
    which the glTF exporter maps to -Z, i.e. Godot's forward axis
  * re-origins it to ground-centre so the car sits on Y=0 in Godot
  * keeps the four wheels as separate nodes so they can be steered / spun,
    each with its pivot moved to its own centre so it rotates in place
"""

import bpy
from mathutils import Vector

TARGET_LENGTH = 4.3  # metres, nose to tail
DROP = {"Camera", "Floor", "Sun"}
OUT = "/Users/erselinankul/2p-racing-game/assets/models/car1.glb"

# Source names in the .blend. The final Wheel_?? names are derived from each
# wheel's measured position, not from these, so a mirrored/renamed source
# can't silently produce a car with its left and right wheels swapped.
WHEEL_SOURCES = ["Wheels.Fr", "Wheels.Fr.001", "Wheels.Bk", "Wheels.Bk.001"]


def world_bbox(objects):
    """Axis-aligned world-space bounds over the evaluated meshes."""
    deps = bpy.context.evaluated_depsgraph_get()
    lo = Vector((float("inf"),) * 3)
    hi = Vector((float("-inf"),) * 3)
    for ob in objects:
        ev = ob.evaluated_get(deps)
        for corner in ev.bound_box:
            p = ev.matrix_world @ Vector(corner)
            for i in range(3):
                lo[i] = min(lo[i], p[i])
                hi[i] = max(hi[i], p[i])
    return lo, hi


def main():
    # 1. strip scene dressing
    for name in DROP:
        ob = bpy.data.objects.get(name)
        if ob:
            bpy.data.objects.remove(ob, do_unlink=True)

    main_empty = bpy.data.objects["Main"]
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]

    # 2. apply modifiers (Mirror on the body) so the exported mesh is final
    bpy.ops.object.select_all(action="DESELECT")
    for ob in meshes:
        bpy.context.view_layer.objects.active = ob
        for mod in list(ob.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)

    # 3. work out which end is the front, from the wheels
    front = bpy.data.objects["Wheels.Fr"]
    back = bpy.data.objects["Wheels.Bk"]
    front_y = (front.matrix_world @ Vector(front.bound_box[0]))[1]
    back_y = (back.matrix_world @ Vector(back.bound_box[0]))[1]
    print(f"[car1] front wheel y={front_y:.3f} back wheel y={back_y:.3f}")
    if front_y < back_y:
        # car points down -Y; spin it so the nose faces +Y (-> Godot -Z)
        main_empty.rotation_euler[2] += 3.141592653589793
        bpy.context.view_layer.update()
        print("[car1] rotated 180deg so the nose faces +Y")

    # 4. normalise scale to a realistic car length
    lo, hi = world_bbox(meshes)
    length = hi[1] - lo[1]
    factor = TARGET_LENGTH / length
    main_empty.scale *= factor
    bpy.context.view_layer.update()
    print(f"[car1] length {length:.3f}m -> {TARGET_LENGTH}m (x{factor:.4f})")

    # 5. re-origin: centred on X/Y, sitting on the ground at Z=0
    lo, hi = world_bbox(meshes)
    centre = (lo + hi) / 2.0
    main_empty.location -= Vector((centre[0], centre[1], lo[2]))
    bpy.context.view_layer.update()

    lo, hi = world_bbox(meshes)
    print(f"[car1] final size W={hi[0]-lo[0]:.3f} L={hi[1]-lo[1]:.3f} H={hi[2]-lo[2]:.3f}")
    print(f"[car1] final bounds min={tuple(round(v,3) for v in lo)} max={tuple(round(v,3) for v in hi)}")

    body = bpy.data.objects.get("Sports car")
    if body:
        body.name = "Body"

    # 6. give each wheel its own pivot, so it spins in place instead of
    #    orbiting the car's centre (they all share the body's origin otherwise)
    wheels = [bpy.data.objects[n] for n in WHEEL_SOURCES if n in bpy.data.objects]
    bpy.ops.object.select_all(action="DESELECT")
    for ob in wheels:
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
        ob.select_set(False)

    # 7. name them from where they actually sit: +Y is the nose, and facing
    #    +Y with +Z up the car's right hand is +X
    for ob in wheels:
        p = ob.matrix_world.translation
        name = f"Wheel_{'F' if p[1] > 0 else 'B'}{'R' if p[0] > 0 else 'L'}"
        ob.name = name
        print(f"[car1] {name} pivot -> {tuple(round(v, 3) for v in p)}")

    # 8. drop the leftover marker empties (the wheels carry their own pivots now)
    for ob in [o for o in bpy.data.objects if o.type == "EMPTY" and o.name != "Main"]:
        bpy.data.objects.remove(ob, do_unlink=True)

    # 9. export
    bpy.ops.export_scene.gltf(
        filepath=OUT,
        export_format="GLB",
        export_apply=True,
        export_yup=True,
    )
    print(f"[car1] wrote {OUT}")


main()
