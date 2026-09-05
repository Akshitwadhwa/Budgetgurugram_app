import bpy
import math

from mathutils import Vector

scene = bpy.context.scene
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

scene.render.engine = 'BLENDER_EEVEE_NEXT'
scene.render.resolution_x = 960
scene.render.resolution_y = 540
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'FFMPEG'
scene.render.ffmpeg.format = 'MPEG4'
scene.render.ffmpeg.codec = 'H264'
scene.render.ffmpeg.constant_rate_factor = 'MEDIUM'
scene.render.fps = 24
scene.frame_start = 1
scene.frame_end = 336
scene.render.film_transparent = False
scene.world.color = (0.055, 0.075, 0.085)

def material(name, color, metallic=0.0, roughness=0.5):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value = metallic
    return mat

concrete = material('warm concrete', (0.64, 0.69, 0.67), 0.0, 0.72)
glass = material('blue glass', (0.06, 0.30, 0.40), 0.35, 0.18)
road_mat = material('asphalt', (0.025, 0.042, 0.052), 0.0, 0.5)
lane_mat = material('lane paint', (0.94, 0.81, 0.26), 0.0, 0.45)
grass_mat = material('grass', (0.12, 0.32, 0.16), 0.0, 0.85)
tree_mat = material('tree foliage', (0.06, 0.25, 0.12), 0.0, 0.8)
trunk_mat = material('trunk', (0.18, 0.08, 0.035), 0.0, 1.0)
crane_mat = material('construction yellow', (1.0, 0.46, 0.025), 0.15, 0.3)
red = material('Gurugram red', (0.9, 0.035, 0.02), 0.15, 0.28)
white = material('sign white', (0.93, 0.96, 0.95), 0.0, 0.45)
black = material('sign black', (0.015, 0.02, 0.025), 0.0, 0.4)
colors = [material('car orange', (0.95, 0.16, 0.04), 0.1, 0.35), material('car teal', (0.02, 0.52, 0.72), 0.1, 0.3), material('car lime', (0.48, 0.78, 0.08), 0.0, 0.4), material('car white', (0.9, 0.94, 0.9), 0.15, 0.25)]

def cube(name, location, dimensions, mat, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new('soft edges', 'BEVEL')
        mod.width = bevel
        mod.segments = 2
    return obj

def text_mesh(name, body, location, size, mat, extrude=0.04, parent=None):
    bpy.ops.object.text_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.data.body = body
    obj.data.align_x = 'CENTER'
    obj.data.align_y = 'CENTER'
    obj.data.size = size
    obj.data.extrude = extrude
    obj.data.bevel_depth = 0.012
    obj.data.bevel_resolution = 2
    obj.data.materials.append(mat)
    if parent:
        obj.parent = parent
    return obj

def empty(name, loc=(0, 0, 0)):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.location = loc
    return obj

def add_tree(x, y, scale=1.0):
    trunk = cube('tree trunk', (x, y, 0.45 * scale), (0.12 * scale, 0.12 * scale, 0.9 * scale), trunk_mat, 0.03)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.54 * scale, location=(x, y, 1.18 * scale))
    crown = bpy.context.object
    crown.data.materials.append(tree_mat)
    return trunk

def add_car(name, start, end, frame_offset, mat):
    root = empty(name, (start[0], start[1], 0.19))
    base = cube(name + ' body', (0, 0, 0), (0.52, 0.26, 0.16), mat, 0.05)
    cabin = cube(name + ' cabin', (0.02, 0, 0.12), (0.26, 0.22, 0.12), glass, 0.025)
    base.parent = root
    cabin.parent = root
    angle = math.atan2(end[1] - start[1], end[0] - start[0])
    root.rotation_euler[2] = angle
    for frame, value in ((1, start), (84 + frame_offset, end), (168 + frame_offset, start), (252 + frame_offset, end), (336, start)):
        root.location.x, root.location.y = value
        root.keyframe_insert(data_path='location', frame=frame)
    return root

