extends Node2D

var enemigo_scene: PackedScene = preload("res://Scenes/UI/Personajes/Villanos/CaballeroMalo/caballero_malo.tscn")
var arquero_scene: PackedScene = preload("res://Scenes/UI/Personajes/Villanos/Arquero/Arquero.tscn")
var lancero_scene: PackedScene = preload("res://Scenes/UI/Personajes/Villanos/Lancero/lancero.tscn")
var pocion_scene: PackedScene = preload("res://Scenes/UI/PocionesHechizos/PocionDeVida.tscn")
var curandero_scene: PackedScene = preload("res://Scenes/UI/Personajes/NPC/monje_npc.tscn")
var gata_scene: PackedScene = preload("res://Scenes/UI/Personajes/Gata/gata.tscn")
var spawn_pausado: bool = false

@onready var player = $Caballero
@onready var punto_a = $PuntoA
@onready var punto_b = $PuntoB

var label_contador_muertes: Label
@onready var music_player: AudioStreamPlayer = $MusicPlayer

# ─────────────────────────────────────────
#  PROGRESIÓN DE MAPAS
#  Para agregar un mapa nuevo: copia una línea, ajusta el umbral y la ruta de escena.
#  El orden importa: deben estar de menor a mayor umbral.
# ─────────────────────────────────────────
var progresion_mapas: Array = [
	{ "umbral": 50,  "escena": preload("res://Scenes/UI/Escenas/mapa_2.tscn"), "nombre": "Tierras Oscuras" },
	# { "umbral": 150, "escena": preload("res://Scenes/UI/Escenas/mapa_3.tscn"), "nombre": "El Castillo" },
	# { "umbral": 300, "escena": preload("res://Scenes/UI/Escenas/mapa_4.tscn"), "nombre": "El Abismo" },
]
var indice_mapa_actual: int = 0

# ─────────────────────────────────────────
#  CONFIGURACIÓN DE ENEMIGOS
# ─────────────────────────────────────────
var enemigos_derrotados: int = 0
var arqueros_derrotados: int = 0
var lanceros_derrotados: int = 0
var oleada_actual: int = 1

var max_caballeros_simultaneos: int = 1
var caballeros_vivos: int = 0

var max_lanceros_simultaneos: int = 0
var lanceros_vivos: int = 0

var fuerza_actual: int = 1
var fuerza_maxima: int = 8

var vida_actual: int = 3
var vida_maxima_enemigo: int = 12

var velocidad_actual: float = 60.0
var velocidad_maxima: float = 130.0

# ─────────────────────────────────────────
#  CONFIGURACIÓN DE ARQUEROS
# ─────────────────────────────────────────
var max_arqueros_simultaneos: int = 0
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
	
	# Iniciar música de fondo (OST-1.wav) al estilo del Main Menu
	if music_player:
		if not music_player.finished.is_connected(_on_music_player_finished):
			music_player.finished.connect(_on_music_player_finished)
		music_player.play()
		print("[SONIDO] Música de fondo OST-1 iniciada para el modo Arcade")

	_calcular_limites()
	_iniciar_timer_pociones()
	_iniciar_timer_arqueros()
	
	_crear_ui_contador()
	
	if player and player.has_signal("nivel_subido"):
		player.nivel_subido.connect(_spawnear_curandero)
		
	var timer_gata = Timer.new()
	timer_gata.wait_time = 60.0
	timer_gata.one_shot = true
	timer_gata.timeout.connect(_spawnear_gata)
	add_child(timer_gata)
	timer_gata.start()
	
	# Limpiar enemigos existentes
	for n in get_tree().get_nodes_in_group("enemigos"):
		n.queue_free()
	
	# Primeros enemigos aparecen al inicio
	await get_tree().create_timer(1.5).timeout
	_mantener_caballeros()

