extends Node

signal phase_changed(new_phase: String, duration: float)
signal emergency_preemption_triggered(lane: String)
signal emergency_preemption_ended()
signal anti_starvation_triggered(lane: String)
signal remote_command_executed(action: String, lane: String)

# Traffic Light Poles references
@export var pole_north: Node3D
@export var pole_south: Node3D
@export var pole_east: Node3D
@export var pole_west: Node3D
@export var intersection_clear_zone: Area3D
@export var vehicle_spawner: Node

# Backend Cloud API Configuration (Render / Local)
@export var api_base_url: String = "https://stms-project-l3vl.onrender.com"
@export var command_poll_interval: float = 0.5

# Remote Command State
var command_url: String = ""
var command_http: HTTPRequest
var command_poll_timer: float = 0.0
var is_command_poll_in_flight: bool = false
var last_executed_command_id: String = ""
var manual_override_all_red: bool = false

# State machine variables
var current_phase: String = "NS_GREEN"
var phase_timer: float = 0.0
var phase_duration: float = 12.0

# Strict Intersection Mutex Lock:
# Enum: FREE, NS_ACTIVE, EW_ACTIVE
enum IntersectionLock { FREE, NS_ACTIVE, EW_ACTIVE }
var intersection_lock: IntersectionLock = IntersectionLock.FREE

# Queue density metrics
var lane_densities: Dictionary = {
	"north": 0,
	"south": 0,
	"east": 0,
	"west": 0
}

# Anti-Starvation tracking: cumulative wait time (seconds) per lane
var lane_wait_times: Dictionary = {
	"north": 0.0,
	"south": 0.0,
	"east": 0.0,
	"west": 0.0
}
var starvation_active_lane: String = ""
const MAX_PERMISSIBLE_WAIT_TIME: float = 35.0
const MIN_STARVATION_GREEN_TIME: float = 12.0

# Emergency Vehicle Preemption (EVP) & FIFO Priority Queue
var emergency_active: bool = false
var active_emergency_lane: String = ""
var emergency_queue: Array[Node] = []
var active_emergency_vehicle: Node = null

# Backward-compatibility alias for test assertions
var active_emergency_vehicles: Array:
	get:
		return emergency_queue

var vehicles_cleared_total: int = 0

# Configuration constants
const BASE_GREEN_TIME: float = 8.0
const MAX_GREEN_TIME: float = 35.0
const YELLOW_TIME: float = 2.5
const MIN_ALL_RED_TIME: float = 1.8
const MAX_ALL_RED_TIME: float = 3.5

func _ready():
	command_url = api_base_url.rstrip("/") + "/api/commands"
	command_http = HTTPRequest.new()
	command_http.name = "CommandHTTPRequest"
	command_http.timeout = 2.0
	add_child(command_http)
	command_http.request_completed.connect(_on_command_request_completed)

	if not vehicle_spawner:
		vehicle_spawner = get_node_or_null("../VehicleSpawner")

	_enter_phase("NS_GREEN")

func _process(delta: float):
	_update_wait_times(delta)
	_poll_command_timer(delta)

	if manual_override_all_red:
		_process_manual_all_red(delta)
	elif emergency_active:
		_process_emergency_mode(delta)
	else:
		_process_standard_adaptive_cycle(delta)

func _physics_process(_delta: float):
	_update_intersection_lock()

func _update_intersection_lock():
	var yellow_vehicles = get_yellow_box_vehicles()
	if yellow_vehicles.is_empty():
		if current_phase.begins_with("ALL_RED"):
			intersection_lock = IntersectionLock.FREE
		elif emergency_active and active_emergency_lane != "":
			if active_emergency_lane in ["north", "south"]:
				intersection_lock = IntersectionLock.NS_ACTIVE
			else:
				intersection_lock = IntersectionLock.EW_ACTIVE
		elif current_phase.begins_with("NS"):
			intersection_lock = IntersectionLock.NS_ACTIVE
		elif current_phase.begins_with("EW"):
			intersection_lock = IntersectionLock.EW_ACTIVE
		else:
			intersection_lock = IntersectionLock.FREE
	else:
		# Box is occupied: lock is strictly held by whichever axis has vehicles inside!
		var has_ns = false
		var has_ew = false
		for v in yellow_vehicles:
			if "lane" in v:
				if v.lane in ["north", "south"]:
					has_ns = true
				elif v.lane in ["east", "west"]:
					has_ew = true
		if has_ns and not has_ew:
			intersection_lock = IntersectionLock.NS_ACTIVE
		elif has_ew and not has_ns:
			intersection_lock = IntersectionLock.EW_ACTIVE

