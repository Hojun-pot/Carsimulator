extends CanvasLayer

# Needle 노드에 대한 참조
@onready var needle = $MarginContainer/Needle
@onready var geartext = $Label
@onready var booster_effect = $MarginContainer/BoosterEffect

var max_speed: float = 220.0
# 바늘 회전을 업데이트하는 함수
func update_needle(speed: float) -> void:
	# 바늘의 회전 범위가 0에서 180도라고 가정
	# 속도계 범위가 0에서 최대 속도(예: 220km/h)까지라고 가정
	var rotation_degrees = speed / max_speed * 220
	needle.rotation_degrees = rotation_degrees
#Gear Display
func update_gear_display(gear: int):
	geartext.text = str(gear)
	
# BoosterEffect active/none_active
func _booster_effect_on(active: bool):
	if booster_effect is GPUParticles2D:
		booster_effect.emitting = active