func _crear_ui_contador() -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 2 
	add_child(canvas)
	
	label_contador_muertes = Label.new()
	label_contador_muertes.add_theme_font_size_override("font_size", 16)
	label_contador_muertes.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	label_contador_muertes.add_theme_color_override("font_outline_color", Color.BLACK)
	label_contador_muertes.add_theme_constant_override("outline_size", 4)
	label_contador_muertes.text = "Enemigos Derrotados: 0\nNivel de Dificultad: 1"
	
	label_contador_muertes.position = Vector2(20, 150)
	canvas.add_child(label_contador_muertes)

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
	var distancia_minima = 400.0 # Empezar buscando un punto muy lejos
	for _intento in range(40):
		var pos = _pos_aleatoria()
		if pos.distance_to(player.global_position) >= distancia_minima:
			return pos
		# Si no encuentra, reduce un poco la exigencia para el siguiente intento
		distancia_minima -= 5.0
	
	return _pos_aleatoria()

# ─────────────────────────────────────────
#  ENEMIGOS CUERPO A CUERPO
# ─────────────────────────────────────────
func _on_enemigo_murio(_pos) -> void:
	enemigos_derrotados += 1
	caballeros_vivos -= 1
	_subir_dificultad()
	get_tree().call_group("mascotas", "registrar_muerte_enemigo")
	
	await get_tree().create_timer(1.0).timeout
	_mantener_caballeros()

func _mantener_caballeros() -> void:
	while caballeros_vivos < max_caballeros_simultaneos and _hay_jugadores_vivos():
		_spawnear_un_enemigo()
		await get_tree().create_timer(0.5).timeout

func _spawnear_un_enemigo() -> void:
	if not enemigo_scene or not _hay_jugadores_vivos():
		return
	
	var nuevo = enemigo_scene.instantiate()
	add_child(nuevo)
	nuevo.global_position = _pos_aleatoria_lejos_del_player()
	nuevo.add_to_group("enemigos")
	caballeros_vivos += 1
	
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
#  LANCEROS (NUEVO)
# ─────────────────────────────────────────
func _mantener_lanceros() -> void:
	while lanceros_vivos < max_lanceros_simultaneos and _hay_jugadores_vivos():
		_spawnear_un_lancero()
		await get_tree().create_timer(0.5).timeout

func _spawnear_un_lancero() -> void:
	if not lancero_scene or not _hay_jugadores_vivos():
		return
	if lanceros_vivos >= max_lanceros_simultaneos:
		return
	
	var nuevo = lancero_scene.instantiate()
	add_child(nuevo)
	nuevo.global_position = _pos_aleatoria_lejos_del_player()
	nuevo.add_to_group("enemigos")
	lanceros_vivos += 1
	
	if "poder_ataque" in nuevo:
		nuevo.poder_ataque = fuerza_actual
	if "vida_maxima" in nuevo:
		nuevo.vida_maxima = vida_actual
		if "salud_actual" in nuevo:
			nuevo.salud_actual = vida_actual
	if "speed" in nuevo:
		# Lancero es un poco más lento (70.0 vs caballero 85.0)
		nuevo.speed = velocidad_actual * 0.82
	
	if not nuevo.murio.is_connected(_on_lancero_murio):
		nuevo.murio.connect(_on_lancero_murio)

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
	_subir_dificultad()
	get_tree().call_group("mascotas", "registrar_muerte_enemigo")
	print("[ARQUERO] Arquero derrotado. Vivos: ", arqueros_vivos)

func _on_lancero_murio(_pos) -> void:
	lanceros_vivos -= 1
	lanceros_derrotados += 1
	_subir_dificultad()
	get_tree().call_group("mascotas", "registrar_muerte_enemigo")
	print("[LANCERO] Lancero derrotado. Vivos: ", lanceros_vivos)
	
	await get_tree().create_timer(1.0).timeout
	_mantener_lanceros.call_deferred()

