extends Control

@export var traffic_controller: Node
@export var telemetry_bridge: Node
@export var vehicle_spawner: Node

@onready var lbl_phase: Label = $PanelMain/VBox/HBoxPhase/LblPhase
@onready var lbl_countdown: Label = $PanelMain/VBox/HBoxPhase/LblCountdown
@onready var lbl_timing_formula: Label = $PanelMain/VBox/LblFormula
@onready var lbl_clear_zone: Label = $PanelMain/VBox/LblClearZone
@onready var lbl_starvation_alert: Label = $PanelMain/VBox/LblStarvation

@onready var val_n: Label = $PanelMain/VBox/GridLanes/ValN
@onready var val_s: Label = $PanelMain/VBox/GridLanes/ValS
@onready var val_e: Label = $PanelMain/VBox/GridLanes/ValE
@onready var val_w: Label = $PanelMain/VBox/GridLanes/ValW

@onready var bar_n: ProgressBar = $PanelMain/VBox/GridLanes/BarN
@onready var bar_s: ProgressBar = $PanelMain/VBox/GridLanes/BarS
@onready var bar_e: ProgressBar = $PanelMain/VBox/GridLanes/BarE
@onready var bar_w: ProgressBar = $PanelMain/VBox/GridLanes/BarW

@onready var emerg_banner: PanelContainer = $EmergencyBanner
@onready var lbl_emerg_lane: Label = $EmergencyBanner/HBoxEmerg/LblEmergLane

@onready var lbl_telemetry: Label = $PanelTelemetry/VBoxTelem/LblTelemStatus
@onready var lbl_packets: Label = $PanelTelemetry/VBoxTelem/LblPackets

@onready var btn_ambulance: Button = $PanelControls/HBoxBtns/BtnAmbulance
@onready var btn_firetruck: Button = $PanelControls/HBoxBtns/BtnFiretruck
@onready var btn_burst: Button = $PanelControls/HBoxBtns/BtnBurst
@onready var btn_clear: Button = $PanelControls/HBoxBtns/BtnClear
@onready var btn_cam: Button = $PanelControls/HBoxBtns/BtnCam

var emerg_blink_timer: float = 0.0

func _ready():
	btn_ambulance.pressed.connect(func(): if vehicle_spawner and vehicle_spawner.has_method("spawn_emergency_vehicle"): vehicle_spawner.spawn_emergency_vehicle("ambulance"))
	btn_firetruck.pressed.connect(func(): if vehicle_spawner and vehicle_spawner.has_method("spawn_emergency_vehicle"): vehicle_spawner.spawn_emergency_vehicle("firetruck"))
	btn_burst.pressed.connect(func(): 
		if vehicle_spawner and vehicle_spawner.has_method("spawn_traffic_burst"):
			vehicle_spawner.spawn_traffic_burst("north", 2)
			vehicle_spawner.spawn_traffic_burst("south", 2)
	)
	btn_clear.pressed.connect(func():
		if vehicle_spawner and vehicle_spawner.has_method("clear_all_vehicles"):
			vehicle_spawner.clear_all_vehicles()
	)
	btn_cam.pressed.connect(func():
		var tree = get_tree().current_scene
		if tree and tree.has_method("toggle_camera_mode"):
			tree.toggle_camera_mode()
	)

func _process(delta: float):
	_update_controller_ui(delta)
	_update_telemetry_ui()

