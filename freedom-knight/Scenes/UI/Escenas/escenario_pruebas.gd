extends Node2D

var enemigo_scene: PackedScene = preload("res://Scenes/UI/Personajes/Villanos/caballero_malo.tscn")

@onready var player = $Caballero 
@onready var punto_a = $PuntoA 
@onready var punto_b = $PuntoB 

# --- AJUSTES ---
var fuerza_maxima_enemigo: int = 5
var cantidad_maxima_enemigos: int = 6
var muertes_para_subir_fuerza: int = 3
var muertes_para_sumar_enemigo: int = 5

var enemigos_derrotados: int = 0
var fuerza_actual_enemigo: int = 1
var cantidad_a_spawnear: int = 1

var limite_izq: float
var limite_der: float
var limite_arr: float
var limite_aba: float

func _ready() -> void:
	y_sort_enabled = true
	
	for n in get_tree().get_nodes_in_group("enemigos"):
		n.queue_free()

	var enemigo_inicial = get_node_or_null("CaballeroMalo")
	if enemigo_inicial:
		if not enemigo_inicial.murio.is_connected(_on_enemigo_murio):
			enemigo_inicial.murio.connect(_on_enemigo_murio)
		enemigo_inicial.add_to_group("enemigos")
	
	if punto_a and punto_b:
		var radio_cuerpo = 40.0 
		
		limite_izq = punto_a.global_position.x + radio_cuerpo
		limite_der = punto_b.global_position.x - radio_cuerpo
		limite_arr = punto_a.global_position.y + radio_cuerpo
		limite_aba = punto_b.global_position.y - radio_cuerpo

func _on_enemigo_murio(_pos):
	enemigos_derrotados += 1
	
	if enemigos_derrotados % muertes_para_subir_fuerza == 0:
		if fuerza_actual_enemigo < fuerza_maxima_enemigo: fuerza_actual_enemigo += 1
	if enemigos_derrotados % muertes_para_sumar_enemigo == 0:
		if cantidad_a_spawnear < cantidad_maxima_enemigos: cantidad_a_spawnear += 1

	await get_tree().create_timer(2.5).timeout
	_spawnear_oleada()

func _spawnear_oleada():
	if not enemigo_scene or not is_instance_valid(player): return
	if "is_dead" in player and player.is_dead: return 
	if not punto_a or not punto_b: return

	for i in range(cantidad_a_spawnear):
		var nuevo = enemigo_scene.instantiate()
		
		# ====================================================
		# 1. PRIMERO LO AÑADIMOS AL MUNDO (¡El secreto para que no se mueva solo!)
		# ====================================================
		add_child(nuevo)
		
		# ====================================================
		# 2. LUEGO LE DAMOS LA POSICIÓN MATEMÁTICA
		# ====================================================
		var px = randf_range(limite_izq, limite_der)
		var py = randf_range(limite_arr, limite_aba)

		nuevo.global_position = Vector2(px, py)
		nuevo.poder_ataque = fuerza_actual_enemigo
		nuevo.add_to_group("enemigos") 
		
		if not nuevo.murio.is_connected(_on_enemigo_murio):
			nuevo.murio.connect(_on_enemigo_murio)
