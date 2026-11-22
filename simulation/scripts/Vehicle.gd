extends CharacterBody3D

signal vehicle_cleared(v: Node)
signal emergency_entered_intersection(v: Node)
signal emergency_exited_intersection(v: Node)

const VehicleMeshBuilder = preload("res://scripts/VehicleMeshBuilder.gd")

@export var vehicle_type: String = "car" # "car", "motorbike", "truck", "ambulance", "firetruck"
@export var lane: String = "north" # "north", "south", "east", "west"
@export var is_emergency: bool = false

var max_speed: float = 13.5
var clear_speed: float = 18.5
var current_speed: float = 0.0
var acceleration_rate: float = 5.0
var braking_force: float = 24.0

var move_direction: Vector3 = Vector3.ZERO
var stop_line_coord: float = 0.0
var is_past_stop_line: bool = false
var has_exited_intersection: bool = false
var is_in_intersection: bool = false
var is_inside_clear_zone: bool = false
var in_junction: bool = false
var is_turning: bool = false
var is_stopped_at_light: bool = false
var is_waiting_for_exit_clearance: bool = false

var intersection_entry_time: float = 0.0
var stall_timer: float = 0.0

# Visual and sensor nodes
@onready var model_container: Node3D = $ModelContainer
@onready var front_ray: RayCast3D = $FrontRay
@onready var exit_clear_ray: RayCast3D = $ExitClearRay

# Flashing sirens for emergency vehicles
var beacon_timer: float = 0.0
var beacon_state: bool = false
var siren_light_red: OmniLight3D
var siren_light_blue: OmniLight3D

# References
var traffic_controller: Node = null
var intersection_clear_zone: Node = null
var vehicle_ahead: Node = null

func _ready():
	if not is_in_group("Vehicle"):
		add_to_group("Vehicle")
	_setup_vehicle_profile()
	_load_3d_mesh()
	_configure_lane_direction()
	
	if is_emergency:
		_setup_emergency_sirens()

func _setup_vehicle_profile():
	match vehicle_type:
		"car":
			max_speed = 13.5
			clear_speed = 18.0
			acceleration_rate = 5.0
			braking_force = 22.0
			is_emergency = false
		"motorbike":
			max_speed = 15.5
			clear_speed = 21.0
			acceleration_rate = 6.0
			braking_force = 25.0
			is_emergency = false
		"truck":
			max_speed = 11.0
			clear_speed = 15.0
			acceleration_rate = 3.8
			braking_force = 18.0
			is_emergency = false
		"ambulance":
			max_speed = 18.5
			clear_speed = 24.0
			acceleration_rate = 6.5
			braking_force = 26.0
			is_emergency = true
		"firetruck":
			max_speed = 15.5
			clear_speed = 20.5
			acceleration_rate = 5.0
			braking_force = 22.0
			is_emergency = true
	
	current_speed = max_speed * 0.85

func _configure_lane_direction():
	# In Godot 4 3D, mesh front faces local -Z.
	# We rotate the vehicle root node so -Z aligns with the forward travel vector.
	match lane:
		"north":
			move_direction = Vector3(0, 0, 1)  # Heading South (+Z)
			stop_line_coord = -7.0
			rotation_degrees.y = 180          # Rotate -Z to face +Z
		"south":
			move_direction = Vector3(0, 0, -1) # Heading North (-Z)
			stop_line_coord = 7.0
			rotation_degrees.y = 0            # -Z is already facing -Z
		"east":
			move_direction = Vector3(-1, 0, 0) # Heading West (-X)
			stop_line_coord = 7.0
			rotation_degrees.y = 90           # Rotate -Z to face -X
		"west":
			move_direction = Vector3(1, 0, 0)  # Heading East (+X)
			stop_line_coord = -7.0
			rotation_degrees.y = -90          # Rotate -Z to face +X

func _load_3d_mesh():
	if model_container:
		VehicleMeshBuilder.build_vehicle_mesh(vehicle_type, model_container, is_emergency)

func _setup_emergency_sirens():
	siren_light_red = OmniLight3D.new()
	siren_light_red.light_color = Color(1.0, 0.1, 0.1)
	siren_light_red.light_energy = 5.0
	siren_light_red.omni_range = 15.0
	siren_light_red.position = Vector3(-0.45, 2.2, 0.0)
	add_child(siren_light_red)

	siren_light_blue = OmniLight3D.new()
	siren_light_blue.light_color = Color(0.1, 0.5, 1.0)
	siren_light_blue.light_energy = 5.0
	siren_light_blue.omni_range = 15.0
	siren_light_blue.position = Vector3(0.45, 2.2, 0.0)
	add_child(siren_light_blue)