func get_intersection_lock() -> IntersectionLock:
	return intersection_lock

func get_intersection_lock_name() -> String:
	match intersection_lock:
		IntersectionLock.FREE: return "FREE"
		IntersectionLock.NS_ACTIVE: return "NS_ACTIVE"
		IntersectionLock.EW_ACTIVE: return "EW_ACTIVE"
	return "UNKNOWN"

func can_lane_enter(lane: String) -> bool:
	if manual_override_all_red:
		return false

	if emergency_active:
		# Only the active emergency corridor may enter
		if lane != active_emergency_lane:
			return false
		var is_emerg_ns = (lane == "north" or lane == "south")
		if is_emerg_ns:
			return (intersection_lock == IntersectionLock.NS_ACTIVE or intersection_lock == IntersectionLock.FREE)
		else:
			return (intersection_lock == IntersectionLock.EW_ACTIVE or intersection_lock == IntersectionLock.FREE)

	var is_ns = (lane == "north" or lane == "south")
	if is_ns:
		return (intersection_lock == IntersectionLock.NS_ACTIVE or intersection_lock == IntersectionLock.FREE)
	else:
		return (intersection_lock == IntersectionLock.EW_ACTIVE or intersection_lock == IntersectionLock.FREE)

func _update_wait_times(delta: float):
	for l in ["north", "south", "east", "west"]:
		var signal_state = get_lane_signal_state(l)
		var queue_count = lane_densities.get(l, 0)
		
		if signal_state == "RED" and queue_count > 0:
			lane_wait_times[l] += delta
		elif signal_state == "GREEN":
			lane_wait_times[l] = max(0.0, lane_wait_times[l] - delta * 3.0)

func _process_standard_adaptive_cycle(delta: float):
	phase_timer += delta

	# In ALL-RED clearance phases, hold until intersection is confirmed clear
	if current_phase == "ALL_RED_1" or current_phase == "ALL_RED_2":
		var current_vehicles = get_yellow_box_vehicles()
		var is_empty = current_vehicles.is_empty()
		
		# The lock can ONLY switch when YellowBoxArea3D is COMPLETELY EMPTY
		if is_empty:
			intersection_lock = IntersectionLock.FREE
			_advance_to_next_phase()
		elif phase_timer >= MAX_ALL_RED_TIME:
			intersection_lock = IntersectionLock.FREE
			_advance_to_next_phase()
	else:
		if phase_timer >= phase_duration:
			_advance_to_next_phase()

func _advance_to_next_phase():
	phase_timer = 0.0
	match current_phase:
		"NS_GREEN":
			_enter_phase("NS_YELLOW", YELLOW_TIME)
		"NS_YELLOW":
			_enter_phase("ALL_RED_1", MIN_ALL_RED_TIME)
		"ALL_RED_1":
			# Strict Mutex Rule: Lock can only switch to EW_ACTIVE when yellow box is completely empty!
			if not get_yellow_box_vehicles().is_empty():
				return # Hold until empty
			intersection_lock = IntersectionLock.FREE
			var next_phase = _determine_optimal_next_phase("EW_GREEN")
			var ew_calc = calculate_adaptive_green_time("east_west")
			if starvation_active_lane != "":
				ew_calc = max(MIN_STARVATION_GREEN_TIME, ew_calc)
			_enter_phase(next_phase, ew_calc)
		"EW_GREEN":
			_enter_phase("EW_YELLOW", YELLOW_TIME)
		"EW_YELLOW":
			_enter_phase("ALL_RED_2", MIN_ALL_RED_TIME)
		"ALL_RED_2":
			# Strict Mutex Rule: Lock can only switch to NS_ACTIVE when yellow box is completely empty!
			if not get_yellow_box_vehicles().is_empty():
				return # Hold until empty
			intersection_lock = IntersectionLock.FREE
			var next_phase = _determine_optimal_next_phase("NS_GREEN")
			var ns_calc = calculate_adaptive_green_time("north_south")
			if starvation_active_lane != "":
				ns_calc = max(MIN_STARVATION_GREEN_TIME, ns_calc)
			_enter_phase(next_phase, ns_calc)

