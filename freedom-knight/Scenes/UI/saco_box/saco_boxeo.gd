extends StaticBody2D

func recibir_dano(cantidad: int, attacker: Node = null) -> void:
	if not NetworkManager.is_multiplayer_active():
		print("[Saco] ¡Golpe recibido de ", cantidad, " daño!")
		var caballero = encontrar_al_jugador()
		if caballero:
			caballero.mejorar_fuerza(1)
		animar_golpe()
	else:
		if NetworkManager.is_server():
			print("[Saco] (Server) ¡Golpe recibido de ", cantidad, " daño! Atacante: ", attacker)
			var caballero = attacker if (attacker and attacker.has_method("mejorar_fuerza")) else encontrar_al_jugador()
			if caballero:
				caballero.mejorar_fuerza(1)
			rpc_animar_golpe.rpc()

# --- FUNCIÓN DE BÚSQUEDA ---
func encontrar_al_jugador() -> Node:
	# Buscamos en el grupo "jugador" al primero que tenga el método mejorar_fuerza
	for nodo in get_tree().get_nodes_in_group("jugador"):
		if nodo.has_method("mejorar_fuerza"):
			return nodo
	return null

# --- RPC ANIMACIÓN ---
@rpc("any_peer", "call_local", "reliable")
func rpc_animar_golpe() -> void:
	animar_golpe()

# --- ANIMACIÓN ---
func animar_golpe():
	var tw = create_tween()
	tw.tween_property($Sprite2D, "modulate", Color.RED, 0.05)
	tw.parallel().tween_property($Sprite2D, "scale", Vector2(1.2, 0.8), 0.05)
	tw.tween_property($Sprite2D, "modulate", Color.WHITE, 0.1)
	tw.parallel().tween_property($Sprite2D, "scale", Vector2(1.0, 1.0), 0.1)
