extends Node2D

var enemigo_scene: PackedScene = preload("res://Scenes/UI/Personajes/Villanos/CaballeroMalo/caballero_malo.tscn")
var arquero_scene: PackedScene = preload("res://Scenes/UI/Personajes/Villanos/Arquero/Arquero.tscn")
var pocion_scene: PackedScene = preload("res://Scenes/UI/PocionesHechizos/PocionDeVida.tscn")

@onready var player = $Caballero
@onready var punto_a = $PuntoA
@onready var punto_b = $PuntoB

# ─────────────────────────────────────────
#  CONFIGURACIÓN DE ENEMIGOS
# ─────────────────────────────────────────
var enemigos_derrotados: int = 0
var arqueros_derrotados: int = 0
var oleada_actual: int = 1

var fuerza_actual: int = 1
var fuerza_maxima: int = 8

var vida_actual: int = 3
var vida_maxima_enemigo: int = 12

var velocidad_actual: float = 60.0
var velocidad_maxima: float = 130.0

# ─────────────────────────────────────────
#  CONFIGURACIÓN DE ARQUEROS
# ─────────────────────────────────────────
var max_arqueros_simultaneos: int = 2
var arqueros_vivos: int = 0
var tiempo_entre_arqueros: float = 15.0
var timer_arqueros: Timer

# ─────────────────────────────────────────
#  CONFIGURACIÓN DE POCIONES
# ─────────────────────────────────────────
var max_pociones_en_escena: int = 3
var intervalo_pocion_min: float = 12.0
var intervalo_pocion_max: float = 22.0
var timer_pociones: Timer

# ─────────────────────────────────────────
#  LÍMITES DEL MAPA
# ─────────────────────────────────────────
var limite_izq: float
var limite_der: float
var limite_arr: float
var limite_aba: float

# ═════════════════════════════════════════
func _ready() -> void:
	y_sort_enabled = true
	_calcular_limites()
	_iniciar_timer_pociones()
	_iniciar_timer_arqueros()
	
	# Limpiar enemigos existentes
	for n in get_tree().get_nodes_in_group("enemigos"):
		n.queue_free()
	
	# Primer enemigo aparece al inicio
	await get_tree().create_timer(1.5).timeout
	_spawnear_un_enemigo()

# Eliminadas funciones de red obsoletas

# ─────────────────────────────────────────
#  LÍMITES
# ─────────────────────────────────────────
func _calcular_limites() -> void:
	if punto_a and punto_b:
		var margen = 40.0
		limite_izq = punto_a.global_position.x + margen
		limite_der = punto_b.global_position.x - margen
		limite_arr = punto_a.global_position.y + margen
		limite_aba = punto_b.global_position.y - margen

func _pos_aleatoria() -> Vector2:
	return Vector2(
		randf_range(limite_izq, limite_der),
		randf_range(limite_arr, limite_aba)
	)

func _pos_aleatoria_lejos_del_player() -> Vector2:
	var distancia_minima = 150.0
	for _intento in range(10):
		var pos = _pos_aleatoria()
		
	return _pos_aleatoria()
	return _pos_aleatoria()

# ─────────────────────────────────────────
#  ENEMIGOS CUERPO A CUERPO
# ─────────────────────────────────────────
func _on_enemigo_murio(_pos) -> void:
	enemigos_derrotados += 1
	_subir_dificultad()
	
	await get_tree().create_timer(2.0).timeout
	_spawnear_un_enemigo()

func _spawnear_un_enemigo() -> void:
	if not enemigo_scene or not _hay_jugadores_vivos():
		return
	
	var nuevo = enemigo_scene.instantiate()
	add_child(nuevo)
	nuevo.global_position = _pos_aleatoria_lejos_del_player()
	nuevo.add_to_group("enemigos")
	
	if "poder_ataque" in nuevo:
		nuevo.poder_ataque = fuerza_actual
	if "vida_maxima" in nuevo:
		nuevo.vida_maxima = vida_actual
		if "salud_actual" in nuevo:
			nuevo.salud_actual = vida_actual
	if "speed" in nuevo:
		nuevo.speed = velocidad_actual
	
	if not nuevo.murio.is_connected(_on_enemigo_murio):
		nuevo.murio.connect(_on_enemigo_murio)