func _determine_optimal_next_phase(default_phase: String) -> String:
	var max_wait = 0.0
	var starving_lane = ""
	for l in ["north", "south", "east", "west"]:
		if lane_densities.get(l, 0) > 0 and lane_wait_times[l] > max_wait:
			max_wait = lane_wait_times[l]
			starving_lane = l

	if max_wait >= MAX_PERMISSIBLE_WAIT_TIME:
		starvation_active_lane = starving_lane
		anti_starvation_triggered.emit(starving_lane)
		if starving_lane in ["north", "south"]:
			return "NS_GREEN"
		else:
			return "EW_GREEN"

	starvation_active_lane = ""
	return default_phase

func _enter_phase(phase: String, custom_duration: float = -1.0):
	current_phase = phase
	phase_timer = 0.0

	if phase.begins_with("NS_GREEN") or phase.begins_with("NS_YELLOW"):
		intersection_lock = IntersectionLock.NS_ACTIVE
	elif phase.begins_with("EW_GREEN") or phase.begins_with("EW_YELLOW"):
		intersection_lock = IntersectionLock.EW_ACTIVE
	elif phase.begins_with("ALL_RED"):
		if get_yellow_box_vehicles().is_empty():
			intersection_lock = IntersectionLock.FREE

	if custom_duration > 0.0:
		phase_duration = custom_duration
	else:
		if phase == "NS_GREEN":
			phase_duration = calculate_adaptive_green_time("north_south")
		elif phase == "EW_GREEN":
			phase_duration = calculate_adaptive_green_time("east_west")
		elif phase.ends_with("YELLOW"):
			phase_duration = YELLOW_TIME
		else:
			phase_duration = MIN_ALL_RED_TIME

	_update_signal_poles()
	phase_changed.emit(current_phase, phase_duration)

func calculate_adaptive_green_time(axis: String) -> float:
	var total_density = 0
	if axis == "north_south":
		total_density = lane_densities.get("north", 0) + lane_densities.get("south", 0)
	else:
		total_density = lane_densities.get("east", 0) + lane_densities.get("west", 0)

	var computed_time = BASE_GREEN_TIME + (float(total_density) * 2.5)
	return clamp(computed_time, BASE_GREEN_TIME, MAX_GREEN_TIME)

