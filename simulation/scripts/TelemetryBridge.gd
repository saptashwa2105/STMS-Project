extends Node

signal telemetry_sent(payload: Dictionary, status_code: int)
signal connection_status_changed(is_connected: bool)

@export var backend_url: String = "http://127.0.0.1:8000/api/telemetry"
@export var dispatch_interval: float = 1.0

var http_request: HTTPRequest
var timer: float = 0.0
var traffic_controller: Node = null
var is_server_connected: bool = false
var packets_sent_count: int = 0
var last_response_time: float = 0.0
var is_request_in_flight: bool = false

func _ready():
	http_request = HTTPRequest.new()
	http_request.timeout = 2.5
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

func setup(controller: Node):
	traffic_controller = controller

func _process(delta: float):
	timer += delta
	if timer >= dispatch_interval:
		timer = 0.0
		_send_telemetry()

func _send_telemetry():
	if is_request_in_flight or not traffic_controller:
		return

	if not traffic_controller.has_method("get_telemetry_payload"):
		return

	var payload = traffic_controller.get_telemetry_payload()
	var json_str = JSON.stringify(payload)
	var headers = ["Content-Type: application/json"]

	is_request_in_flight = true
	var err = http_request.request(backend_url, headers, HTTPClient.METHOD_POST, json_str)
	if err != OK:
		print("[TelemetryBridge] HTTP Request error: ", err)
		is_request_in_flight = false
		if is_server_connected:
			is_server_connected = false
			connection_status_changed.emit(false)

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	is_request_in_flight = false
	
	if response_code == 200 or response_code == 201:
		packets_sent_count += 1
		last_response_time = Time.get_unix_time_from_system()
		if not is_server_connected:
			is_server_connected = true
			connection_status_changed.emit(true)
			print("[TelemetryBridge] Connected to STMS Cloud Ingestion backend at ", backend_url)
		
		if traffic_controller and traffic_controller.has_method("get_telemetry_payload"):
			telemetry_sent.emit(traffic_controller.get_telemetry_payload(), response_code)
	else:
		if is_server_connected:
			is_server_connected = false
			connection_status_changed.emit(false)