def add_crane(x, y, delay, direction=1):
    root = empty('tower crane', (x, y, 0))
    mast = cube('crane mast', (0, 0, 3.0), (0.18, 0.18, 6.0), crane_mat, 0.025)
    mast.parent = root
    boom = empty('rotating boom', (0, 0, 5.85))
    boom.parent = root
    arm = cube('crane boom', (3.2, 0, 0), (6.5, 0.14, 0.14), crane_mat, 0.02)
    arm.parent = boom
    counter = cube('crane counterbalance', (-0.7, 0, 0), (1.2, 0.45, 0.45), crane_mat, 0.04)
    counter.parent = boom
    hook_line = cube('hook cable', (4.8, 0, -1.15), (0.025, 0.025, 2.35), black, 0)
    hook_line.parent = boom
    hook = cube('hook', (4.8, 0, -2.35), (0.22, 0.12, 0.22), black, 0.04)
    hook.parent = boom
    rise_start = 1 + delay
    root.scale = (1, 1, 0.02)
    root.keyframe_insert(data_path='scale', frame=rise_start)
    root.scale = (1, 1, 1)
    root.keyframe_insert(data_path='scale', frame=rise_start + 35)
    for frame, angle in ((1, -0.24 * direction), (112, 0.24 * direction), (224, -0.18 * direction), (336, 0.28 * direction)):
        boom.rotation_euler[2] = angle
        boom.keyframe_insert(data_path='rotation_euler', frame=frame)
    for frame, height in ((1, -1.15), (82, -1.9), (164, -0.75), (246, -1.75), (336, -1.0)):
        hook_line.location.z = height
        hook.location.z = height - 1.2
        hook_line.keyframe_insert(data_path='location', frame=frame)
        hook.keyframe_insert(data_path='location', frame=frame)

def add_building(x, y, w, d, h, name='', sign_mat=None, delay=0):
    root = empty('building ' + (name or 'office'), (x, y, 0))
    body = cube('building core', (0, 0, h / 2), (w, d, h), concrete, 0.16)
    body.parent = root
    roof = cube('roof slab', (0, 0, h + 0.08), (w + 0.18, d + 0.18, 0.16), white, 0.08)
    roof.parent = root
    for level in range(1, max(2, int(h / 1.15))):
        z = level * 1.1
        stripe = cube('glass band', (0, -d / 2 - 0.012, z), (w * 0.88, 0.04, 0.16), glass, 0.01)
        stripe.parent = root
        side_stripe = cube('side glass band', (w / 2 + 0.012, 0, z), (0.04, d * 0.88, 0.16), glass, 0.01)
        side_stripe.parent = root
    if name:
        label = text_mesh('company sign ' + name, name, (0, 0, h + 0.18), min(0.48, w / max(4.5, len(name) * 1.25)), sign_mat or black, 0.06, root)
    start = 1 + delay
    root.scale = (1, 1, 0.025)
    root.keyframe_insert(data_path='scale', frame=start)
    root.scale = (1, 1, 1)
    root.keyframe_insert(data_path='scale', frame=start + 44)
    return root

# Ground slab and road network
base = cube('city foundation', (0, 0, -0.35), (25, 25, 0.7), material('base slab', (0.18, 0.25, 0.23), 0.1, 0.7), 0.28)
for road in [(-0.2, 0, 24, 1.12), (0, -0.2, 1.12, 24), (-6.1, 0, 1.12, 24), (6.1, 0, 1.12, 24), (0, 5.8, 24, 1.12), (0, -5.8, 24, 1.12)]:
    cube('road', (road[0], road[1], 0.03), (road[2], road[3], 0.1), road_mat, 0.05)

for x in (-10, -8, -4, 3, 8, 10):
    for y in (-9, -4, 3, 8):
        cube('park patch', (x, y, 0.05), (1.35, 1.35, 0.1), grass_mat, 0.08)
        add_tree(x - 0.28, y + 0.15, 0.72)
        add_tree(x + 0.26, y - 0.18, 0.55)

# Generic city massing, then named company blocks.
generic = [(-9,-8,1.4,1.3,3.2), (-7,7,1.8,1.4,4.1), (-3,-8,1.5,1.7,4.3), (3,-8,1.6,1.5,4.7), (8,-8,1.4,1.3,3.7), (9,7,1.6,1.4,4.2), (-9,3,1.4,1.4,3.6), (3,7,1.6,1.5,4.6), (-3,7,1.5,1.4,3.9), (8,3,1.4,1.7,3.8), (-8,-3,1.4,1.6,4.1), (8,-3,1.6,1.4,3.9)]
for index, args in enumerate(generic):
    add_building(*args, delay=8 + index * 3)

