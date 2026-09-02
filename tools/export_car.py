"""Export the JDM car from car_low-poly_jdm.blend into a game-ready car.glb.

Run headlessly:
    blender -b "<path>/car_low-poly_jdm.blend" --python tools/export_car.py

This model replaces the earlier Low Poly Car, which was only a body shell and
four wheels. This one carries an interior, a steering wheel and a gear stick,
which is what makes a first person view worth having.

What this does:
  * drops the camera and light
  * turns the car to face +Y, which the glTF exporter maps to -Z, Godot's
    forward. The model is authored facing -Y, so it needs a half turn
  * re-origins it to the centre of the wheelbase, sitting on the ground
  * renames the rear wheels from RL/RR to BL/BR, the names the car script
    already looks for
  * keeps the interior parented under the body, so the steering wheel travels
    with the car and can be turned from code

Everything is left at its authored size: the car is 4.87 m long, which is a
believable Skyline, so there is nothing to normalise.
"""

import math

import bpy
from mathutils import Vector

OUT = "/Users/erselinankul/2p-racing-game/assets/models/car.glb"
ROOT = "Low Poly JDM Sports Car (Skyline)"
RENAME = {"Wheel_RL": "Wheel_BL", "Wheel_RR": "Wheel_BR"}


def centre_of(ob):
    lo = Vector((float("inf"),) * 3)
    hi = Vector((float("-inf"),) * 3)
    for corner in ob.bound_box:
        p = ob.matrix_world @ Vector(corner)
        for i in range(3):
            lo[i] = min(lo[i], p[i])
            hi[i] = max(hi[i], p[i])
    return (lo + hi) * 0.5, lo, hi


def world_bounds(objects):
    lo = Vector((float("inf"),) * 3)
    hi = Vector((float("-inf"),) * 3)
    for ob in objects:
        _, olo, ohi = centre_of(ob)
        for i in range(3):
            lo[i] = min(lo[i], olo[i])
            hi[i] = max(hi[i], ohi[i])
    return lo, hi


def main():
    for ob in list(bpy.data.objects):
        if ob.type in {"CAMERA", "LIGHT"}:
            bpy.data.objects.remove(ob, do_unlink=True)

    root = bpy.data.objects.get(ROOT)
    if root is None:
        print("[car] missing root %r" % ROOT)
        return

    front, _, _ = centre_of(bpy.data.objects["Wheel_FL"])
    rear, _, _ = centre_of(bpy.data.objects["Wheel_BL"]
                           if "Wheel_BL" in bpy.data.objects
                           else bpy.data.objects["Wheel_RL"])
    print("[car] front wheel y=%.2f, rear wheel y=%.2f" % (front.y, rear.y))
    if front.y < rear.y:
        # Authored facing -Y; turn it so the nose points +Y, which glTF maps
        # to Godot's forward.
        root.rotation_euler.z += math.pi
        print("[car] turned 180deg so the nose faces +Y")

    # The root empty already sits at the centre of the wheelbase, so moving it
    # to the origin centres the car without disturbing anything inside it.
    root.location = (0.0, 0.0, 0.0)
    bpy.context.view_layer.update()

    for old, new in RENAME.items():
        ob = bpy.data.objects.get(old)
        if ob:
            ob.name = new

    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    lo, hi = world_bounds(meshes)
    # Rest the wheels on the ground rather than trusting that they already are.
    if abs(lo.z) > 0.001:
        root.location.z -= lo.z
        bpy.context.view_layer.update()
        lo, hi = world_bounds(meshes)

    print("[car] size W=%.2f L=%.2f H=%.2f, base at z=%.3f"
          % (hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2], lo[2]))
    for name in ["Wheel_FL", "Wheel_FR", "Wheel_BL", "Wheel_BR", "SteeringWheel"]:
        ob = bpy.data.objects.get(name)
        if ob:
            c, _, _ = centre_of(ob)
            print("[car] %-14s at (%.2f, %.2f, %.2f)" % (name, c.x, c.y, c.z))

    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB",
                              export_apply=True, export_yup=True)
    print("[car] wrote %s" % OUT)


main()