# ─────────────────────────────────────────
#  ARQUEROS (NUEVO)
# ─────────────────────────────────────────
func _iniciar_timer_arqueros() -> void:
	timer_arqueros = Timer.new()
	timer_arqueros.wait_time = tiempo_entre_arqueros
	timer_arqueros.one_shot = false
	timer_arqueros.timeout.connect(_spawnear_arquero)
	add_child(timer_arqueros)
	timer_arqueros.start()

func _spawnear_arquero() -> void:
	if not arquero_scene or not _hay_jugadores_vivos():
		return
	if arqueros_vivos >= max_arqueros_simultaneos:
		return
	
	var nuevo_arquero = arquero_scene.instantiate()
	add_child(nuevo_arquero)
	nuevo_arquero.global_position = _pos_aleatoria_lejos_del_player()
	nuevo_arquero.add_to_group("enemigos")
	arqueros_vivos += 1
	
	# Configurar estadísticas del arquero
	if "poder_ataque" in nuevo_arquero:
		nuevo_arquero.poder_ataque = fuerza_actual
	if "vida_maxima" in nuevo_arquero:
		nuevo_arquero.vida_maxima = vida_actual
		if "salud_actual" in nuevo_arquero:
			nuevo_arquero.salud_actual = vida_actual
	
	# Conectar señal de muerte
	if nuevo_arquero.has_signal("murio"):
		if not nuevo_arquero.murio.is_connected(_on_arquero_murio):
			nuevo_arquero.murio.connect(_on_arquero_murio)
	else:
		# Si no tiene señal, usamos un grupo y lo verificamos periódicamente
		print("[ARQUERO] No tiene señal 'murio', usando método alternativo")

func _on_arquero_murio(_pos) -> void:
	arqueros_vivos -= 1
	arqueros_derrotados += 1
	print("[ARQUERO] Arquero derrotado. Vivos: ", arqueros_vivos)

# ─────────────────────────────────────────
#  DIFICULTAD
# ─────────────────────────────────────────
func _subir_dificultad() -> void:
	oleada_actual += 1
	
	# Fuerza: +1 cada 3 muertes totales
	var muertes_totales = enemigos_derrotados + arqueros_derrotados
	if muertes_totales % 3 == 0 and muertes_totales > 0:
		fuerza_actual = min(fuerza_actual + 1, fuerza_maxima)
	
	# Vida: +1 cada 4 muertes
	if muertes_totales % 4 == 0 and muertes_totales > 0:
		vida_actual = min(vida_actual + 1, vida_maxima_enemigo)
	
	# Velocidad: sube suavemente con cada muerte
	velocidad_actual = min(velocidad_actual + 1.5, velocidad_maxima)
	
	# Más arqueros a partir de ciertas muertes
	if muertes_totales >= 5:
		max_arqueros_simultaneos = 3
	if muertes_totales >= 10:
		max_arqueros_simultaneos = 4
		tiempo_entre_arqueros = 12.0
	
	print("[DIFICULTAD] Muertes:%d | Fuerza:%d | Vida:%d | Vel:%.0f | Arqueros max:%d" % [
		muertes_totales, fuerza_actual, vida_actual, velocidad_actual, max_arqueros_simultaneos
	])

# ─────────────────────────────────────────
#  POCIONES
# ─────────────────────────────────────────
func _iniciar_timer_pociones() -> void:
	timer_pociones = Timer.new()
	timer_pociones.wait_time = randf_range(intervalo_pocion_min, intervalo_pocion_max)
	timer_pociones.one_shot = true
	timer_pociones.timeout.connect(_spawnear_pocion)
	add_child(timer_pociones)
	timer_pociones.start()

func _spawnear_pocion() -> void:
	timer_pociones.wait_time = randf_range(intervalo_pocion_min, intervalo_pocion_max)
	timer_pociones.start()
	
	if not _hay_jugadores_vivos():
		return
	if not pocion_scene:
		return
	
	var pociones_vivas = get_tree().get_nodes_in_group("pociones").size()
	if pociones_vivas >= max_pociones_en_escena:
		return
	
	var nueva_pocion = pocion_scene.instantiate()
	add_child(nueva_pocion)
	nueva_pocion.global_position = _pos_aleatoria()
	nueva_pocion.add_to_group("pociones")
	
	if "cantidad_curacion" in nueva_pocion:
		nueva_pocion.cantidad_curacion = 2

func _hay_jugadores_vivos() -> bool:
	if is_instance_valid(player) and not player.is_dead:
		return true
	return false
