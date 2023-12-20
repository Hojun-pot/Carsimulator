var mouseDelta = Vector2()

# Camera variables

var lookSensitivity = 0.1
var minLookAngle = -130.0
var maxLookAngle = 25.0
var followCameraAngle = 20
var camera_onoff = true
var cameraTimerSecond = 2
var cameraOrbit
var followCameraY = 0

# Car variables

# These become just placeholders if presets are in use
var MAX_ENGINE_FORCE = 100.0
var MAX_BRAKE = 5.0
var MAX_STEERING = 0.5
var STEERING_SPEED = 7

################################################
################## Car Script ##################
################################################

func _physics_process(delta):
	# This variable turns the camera when the car turns
	followCameraY = 0
	# If user wants to control the car
	var steer_val = 0.0
	var throttle_val = 0.0
	var brake_val = 0.0

	if Input.is_action_pressed("ui_up"):
		throttle_val = 1.0
	if Input.is_action_pressed("ui_down"):
		throttle_val = -0.5
	if Input.is_action_pressed("ui_select"):
		brake_val = 1.0
	if Input.is_action_pressed("ui_left"):
		steer_val = 1.0
	if Input.is_action_pressed("ui_right"):
		steer_val = -1.0
	engine_force = throttle_val * MAX_ENGINE_FORCE
	brake = brake_val * MAX_BRAKE
	
	# Using lerp for a smooth steering
	steering = lerp(steering, steer_val * MAX_STEERING, STEERING_SPEED * delta)

################################################
################# Camera Script ################
################################################

func _input(event):
	if event is InputEventMouseMotion:
		mouseDelta = event.relative

func _process(delta):
	# If user wants to use the car camera
	if(!use_camera || !use_controls):
		return
	
	var rot = Vector3(mouseDelta.y, mouseDelta.x, 0) * lookSensitivity
	
	# Checking if the Settingspanel is active or not
	if(camera_onoff):
		# If the mouse is moving then camera turns around the car
		if(mouseDelta != Vector2()):
			cameraOrbit.rotation_degrees.x = clamp(cameraOrbit.rotation_degrees.x, minLookAngle, maxLookAngle)
			cameraOrbit.rotation_degrees.x -= rot.x
			cameraOrbit.rotation_degrees.y -= rot.y
			
			# ..and the timer gets activated so that the
			# camera doesn't follow the car for the duration of the timer
			cameraTimer = cameraTimerSecond
		
		if(cameraTimer > 0):
			cameraTimer -= delta
		else:
			
			# If the timer is up / mouse did not move for the duration of the timer
			# The camera smoothly moves to the follow position
			cameraOrbit.rotation_degrees.x = lerp(cameraOrbit.rotation_degrees.x, followCameraAngle, delta * 10)
			cameraOrbit.rotation_degrees.y = lerp(cameraOrbit.rotation_degrees.y, followCameraY, delta * 10)
	
	# Recorded mouse positions are being deleted
	# so that we can capture the next movement
	mouseDelta = Vector2()
