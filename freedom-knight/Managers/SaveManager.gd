extends Node

const SAVE_PATH = "user://savegame.save"

func guardar_datos(datos: Dictionary) -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("No se pudo abrir archivo de guardado.")
		return
	
	file.store_string(JSON.stringify(datos))
	file.close()

func cargar_datos() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	
	var contenido = file.get_as_text()
	file.close()
	
	var resultado = JSON.parse_string(contenido)
	
	if typeof(resultado) == TYPE_DICTIONARY:
		return resultado
	
	return {}

func existe_partida() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func borrar_partida() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		
func cargar_y_posicionar() -> void:
	var datos = cargar_datos()
	if datos.is_empty():
		return
	
	# 1. Cambiamos la escena
	get_tree().change_scene_to_file(datos["escena"])
	
	# 2. Esperamos a que la escena se "instancie"
	await get_tree().tree_changed 
	
	# 3. Damos un pequeño respiro (un frame) para que los nodos hagan su _ready()
	await get_tree().process_frame
	
	# 4. Intentamos mover al jugador
	var player = get_tree().get_first_node_in_group("Jugador")
	if player:
		if player is CharacterBody2D:
			player.velocity = Vector2.ZERO
			
		player.global_position = Vector2(datos["pos_x"], datos["pos_y"])
		print("Jugador posicionado en: ", player.global_position)
	else:
		print("Error: No se encontró al jugador en el grupo 'player'")
