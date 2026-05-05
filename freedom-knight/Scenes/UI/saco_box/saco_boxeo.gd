extends StaticBody2D

func recibir_dano(cantidad: int) -> void:
	print("[Saco] ¡Golpe recibido de ", cantidad, " daño!")
	
	# Usamos un método de búsqueda profunda para encontrar al Caballero
	var caballero = encontrar_al_jugador()
	
	if caballero:
		caballero.mejorar_fuerza(1)
		animar_golpe()
	else:
		print("[Error] Recibí el golpe, pero no encontré a nadie con la función 'mejorar_fuerza'")

# --- FUNCIÓN DE BÚSQUEDA PROFUNDA ---
func encontrar_al_jugador() -> Node:
	# 1. Buscamos en el árbol principal (Root) a todos los hijos y subhijos
	var root = get_tree().root
	return buscar_nodo_con_metodo(root, "mejorar_fuerza")

func buscar_nodo_con_metodo(nodo_actual: Node, nombre_metodo: String) -> Node:
	# Si el nodo que estamos revisando tiene la función, ¡lo encontramos!
	if nodo_actual.has_method(nombre_metodo):
		return nodo_actual
		
	# Si no lo tiene, revisamos a todos sus hijos uno por uno
	for hijo in nodo_actual.get_children():
		var resultado = buscar_nodo_con_metodo(hijo, nombre_metodo)
		if resultado != null:
			return resultado
			
	# Si ni este nodo ni sus hijos lo tienen, devolvemos null
	return null

# --- ANIMACIÓN ---
func animar_golpe():
	var tw = create_tween()
	tw.tween_property($Sprite2D, "modulate", Color.RED, 0.05)
	tw.parallel().tween_property($Sprite2D, "scale", Vector2(1.2, 0.8), 0.05)
	tw.tween_property($Sprite2D, "modulate", Color.WHITE, 0.1)
	tw.parallel().tween_property($Sprite2D, "scale", Vector2(1.0, 1.0), 0.1)
