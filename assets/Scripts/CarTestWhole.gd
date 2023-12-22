extends VehicleBody3D

# Defines the jump force. Used when the vehicle jumps.
var jump_force = Vector3.UP * 300
# Defines the force used for air control.
var air_control_force = 5000

# Variables related to turbo.
var turbo_force = 100
var turbo_duration = 1.2
var turbo_timer = 0.0

# Defines the normal engine force.
var normal_engine_force = 120
# Flag to track if jump has been triggered.
var jump_triggered = false
# Defines the respawn position of the vehicle.
var respawn_position = Vector3.ZERO

# Defines the friction coefficients used for drifting.
var drifting = false
var normal_friction_slip = 100
var drift_friction_slip = 3.6

# Stores references to sound nodes.
@onready var sound_effects = $SoundEffects
# Defines the sound volume and pitch values for each gear stage.
var gear_volumes = [-10, -5, 0, 5]
var gear_pitches = [0.8, 1.0, 1.2, 1.5]

# Stores references to particle nodes.
@onready var Booster = [$GPUParticles/BoosterLeft, $GPUParticles/BoosterRight]
@onready var Smoke = [$GPUParticles/SmokeLeft, $GPUParticles/SmokeRight]
@onready var DriftSmoke = [$GPUParticles/DriftSmokeLeft, $GPUParticles/DriftSmokeRight]
@onready var tail_neon_left = $GPUParticles/TailNeon_Left
@onready var tail_neon_right = $GPUParticles/TailNeon_Right

# Defines variables related to gears.
var gear = 1
var max_speeds = [60, 80, 120, 140]
var max_speed = max_speeds[0]
var booster_max_speed = 220

# Defines variables related to braking.
var brake_force = 150.0
var braking = false

# Variables related to dodging.
var dodge_strength = 1000.0
var last_dodge_time_left = -1.0  # Last time recorded for left dodge
var last_dodge_time_right = -1.0  # Last time recorded for right dodge
var dodge_interval = 0.25  # Executes dodge if pressed twice within 0.25 seconds

# Lights
@onready var head_light_left = $Lights/HeadLight_Left
@onready var head_light_right = $Lights/HeadLight_Right
@onready var tail_lights_left = $Lights/TailLights_Left
@onready var tail_lights_right = $Lights/TailLights_Right

# Camera
@onready var camera = $Camera
@export var sens_horizontal = 0.5
@export var sens_vertical = 0.5

# Collision
var previous_velocity = Vector3.ZERO

func activate_control():
	# Code to activate vehicle control.
	pass
	
func _ready():
	respawn_position = global_transform.origin
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	turbo_timer = turbo_duration
	# Play the start sound.
	sound_effects.get_node("StartSound").play()
	# Turn on smoke particles.
	toggle_emitting(Smoke, true)
	head_light_left.visible = false
	head_light_right.visible = false
	tail_lights_left.visible = false
	tail_lights_right.visible = false
	tail_neon_left.emitting = false
	tail_neon_right.emitting = false
	
	# Connect the collision shape body entered signal.
	
func _physics_process(delta: float) -> void:
	var on_floor = is_vehicle_on_floor()
	var current_time = Time.get_ticks_msec() / 1000.0
	previous_velocity = linear_velocity
	
	# Handle camera movement with the joystick.
	rotate_y(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X) * -sens_horizontal * 0.1)
	camera.rotate_x(Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y) * -sens_vertical * 0.05)
	
	# Update the vehicle's speed.
	var speed = get_current_speed()
	update_driving_sound(speed)
	
	# Process user inputs.
	process_input(delta, speed, on_floor)
	
	# Process physics effects.
	process_physics(delta, speed, on_floor)  # Pass 'speed' variable as an argument.
	
	# Update the speedometer UI.
	var speed_meter_panel = get_node("CanvasLayer")
	speed_meter_panel.update_needle(speed)
	speed_meter_panel.update_gear_display(gear)
	
	# Detect 'A' key (move left) input.
	if Input.is_action_just_pressed("left"):
		if current_time - last_dodge_time_left < dodge_interval:
			# Execute left dodge maneuver.
			dodge(Vector3.LEFT, current_time)
		last_dodge_time_left = current_time

	# Detect 'D' key (move right) input.
	if Input.is_action_just_pressed("right"):
		if current_time - last_dodge_time_right < dodge_interval:
			# Execute right dodge maneuver.
			dodge(Vector3.RIGHT, current_time)
		last_dodge_time_right = current_time
		
