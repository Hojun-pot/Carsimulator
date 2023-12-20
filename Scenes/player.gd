extends CharacterBody3D

@onready var camera = $Camera
signal vehicle_selected(car)  # 신호 정의 추가

const SPEED = 3.0
const JUMP_VELOCITY = 4.5

@export var sens_horizontal = 0.5
@export var sens_vertical = 0.5

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
func _input(event):
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * sens_horizontal))
		camera.rotate_x(deg_to_rad(-event.relative.y * sens_vertical))
		
func _physics_process(delta):
	# 오른쪽 조이스틱의 현재 위치를 가져옴
	var right_stick_x = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var right_stick_y = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed("SpaceBar") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	#Handle Camer with JoyStick
	rotate_y(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X) * -sens_horizontal * 0.1)
	camera.rotate_x(Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y) * -sens_vertical * 0.1)
		
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("left", "right", "forward", "back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