func _update_signal_poles():
	if not pole_north or not pole_south or not pole_east or not pole_west:
		return

	if manual_override_all_red:
		if pole_north.has_method("set_signal"): pole_north.set_signal("RED")
		if pole_south.has_method("set_signal"): pole_south.set_signal("RED")
		if pole_east.has_method("set_signal"): pole_east.set_signal("RED")
		if pole_west.has_method("set_signal"): pole_west.set_signal("RED")
		return

	if emergency_active:
		if current_phase == "ALL_RED_EMERGENCY":
			if pole_north.has_method("set_signal"): pole_north.set_signal("RED")
			if pole_south.has_method("set_signal"): pole_south.set_signal("RED")
			if pole_east.has_method("set_signal"): pole_east.set_signal("RED")
			if pole_west.has_method("set_signal"): pole_west.set_signal("RED")
			return

		# STRICT SINGLE-LANE EMERGENCY CORRIDOR:
		# Only the active emergency vehicle's lane gets GREEN!
		# All conflicting and cross lanes (including opposite lane) are strictly RED!
		if pole_north.has_method("set_signal"):
			pole_north.set_signal("GREEN" if active_emergency_lane == "north" else "RED")
		if pole_south.has_method("set_signal"):
			pole_south.set_signal("GREEN" if active_emergency_lane == "south" else "RED")
		if pole_east.has_method("set_signal"):
			pole_east.set_signal("GREEN" if active_emergency_lane == "east" else "RED")
		if pole_west.has_method("set_signal"):
			pole_west.set_signal("GREEN" if active_emergency_lane == "west" else "RED")
		return

	match current_phase:
		"NS_GREEN":
			if pole_north.has_method("set_signal"): pole_north.set_signal("GREEN")
			if pole_south.has_method("set_signal"): pole_south.set_signal("GREEN")
			if pole_east.has_method("set_signal"): pole_east.set_signal("RED")
			if pole_west.has_method("set_signal"): pole_west.set_signal("RED")
		"NS_YELLOW":
			if pole_north.has_method("set_signal"): pole_north.set_signal("YELLOW")
			if pole_south.has_method("set_signal"): pole_south.set_signal("YELLOW")
			if pole_east.has_method("set_signal"): pole_east.set_signal("RED")
			if pole_west.has_method("set_signal"): pole_west.set_signal("RED")
		"EW_GREEN":
			if pole_north.has_method("set_signal"): pole_north.set_signal("RED")
			if pole_south.has_method("set_signal"): pole_south.set_signal("RED")
			if pole_east.has_method("set_signal"): pole_east.set_signal("GREEN")
			if pole_west.has_method("set_signal"): pole_west.set_signal("GREEN")
		"EW_YELLOW":
			if pole_north.has_method("set_signal"): pole_north.set_signal("RED")
			if pole_south.has_method("set_signal"): pole_south.set_signal("RED")
			if pole_east.has_method("set_signal"): pole_east.set_signal("YELLOW")
			if pole_west.has_method("set_signal"): pole_west.set_signal("YELLOW")
		"ALL_RED_1", "ALL_RED_2", "ALL_RED_EMERGENCY":
			if pole_north.has_method("set_signal"): pole_north.set_signal("RED")
			if pole_south.has_method("set_signal"): pole_south.set_signal("RED")
			if pole_east.has_method("set_signal"): pole_east.set_signal("RED")
			if pole_west.has_method("set_signal"): pole_west.set_signal("RED")

func get_lane_signal_state(lane: String) -> String:
	if manual_override_all_red:
		return "RED"

	if emergency_active:
		if current_phase == "ALL_RED_EMERGENCY":
			return "RED"
		return "GREEN" if lane == active_emergency_lane else "RED"

	match current_phase:
		"NS_GREEN":
			return "GREEN" if (lane == "north" or lane == "south") else "RED"
		"NS_YELLOW":
			return "YELLOW" if (lane == "north" or lane == "south") else "RED"
		"EW_GREEN":
			return "GREEN" if (lane == "east" or lane == "west") else "RED"
		"EW_YELLOW":
			return "YELLOW" if (lane == "east" or lane == "west") else "RED"
		_:
			return "RED"

func trigger_emergency_preemption(vehicle: Node):
	if not vehicle or not is_instance_valid(vehicle):
		return
	
	if not emergency_queue.has(vehicle):
		emergency_queue.append(vehicle)

	# If no emergency vehicle is currently active, service the head of queue immediately
	if not emergency_active or active_emergency_vehicle == null or not is_instance_valid(active_emergency_vehicle):
		_service_next_emergency_in_queue()