# Function to process user input.
func process_input(_delta, _speed, _on_floor):
	# Handle steering and engine force based on user input.
	steering = Input.get_axis("right", "left") * 0.4
	engine_force = Input.get_axis("back", "forward") * normal_engine_force
	
	# Shift gears up.
	if Input.is_action_just_pressed("GearUp"):
		if gear < 4:
			gear += 1
			max_speed = max_speeds[gear - 1]
		elif gear == 4:
			max_speed = 180

	# Shift gears down.
	if Input.is_action_just_pressed("GearDown"):
		if gear > 1:
			gear -= 1
			max_speed = max_speeds[gear - 1]

	# Activate turbo.
	var booster_effect = get_node("CanvasLayer")
	if gear == 4 and Input.is_action_just_pressed("Ctrl"):
		turbo_timer = 0.0
		sound_effects.get_node("BoosterSound").play()
		toggle_emitting(Booster, true)
		booster_effect._booster_effect_on(true)
		
	# Apply brakes.
	braking = Input.is_action_pressed("Brake")
		
# Function for processing physics effects.
func process_physics(delta, speed, on_floor):
	# Jump logic.
	if Input.is_action_just_pressed("SpaceBar") and on_floor:
		jump_triggered = true
	if jump_triggered and on_floor:
		apply_central_impulse(jump_force)
		jump_triggered = false

	# Brake logic.
	if braking and on_floor:
		engine_force = 0
		apply_central_impulse(-linear_velocity.normalized() * min(brake_force * delta, speed))

	# Air control logic.
	if not on_floor:
		var air_control = Input.get_axis("right", "left") * air_control_force
		apply_impulse(Vector3.ZERO, Vector3(air_control, 0, 0))

	# Speed limit logic.
	if speed > max_speed:
		engine_force = 0

	# Turbo logic.
	var booster_effect = get_node("CanvasLayer")
	if turbo_timer < turbo_duration:
		engine_force += turbo_force
		turbo_timer += delta
	elif turbo_timer >= turbo_duration or gear < 4:
		toggle_emitting(Booster, false)
		sound_effects.get_node("BoosterSound").stop()
		booster_effect._booster_effect_on(false)

	# Respawn logic.
	if Input.is_action_just_pressed("Respawn"):
		global_transform.origin = respawn_position
		global_transform.basis = Basis.IDENTITY
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		
	# Start and end drift handling.
	var currently_drifting = Input.is_action_pressed("Drift") and on_floor and speed > 40.0
	if currently_drifting and not drifting:
		start_drift()
	elif not currently_drifting and drifting:
		end_drift()
	
# Function to check if the vehicle is on the ground.
func is_vehicle_on_floor() -> bool:
	# Check each wheel to see if the vehicle is in contact with the ground.
	for wheel_name in ["rear_left", "rear_right", "front_right", "front_left"]:
		var wheel = get_node_or_null(wheel_name)
		if wheel and not wheel.is_in_contact():
			return false
	return true

# Function to start drifting.
func start_drift():
	# Activate drift mode and effects.
	if not drifting:
		drifting = true
		toggle_emitting(DriftSmoke, true)
		if not sound_effects.get_node("DriftSound").playing:
			sound_effects.get_node("DriftSound").play()
		for wheel in ["rear_left", "rear_right"]: # Drift is typically applied to rear wheels.
			var wheel_node = get_node_or_null(wheel)
			if wheel_node:
				wheel_node.wheel_friction_slip = drift_friction_slip

# Function to end drifting.
func end_drift():
	# Deactivate drift mode and effects.
	if drifting:
		drifting = false
		toggle_emitting(DriftSmoke, false)
		sound_effects.get_node("DriftSound").stop()
		for wheel in ["rear_left", "rear_right"]:
			var wheel_node = get_node_or_null(wheel)
			if wheel_node:
				wheel_node.wheel_friction_slip = normal_friction_slip

# Function to calculate current speed.
func get_current_speed() -> float:
	# Convert m/s to km/h to obtain the current speed.
	return linear_velocity.length() * 3.6

# Function to toggle particle emitting state.
func toggle_emitting(nodes: Array, emitting: bool):
	# Toggle the emitting state for an array of particle nodes.
	for node in nodes:
		if node is GPUParticles3D:
			node.emitting = emitting

