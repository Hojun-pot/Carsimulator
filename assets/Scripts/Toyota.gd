extends VehicleBody3D
var velocity = Vector3()
var Player = null
var is_first_call = true
var current_patrol_point_index = 0
@onready var sound_effects = $SoundEffects
@onready var head_light = $WholeBody/HeadLight
@onready var navigation = $NavigationAgent3D
@onready var detection_area = $DetectionArea
# Defines the normal engine force.
@export var normal_engine_force = 60
@export var drift_engine_force = 20
@export var patrol_points : Array[Marker3D]
# Drdrifting
var drifting = false
var normal_friction_slip = 15
var drift_friction_slip = 5.5
# Lights
@onready var head_light_left = $Lights/HeadLight_left
@onready var head_light_right = $Lights/HeadLight_right
@onready var tail_light_left = $Lights/TailLight_left
@onready var tail_light_right = $Lights/TailLight_right

# Called when the node enters the scene tree for the first time.
func _ready():
	Player = get_node("/root/Game/Player/").get_child(0)
	navigation.avoidance_enabled = true
	sound_effects.get_node("Song").play()
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta):
	var previous_velocity = Vector3.ZERO
	# We add this line because the navigation region takes time to prepare itself.
	if is_first_call:
		is_first_call = false
		if navigation.is_navigation_finished():
			is_first_call = false
		return
	set_driving_behavior(current_patrol_point_index)
	
	# This line will create a path in the navigation agent.
	navigation.target_position = patrol_points[current_patrol_point_index].global_position
	set_patrol_target()
	move_to_target()
	check_reached_target()

func avoid_player():
	var player_pos = Player.global_transform.origin
	var my_pos = global_transform.origin
	var direction_to_player = (player_pos - my_pos).normalized()
	
	# Randomly choose to avoid left or right.
	var avoid_direction = Vector3.LEFT if randf() > 0.5 else Vector3.RIGHT
	# Determine the final avoidance direction by combining the player's direction and the avoidance direction.
	var final_avoid_direction = (avoid_direction.cross(Vector3.UP).normalized() - direction_to_player).normalized()
	# Apply brakes to slow down.
	var brake_strength = normal_engine_force * 2  # You can set the brake strength here.
	var brake_velocity = -linear_velocity.normalized() * brake_strength
	apply_central_impulse(brake_velocity)
	
	# Determine the escape velocity. (The escape velocity should be lower than the original speed.)
	var escape_velocity = final_avoid_direction * normal_engine_force * 0.23  # Here the speed is halved.
	navigation.set_velocity(escape_velocity)
	look_at(my_pos + escape_velocity, Vector3.UP)
	
	# Action
	head_light.rotation_degrees.x += 82.5
	head_light_left.visible = true
	head_light_right.visible = true
	tail_light_left.visible = true
	tail_light_right.visible = true
	# Schedule to return to the original path after a brief avoidance.
	return_to_path()
	
func _on_detection_area_body_entered(body):
	if body == Player:
		sound_effects.get_node("Horn").play()
		avoid_player()

# The navigation will give us the proper velocity.
func _on_navigation_agent_3d_velocity_computed(safe_velocity):
	if safe_velocity != Vector3.ZERO:
		apply_central_impulse(safe_velocity)
		
func set_patrol_target():
	navigation.target_position = patrol_points[current_patrol_point_index].global_position

func move_to_target():
	var next_pos = navigation.get_next_path_position()
	# Set the Y-axis value to the current vehicle's Y-axis to only consider horizontal movement.
	next_pos.y = global_transform.origin.y
	
	var displacement = next_pos - global_transform.origin
	# Check if the target location and the current location are the same or very close.
	if displacement.length() < 0.01: # 0.01 here is an arbitrary small value, adjust it according to the actual game.
		return  # The target location and the current location are the same or very close, so skip the call to look_at().
	
	var direction_to_move_to = displacement.normalized()
	var desired_velocity = direction_to_move_to * normal_engine_force
	navigation.set_velocity(desired_velocity)
	# Before calling look_at(), check if the 'up' vector and direction vector are parallel.
	if !displacement.cross(Vector3.UP).is_zero_approx():
		look_at(global_transform.origin + displacement, Vector3.UP)

func check_reached_target():
	if navigation.is_navigation_finished():
		current_patrol_point_index += 1
		if current_patrol_point_index >= patrol_points.size():
			current_patrol_point_index = 0
			
func set_driving_behavior(_index):
	# Perform drifting on even indexes and straight driving on odd indexes.
	if current_patrol_point_index % 2 == 0:
		start_drift()
	else:
		end_drift()
					
func return_to_path():
	set_patrol_target()
	
func start_drift():
	if not drifting:
		drifting = true
		if not sound_effects.get_node("DriftSound").playing:
			sound_effects.get_node("DriftSound").play()
		for wheel in ["rear_left", "rear_right"]: # Drift is typically applied to rear wheels.
			var wheel_node = get_node_or_null(wheel)
			if wheel_node:
				wheel_node.wheel_friction_slip = drift_friction_slip
				
func end_drift():
	if drifting:
		drifting = false
		sound_effects.get_node("DriftSound").stop()
		for wheel in ["rear_left", "rear_right"]:
			var wheel_node = get_node_or_null(wheel)
			if wheel_node:
				wheel_node.wheel_friction_slip = normal_friction_slip

func _on_body_entered(_body):
	if abs(self.linear_velocity.x > 0.1 or abs(self.linear_velocity.z) > 0.1):
		sound_effects.get_node("Horn").play()
