extends Node2D

@export var enemigo_scene: PackedScene 
@onready var player = $Caballero 
@onready var zona_spawn = $ZonaSpawn 

# --- AJUSTES DE DIFICULTAD (Cámbialos a tu gusto) ---
var fuerza_maxima_enemigo: int = 5    # El daño no subirá de aquí
var cantidad_maxima_enemigos: int = 6  # No aparecerán más de 6 a la vez
var muertes_para_subir_fuerza: int = 3 # Cada cuántas muertes sube el daño
var muertes_para_sumar_enemigo: int = 5 # Cada cuántas muertes sale uno extra

# --- VARIABLES DE CONTROL ---
var enemigos_derrotados: int = 0
var fuerza_actual_enemigo: int = 1
var cantidad_a_spawnear: int = 1

func _ready() -> void:
	var enemigo_inicial = get_node_or_null("CaballeroMalo")
	if enemigo_inicial:
		enemigo_inicial.murio.connect(_on_enemigo_murio)
	
	if zona_spawn:
		zona_spawn.visible = false

func _on_enemigo_murio(_pos):
	enemigos_derrotados += 1
	print("⚔️ Derrotas totales: ", enemigos_derrotados)
	
	# --- LÓGICA DE DIFICULTAD EQUILIBRADA ---
	
	# 1. Subir la FUERZA de forma lenta
	if enemigos_derrotados % muertes_para_subir_fuerza == 0:
		if fuerza_actual_enemigo < fuerza_maxima_enemigo:
			fuerza_actual_enemigo += 1
			print("💪 ¡Los enemigos ahora son más fuertes! Fuerza: ", fuerza_actual_enemigo)

	# 2. Subir la CANTIDAD de forma aún más lenta
	if enemigos_derrotados % muertes_para_sumar_enemigo == 0:
		if cantidad_a_spawnear < cantidad_maxima_enemigos:
			cantidad_a_spawnear += 1
			print("👥 ¡Cuidado! Ahora aparecen de a ", cantidad_a_spawnear)

	# 3. Pausa entre oleadas (un poco más larga para respirar)
	await get_tree().create_timer(2.5).timeout
	_spawnear_oleada()

func _spawnear_oleada():
	if not enemigo_scene or not zona_spawn: return
	if not is_instance_valid(player) or player.is_dead: return # No spawn si moriste

	var rect = zona_spawn.get_global_rect()

	for i in range(cantidad_a_spawnear):
		var nuevo = enemigo_scene.instantiate()
		
		# Spawn aleatorio dentro del ColorRect
		var px = randf_range(rect.position.x, rect.end.x)
		var py = randf_range(rect.position.y, rect.end.y)
		
		# Evitar que aparezcan justo encima del jugador (un poco de espacio)
		var pos_final = Vector2(px, py)
		if pos_final.distance_to(player.global_position) < 100:
			pos_final += Vector2(150, 150) # Desplazarlo si está muy cerca

		nuevo.global_position = pos_final
		nuevo.poder_ataque = fuerza_actual_enemigo
		nuevo.murio.connect(_on_enemigo_murio)
		
		add_child(nuevo)