# Function to update engine sound.
func update_driving_sound(speed):
	# Adjust the engine sound based on speed and gear.
	if speed > 10:
		if not sound_effects.get_node("DrivingSound").playing:
			sound_effects.get_node("DrivingSound").play()
		sound_effects.get_node("DrivingSound").volume_db = gear_volumes[gear - 1]
		sound_effects.get_node("DrivingSound").pitch_scale = gear_pitches[gear - 1]
	else:
		if sound_effects.get_node("DrivingSound").playing:
			sound_effects.get_node("DrivingSound").stop()

# Function to execute a dodge maneuver.
func dodge(direction: Vector3, current_time: float):
	# Apply an immediate lateral force for dodging.
	var dodge_distance = 2
	if direction == Vector3.LEFT:
		global_transform.origin.x += dodge_distance  # Use '-' operator to move left.
		last_dodge_time_left = current_time
	elif direction == Vector3.RIGHT:
		global_transform.origin.x -= dodge_distance  # Use '+' operator to move right.
		last_dodge_time_right = current_time
	# Activate drift sound and effects.
	toggle_drift_sound_and_effect(true)
	# Call function to stop sound and effects asynchronously.
	stop_drift_sound_and_effect()

# Function to stop drift sound and effect asynchronously.
func stop_drift_sound_and_effect():
	# Create a timer and wait for 0.3 seconds.
	await get_tree().create_timer(0.3).timeout
	# Deactivate drift sound and effects.
	toggle_drift_sound_and_effect(false)

# Function to toggle drift sound and effect.
func toggle_drift_sound_and_effect(active: bool):
	# Toggle the state of drift sound and smoke effects.
	toggle_emitting(DriftSmoke, active)
	if active:
		if not sound_effects.get_node("DriftSound").playing:
			sound_effects.get_node("DriftSound").play()
	else:
		if sound_effects.get_node("DriftSound").playing:
			sound_effects.get_node("DriftSound").stop()

# Gear Display
func _update_gear_display(_gear: int):
	# Update the UI with the current gear.
	var gear_label = get_node("CanvasLayer") # Replace with the actual path to the gear label.
	gear_label.text = str(gear)
	
func _input(event):
	# Handle additional inputs like sound control and lights.
	var song = sound_effects.get_node("RPM")
	var volume = song.volume_db
	if event.is_action_pressed("song"):
		# Toggle the song's play state.
		if song.is_playing():
			song.stop()
		else:
			song.play()
			
	if event.is_action_pressed("volumeup"):
		# Increase the volume, ensuring it doesn't exceed 0 dB.
		volume = min(volume + 1, 0) # Assumes volume_db is in decibels, and 0 is max volume.
		song.volume_db = volume
	if event.is_action_pressed("volumedown"):
		# Decrease the volume, ensuring it doesn't exceed 0 dB.
		volume = min(volume - 1, 0) # Assumes volume_db is in decibels, and 0 is max volume.
		song.volume_db = volume
		
	if event.is_action_pressed("headlights"):
		# Toggle the visibility of the headlights.
		head_light_left.visible = !head_light_left.visible
		head_light_right.visible = !head_light_right.visible
		
	if event.is_action_pressed("taillights"):
		# Toggle the visibility of the taillights and neon lights.
		tail_lights_left.visible = !tail_lights_left.visible
		tail_lights_right.visible = !tail_lights_right.visible
		tail_neon_left.emitting = !tail_neon_left.emitting
		tail_neon_right.emitting = !tail_neon_right.emitting
	if event is InputEventMouseMotion:
		# Rotate the camera based on mouse movement.
		camera.rotate_y(deg_to_rad(-event.relative.x * sens_horizontal))
		camera.rotate_x(deg_to_rad(event.relative.y * sens_vertical))
		
func _on_body_entered(_body):
	# 충돌 전 차량의 속도를 저장합니다. (이전 _physics_process 함수에서 해야 함)
	var impact_velocity = previous_velocity - linear_velocity
	impact_velocity.y = 0 # y축은 무시합니다 (충돌이 수평 방향에 대해서만 감지되길 원할 때).
	# x 또는 z축 방향에 상당한 충돌이 감지된 경우 소리를 재생합니다.
	if impact_velocity.length() > 0.1 and (abs(impact_velocity.x) > 0.1 or abs(impact_velocity.z) > 0.1):
		sound_effects.get_node("Horn").play()
