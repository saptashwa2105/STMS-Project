extends Node

signal vehicle_spawned(v: Node)

@export var vehicle_scene: PackedScene
@export var traffic_controller: Node
@export var intersection_clear_zone: Area3D
@export var vehicles_root: Node3D

var spawn_timer: float = 0.0
var base_spawn_interval: float = 2.4
const MAX_LANE_QUEUE_BUFFER: int = 8
const QUEUE_UNLOCK_THRESHOLD: int = 4

# Lane capacity lock states
var lane_spawn_locked: Dictionary = {
	"north": false,
	"south": false,
	"east": false,
	"west": false
}

# Active tracked vehicles per lane
var active_vehicles_by_lane: Dictionary = {
	"north": [],
	"south": [],
	"east": [],
	"west": []
}

var spawn_points: Dictionary = {
	"north": Vector3(-2.1, 0.0, -52.0),
	"south": Vector3(2.1, 0.0, 52.0),
	"east": Vector3(52.0, 0.0, -2.1),
	"west": Vector3(-52.0, 0.0, 2.1)
}

func _ready():
	if not vehicle_scene:
		vehicle_scene = load("res://scenes/Vehicle.tscn")

func _process(delta: float):
	spawn_timer += delta
	if spawn_timer >= base_spawn_interval:
		spawn_timer = 0.0
		_spawn_random_civilian_vehicle()

	_update_queue_densities_and_leader_tracking()

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("spawn_ambulance"):
		spawn_emergency_vehicle("ambulance")
	elif event.is_action_pressed("spawn_firetruck"):
		spawn_emergency_vehicle("firetruck")
	elif event.is_action_pressed("spawn_random_burst"):
		spawn_traffic_burst("north", 2)
		spawn_traffic_burst("south", 2)

func _spawn_random_civilian_vehicle():
	var available_lanes = []
	for l in ["north", "south", "east", "west"]:
		if not lane_spawn_locked[l]:
			available_lanes.append(l)

	if available_lanes.is_empty():
		return # All lanes at capacity, wait for clearance

	var chosen_lane = available_lanes[randi() % available_lanes.size()]

	var rand_val = randf()
	var v_type = "car"
	if rand_val < 0.65:
		v_type = "car"
	elif rand_val < 0.82:
		v_type = "motorbike"
	else:
		v_type = "truck"

	spawn_vehicle(chosen_lane, v_type, false)

func spawn_vehicle(lane: String, v_type: String, is_emergency: bool = false) -> Node:
	if not vehicle_scene:
		vehicle_scene = load("res://scenes/Vehicle.tscn")
	if not vehicle_scene or not spawn_points.has(lane):
		return null

	var spawn_pos = spawn_points[lane]

	# Queue Capacity & Buffer Hysteresis Check
	var current_lane_queue = 0
	for v in active_vehicles_by_lane[lane]:
		if is_instance_valid(v) and ("is_past_stop_line" in v) and not v.is_past_stop_line:
			current_lane_queue += 1

	if current_lane_queue >= MAX_LANE_QUEUE_BUFFER:
		lane_spawn_locked[lane] = true

	if lane_spawn_locked[lane] and not is_emergency:
		return null # Locked until queue drains to 4

	# Check if spawn zone is clear for civilian vehicles
	if not is_emergency:
		for v in active_vehicles_by_lane[lane]:
			if is_instance_valid(v):
				var v_pos = v.position
				if v_pos.distance_to(spawn_pos) < 6.5:
					return null
	else:
		# If emergency vehicle spawns and a lead car is at spawn point, offset spawn position backward
		for v in active_vehicles_by_lane[lane]:
			if is_instance_valid(v) and v.position.distance_to(spawn_pos) < 6.0:
				match lane:
					"north": spawn_pos.z -= 7.0
					"south": spawn_pos.z += 7.0
					"east":  spawn_pos.x += 7.0
					"west":  spawn_pos.x -= 7.0

	# Find lead vehicle in this lane
	var lead_vehicle: Node = null
	if not active_vehicles_by_lane[lane].is_empty():
		var last_v = active_vehicles_by_lane[lane].back()
		if is_instance_valid(last_v):
			lead_vehicle = last_v

	var vehicle_instance = vehicle_scene.instantiate()
	vehicle_instance.vehicle_type = v_type
	vehicle_instance.lane = lane
	vehicle_instance.is_emergency = is_emergency
	vehicle_instance.traffic_controller = traffic_controller
	vehicle_instance.intersection_clear_zone = intersection_clear_zone
	vehicle_instance.vehicle_ahead = lead_vehicle
	vehicle_instance.position = spawn_pos

	# Connect signals
	if vehicle_instance.has_signal("vehicle_cleared"):
		vehicle_instance.vehicle_cleared.connect(_on_vehicle_cleared)
	if is_emergency:
		if vehicle_instance.has_signal("emergency_entered_intersection"):
			vehicle_instance.emergency_entered_intersection.connect(_on_emergency_entered)
		if vehicle_instance.has_signal("emergency_exited_intersection"):
			vehicle_instance.emergency_exited_intersection.connect(_on_emergency_exited)

	if vehicles_root:
		vehicles_root.add_child(vehicle_instance)
	else:
		add_child(vehicle_instance)

	active_vehicles_by_lane[lane].append(vehicle_instance)
	vehicle_spawned.emit(vehicle_instance)

	if is_emergency and traffic_controller and traffic_controller.has_method("trigger_emergency_preemption"):
		traffic_controller.trigger_emergency_preemption(vehicle_instance)

	return vehicle_instance

