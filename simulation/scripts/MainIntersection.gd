extends Node3D

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var traffic_controller: Node = $TrafficController
@onready var telemetry_bridge: Node = $TelemetryBridge
@onready var vehicle_spawner: Node = $VehicleSpawner
@onready var ui_overlay: Node = $UIOverlay

var current_cam_mode: int = 0
var cam_modes = [
	{"pos": Vector3(30, 36, 30), "rot": Vector3(-45, 45, 0), "fov": 42.0}, # High-Angle Isometric 45-deg
	{"pos": Vector3(0.01, 52, 0.01), "rot": Vector3(-90, 0, 0), "fov": 50.0}, # Top-Down Orthogonal
	{"pos": Vector3(18, 20, 18), "rot": Vector3(-38, 45, 0), "fov": 38.0}  # Cinematic Close View
]

var is_orbiting: bool = false
var last_mouse_pos: Vector2 = Vector2.ZERO

func _ready():
	if telemetry_bridge and telemetry_bridge.has_method("setup"):
		telemetry_bridge.setup(traffic_controller)
	_apply_camera_mode(0)

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("toggle_camera"):
		toggle_camera_mode()
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_orbiting = event.pressed
			last_mouse_pos = event.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.position.z = max(12.0, camera.position.z - 2.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.position.z = min(75.0, camera.position.z + 2.5)

	elif event is InputEventMouseMotion and is_orbiting:
		var delta = event.position - last_mouse_pos
		last_mouse_pos = event.position
		camera_pivot.rotation_degrees.y -= delta.x * 0.3
		camera_pivot.rotation_degrees.x = clamp(camera_pivot.rotation_degrees.x - delta.y * 0.3, -88.0, -10.0)

func toggle_camera_mode():
	current_cam_mode = (current_cam_mode + 1) % cam_modes.size()
	_apply_camera_mode(current_cam_mode)

func _apply_camera_mode(index: int):
	var mode = cam_modes[index]
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "position", mode["pos"], 0.7)
	tween.tween_property(camera, "rotation_degrees", mode["rot"], 0.7)
	tween.tween_property(camera, "fov", mode["fov"], 0.7)
