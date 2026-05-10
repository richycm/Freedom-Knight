extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


func _on_texture_button_pressed_salir() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/UI/MainMenu.tscn")


func _on_texture_button_pressed_guardar() -> void:
	var player = get_tree().get_first_node_in_group("Jugador") 
	
	if player:
		var datos_a_guardar = {
			"escena": get_tree().current_scene.scene_file_path,
			"pos_x": player.global_position.x,
			"pos_y": player.global_position.y
		}
		
		# Llamamos a la función de tu SaveManager
		SaveManager.guardar_datos(datos_a_guardar)
		print("Partida guardada con éxito")
	else:
		push_error("No se encontró el nodo del jugador para guardar.")