func _physics_process(delta: float):
	if is_emergency:
		_process_emergency_beacons(delta)

	_check_intersection_bounds()
	in_junction = is_in_intersection or is_inside_clear_zone or (is_past_stop_line and not has_exited_intersection)

	# Long-vehicle raycast tuning:
	# When actively inside the intersection box, reduce front RayCast3D length to bare minimum (0.2m)
	# to prevent freezing mid-junction from detecting turning cross-traffic.
	if front_ray:
		if in_junction:
			front_ray.target_position = Vector3(0, 0, -0.2)
		else:
			var default_ray_len = -5.5 if (vehicle_type == "truck" or vehicle_type == "firetruck") else -4.5
			front_ray.target_position = Vector3(0, 0, default_ray_len)

	var target_speed = _evaluate_target_speed(delta)

	# Anti-stall watchdog: If inside intersection, force non-zero sprint speed
	if is_in_intersection or (is_past_stop_line and not has_exited_intersection):
		if current_speed < 2.0:
			stall_timer += delta
			if stall_timer > 1.2:
				target_speed = clear_speed
		else:
			stall_timer = 0.0

	# Aggressive Acceleration & Smooth Deceleration
	var accel_factor = acceleration_rate
	if is_in_intersection or _is_emergency_flushing_lane():
		accel_factor *= 1.5

	if current_speed < target_speed:
		current_speed = lerp(current_speed, target_speed, delta * accel_factor)
	else:
		current_speed = move_toward(current_speed, target_speed, braking_force * delta)

	velocity = move_direction * current_speed
	move_and_slide()

	_check_despawn()

func _is_emergency_flushing_lane() -> bool:
	if traffic_controller and ("emergency_active" in traffic_controller) and traffic_controller.emergency_active:
		if ("active_emergency_lane" in traffic_controller) and traffic_controller.active_emergency_lane == lane:
			return true
	return false

func _process_emergency_beacons(delta: float):
	beacon_timer += delta
	if beacon_timer >= 0.12:
		beacon_timer = 0.0
		beacon_state = !beacon_state
		if siren_light_red and siren_light_blue:
			siren_light_red.visible = beacon_state
			siren_light_blue.visible = !beacon_state

func _evaluate_target_speed(delta: float) -> float:
	# -------------------------------------------------------------
	# 1. FORCE-CLEAR JUNCTION OVERRIDE (THE DEADLOCK BREAKER)
	# If inside the intersection box, MUST ignore traffic lights and
	# bypass crossing raycasts to sprint out of the yellow box immediately!
	# The primary rule: Once inside the box, prioritize exiting the box over polite collision avoidance!
	# -------------------------------------------------------------
	if in_junction or is_in_intersection or (is_past_stop_line and not has_exited_intersection):
		var sprint_spd = clear_speed
		if _is_emergency_flushing_lane():
			sprint_spd = max_speed * 1.5
		return sprint_spd

	# -------------------------------------------------------------
	# 2. EMERGENCY LANE FLUSHING
	# If this vehicle is in the active emergency corridor, apply 1.5x multiplier
	# to accelerate out of the way immediately.
	# -------------------------------------------------------------
	var is_flush_corridor = _is_emergency_flushing_lane()

	# -------------------------------------------------------------
	# 3. SAME-LANE LEADER FOLLOWING (Safe Spacing)
	# -------------------------------------------------------------
	if is_instance_valid(vehicle_ahead) and not vehicle_ahead.is_queued_for_deletion():
		var dist_to_ahead = global_position.distance_to(vehicle_ahead.global_position)
		var min_gap = 4.0 if (vehicle_type == "truck" or vehicle_type == "firetruck") else 3.2
		if dist_to_ahead < min_gap:
			return 0.0
		elif dist_to_ahead < 9.5:
			var lead_spd = vehicle_ahead.current_speed if ("current_speed" in vehicle_ahead) else 0.0
			var follow_ratio = clamp((dist_to_ahead - min_gap) / (9.5 - min_gap), 0.0, 1.0)
			var base_cap = max_speed * (1.5 if is_flush_corridor else 1.0)
			return min(lead_spd * 0.95 + (base_cap * 0.1), base_cap * follow_ratio)

	# -------------------------------------------------------------
	# 4. FORWARD OBSTACLE RAYCAST SENSING (Only when outside intersection)
	# -------------------------------------------------------------
	if not in_junction and front_ray and front_ray.is_colliding():
		var collider = front_ray.get_collider()
		if is_instance_valid(collider) and collider != self and not collider.is_queued_for_deletion():
			# Ignore perpendicular vehicles crossing laterally in front
			var is_perpendicular = false
			if "lane" in collider:
				var my_ns = (lane == "north" or lane == "south")
				var their_ns = (collider.lane == "north" or collider.lane == "south")
				if my_ns != their_ns:
					is_perpendicular = true

			if not is_perpendicular:
				var distance = global_position.distance_to(collider.global_position)
				var c_speed = collider.current_speed if ("current_speed" in collider) else 0.0
				
				if distance < 3.5:
					return 0.0
				elif distance < 6.5:
					var speed_ratio = clamp((distance - 3.5) / 3.0, 0.0, 1.0)
					return min(c_speed * 0.85, max_speed * speed_ratio)

	# -------------------------------------------------------------
	# 5. STOP LINE & TRAFFIC SIGNAL EVALUATION
	# -------------------------------------------------------------
	if not is_past_stop_line:
		var dist_to_stop = _get_distance_to_stop_line()
		
		# Approaching stop line (within 24m)
		if dist_to_stop >= 0.0 and dist_to_stop < 24.0:
			var light_state = "RED"
			if traffic_controller and traffic_controller.has_method("get_lane_signal_state"):
				light_state = traffic_controller.get_lane_signal_state(lane)
			
			var can_pass_light = (light_state == "GREEN") or (is_flush_corridor and light_state != "RED")

			# Strict Intersection Mutex Lock:
			# An East/West vehicle CANNOT accelerate past the stop line unless intersection_lock == EW_ACTIVE or FREE.
			# A North/South vehicle CANNOT accelerate past the stop line unless intersection_lock == NS_ACTIVE or FREE.
			if can_pass_light and traffic_controller and traffic_controller.has_method("can_lane_enter"):
				if not traffic_controller.can_lane_enter(lane):
					can_pass_light = false

			# Anti-Gridlock Yellow Box Check: Only check exit lane if NOT in emergency flush
			if can_pass_light and not is_emergency and not is_flush_corridor:
				if intersection_clear_zone and intersection_clear_zone.has_method("has_conflicting_vehicles"):
					if intersection_clear_zone.has_conflicting_vehicles(lane):
						can_pass_light = false

				var exit_is_clear = _check_exit_lane_clearance()
				if not exit_is_clear:
					is_waiting_for_exit_clearance = true
					can_pass_light = false
				else:
					is_waiting_for_exit_clearance = false

			if not can_pass_light:
				if dist_to_stop <= 2.2:
					is_stopped_at_light = true
					return 0.0
				else:
					# Smooth deceleration curve approaching stop line
					var decel_ratio = clamp(dist_to_stop / 16.0, 0.05, 1.0)
					return max_speed * decel_ratio * 0.9

	is_stopped_at_light = false
	if is_flush_corridor:
		return max_speed * 1.5
	return max_speed