func _update_controller_ui(delta: float):
	if not traffic_controller:
		return

	var phase = traffic_controller.current_phase if ("current_phase" in traffic_controller) else "NS_GREEN"
	var p_dur = traffic_controller.phase_duration if ("phase_duration" in traffic_controller) else 12.0
	var p_tim = traffic_controller.phase_timer if ("phase_timer" in traffic_controller) else 0.0
	var rem_time = max(0.0, p_dur - p_tim)
	
	lbl_phase.text = phase
	lbl_countdown.text = "%.1fs" % rem_time

	if phase.contains("GREEN"):
		lbl_phase.modulate = Color(0.2, 1.0, 0.4)
	elif phase.contains("YELLOW"):
		lbl_phase.modulate = Color(1.0, 0.8, 0.2)
	else:
		lbl_phase.modulate = Color(1.0, 0.3, 0.3)

	var dens = traffic_controller.lane_densities if ("lane_densities" in traffic_controller) else {}
	var ns_dens = dens.get("north", 0) + dens.get("south", 0)
	var ew_dens = dens.get("east", 0) + dens.get("west", 0)
	var cur_dens = ns_dens if phase.begins_with("NS") else ew_dens
	lbl_timing_formula.text = "Dynamic Timing: 8s base + (%d veh * 2.5s) = %.1fs (Max 35s)" % [cur_dens, p_dur]

	# Yellow Box Status & Mutex Lock
	var in_box_count = 0
	if traffic_controller and traffic_controller.has_method("get_vehicles_count"):
		in_box_count = traffic_controller.get_vehicles_count()
	elif traffic_controller and ("intersection_clear_zone" in traffic_controller) and traffic_controller.intersection_clear_zone:
		var clear_zone = traffic_controller.intersection_clear_zone
		if clear_zone.has_method("get_vehicles_count"):
			in_box_count = clear_zone.get_vehicles_count()

	var lock_name = ""
	if traffic_controller and traffic_controller.has_method("get_intersection_lock_name"):
		lock_name = " [Mutex: " + traffic_controller.get_intersection_lock_name() + "]"

	if in_box_count > 0:
		lbl_clear_zone.text = "🟡 Yellow Box: CLEARING (%d in junction)%s" % [in_box_count, lock_name]
		lbl_clear_zone.modulate = Color(1.0, 0.8, 0.2)
	else:
		lbl_clear_zone.text = "🟢 Yellow Box: CLEAR (Anti-Gridlock Active)%s" % lock_name
		lbl_clear_zone.modulate = Color(0.2, 1.0, 0.4)

	# Anti-Starvation indicator
	var is_starving = ("starvation_active_lane" in traffic_controller) and traffic_controller.starvation_active_lane != ""
	if is_starving:
		lbl_starvation_alert.visible = true
		lbl_starvation_alert.text = "⚠️ ANTI-STARVATION OVERRIDE: [%s LANE]" % traffic_controller.starvation_active_lane.to_upper()
	else:
		lbl_starvation_alert.visible = false

	var dn = dens.get("north", 0)
	var ds = dens.get("south", 0)
	var de = dens.get("east", 0)
	var dw = dens.get("west", 0)

	val_n.text = "%d" % dn
	val_s.text = "%d" % ds
	val_e.text = "%d" % de
	val_w.text = "%d" % dw

	bar_n.value = dn
	bar_s.value = ds
	bar_e.value = de
	bar_w.value = dw

	var is_emerg = traffic_controller.emergency_active if ("emergency_active" in traffic_controller) else false
	var is_trans = traffic_controller.is_emergency_transitioning if ("is_emergency_transitioning" in traffic_controller) else false
	if is_emerg or is_trans:
		emerg_banner.visible = true
		var lane_name = ""
		if is_emerg:
			lane_name = traffic_controller.active_emergency_lane if ("active_emergency_lane" in traffic_controller) else "LANE"
		else:
			lane_name = traffic_controller.pending_emergency_lane if ("pending_emergency_lane" in traffic_controller) else "LANE"
		
		var q_count = traffic_controller.emergency_queue.size() if ("emergency_queue" in traffic_controller) else 0
		if q_count > 1:
			lbl_emerg_lane.text = "EMERGENCY CORRIDOR: [%s LANE] (%d vehicles queued)" % [lane_name.to_upper(), q_count]
		else:
			lbl_emerg_lane.text = "EMERGENCY CORRIDOR: [%s LANE]" % lane_name.to_upper()
		emerg_blink_timer += delta
		emerg_banner.modulate.a = 0.7 + 0.3 * sin(emerg_blink_timer * 10.0)
	else:
		emerg_banner.visible = false

func _update_telemetry_ui():
	if not telemetry_bridge:
		return

	var is_conn = telemetry_bridge.is_server_connected if ("is_server_connected" in telemetry_bridge) else false
	var pkt_count = telemetry_bridge.packets_sent_count if ("packets_sent_count" in telemetry_bridge) else 0

	if is_conn:
		lbl_telemetry.text = "CLOUD INGESTION: ONLINE (127.0.0.1:8000)"
		lbl_telemetry.modulate = Color(0.2, 1.0, 0.4)
	else:
		lbl_telemetry.text = "CLOUD INGESTION: CONNECTING..."
		lbl_telemetry.modulate = Color(1.0, 0.8, 0.2)

	lbl_packets.text = "Telemetry Dispatched: %d frames" % pkt_count