func spawn_emergency_vehicle(v_type: String = "ambulance", preferred_lane: String = "") -> Node:
	var lane = preferred_lane
	if lane == "":
		var lanes = ["north", "south", "east", "west"]
		lane = lanes[randi() % lanes.size()]

	return spawn_vehicle(lane, v_type, true)

func spawn_traffic_burst(lane: String, count: int = 2):
	for i in range(count):
		var timer = get_tree().create_timer(i * 1.4)
		timer.timeout.connect(func():
			var v_type = "car" if i % 2 == 0 else "truck"
			spawn_vehicle(lane, v_type, false)
		)

func clear_all_vehicles():
	for lane_key in active_vehicles_by_lane.keys():
		for v in active_vehicles_by_lane[lane_key]:
			if is_instance_valid(v):
				v.queue_free()
		active_vehicles_by_lane[lane_key].clear()
		lane_spawn_locked[lane_key] = false

func _update_queue_densities_and_leader_tracking():
	var densities = {"north": 0, "south": 0, "east": 0, "west": 0}

	for lane_key in active_vehicles_by_lane.keys():
		var valid_list: Array[Node] = []
		var waiting_count = 0
		
		for i in range(active_vehicles_by_lane[lane_key].size()):
			var v = active_vehicles_by_lane[lane_key][i]
			if is_instance_valid(v):
				valid_list.append(v)
				if ("is_past_stop_line" in v) and not v.is_past_stop_line:
					waiting_count += 1
		
		# Update sequential leader pointers
		for i in range(valid_list.size()):
			if i > 0:
				valid_list[i].vehicle_ahead = valid_list[i - 1]
			else:
				valid_list[i].vehicle_ahead = null

		active_vehicles_by_lane[lane_key] = valid_list
		densities[lane_key] = waiting_count

		# Unlock lane when queue drains below threshold
		if waiting_count <= QUEUE_UNLOCK_THRESHOLD and lane_spawn_locked[lane_key]:
			lane_spawn_locked[lane_key] = false

	if traffic_controller and traffic_controller.has_method("update_lane_densities"):
		traffic_controller.update_lane_densities(
			densities["north"],
			densities["south"],
			densities["east"],
			densities["west"]
		)

func _on_vehicle_cleared(v: Node):
	if traffic_controller and ("vehicles_cleared_total" in traffic_controller):
		traffic_controller.vehicles_cleared_total += 1

func _on_emergency_entered(_v: Node):
	pass

func _on_emergency_exited(v: Node):
	if traffic_controller and traffic_controller.has_method("on_emergency_exited"):
		traffic_controller.on_emergency_exited(v)
