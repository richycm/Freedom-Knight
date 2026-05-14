extends Node

const SAVE_DIR = "user://saves/"
var nombre_jugador: String = ""
var partida_actual: String = ""
var escribiendo_texto: bool = false

func _ready():
	var dir = DirAccess.open("user://")
	if dir == null:
		push_error("No se pudo abrir el directorio user:// para inicializar los guardados.")
		return
	if not dir.dir_exists("saves"):
		dir.make_dir("saves")
	cargar_config()

func guardar_datos_con_nombre(nombre_partida: String, datos: Dictionary) -> void:
	datos["nombre_jugador"] = nombre_jugador
	datos["nombre_partida"] = nombre_partida
	partida_actual = nombre_partida # Rastrear como la partida actual
	datos["fecha"] = Time.get_datetime_string_from_system(false, true)
	
	var modo = "Historia"
	if "pruebas" in String(datos.get("escena", "")).to_lower():
		modo = "Pruebas"
	datos["modo"] = modo
	
	# Reemplazar espacios para el nombre de archivo
	var safe_name = nombre_partida.validate_filename()
	var path = SAVE_DIR + safe_name + ".save"
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("No se pudo abrir archivo de guardado.")
		return
	
	file.store_string(JSON.stringify(datos))
	file.close()

func obtener_lista_partidas() -> Array:
	var partidas = []
	var dir = DirAccess.open(SAVE_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".save"):
				var datos = cargar_datos_ruta(SAVE_DIR + file_name)
				if not datos.is_empty():
					datos["archivo"] = SAVE_DIR + file_name
					partidas.append(datos)
			file_name = dir.get_next()
	
	# Ordenar por fecha descendente (más recientes primero)
	partidas.sort_custom(func(a, b): return a.get("fecha", "") > b.get("fecha", ""))
	return partidas

func cargar_datos_ruta(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	
	var contenido = file.get_as_text()
	file.close()
	
	var resultado = JSON.parse_string(contenido)
	if typeof(resultado) == TYPE_DICTIONARY:
		return resultado
	
	return {}

# Función legacy por si se necesita
func guardar_datos(datos: Dictionary) -> void:
	guardar_datos_con_nombre("AutoSave", datos)

func cargar_datos() -> Dictionary:
	var lista = obtener_lista_partidas()
	if lista.size() > 0:
		var datos = lista[0]
		if datos.has("nombre_jugador"):
			nombre_jugador = datos["nombre_jugador"]
		return datos
	return {}

func existe_partida() -> bool:
	return obtener_lista_partidas().size() > 0

func borrar_partida(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		
func cargar_y_posicionar_datos(datos: Dictionary) -> void:
	if datos.is_empty():
		return
	
	if datos.has("nombre_jugador"):
		nombre_jugador = datos["nombre_jugador"]
	if datos.has("nombre_partida"):
		partida_actual = datos["nombre_partida"]
	
	# 1. Cambiamos la escena
	get_tree().change_scene_to_file(datos["escena"])
	
	# 2. Esperamos a que la escena se "instancie"
	await get_tree().tree_changed 
	
	# 3. Damos un pequeño respiro (un frame) para que los nodos hagan su _ready()
	await get_tree().process_frame
	
	# 4. Intentamos mover al jugador
	var player = get_tree().get_first_node_in_group("Jugador")
	if player == null:
		player = get_tree().get_first_node_in_group("jugador")
	if player:
		if player is CharacterBody2D:
			player.velocity = Vector2.ZERO
			
		player.global_position = Vector2(datos["pos_x"], datos["pos_y"])
		print("Jugador posicionado en: ", player.global_position)
	else:
		print("Error: No se encontró al jugador en los grupos 'Jugador'/'jugador'")

func cargar_y_posicionar() -> void:
	var datos = cargar_datos()
	cargar_y_posicionar_datos(datos)

# --- PERSISTENCIA DE CONFIGURACIÓN ---
func guardar_config() -> void:
	var config = {"nombre_jugador": nombre_jugador}
	var file = FileAccess.open("user://config.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(config))
		file.close()

func cargar_config() -> void:
	if FileAccess.file_exists("user://config.json"):
		var file = FileAccess.open("user://config.json", FileAccess.READ)
		if file:
			var contenido = file.get_as_text()
			file.close()
			var config = JSON.parse_string(contenido)
			if typeof(config) == TYPE_DICTIONARY:
				if config.has("nombre_jugador"):
					nombre_jugador = config["nombre_jugador"]
