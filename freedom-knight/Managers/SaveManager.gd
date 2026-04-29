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
