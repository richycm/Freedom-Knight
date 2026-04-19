extends Node2D

# ¡AQUÍ ESTÁ LA MAGIA! Lo cargo yo directamente con tu ruta:
var enemigo_scene: PackedScene = preload("res://Scenes/UI/Personajes/Villanos/caballero_malo.tscn")

@onready var player = $Caballero 
@onready var zona_spawn = $ZonaSpawn 

# --- AJUSTES DE DIFICULTAD ---
var fuerza_maxima_enemigo: int = 5
var cantidad_maxima_enemigos: int = 6
var muertes_para_subir_fuerza: int = 3
var muertes_para_sumar_enemigo: int = 5

# --- VARIABLES DE CONTROL ---
var enemigos_derrotados: int = 0
var fuerza_actual_enemigo: int = 1
var cantidad_a_spawnear: int = 1

func _ready() -> void:
	# 1. Forzar Y-Sort en el escenario para que ordene a los hijos
	y_sort_enabled = true
	
	# 2. Limpiar la escena de enemigos viejos si reiniciaste
	for n in get_tree().get_nodes_in_group("enemigos"):
		n.queue_free()

	# 3. Si pusiste un enemigo a mano en el editor, lo conectamos
	var enemigo_inicial = get_node_or_null("CaballeroMalo")
	if enemigo_inicial:
		if not enemigo_inicial.murio.is_connected(_on_enemigo_murio):
			enemigo_inicial.murio.connect(_on_enemigo_murio)
		enemigo_inicial.add_to_group("enemigos")
	
	if zona_spawn:
		zona_spawn.visible = false

func _on_enemigo_murio(_pos):
	enemigos_derrotados += 1
	print("⚔️ Derrotas totales: ", enemigos_derrotados)
	
	if enemigos_derrotados % muertes_para_subir_fuerza == 0:
		if fuerza_actual_enemigo < fuerza_maxima_enemigo:
			fuerza_actual_enemigo += 1
			print("💪 ¡Enemigos más fuertes! Fuerza: ", fuerza_actual_enemigo)
	
	if enemigos_derrotados % muertes_para_sumar_enemigo == 0:
		if cantidad_a_spawnear < cantidad_maxima_enemigos:
			cantidad_a_spawnear += 1
			print("👥 ¡Aparecen de a ", cantidad_a_spawnear, "!")

	await get_tree().create_timer(2.5).timeout
	_spawnear_oleada()

func _spawnear_oleada():
	# --- AVISOS DE SEGURIDAD ---
	if not enemigo_scene:
		print("❌ ERROR: La ruta del caballero malo está mal escrita en el preload.")
		return
	if not zona_spawn:
		print("❌ ERROR: No se encontró el nodo ZonaSpawn")
		return
		
	if not is_instance_valid(player): return
	if "is_dead" in player and player.is_dead: return 

	var rect = zona_spawn.get_global_rect()

	for i in range(cantidad_a_spawnear):
		var nuevo = enemigo_scene.instantiate()
		var encontrado = false
		var posicion_final = Vector2.ZERO
		
		# Buscar un punto seguro dentro del cuadro azul
		for intento in range(20):
			var px = randf_range(rect.position.x, rect.end.x)
			var py = randf_range(rect.position.y, rect.end.y)
			var candidata = Vector2(px, py)
			
			if candidata.distance_to(player.global_position) > 150:
				posicion_final = candidata
				encontrado = true
				break
		
		if not encontrado:
			posicion_final = rect.get_center()

		nuevo.global_position = posicion_final
		nuevo.poder_ataque = fuerza_actual_enemigo
		nuevo.add_to_group("enemigos") 
		
		if nuevo.has_signal("murio"):
			nuevo.murio.connect(_on_enemigo_murio)
		
		# AÑADIR DIRECTO AL ESCENARIO
		add_child(nuevo)
