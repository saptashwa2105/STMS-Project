class_name VehicleMeshBuilder
extends RefCounted

## Generates high-detail, stylized low-poly 3D models procedurally for STMS vehicles.

# Color palettes for civilian cars
const CAR_COLORS = [
	Color(0.18, 0.52, 0.95), # Electric Blue
	Color(0.92, 0.18, 0.18), # Crimson Red
	Color(0.15, 0.72, 0.42), # Emerald Green
	Color(0.95, 0.75, 0.12), # Racing Yellow
	Color(0.88, 0.88, 0.92), # Pearl White
	Color(0.22, 0.24, 0.28), # Charcoal Gray
	Color(0.60, 0.22, 0.75), # Royal Purple
	Color(0.95, 0.45, 0.10)  # Sunset Orange
]

const TRUCK_COLORS = [
	Color(0.95, 0.55, 0.10), # Industrial Orange
	Color(0.20, 0.45, 0.85), # Freight Blue
	Color(0.85, 0.20, 0.20), # Transport Red
	Color(0.30, 0.65, 0.35)  # Cargo Green
]

static func build_vehicle_mesh(vehicle_type: String, container: Node3D, is_emergency: bool = false):
	# Clear existing children in container
	for child in container.get_children():
		child.queue_free()

	match vehicle_type:
		"car":
			_build_car(container)
		"motorbike":
			_build_motorbike(container)
		"truck":
			_build_truck(container)
		"ambulance":
			_build_ambulance(container)
		"firetruck":
			_build_firetruck(container)
		_:
			_build_car(container)

static func _create_material(albedo: Color, roughness: float = 0.5, metallic: float = 0.0, emission: Color = Color.BLACK, emission_energy: float = 0.0) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = roughness
	mat.metallic = metallic
	if emission_energy > 0.0 or emission != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = emission_energy
	return mat