func _check_exit_lane_clearance() -> bool:
	if exit_clear_ray and exit_clear_ray.is_colliding():
		var collider = exit_clear_ray.get_collider()
		if is_instance_valid(collider) and collider != self and not collider.is_queued_for_deletion():
			var c_speed = 10.0
			if "current_speed" in collider:
				c_speed = collider.current_speed
			if c_speed < 2.0:
				return false
	return true

func _get_distance_to_stop_line() -> float:
	match lane:
		"north":
			return stop_line_coord - global_position.z
		"south":
			return global_position.z - stop_line_coord
		"east":
			return global_position.x - stop_line_coord
		"west":
			return stop_line_coord - global_position.x
	return 999.0

func _check_intersection_bounds():
	var dist_to_stop = _get_distance_to_stop_line()
	
	if not is_past_stop_line and dist_to_stop < 0.0:
		is_past_stop_line = true
		is_in_intersection = true
		if intersection_entry_time == 0.0:
			intersection_entry_time = Time.get_ticks_msec() / 1000.0
		if is_emergency:
			emergency_entered_intersection.emit(self)

	# Exiting intersection check (past center by 9.5m)
	if is_past_stop_line and not has_exited_intersection:
		var pos_axis = 0.0
		match lane:
			"north": pos_axis = global_position.z
			"south": pos_axis = -global_position.z
			"east":  pos_axis = -global_position.x
			"west":  pos_axis = global_position.x
		
		if pos_axis > 9.5:
			has_exited_intersection = true
			is_in_intersection = false
			if is_emergency:
				emergency_exited_intersection.emit(self)

func _check_despawn():
	# Ensure no vehicle ever despawns while anywhere near the intersection center or before exiting
	if not has_exited_intersection:
		return
	
	var dist_from_center = global_position.length()
	if dist_from_center < 20.0:
		return

	# Move despawn trigger significantly further down the exit lanes (far end of 70m road)
	var has_reached_lane_end = false
	match lane:
		"north":
			has_reached_lane_end = (global_position.z >= 66.0)
		"south":
			has_reached_lane_end = (global_position.z <= -66.0)
		"east":
			has_reached_lane_end = (global_position.x <= -66.0)
		"west":
			has_reached_lane_end = (global_position.x >= 66.0)

	if has_reached_lane_end or dist_from_center >= 68.0:
		collision_layer = 0
		collision_mask = 0
		vehicle_cleared.emit(self)
		queue_free()
