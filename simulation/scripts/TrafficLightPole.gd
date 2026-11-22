extends Node3D

@export var direction: String = "north" # "north", "south", "east", "west"

@onready var light_red: MeshInstance3D = $LightRed
@onready var light_yellow: MeshInstance3D = $LightYellow
@onready var light_green: MeshInstance3D = $LightGreen

var mat_red: StandardMaterial3D
var mat_yellow: StandardMaterial3D
var mat_green: StandardMaterial3D

var current_state: String = "RED"

func _ready():
	_create_materials()
	set_signal("RED")

func _create_materials():
	# Red material
	mat_red = StandardMaterial3D.new()
	mat_red.albedo_color = Color(0.9, 0.1, 0.1)
	mat_red.emission_enabled = true
	mat_red.emission = Color(1.0, 0.1, 0.1)
	mat_red.emission_energy_multiplier = 3.5

	# Yellow material
	mat_yellow = StandardMaterial3D.new()
	mat_yellow.albedo_color = Color(0.95, 0.75, 0.1)
	mat_yellow.emission_enabled = true
	mat_yellow.emission = Color(1.0, 0.8, 0.1)
	mat_yellow.emission_energy_multiplier = 3.5

	# Green material
	mat_green = StandardMaterial3D.new()
	mat_green.albedo_color = Color(0.1, 0.95, 0.35)
	mat_green.emission_enabled = true
	mat_green.emission = Color(0.2, 1.0, 0.4)
	mat_green.emission_energy_multiplier = 3.5

func set_signal(state: String):
	current_state = state.to_upper()
	
	var dim_color = Color(0.1, 0.1, 0.1)

	var m_r = mat_red.duplicate() as StandardMaterial3D
	var m_y = mat_yellow.duplicate() as StandardMaterial3D
	var m_g = mat_green.duplicate() as StandardMaterial3D

	match current_state:
		"RED":
			m_r.emission_energy_multiplier = 4.0
			m_y.emission_energy_multiplier = 0.0
			m_y.albedo_color = dim_color
			m_g.emission_energy_multiplier = 0.0
			m_g.albedo_color = dim_color
		"YELLOW":
			m_r.emission_energy_multiplier = 0.0
			m_r.albedo_color = dim_color
			m_y.emission_energy_multiplier = 4.0
			m_g.emission_energy_multiplier = 0.0
			m_g.albedo_color = dim_color
		"GREEN":
			m_r.emission_energy_multiplier = 0.0
			m_r.albedo_color = dim_color
			m_y.emission_energy_multiplier = 0.0
			m_y.albedo_color = dim_color
			m_g.emission_energy_multiplier = 4.0
		"ALL_RED", "OFF":
			m_r.emission_energy_multiplier = 4.0
			m_y.emission_energy_multiplier = 0.0
			m_y.albedo_color = dim_color
			m_g.emission_energy_multiplier = 0.0
			m_g.albedo_color = dim_color

	if light_red:
		light_red.material_override = m_r
	if light_yellow:
		light_yellow.material_override = m_y
	if light_green:
		light_green.material_override = m_g