static func _add_box(parent: Node3D, pos: Vector3, size: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	box.material = mat
	mi.mesh = box
	mi.position = pos
	parent.add_child(mi)
	return mi

static func _add_cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, mat: StandardMaterial3D, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.radial_segments = 12
	cyl.material = mat
	mi.mesh = cyl
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi

# 1. Sleek Sedan Car
static func _build_car(parent: Node3D):
	var body_color = CAR_COLORS[randi() % CAR_COLORS.size()]
	var mat_body = _create_material(body_color, 0.25, 0.6)
	var mat_glass = _create_material(Color(0.12, 0.18, 0.28, 0.9), 0.1, 0.2)
	var mat_tire = _create_material(Color(0.12, 0.12, 0.14), 0.8, 0.0)
	var mat_rim = _create_material(Color(0.85, 0.85, 0.90), 0.2, 0.8)
	var mat_headlight = _create_material(Color(1.0, 1.0, 0.9), 0.1, 0.0, Color(1.0, 1.0, 0.85), 3.0)
	var mat_taillight = _create_material(Color(0.9, 0.1, 0.1), 0.1, 0.0, Color(1.0, 0.1, 0.1), 2.5)
	var mat_grille = _create_material(Color(0.15, 0.15, 0.17), 0.6, 0.3)

	# Lower Chassis
	_add_box(parent, Vector3(0, 0.42, 0), Vector3(1.65, 0.44, 3.6), mat_body)
	# Hood Slope
	_add_box(parent, Vector3(0, 0.65, -0.85), Vector3(1.55, 0.14, 1.4), mat_body)
	# Cabin Top
	_add_box(parent, Vector3(0, 0.98, 0.05), Vector3(1.36, 0.54, 1.8), mat_body)
	# Windows
	_add_box(parent, Vector3(0, 0.98, -0.86), Vector3(1.30, 0.46, 0.05), mat_glass) # Front Windshield
	_add_box(parent, Vector3(0, 0.98, 0.96), Vector3(1.30, 0.46, 0.05), mat_glass)  # Rear Windshield
	_add_box(parent, Vector3(0, 0.98, 0.05), Vector3(1.40, 0.44, 1.7), mat_glass)   # Side Windows
	# Front Grille
	_add_box(parent, Vector3(0, 0.38, -1.82), Vector3(1.4, 0.26, 0.06), mat_grille)
	# Headlights & Taillights
	_add_box(parent, Vector3(-0.60, 0.46, -1.81), Vector3(0.32, 0.16, 0.06), mat_headlight)
	_add_box(parent, Vector3(0.60, 0.46, -1.81), Vector3(0.32, 0.16, 0.06), mat_headlight)
	_add_box(parent, Vector3(-0.60, 0.46, 1.81), Vector3(0.32, 0.16, 0.06), mat_taillight)
	_add_box(parent, Vector3(0.60, 0.46, 1.81), Vector3(0.32, 0.16, 0.06), mat_taillight)
	# Wheels
	for wx in [-0.85, 0.85]:
		for wz in [-1.05, 1.05]:
			_add_cylinder(parent, Vector3(wx, 0.32, wz), 0.34, 0.22, mat_tire, Vector3(0, 0, 90))
			_add_cylinder(parent, Vector3(wx * 1.05, 0.32, wz), 0.20, 0.24, mat_rim, Vector3(0, 0, 90))

# 2. Modern Motorbike with Rider
static func _build_motorbike(parent: Node3D):
	var mat_frame = _create_material(Color(0.95, 0.35, 0.08), 0.3, 0.5)
	var mat_metal = _create_material(Color(0.28, 0.30, 0.34), 0.4, 0.7)
	var mat_tire = _create_material(Color(0.12, 0.12, 0.14), 0.8, 0.0)
	var mat_suit = _create_material(Color(0.15, 0.65, 0.45), 0.6, 0.1)
	var mat_helmet = _create_material(Color(0.18, 0.18, 0.22), 0.3, 0.3)
	var mat_headlight = _create_material(Color(1.0, 1.0, 0.85), 0.1, 0.0, Color(1.0, 1.0, 0.85), 3.0)
	var mat_taillight = _create_material(Color(0.95, 0.1, 0.1), 0.1, 0.0, Color(1.0, 0.1, 0.1), 2.5)

	# 2 Wheels
	_add_cylinder(parent, Vector3(0, 0.30, -0.8), 0.30, 0.14, mat_tire, Vector3(0, 0, 90))
	_add_cylinder(parent, Vector3(0, 0.30, 0.8), 0.30, 0.14, mat_tire, Vector3(0, 0, 90))
	# Chassis & Fuel Tank
	_add_box(parent, Vector3(0, 0.45, 0.0), Vector3(0.32, 0.38, 1.2), mat_metal)
	_add_box(parent, Vector3(0, 0.68, -0.2), Vector3(0.38, 0.24, 0.55), mat_frame)
	# Handlebars & Fork
	_add_box(parent, Vector3(0, 0.82, -0.62), Vector3(0.75, 0.06, 0.08), mat_metal)
	_add_box(parent, Vector3(0, 0.65, -0.85), Vector3(0.18, 0.18, 0.08), mat_headlight)
	_add_box(parent, Vector3(0, 0.58, 0.95), Vector3(0.14, 0.12, 0.06), mat_taillight)
	# Rider Torso & Helmet
	_add_box(parent, Vector3(0, 0.96, 0.18), Vector3(0.38, 0.55, 0.32), mat_suit)
	_add_box(parent, Vector3(0, 1.34, 0.08), Vector3(0.30, 0.30, 0.32), mat_helmet)

# 3. Heavy Freight Cargo Truck
static func _build_truck(parent: Node3D):
	var cab_color = TRUCK_COLORS[randi() % TRUCK_COLORS.size()]
	var mat_cab = _create_material(cab_color, 0.3, 0.4)
	var mat_container = _create_material(Color(0.88, 0.90, 0.94), 0.4, 0.2)
	var mat_chassis = _create_material(Color(0.18, 0.20, 0.24), 0.6, 0.5)
	var mat_glass = _create_material(Color(0.12, 0.18, 0.28, 0.9), 0.1, 0.2)
	var mat_tire = _create_material(Color(0.12, 0.12, 0.14), 0.8, 0.0)
	var mat_rim = _create_material(Color(0.75, 0.75, 0.78), 0.3, 0.7)
	var mat_headlight = _create_material(Color(1.0, 1.0, 0.9), 0.1, 0.0, Color(1.0, 1.0, 0.85), 3.0)
	var mat_taillight = _create_material(Color(0.9, 0.1, 0.1), 0.1, 0.0, Color(1.0, 0.1, 0.1), 2.5)
	var mat_stripe = _create_material(Color(0.95, 0.75, 0.1), 0.4, 0.2)

	# Heavy Chassis Frame
	_add_box(parent, Vector3(0, 0.48, 0.0), Vector3(2.0, 0.36, 6.4), mat_chassis)
	# Cab Front
	_add_box(parent, Vector3(0, 1.35, -2.25), Vector3(2.0, 1.45, 1.8), mat_cab)
	_add_box(parent, Vector3(0, 1.55, -3.16), Vector3(1.8, 0.75, 0.06), mat_glass) # Windshield
	_add_box(parent, Vector3(0, 1.55, -2.25), Vector3(2.06, 0.70, 1.1), mat_glass) # Side Glass
	_add_box(parent, Vector3(0, 0.60, -3.16), Vector3(1.9, 0.45, 0.08), mat_chassis) # Grille
	# Headlights & Taillights
	_add_box(parent, Vector3(-0.75, 0.65, -3.17), Vector3(0.38, 0.22, 0.06), mat_headlight)
	_add_box(parent, Vector3(0.75, 0.65, -3.17), Vector3(0.38, 0.22, 0.06), mat_headlight)
	_add_box(parent, Vector3(-0.80, 0.55, 3.21), Vector3(0.38, 0.22, 0.06), mat_taillight)
	_add_box(parent, Vector3(0.80, 0.55, 3.21), Vector3(0.38, 0.22, 0.06), mat_taillight)
	# Large Freight Container
	_add_box(parent, Vector3(0, 1.70, 0.8), Vector3(2.15, 2.1, 4.6), mat_container)
	_add_box(parent, Vector3(0, 0.85, 0.8), Vector3(2.18, 0.18, 4.62), mat_stripe) # Caution Stripe
	# 6 Heavy Wheels
	for wz in [-2.25, 1.1, 2.4]:
		for wx in [-1.10, 1.10]:
			_add_cylinder(parent, Vector3(wx, 0.48, wz), 0.48, 0.32, mat_tire, Vector3(0, 0, 90))
			_add_cylinder(parent, Vector3(wx * 1.05, 0.48, wz), 0.28, 0.34, mat_rim, Vector3(0, 0, 90))

# 4. Emergency Ambulance
static func _build_ambulance(parent: Node3D):
	var mat_white = _create_material(Color(0.96, 0.96, 0.98), 0.2, 0.3)
	var mat_stripe = _create_material(Color(0.95, 0.12, 0.12), 0.3, 0.1)
	var mat_glass = _create_material(Color(0.12, 0.18, 0.28, 0.9), 0.1, 0.2)
	var mat_tire = _create_material(Color(0.12, 0.12, 0.14), 0.8, 0.0)
	var mat_rim = _create_material(Color(0.85, 0.85, 0.88), 0.2, 0.8)
	var mat_siren_r = _create_material(Color(1.0, 0.15, 0.15), 0.1, 0.0, Color(1.0, 0.1, 0.1), 5.0)
	var mat_siren_b = _create_material(Color(0.1, 0.5, 1.0), 0.1, 0.0, Color(0.1, 0.5, 1.0), 5.0)
	var mat_headlight = _create_material(Color(1.0, 1.0, 0.9), 0.1, 0.0, Color(1.0, 1.0, 0.85), 3.0)
	var mat_taillight = _create_material(Color(0.9, 0.1, 0.1), 0.1, 0.0, Color(1.0, 0.1, 0.1), 2.5)

	# Main Body
	_add_box(parent, Vector3(0, 1.05, 0.15), Vector3(1.9, 1.35, 4.0), mat_white)
	_add_box(parent, Vector3(0, 0.70, -1.65), Vector3(1.9, 0.70, 1.1), mat_white)
	# Red Reflective Livery Stripes
	_add_box(parent, Vector3(0, 0.90, 0.15), Vector3(1.94, 0.32, 4.02), mat_stripe)
	# Medical Crosses
	_add_box(parent, Vector3(-0.98, 1.25, 0.4), Vector3(0.05, 0.50, 0.16), mat_stripe)
	_add_box(parent, Vector3(-0.98, 1.25, 0.4), Vector3(0.05, 0.16, 0.50), mat_stripe)
	_add_box(parent, Vector3(0.98, 1.25, 0.4), Vector3(0.05, 0.50, 0.16), mat_stripe)
	_add_box(parent, Vector3(0.98, 1.25, 0.4), Vector3(0.05, 0.16, 0.50), mat_stripe)
	# Windows
	_add_box(parent, Vector3(0, 1.25, -1.15), Vector3(1.75, 0.58, 0.06), mat_glass)
	_add_box(parent, Vector3(0, 1.25, -0.65), Vector3(1.94, 0.50, 0.8), mat_glass)
	# Rooftop Dual Strobe Lightbars
	_add_box(parent, Vector3(-0.42, 1.82, -0.65), Vector3(0.42, 0.18, 0.28), mat_siren_r)
	_add_box(parent, Vector3(0.42, 1.82, -0.65), Vector3(0.42, 0.18, 0.28), mat_siren_b)
	# Headlights & Taillights
	_add_box(parent, Vector3(-0.70, 0.60, -2.21), Vector3(0.34, 0.20, 0.06), mat_headlight)
	_add_box(parent, Vector3(0.70, 0.60, -2.21), Vector3(0.34, 0.20, 0.06), mat_headlight)
	_add_box(parent, Vector3(-0.70, 0.60, 2.16), Vector3(0.34, 0.20, 0.06), mat_taillight)
	_add_box(parent, Vector3(0.70, 0.60, 2.16), Vector3(0.34, 0.20, 0.06), mat_taillight)
	# 4 Wheels
	for wx in [-0.98, 0.98]:
		for wz in [-1.25, 1.35]:
			_add_cylinder(parent, Vector3(wx, 0.40, wz), 0.40, 0.28, mat_tire, Vector3(0, 0, 90))
			_add_cylinder(parent, Vector3(wx * 1.05, 0.40, wz), 0.24, 0.30, mat_rim, Vector3(0, 0, 90))

# 5. Emergency Fire Rescue Truck
static func _build_firetruck(parent: Node3D):
	var mat_red = _create_material(Color(0.92, 0.10, 0.10), 0.25, 0.4)
	var mat_white = _create_material(Color(0.96, 0.96, 0.98), 0.3, 0.2)
	var mat_yellow = _create_material(Color(0.96, 0.82, 0.12), 0.3, 0.3)
	var mat_silver = _create_material(Color(0.78, 0.80, 0.84), 0.2, 0.8)
	var mat_glass = _create_material(Color(0.12, 0.18, 0.28, 0.9), 0.1, 0.2)
	var mat_tire = _create_material(Color(0.12, 0.12, 0.14), 0.8, 0.0)
	var mat_siren_r = _create_material(Color(1.0, 0.15, 0.15), 0.1, 0.0, Color(1.0, 0.1, 0.1), 5.0)
	var mat_siren_b = _create_material(Color(0.1, 0.5, 1.0), 0.1, 0.0, Color(0.1, 0.5, 1.0), 5.0)
	var mat_headlight = _create_material(Color(1.0, 1.0, 0.9), 0.1, 0.0, Color(1.0, 1.0, 0.85), 3.0)
	var mat_taillight = _create_material(Color(0.9, 0.1, 0.1), 0.1, 0.0, Color(1.0, 0.1, 0.1), 2.5)

	# Main Red Body
	_add_box(parent, Vector3(0, 1.30, 0.0), Vector3(2.15, 1.6, 6.0), mat_red)
	_add_box(parent, Vector3(0, 1.55, -3.01), Vector3(1.9, 0.75, 0.06), mat_glass)
	_add_box(parent, Vector3(0, 1.55, -2.1), Vector3(2.18, 0.70, 1.3), mat_glass)
	_add_box(parent, Vector3(0, 0.90, 0.0), Vector3(2.18, 0.28, 6.04), mat_white)
	# Side Roller Shutter Doors
	for sz in [-0.2, 1.2, 2.2]:
		_add_box(parent, Vector3(-1.10, 1.25, sz), Vector3(0.06, 0.85, 0.80), mat_silver)
		_add_box(parent, Vector3(1.10, 1.25, sz), Vector3(0.06, 0.85, 0.80), mat_silver)
	# Roof Rescue Ladder
	_add_box(parent, Vector3(0, 2.25, 0.4), Vector3(0.8, 0.18, 4.2), mat_silver)
	_add_box(parent, Vector3(0, 2.38, 0.4), Vector3(0.6, 0.12, 3.8), mat_yellow)
	# Rooftop Dual Strobe Lightbars
	_add_box(parent, Vector3(-0.60, 2.20, -2.3), Vector3(0.50, 0.20, 0.32), mat_siren_r)
	_add_box(parent, Vector3(0.60, 2.20, -2.3), Vector3(0.50, 0.20, 0.32), mat_siren_b)
	# Headlights & Taillights
	_add_box(parent, Vector3(-0.80, 0.65, -3.01), Vector3(0.38, 0.22, 0.06), mat_headlight)
	_add_box(parent, Vector3(0.80, 0.65, -3.01), Vector3(0.38, 0.22, 0.06), mat_headlight)
	_add_box(parent, Vector3(-0.80, 0.65, 3.01), Vector3(0.38, 0.22, 0.06), mat_taillight)
	_add_box(parent, Vector3(0.80, 0.65, 3.01), Vector3(0.38, 0.22, 0.06), mat_taillight)
	# 6 Heavy Wheels
	for wz in [-2.0, 1.1, 2.3]:
		for wx in [-1.15, 1.15]:
			_add_cylinder(parent, Vector3(wx, 0.50, wz), 0.50, 0.35, mat_tire, Vector3(0, 0, 90))
			_add_cylinder(parent, Vector3(wx * 1.05, 0.50, wz), 0.30, 0.37, mat_silver, Vector3(0, 0, 90))