# ─────────────────────────────────────────
#  DIFICULTAD
# ─────────────────────────────────────────
func _subir_dificultad() -> void:
	oleada_actual += 1
	var muertes_totales = enemigos_derrotados + arqueros_derrotados + lanceros_derrotados
	
	# Dificultad base
	fuerza_actual = 1 + floor(muertes_totales / 12.0)
	vida_actual = 3 + floor(muertes_totales / 8.0)
	velocidad_actual = min(velocidad_actual + 0.5, 150.0)
	
	# Control de Caballeros (Etapa 1)
	max_caballeros_simultaneos = min(3, 1 + int(floor(muertes_totales / 15.0)))
	
	# Control de Arqueros (Etapa 2 - a partir de 25 muertes)
	if muertes_totales >= 25:
		max_arqueros_simultaneos = min(2, 1 + int(floor((muertes_totales - 25) / 20.0)))
	else:
		max_arqueros_simultaneos = 0
		
	# Control de Lanceros (Etapa 3 - a partir de 50 muertes)
	if muertes_totales >= 50:
		max_lanceros_simultaneos = min(2, 1 + int(floor((muertes_totales - 50) / 15.0)))
	else:
		max_lanceros_simultaneos = 0
	
	_mantener_caballeros.call_deferred()
	_mantener_lanceros.call_deferred()
	
	# Ajustar tiempo del timer de arqueros si estan activos
	if muertes_totales >= 25 and is_instance_valid(timer_arqueros):
		tiempo_entre_arqueros = max(6.0, 15.0 - floor((muertes_totales - 25) / 5.0))
		timer_arqueros.wait_time = tiempo_entre_arqueros
	
	if is_instance_valid(label_contador_muertes):
		label_contador_muertes.text = "Enemigos Derrotados: %d\nNivel de Dificultad: %d" % [muertes_totales, oleada_actual]
		
	# Verificar si hay un mapa siguiente desbloqueado por muertes totales
	if indice_mapa_actual < progresion_mapas.size():
		var siguiente = progresion_mapas[indice_mapa_actual]
		if muertes_totales >= siguiente["umbral"]:
			indice_mapa_actual += 1
			_cambiar_mapa.call_deferred(siguiente)
		
	print("[DIFICULTAD] Muertes:%d | Fuerza:%d | Vida:%d | Vel:%.0f | Arqueros max:%d | Lanceros max:%d" % [
		muertes_totales, fuerza_actual, vida_actual, velocidad_actual, max_arqueros_simultaneos, max_lanceros_simultaneos
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

# ─────────────────────────────────────────
#  NPCs (NUEVO)
# ─────────────────────────────────────────
func _spawnear_curandero() -> void:
	_do_spawnear_curandero.call_deferred()

func _do_spawnear_curandero() -> void:
	if not curandero_scene or not _hay_jugadores_vivos():
		return
		
	# Verificar si ya existe un curandero en la escena
	var curanderos_activos = get_tree().get_nodes_in_group("curanderos")
	if curanderos_activos.size() > 0:
		print("[NPC] Ya hay un curandero activo. No se genera uno nuevo.")
		return
		
	var nuevo_curandero = curandero_scene.instantiate()
	add_child(nuevo_curandero)
	nuevo_curandero.add_to_group("curanderos")
	nuevo_curandero.global_position = _pos_aleatoria_lejos_del_player()
	print("[NPC] Curandero invocado por subir de nivel en ", nuevo_curandero.global_position)

func _spawnear_gata() -> void:
	if not gata_scene or not _hay_jugadores_vivos():
		return
		
	var nueva_gata = gata_scene.instantiate()
	add_child(nueva_gata)
	nueva_gata.global_position = _pos_aleatoria_lejos_del_player()
	print("[NPC] Gata aparecio en el mapa a los 60s en ", nueva_gata.global_position)

func _cambiar_mapa(config: Dictionary) -> void:
	print("[MAPA] %d enemigos derrotados. Cargando: %s" % [config["umbral"], config["nombre"]])
	
	# ── Flash rápido (no bloquea el juego ni resetea stats) ──
	var canvas = CanvasLayer.new()
	canvas.layer = 99
	add_child(canvas)
	var flash = ColorRect.new()
	flash.color = Color(1.0, 1.0, 1.0, 0.0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(flash)
	var tween = create_tween()
	tween.tween_property(flash, "color:a", 0.7, 0.12)
	tween.tween_property(flash, "color:a", 0.0, 0.30)
	tween.tween_callback(canvas.queue_free)
	
	# ── Intercambiar solo el TileMapLayer; el jugador, enemigos y stats se conservan ──
	var tilemap_viejo = get_node_or_null("TileMapLayer")
	if tilemap_viejo:
		tilemap_viejo.queue_free()
	
	var nuevo_mapa = config["escena"].instantiate()
	nuevo_mapa.name = "TileMapLayer"
	add_child(nuevo_mapa)
	move_child(nuevo_mapa, 0) # Al fondo para que el jugador y enemigos queden encima

func _on_music_player_finished() -> void:
	if music_player:
		music_player.play()