brand_mats = {
    'GOOGLE': material('google sign', (0.10, 0.35, 0.88), 0.0, 0.35),
    'AMAZON': material('amazon sign', (0.93, 0.34, 0.04), 0.0, 0.35),
    'MICROSOFT': material('microsoft sign', (0.00, 0.54, 0.74), 0.0, 0.35),
    'PAYTM': material('paytm sign', (0.00, 0.57, 0.80), 0.0, 0.35),
    'RAZORPAY': material('razorpay sign', (0.10, 0.32, 0.95), 0.0, 0.35),
    'ZEPTO': material('zepto sign', (0.47, 0.06, 0.67), 0.0, 0.35),
    'BLINKIT': material('blinkit sign', (0.84, 0.76, 0.02), 0.0, 0.35),
    'THREAD': black,
}
named = [(-4.2, -2.8, 2.25, 2.0, 6.1, 'GOOGLE'), (2.8, -2.9, 2.45, 2.1, 5.8, 'MICROSOFT'), (-3.3, 3.0, 2.2, 2.0, 5.3, 'ZEPTO'), (3.4, 3.0, 2.35, 2.0, 6.0, 'RAZORPAY'), (-8.1, 0.9, 2.0, 1.9, 4.8, 'PAYTM'), (8.0, 0.9, 2.1, 1.9, 5.1, 'AMAZON'), (-0.2, 8.1, 2.0, 1.8, 4.5, 'BLINKIT'), (0.2, -8.1, 2.0, 1.8, 4.4, 'THREAD')]
for index, (x, y, w, d, h, name) in enumerate(named):
    add_building(x, y, w, d, h, name, brand_mats[name], 18 + index * 8)

add_crane(-1.5, -0.8, 30, 1)
add_crane(1.6, 1.0, 48, -1)
add_crane(-0.3, 2.7, 64, 1)

for index, ((x1, y1), (x2, y2)) in enumerate([((-11,-0.33),(11,-0.33)), ((11,0.36),(-11,0.36)), ((-0.35,-11),(-0.35,11)), ((0.35,11),(0.35,-11)), ((-6.3,-11),(-6.3,11)), ((6.3,11),(6.3,-11))]):
    add_car('flowing car', (x1, y1), (x2, y2), index * 18, colors[index % len(colors)])

# The central title is modeled text that rises above the new city.
title_root = empty('Gurugram title', (0, 0.3, 0))
title = text_mesh('GURUGRAM title', 'GURUGRAM', (0, 0, 8.2), 1.48, red, 0.23, title_root)
title_root.scale = (0.05, 0.05, 0.05)
title_root.keyframe_insert(data_path='scale', frame=224)
title_root.scale = (1, 1, 1)
title_root.keyframe_insert(data_path='scale', frame=274)
title_root.location.z = -1.2
title_root.keyframe_insert(data_path='location', frame=224)
title_root.location.z = 0
title_root.keyframe_insert(data_path='location', frame=274)

# Camera / lighting
target = empty('camera target', (0, 0, 1.2))
bpy.ops.object.camera_add(location=(16, -22, 20))
camera = bpy.context.object
camera.data.type = 'ORTHO'
camera.data.ortho_scale = 22
camera.data.lens = 44
constraint = camera.constraints.new(type='TRACK_TO')
constraint.target = target
constraint.track_axis = 'TRACK_NEGATIVE_Z'
constraint.up_axis = 'UP_Y'
for frame, loc, scale in ((1, (16,-22,20), 22.0), (168, (14,-20,18), 20.0), (336, (11,-17,15.5), 18.3)):
    camera.location = loc
    camera.data.ortho_scale = scale
    camera.keyframe_insert(data_path='location', frame=frame)
    camera.data.keyframe_insert(data_path='ortho_scale', frame=frame)
scene.camera = camera

bpy.ops.object.light_add(type='AREA', location=(-8, -9, 21))
key = bpy.context.object
key.data.energy = 1800
key.data.shape = 'DISK'
key.data.size = 11
key.data.color = (1.0, 0.68, 0.38)

bpy.ops.object.light_add(type='AREA', location=(10, 7, 14))
fill = bpy.context.object
fill.data.energy = 1000
fill.data.size = 9
fill.data.color = (0.33, 0.64, 1.0)

bpy.ops.object.light_add(type='SUN', location=(0, 0, 15))
sun = bpy.context.object
sun.rotation_euler = (math.radians(24), math.radians(-15), math.radians(-32))
sun.data.energy = 1.6

for obj in scene.objects:
    if obj.type == 'MESH':
        for polygon in obj.data.polygons:
            polygon.use_smooth = False

scene.view_settings.look = 'AgX - Medium High Contrast'
scene.render.image_settings.color_mode = 'RGBA'
