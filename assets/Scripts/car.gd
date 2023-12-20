extends VehicleBody3D
#Jump
var jump_force = Vector3.UP * 300
var air_control_force = 1000  # 공중에서 조작할 때 사용할 힘
#turbo
var turbo_force = 100
var turbo_duration = 1.2
var turbo_timer = 0.0
var normal_engine_force = 200
var jump_triggered = false
var respawn_position = Vector3.ZERO  # 리스폰 위치
#Drifting
var drifting = false
var normal_friction_slip = 20
var drift_friction_slip = 5.5
#Sound 
@onready var sound_effects = $SoundEffects
var gear_volumes = [-10, -5, 0, 5]  # dB로 표현된 볼륨 값
var gear_pitches = [0.8, 1.0, 1.2, 1.5]  # 기본 피치를 기준으로 한 스케일 값
#Particles
@onready var Booster = [$GPUParticles/BoosterLeft, $GPUParticles/BoosterRight]
@onready var Smoke = [$GPUParticles/SmokeLeft, $GPUParticles/SmokeRight]
@onready var DriftSmoke = [$GPUParticles/DriftSmokeLeft, $GPUParticles/DriftSmokeRight]
#Gear
var gear = 1
var max_speeds = [60, 80, 120, 140]
var max_speed = max_speeds[0]
var booster_max_speed = 220
#Breake
var brake_force = 150.0  # 브레이크 감속 힘
var braking = false  # 현재 브레이크가 활성화되어 있는지

func _ready():
	turbo_timer = turbo_duration
	sound_effects.get_node("StartSound").play()
	toggle_emitting(Smoke, true)
	
func _physics_process(delta: float) -> void:
	var on_floor = is_vehicle_on_floor()
	steering = Input.get_axis("right", "left") * 0.4
	engine_force = Input.get_axis("back", "forward") * normal_engine_force
	# 속도 업데이트
	var speed = get_current_speed()
	# SpeedMeterPanel 인스턴스를 찾아서 업데이트 함수 호출
	var speed_meter_panel = get_node("CanvasLayer") # 실제 경로로 교체해주세요.
	speed_meter_panel.update_needle(speed)
	# 시속 10km/h 이상일 때만 드라이빙 사운드 재생
	if speed > 10 and not sound_effects.get_node("DrivingSound").playing:
		sound_effects.get_node("DrivingSound").play()
	elif speed <= 10 and sound_effects.get_node("DrivingSound").playing:
		sound_effects.get_node("DrivingSound").stop()
	# 기어에 따른 엔진 소리 크기와 피치 조절
	if gear >= 1 and gear <= 4 and speed > 10:
		sound_effects.get_node("DrivingSound").volume_db = gear_volumes[gear - 1]
		sound_effects.get_node("DrivingSound").pitch_scale = gear_pitches[gear - 1]
	# 드리프트 시작과 끝 처리
	var currently_drifting = Input.is_action_pressed("Drift") and on_floor and speed > 40.0
	if currently_drifting and not drifting:
		start_drift()
	elif not currently_drifting and drifting:
		end_drift()
	# Handle jumping
	if Input.is_action_just_pressed("SpaceBar") and on_floor:
		jump_triggered = true
	# Handle air control
	if not on_floor:
		var air_control = Input.get_axis("right", "left") * air_control_force
		apply_impulse(Vector3.ZERO, Vector3(air_control, 1, 1))
	# Handle turbo boost
	if gear == 4 and Input.is_action_just_pressed("Ctrl"):
		turbo_timer = 0.0
		# 부스터 사운드 재생
		if not sound_effects.get_node("BoosterSound").playing:
			sound_effects.get_node("BoosterSound").play()
		toggle_emitting(Booster, true)
	elif turbo_timer >= turbo_duration or gear < 4:
		toggle_emitting(Booster, false)
		if sound_effects.get_node("BoosterSound").playing:
			sound_effects.get_node("BoosterSound").stop()
	if turbo_timer < turbo_duration:
		engine_force += turbo_force
		turbo_timer += delta
	else:
		# 부스터가 끝나면 파티클과 사운드를 비활성화
		toggle_emitting(Booster, false)
		if sound_effects.get_node("BoosterSound").playing:
			sound_effects.get_node("BoosterSound").stop()
	# Apply the jump force if triggered
	if jump_triggered and on_floor:
		apply_central_impulse(jump_force)
		jump_triggered = false
	# Handle respawn
	if Input.is_action_just_pressed("Respawn"):
		global_transform.origin = respawn_position
		# Reset the rotation to the default orientation
		global_transform.basis = Basis.IDENTITY
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
	# 기어 상승 로직
	if Input.is_action_just_pressed("GearUp"):
		if gear < 4:
			gear += 1
			max_speed = max_speeds[gear - 1]
		elif gear == 4:
			max_speed = 180  # 4단계에서의 최대 속력 제한
	# 기어 하강 로직
	if Input.is_action_just_pressed("GearDown"):
		if gear > 1:
			gear -= 1
			max_speed = max_speeds[gear - 1]
	# 속력 제한 로직
	# 속도가 최대치를 초과하지 않도록 엔진 힘 조절
	if speed > max_speed:
		engine_force = 0
	else:
		engine_force = Input.get_axis("back", "forward") * normal_engine_force
	# 4단일 때 부스터 활성화 조건 체크
	if gear == 4:
		if turbo_timer < turbo_duration:
			if speed > booster_max_speed:
				engine_force = 0
			else:
				if speed > 180:
					engine_force = 0
				elif speed < 180:
					engine_force = Input.get_axis("back", "forward") * normal_engine_force
	if Input.is_action_pressed("Breake"):
		braking = true
	else:
		braking = false
	# 브레이크 로직
	if braking and on_floor:
		# 엔진 힘을 감소시키고 브레이크 힘을 적용하여 속도를 줄임
		engine_force = 0  # 가속을 중지
		var brake_strength = min(brake_force * delta, speed)  # 브레이크 감속 힘은 현재 속도를 초과
		apply_central_impulse(-linear_velocity.normalized() * brake_strength)
	elif not braking and engine_force == 0 and speed > 0:
		# 브레이크가 활성화되지 않았지만 여전히 속도가 있는 경우 약간의 감속을 적용 (엔진 제동)
		apply_central_impulse(-linear_velocity.normalized() * (brake_force * delta * 0.1))