func _service_next_emergency_in_queue():
	# 1. Clean the queue of any invalid instances
	var valid_queue: Array[Node] = []
	for v in emergency_queue:
		if is_instance_valid(v) and not v.is_queued_for_deletion():
			if ("has_exited_intersection" not in v) or not v.has_exited_intersection:
				valid_queue.append(v)
	emergency_queue = valid_queue

	if emergency_queue.is_empty():
		_finish_emergency_preemption()
		return

	var next_ev = emergency_queue[0]

	# Check if the yellow box is occupied by foreign vehicles
	var yellow_vehicles = get_yellow_box_vehicles()
	var conflicting_vehicles: Array[Node] = []
	for bv in yellow_vehicles:
		if bv != next_ev:
			conflicting_vehicles.append(bv)

	if not conflicting_vehicles.is_empty():
		# Yellow box still clearing: hold all signals RED
		emergency_active = true
		active_emergency_vehicle = next_ev
		active_emergency_lane = next_ev.lane
		current_phase = "ALL_RED_EMERGENCY"
		_update_signal_poles()
		return

	# Yellow box is completely clear: grant exclusive green corridor to the first-in-queue emergency vehicle
	emergency_active = true
	active_emergency_vehicle = next_ev
	active_emergency_lane = next_ev.lane

	if active_emergency_lane in ["north", "south"]:
		current_phase = "EMERGENCY_NS"
		intersection_lock = IntersectionLock.NS_ACTIVE
	else:
		current_phase = "EMERGENCY_EW"
		intersection_lock = IntersectionLock.EW_ACTIVE

	phase_timer = 0.0
	phase_duration = 35.0
	_update_signal_poles()
	emergency_preemption_triggered.emit(active_emergency_lane)

func _process_emergency_mode(delta: float):
	var valid_queue: Array[Node] = []
	for v in emergency_queue:
		if is_instance_valid(v) and not v.is_queued_for_deletion():
			valid_queue.append(v)
	emergency_queue = valid_queue

	if emergency_queue.is_empty():
		_finish_emergency_preemption()
		return

	# If in holding state waiting for clear box:
	if current_phase == "ALL_RED_EMERGENCY":
		var box_vehicles = get_yellow_box_vehicles()
		var foreign_vehicles: Array[Node] = []
		for bv in box_vehicles:
			if bv != active_emergency_vehicle:
				foreign_vehicles.append(bv)
		
		if foreign_vehicles.is_empty():
			_service_next_emergency_in_queue()
		else:
			_update_signal_poles()
		return

	# Check active emergency vehicle
	if not is_instance_valid(active_emergency_vehicle):
		_service_next_emergency_in_queue()
		return

	var has_cleared = false
	if "has_exited_intersection" in active_emergency_vehicle and active_emergency_vehicle.has_exited_intersection:
		var box_vehicles = get_yellow_box_vehicles()
		if not box_vehicles.has(active_emergency_vehicle):
			has_cleared = true

	if has_cleared:
		emergency_queue.erase(active_emergency_vehicle)
		active_emergency_vehicle = null
		
		if not emergency_queue.is_empty():
			# Check if yellow box is completely clear before granting next green
			if get_yellow_box_vehicles().is_empty():
				_service_next_emergency_in_queue()
			else:
				current_phase = "ALL_RED_EMERGENCY"
				active_emergency_vehicle = emergency_queue[0]
				active_emergency_lane = active_emergency_vehicle.lane
				_update_signal_poles()
		else:
			_finish_emergency_preemption()

func _finish_emergency_preemption():
	emergency_active = false
	active_emergency_vehicle = null
	var finished_lane = active_emergency_lane
	active_emergency_lane = ""
	emergency_preemption_ended.emit()

	if get_yellow_box_vehicles().is_empty():
		intersection_lock = IntersectionLock.FREE

	# 2.0-second Yellow clearance delay before returning to normal cycle
	if finished_lane in ["north", "south"]:
		_enter_phase("NS_YELLOW", 2.0)
	else:
		_enter_phase("EW_YELLOW", 2.0)

func on_emergency_exited(vehicle: Node):
	if emergency_queue.has(vehicle):
		emergency_queue.erase(vehicle)
	if active_emergency_vehicle == vehicle:
		active_emergency_vehicle = null
		_service_next_emergency_in_queue()

func update_lane_densities(n: int, s: int, e: int, w: int):
	lane_densities["north"] = n
	lane_densities["south"] = s
	lane_densities["east"] = e
	lane_densities["west"] = w

