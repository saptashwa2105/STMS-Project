extends Area3D

signal vehicle_entered_box(v: Node)
signal vehicle_exited_box(v: Node)

# Maintained dynamically each frame from physical overlap
var vehicles_inside: Array[Node] = []

func _ready():
	# Ensure Area3D collision mask listens to Vehicle layer (Layer 2)
	collision_mask |= 2

func _physics_process(_delta: float):
	var current_overlapping = get_overlapping_vehicles()
	
	# Detect newly entered vehicles for signals and state
	for v in current_overlapping:
		if not vehicles_inside.has(v):
			if "is_in_intersection" in v:
				v.is_in_intersection = true
			if "is_inside_clear_zone" in v:
				v.is_inside_clear_zone = true
			if "intersection_entry_time" in v and v.intersection_entry_time == 0.0:
				v.intersection_entry_time = Time.get_ticks_msec() / 1000.0
			vehicle_entered_box.emit(v)

	# Detect exited vehicles for signals and state
	for v in vehicles_inside:
		if is_instance_valid(v) and not current_overlapping.has(v):
			if "is_inside_clear_zone" in v:
				v.is_inside_clear_zone = false
			vehicle_exited_box.emit(v)

	vehicles_inside = current_overlapping

func get_overlapping_vehicles() -> Array[Node]:
	# Built-in Godot physics overlap check
	var current_bodies = get_overlapping_bodies()
	var filtered: Array[Node] = []
	for body in current_bodies:
		if is_instance_valid(body) and not body.is_queued_for_deletion():
			if body.is_in_group("Vehicle"):
				filtered.append(body)
	return filtered

func is_intersection_empty() -> bool:
	return get_overlapping_vehicles().is_empty()

func get_vehicles_count() -> int:
	return get_overlapping_vehicles().size()

func has_conflicting_vehicles(approaching_lane: String) -> bool:
	var current = get_overlapping_vehicles()
	var is_ns = (approaching_lane == "north" or approaching_lane == "south")
	for v in current:
		if is_instance_valid(v) and ("lane" in v):
			var v_lane = v.lane
			var v_is_ns = (v_lane == "north" or v_lane == "south")
			if is_ns != v_is_ns:
				return true
	return false

func has_emergency_vehicle() -> bool:
	var current = get_overlapping_vehicles()
	for v in current:
		if is_instance_valid(v) and ("is_emergency" in v) and v.is_emergency:
			return true
	return false
