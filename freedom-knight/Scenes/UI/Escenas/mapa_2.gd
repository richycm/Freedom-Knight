extends TileMapLayer

func _ready() -> void:
	# Diferir el registro para garantizar que el árbol de nodos
	# esté completamente inicializado antes de acceder a global_position
	call_deferred("_register_spawn_zone")

func _register_spawn_zone() -> void:
	var zona = get_node_or_null("ZonaSpawn")
	if zona:
		zona.add_to_group("zona_spawn_activa")
		print("[Mapa2] ZonaSpawn registrada. pos=", zona.global_position)
	else:
		push_warning("[Mapa2] No se encontró ZonaSpawn como hijo directo.")

func _exit_tree() -> void:
	var zona = get_node_or_null("ZonaSpawn")
	if zona and zona.is_in_group("zona_spawn_activa"):
		zona.remove_from_group("zona_spawn_activa")
