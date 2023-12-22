extends Area3D

signal player_detected(player)

func _on_body_entered(body):
	if body.is_in_group("Player"):
		emit_signal("player_detected", body)