func get_yellow_box_vehicles() -> Array[Node]:
	if not intersection_clear_zone or not is_instance_valid(intersection_clear_zone):
		return []
	var yellow_box_area = intersection_clear_zone
	var current_vehicles = yellow_box_area.get_overlapping_bodies()
	var filtered_vehicles: Array[Node] = []
	for body in current_vehicles:
		if is_instance_valid(body) and not body.is_queued_for_deletion():
			if body.is_in_group("Vehicle"):
				filtered_vehicles.append(body)
	return filtered_vehicles

func is_intersection_empty() -> bool:
	if intersection_clear_zone and intersection_clear_zone.has_method("is_intersection_empty"):
		return intersection_clear_zone.is_intersection_empty()
	return get_yellow_box_vehicles().is_empty()

func get_vehicles_count() -> int:
	if intersection_clear_zone and intersection_clear_zone.has_method("get_vehicles_count"):
		return intersection_clear_zone.get_vehicles_count()
	return get_yellow_box_vehicles().size()

func get_telemetry_payload() -> Dictionary:
	var max_wait = 0.0
	for l in lane_wait_times.keys():
		if lane_wait_times[l] > max_wait:
			max_wait = lane_wait_times[l]

	var in_junction = get_vehicles_count()

	return {
		"timestamp": Time.get_unix_time_from_system(),
		"lane_densities": {
			"north": lane_densities.get("north", 0),
			"south": lane_densities.get("south", 0),
			"east": lane_densities.get("east", 0),
			"west": lane_densities.get("west", 0)
		},
		"current_phase": current_phase,
		"intersection_lock": get_intersection_lock_name(),
		"emergency_active": emergency_active,
		"active_emergency_lane": active_emergency_lane if emergency_active else null,
		"emergency_queue_count": emergency_queue.size(),
		"vehicles_waiting": lane_densities["north"] + lane_densities["south"] + lane_densities["east"] + lane_densities["west"],
		"vehicles_in_intersection": in_junction,
		"vehicles_cleared_total": vehicles_cleared_total,
		"max_wait_time_seconds": round(max_wait * 10.0) / 10.0,
		"anti_starvation_active": starvation_active_lane != "",
		"starving_lane": starvation_active_lane if starvation_active_lane != "" else null,
		"manual_override_active": manual_override_all_red
	}

# =============================================================
# Cloud-to-Edge Remote Command Engine
# =============================================================
func _poll_command_timer(delta: float):
	command_poll_timer += delta
	if command_poll_timer >= command_poll_interval:
		command_poll_timer = 0.0
		_poll_remote_command()