# Helper function to check if the vehicle is on the floor
func is_vehicle_on_floor() -> bool:
	for wheel_name in ["rear_left", "rear_right", "front_right", "front_left"]:
		var wheel = get_node_or_null(wheel_name)
		if wheel and not wheel.is_in_contact():
			return false
	return true
	
func start_drift():
	if not drifting:
		drifting = true
		toggle_emitting(DriftSmoke, true)
		if not sound_effects.get_node("DriftSound").playing:
			sound_effects.get_node("DriftSound").play()
		for wheel in ["rear_left", "rear_right"]: # 일반적으로 후방 바퀴에 드리프트 적용
			var wheel_node = get_node_or_null(wheel)
			if wheel_node:
				wheel_node.wheel_friction_slip = drift_friction_slip

func end_drift():
	if drifting:
		drifting = false
		toggle_emitting(DriftSmoke, false)
		sound_effects.get_node("DriftSound").stop()
		for wheel in ["rear_left", "rear_right"]:
			var wheel_node = get_node_or_null(wheel)
			if wheel_node:
				wheel_node.wheel_friction_slip = normal_friction_slip
				

func get_current_speed() -> float:
	# linear_velocity의 길이를 계산하여 속도(m/s)를 얻습니다.
	var speed_m_per_s = linear_velocity.length()
	# m/s를 km/h로 변환합니다.
	var speed_km_per_h = speed_m_per_s * 3.6
	return speed_km_per_h

#Toggle Emitting Function
func toggle_emitting(nodes: Array, emitting: bool):
	for node in nodes:
		if node is GPUParticles3D:
			node.emitting = emitting

#Gear Display
func _update_gear_display(gear: int):
	var gear_label = get_node("경로/스피드미터패널/기어표시라벨") # 실제 경로로 수정
	gear_label.text = str(gear)

