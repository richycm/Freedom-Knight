extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _on_texture_button_pressed_juego() -> void:
	print("CLICK")
	get_tree().change_scene_to_file("res://Scenes/Mapa/1.tscn")
