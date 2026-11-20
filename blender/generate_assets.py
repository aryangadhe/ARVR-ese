"""
Blender Automation Script for VR Humanoid Robot Simulator.
Generates humanoid.blend, environment.blend, and exports GLTF/GLB models for Godot.
Run via: blender --background --python blender/generate_assets.py
"""

import bpy
import os
import math

def clean_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def create_material(name, base_color, metallic=0.0, roughness=0.5, emission=None, emission_strength=1.0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = base_color
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = roughness
        if emission:
            # Handle emission for Blender 4.x
            if "Emission Color" in bsdf.inputs:
                bsdf.inputs["Emission Color"].default_value = emission
                bsdf.inputs["Emission Strength"].default_value = emission_strength
            elif "Emission" in bsdf.inputs:
                bsdf.inputs["Emission"].default_value = emission
    return mat

def build_humanoid(output_blend_path, output_glb_path):
    clean_scene()

    mat_torso = create_material("MatTorso", (0.12, 0.15, 0.20, 1.0), metallic=0.8, roughness=0.3)
    mat_limbs = create_material("MatLimbs", (0.80, 0.82, 0.86, 1.0), metallic=0.4, roughness=0.3)
    mat_visor = create_material("MatVisor", (0.0, 0.9, 1.0, 1.0), metallic=0.1, roughness=0.1, emission=(0.0, 0.9, 1.0, 1.0), emission_strength=3.0)
    mat_joints = create_material("MatJoints", (0.05, 0.65, 0.95, 1.0), metallic=0.9, roughness=0.2, emission=(0.05, 0.65, 0.95, 1.0), emission_strength=1.2)

    # Torso
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.85))
    torso = bpy.context.active_object
    torso.name = "torso"
    torso.scale = (0.26, 0.22, 0.40)
    bpy.ops.object.transform_apply(scale=True)
    torso.data.materials.append(mat_torso)

    # Head
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.10, location=(0, 0, 1.13))
    head = bpy.context.active_object
    head.name = "head"
    head.data.materials.append(mat_limbs)

    # Visor
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.09, 0, 1.14))
    visor = bpy.context.active_object
    visor.name = "visor"
    visor.scale = (0.03, 0.12, 0.04)
    bpy.ops.object.transform_apply(scale=True)
    visor.data.materials.append(mat_visor)
    visor.parent = head

    # Arms and Legs
    parts = [
        # name, primitive, scale/radius, location, material
        ("left_upper_arm", "cylinder", 0.04, 0.22, (0, 0.17, 0.88), mat_limbs),
        ("left_forearm", "cylinder", 0.035, 0.20, (0, 0.17, 0.67), mat_limbs),
        ("right_upper_arm", "cylinder", 0.04, 0.22, (0, -0.17, 0.88), mat_limbs),
        ("right_forearm", "cylinder", 0.035, 0.20, (0, -0.17, 0.67), mat_limbs),
        ("left_thigh", "cylinder", 0.05, 0.30, (0, 0.10, 0.50), mat_limbs),
        ("left_shin", "cylinder", 0.045, 0.28, (0, 0.10, 0.21), mat_limbs),
        ("right_thigh", "cylinder", 0.05, 0.30, (0, -0.10, 0.50), mat_limbs),
        ("right_shin", "cylinder", 0.045, 0.28, (0, -0.10, 0.21), mat_limbs),
    ]

    for name, ptype, rad, length, loc, mat in parts:
        bpy.ops.mesh.primitive_cylinder_add(radius=rad, depth=length, location=loc)
        obj = bpy.context.active_object
        obj.name = name
        obj.data.materials.append(mat)

    # Feet
    for name, loc in [("left_foot", (0.03, 0.10, 0.02)), ("right_foot", (0.03, -0.10, 0.02))]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
        foot = bpy.context.active_object
        foot.name = name
        foot.scale = (0.20, 0.11, 0.04)
        bpy.ops.object.transform_apply(scale=True)
        foot.data.materials.append(mat_torso)

    # Save .blend
    os.makedirs(os.path.dirname(output_blend_path), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=output_blend_path)
    print(f"[Blender] Saved humanoid model to {output_blend_path}")

    # Export .glb
    os.makedirs(os.path.dirname(output_glb_path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=output_glb_path, export_format='GLB')
    print(f"[Blender] Exported humanoid GLB to {output_glb_path}")

def build_environment(output_blend_path, output_glb_path):
    clean_scene()

    mat_floor = create_material("MatFloor", (0.08, 0.10, 0.14, 1.0), metallic=0.3, roughness=0.5)
    mat_metal = create_material("MatMetal", (0.4, 0.45, 0.5, 1.0), metallic=0.9, roughness=0.2)
    mat_accent = create_material("MatAccent", (0.0, 0.8, 1.0, 1.0), metallic=0.5, roughness=0.2, emission=(0.0, 0.8, 1.0, 1.0), emission_strength=2.0)

    # Floor plane
    bpy.ops.mesh.primitive_plane_add(size=30.0, location=(0, 0, 0))
    floor_obj = bpy.context.active_object
    floor_obj.name = "Floor"
    floor_obj.data.materials.append(mat_floor)

    # Center inspection ring
    bpy.ops.mesh.primitive_cylinder_add(radius=3.5, depth=0.03, location=(0, 0, 0.015))
    ring = bpy.context.active_object
    ring.name = "PlatformRing"
    ring.data.materials.append(mat_accent)

    # 4 Corner Pillars
    pillar_coords = [(-8, -8), (-8, 8), (8, -8), (8, 8)]
    for idx, (px, py) in enumerate(pillar_coords):
        bpy.ops.mesh.primitive_cylinder_add(radius=0.4, depth=6.0, location=(px, py, 3.0))
        pillar = bpy.context.active_object
        pillar.name = f"Pillar_{idx+1}"
        pillar.data.materials.append(mat_metal)

    os.makedirs(os.path.dirname(output_blend_path), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=output_blend_path)
    print(f"[Blender] Saved environment to {output_blend_path}")

    os.makedirs(os.path.dirname(output_glb_path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=output_glb_path, export_format='GLB')
    print(f"[Blender] Exported environment GLB to {output_glb_path}")

if __name__ == "__main__":
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    humanoid_blend = os.path.join(base_dir, "blender", "humanoid.blend")
    humanoid_glb = os.path.join(base_dir, "godot", "models", "humanoid.glb")
    env_blend = os.path.join(base_dir, "blender", "environment.blend")
    env_glb = os.path.join(base_dir, "godot", "models", "environment.glb")

    build_humanoid(humanoid_blend, humanoid_glb)
    build_environment(env_blend, env_glb)
