extends CanvasLayer

# --- CONTROLES DE FREEDOM KNIGHT ---

func _on_up_pressed() -> void:
	$Control/up.modulate = Color(0.7, 0.7, 0.7)

func _on_up_released() -> void:
	$Control/up.modulate = Color(1, 1, 1)

func _on_right_pressed() -> void:
	$Control/right.modulate = Color(0.7, 0.7, 0.7)

func _on_right_released() -> void:
	$Control/right.modulate = Color(1, 1, 1)

func _on_down_pressed() -> void:
	$Control/down.modulate = Color(0.7, 0.7, 0.7)

func _on_down_released() -> void:
	$Control/down.modulate = Color(1, 1, 1)

func _on_left_pressed() -> void:
	$Control/left.modulate = Color(0.7, 0.7, 0.7)

func _on_left_released() -> void:
	$Control/left.modulate = Color(1, 1, 1)




func _on_attack_pressed() -> void:
	$Control/attack.modulate = Color(0.7, 0.7, 0.7)

func _on_attack_released() -> void:
	$Control/attack.modulate = Color(1, 1, 1)