func _poll_remote_command():
	if not is_inside_tree() or not command_http:
		return
	# Dedicated command HTTPRequest busy guard: never overlap or drop command requests
	if is_command_poll_in_flight or command_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	if command_url == "":
		command_url = api_base_url.rstrip("/") + "/api/commands"
	is_command_poll_in_flight = true
	var headers = ["User-Agent: STMS-Godot-Edge/1.0"]
	var err = command_http.request(command_url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		is_command_poll_in_flight = false

func _on_command_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	is_command_poll_in_flight = false
	if response_code != 200 or body.is_empty():
		return

	var json = JSON.new()
	var parse_err = json.parse(body.get_string_from_utf8())
	if parse_err != OK:
		return

	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return

	# 1. Process batched commands array popped from in-memory queue
	if data.has("commands") and typeof(data["commands"]) == TYPE_ARRAY:
		for cmd_item in data["commands"]:
			if typeof(cmd_item) == TYPE_DICTIONARY:
				_process_single_command_data(cmd_item)
	# 2. Or process single top-level command dictionary (backward compatibility)
	elif data.has("action") and data["action"] != null:
		_process_single_command_data(data)

func _process_single_command_data(data: Dictionary):
	var action = data.get("action", null)
	if action == null or str(action) == "" or str(action) == "<null>":
		return

	var cmd_id = str(data.get("command_id", ""))
	if cmd_id != "" and cmd_id == last_executed_command_id:
		return

	if cmd_id != "":
		last_executed_command_id = cmd_id

	var target_lane = str(data.get("lane", "")).to_lower()
	if target_lane == "<null>":
		target_lane = ""
	execute_remote_command(str(action).to_upper(), target_lane)

func execute_remote_command(action: String, lane: String = ""):
	print("[TrafficController] Executing Remote Command: ", action, " (Lane: ", lane, ")")
	match action:
		"FORCE_ALL_RED":
			force_all_red()
		"TRIGGER_EMERGENCY":
			trigger_remote_emergency(lane)
		"SPAWN_TRAFFIC_SURGE":
			trigger_traffic_surge(lane)
		"RESUME_AUTO":
			resume_automatic_mode()
		_:
			print("[TrafficController] Unknown remote command action: ", action)
	remote_command_executed.emit(action, lane)

func _process_manual_all_red(_delta: float):
	current_phase = "ALL_RED_MANUAL"
	_update_signal_poles()

func force_all_red():
	manual_override_all_red = true
	emergency_active = false
	active_emergency_lane = ""
	current_phase = "ALL_RED_MANUAL"
	phase_timer = 0.0
	phase_duration = 9999.0
	intersection_lock = IntersectionLock.FREE
	_update_signal_poles()
	phase_changed.emit("ALL_RED_MANUAL", 9999.0)
	print("[TrafficController] Cloud Override: FORCE_ALL_RED active. All signals locked RED.")

func resume_automatic_mode():
	manual_override_all_red = false
	if emergency_active:
		_finish_emergency_preemption()
	else:
		_enter_phase("NS_GREEN", calculate_adaptive_green_time("north_south"))
	print("[TrafficController] Cloud Override: RESUME_AUTO. Returned to dynamic adaptive cycle.")

func trigger_remote_emergency(lane: String = ""):
	manual_override_all_red = false
	var target_lane = lane.to_lower()
	if not ["north", "south", "east", "west"].has(target_lane):
		target_lane = "north"

	if not vehicle_spawner:
		vehicle_spawner = get_node_or_null("../VehicleSpawner")

	if vehicle_spawner and vehicle_spawner.has_method("spawn_emergency_vehicle"):
		var ev = vehicle_spawner.spawn_emergency_vehicle("ambulance", target_lane)
		print("[TrafficController] Cloud Override: Spawned emergency vehicle on lane: ", target_lane, " (instance: ", ev, ")")
	else:
		# Direct fallback if spawner not in tree
		emergency_active = true
		active_emergency_lane = target_lane
		if target_lane in ["north", "south"]:
			current_phase = "EMERGENCY_NS"
			intersection_lock = IntersectionLock.NS_ACTIVE
		else:
			current_phase = "EMERGENCY_EW"
			intersection_lock = IntersectionLock.EW_ACTIVE
		phase_timer = 0.0
		phase_duration = 35.0
		_update_signal_poles()
		emergency_preemption_triggered.emit(active_emergency_lane)
		print("[TrafficController] Cloud Override: Direct emergency preemption activated on: ", target_lane)

func trigger_traffic_surge(lane: String = ""):
	if not vehicle_spawner:
		vehicle_spawner = get_node_or_null("../VehicleSpawner")

	if vehicle_spawner and vehicle_spawner.has_method("spawn_traffic_burst"):
		var target_lane = lane.to_lower()
		if ["north", "south", "east", "west"].has(target_lane):
			vehicle_spawner.spawn_traffic_burst(target_lane, 3)
		else:
			vehicle_spawner.spawn_traffic_burst("north", 2)
			vehicle_spawner.spawn_traffic_burst("south", 2)
			vehicle_spawner.spawn_traffic_burst("east", 2)
			vehicle_spawner.spawn_traffic_burst("west", 2)
		print("[TrafficController] Cloud Override: Traffic surge burst dispatched.")
	else:
		for l in lane_densities.keys():
			lane_densities[l] += 3
		print("[TrafficController] Cloud Override: Density surge applied to local metrics.")
