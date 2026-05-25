## ============================================================
##  escenario_pruebas.gd  — Freedom Knight  (Modo Arcade)
##  HOST AUTHORITY: toda la lógica de juego corre en el host.
##  CLIENTES: solo renderizan y envían input.
##
##  En SOLITARIO: funciona exactamente igual que antes.
##  El modo solitario no toca ningún path de red.
## ============================================================
extends Node2D

# ─────────────────────────────────────────────────────────────
#  PRELOADS
# ─────────────────────────────────────────────────────────────
var enemigo_scene   : PackedScene = preload("res://Scenes/UI/Personajes/Villanos/CaballeroMalo/caballero_malo.tscn")
var arquero_scene   : PackedScene = preload("res://Scenes/UI/Personajes/Villanos/Arquero/Arquero.tscn")
var lancero_scene   : PackedScene = preload("res://Scenes/UI/Personajes/Villanos/Lancero/lancero.tscn")
var vikingo_scene   : PackedScene = preload("res://Scenes/UI/Personajes/Villanos/Vikingo/vikingo.tscn")
var pocion_scene    : PackedScene = preload("res://Scenes/UI/PocionesHechizos/PocionDeVida.tscn")
var curandero_scene : PackedScene = preload("res://Scenes/UI/Personajes/NPC/monje_npc.tscn")
var gata_scene      : PackedScene = preload("res://Scenes/UI/Personajes/Gata/gata.tscn")
var jefe_scene      : PackedScene = preload("res://Scenes/UI/Personajes/Villanos/jefe/jefe_piso.tscn")
var remoto_scene    : PackedScene = preload("res://Scenes/UI/Personajes/Heroe/caballero_remoto.tscn")

# ─────────────────────────────────────────────────────────────
#  REFERENCIAS
# ─────────────────────────────────────────────────────────────
@onready var player   = $Caballero
@onready var punto_a  = $PuntoA
@onready var punto_b  = $PuntoB

# ─────────────────────────────────────────────────────────────
#  PROGRESIÓN DE MAPAS
# ─────────────────────────────────────────────────────────────
var progresion_mapas: Array = [
	{ "umbral": 50, "escena": preload("res://Scenes/UI/Escenas/mapa_2.tscn"), "nombre": "Tierras Oscuras" },
]
var indice_mapa_actual: int = 0

# ─────────────────────────────────────────────────────────────
#  ESTADO DE DIFICULTAD (solo host lo modifica)
# ─────────────────────────────────────────────────────────────
var enemigos_derrotados : int = 0
var arqueros_derrotados : int = 0
var lanceros_derrotados : int = 0
var vikingos_derrotados : int = 0
var oleada_actual       : int = 1
var tiempo_partida      : float = 0.0

var max_caballeros_simultaneos : int   = 1
var caballeros_vivos           : int   = 0
var max_lanceros_simultaneos   : int   = 0
var lanceros_vivos             : int   = 0
var max_arqueros_simultaneos   : int   = 0
var arqueros_vivos             : int   = 0
var max_vikingos_simultaneos   : int   = 0
var vikingos_vivos             : int   = 0

var fuerza_actual   : int   = 1
var fuerza_maxima   : int   = 8
var vida_actual     : int   = 3
var vida_maxima_enemigo: int = 12
var velocidad_actual: float = 60.0
var velocidad_maxima: float = 130.0

var tiempo_entre_arqueros: float = 15.0
var timer_arqueros : Timer
var timer_pociones : Timer
var jefe_activo    : bool = false

const SYNC_RATE_REMOTE: float = 0.05  # 20Hz para jugadores remotos

# ─────────────────────────────────────────────────────────────
#  UI
# ─────────────────────────────────────────────────────────────
var label_contador_muertes : Label
var max_pociones_en_escena : int   = 3
var intervalo_pocion_min   : float = 12.0
var intervalo_pocion_max   : float = 22.0

# ─────────────────────────────────────────────────────────────
#  LÍMITES DEL MAPA
# ─────────────────────────────────────────────────────────────
var limite_izq : float
var limite_der : float
var limite_arr : float
var limite_aba : float

# Sync timer para remotos
var _remote_sync_timer: float = 0.0

# ─────────────────────────────────────────────────────────────
#  READY
# ─────────────────────────────────────────────────────────────
func _ready() -> void:
	y_sort_enabled = true
	_calcular_limites()

	# Configurar jugador local
	_setup_local_player()

	# Spawnar jugadores remotos si hay red
	if NetworkManager.is_multiplayer_active():
		_setup_multiplayer()
	
	# Crear UI
	_crear_ui_contador()

	# Solo el HOST corre la lógica del juego
	if _should_run_host_logic():
		_iniciar_timer_pociones()
		_iniciar_timer_arqueros()

		if player and player.has_signal("nivel_subido"):
			player.nivel_subido.connect(_spawnear_curandero)

		var timer_gata = Timer.new()
		timer_gata.wait_time = 60.0
		timer_gata.one_shot  = false
		timer_gata.timeout.connect(_spawnear_gata)
		add_child(timer_gata)
		timer_gata.start()

		# Limpiar enemigos previos
		for n in get_tree().get_nodes_in_group("enemigos"):
			n.queue_free()

		await get_tree().create_timer(1.5).timeout
		_mantener_caballeros()
		_spawnear_gatas_iniciales()

func _should_run_host_logic() -> bool:
	# Solitario: siempre corre lógica
	# Multijugador: solo el host
	return not NetworkManager.is_multiplayer_active() or NetworkManager.is_server()

func _setup_local_player() -> void:
	# El caballero mantiene su nombre "Caballero" en la escena.
	# Usamos PlayerRegistry (con peer_id) para identificarlo, NO el nombre del nodo.
	if is_instance_valid(player):
		var local_id = NetworkManager.get_my_peer_id()
		PlayerRegistry.set_local_peer_id(local_id)
		# Solo registrar si no hay ya un nodo válido (evita doble registro si caballero.gd
		# llama a register() en su propio _ready() antes que nosotros).
		var existing = PlayerRegistry.get_player(local_id)
		if not is_instance_valid(existing):
			PlayerRegistry.register(local_id, player)

func _setup_multiplayer() -> void:
	# Conectar señales para manejar nuevos jugadores
	NetworkManager.player_registered.connect(_on_remote_player_registered)
	NetworkManager.player_unregistered.connect(_on_remote_player_left)

	# Spawnar jugadores ya registrados (si el cliente se une después)
	for pid in NetworkManager.players:
		if pid != NetworkManager.get_my_peer_id():
			_spawn_remote_player(pid, NetworkManager.get_gamertag(pid))

	# Configurar MultiplayerSpawner para sincronizar enemigos y proyectiles automáticamente
	var spawner = MultiplayerSpawner.new()
	spawner.name = "MultiplayerSpawner"
	add_child(spawner)
	spawner.spawn_path = get_path() # EscenarioPruebas
	
	# Registramos las escenas que el Host spawnea dinámicamente
	spawner.add_spawnable_scene("res://Scenes/UI/Personajes/Villanos/CaballeroMalo/caballero_malo.tscn")
	spawner.add_spawnable_scene("res://Scenes/UI/Personajes/Villanos/Arquero/Arquero.tscn")
	spawner.add_spawnable_scene("res://Scenes/UI/Personajes/Villanos/Lancero/lancero.tscn")
	spawner.add_spawnable_scene("res://Scenes/UI/Personajes/Villanos/Vikingo/vikingo.tscn")
	spawner.add_spawnable_scene("res://Scenes/UI/Personajes/Villanos/Arquero/Flecha.tscn")
	spawner.add_spawnable_scene("res://Scenes/UI/PocionesHechizos/PocionDeVida.tscn")
	spawner.add_spawnable_scene("res://Scenes/UI/Personajes/NPC/monje_npc.tscn")
	spawner.add_spawnable_scene("res://Scenes/UI/Personajes/Gata/gata.tscn")
	spawner.add_spawnable_scene("res://Scenes/UI/Personajes/Villanos/jefe/jefe_piso.tscn")

# ─────────────────────────────────────────────────────────────
#  PROCESO (sincronización de remotos)
# ─────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if _should_run_host_logic():
		var old_minutes = floor(tiempo_partida / 60.0)
		tiempo_partida += delta
		var new_minutes = floor(tiempo_partida / 60.0)
		if new_minutes > old_minutes:
			_subir_dificultad()

	if not NetworkManager.is_multiplayer_active(): return
	if not NetworkManager.is_server(): return

	_remote_sync_timer += delta
	if _remote_sync_timer >= SYNC_RATE_REMOTE:
		_remote_sync_timer = 0.0
		_sync_remote_players()

## El host envía el estado del local player a los nodos remotos de los demás
func _sync_remote_players() -> void:
	if not is_instance_valid(player) or player.is_dead: return
	_broadcast_local_state()

func _broadcast_local_state() -> void:
	if not is_instance_valid(player): return
	var anim: String = str(player.sprite.animation) if player.sprite else "idle"
	var flip: bool   = player.sprite.flip_h          if player.sprite else false
	var my_id = NetworkManager.get_my_peer_id()
	
	# Sincronizar el Caballero local a través de la llamada RPC centralizada
	rpc_sync_player.rpc(
		my_id,
		player.global_position,
		player.velocity,
		anim, flip,
		player.salud_actual,
		player.nivel
	)

@rpc("authority", "unreliable_ordered")
func rpc_sync_player(peer_id: int, pos: Vector2, vel: Vector2, anim: String, flip: bool, salud: int, nivel_val: int) -> void:
	if NetworkManager.is_server(): return
	var remote_node = PlayerRegistry.get_player(peer_id)
	if remote_node and remote_node.has_method("sync_state"):
		remote_node.sync_state(pos, vel, anim, flip, salud, nivel_val)

# ─────────────────────────────────────────────────────────────
#  REMOTE PLAYER MANAGEMENT
# ─────────────────────────────────────────────────────────────
func _on_remote_player_registered(peer_id: int, gamertag: String) -> void:
	if peer_id == NetworkManager.get_my_peer_id(): return
	_spawn_remote_player(peer_id, gamertag)

func _on_remote_player_left(peer_id: int) -> void:
	var node = PlayerRegistry.get_player(peer_id)
	if is_instance_valid(node):
		node.queue_free()
	
	# Eliminar el gato asociado al peer que salió (evitar gatos huérfanos)
	for m in get_tree().get_nodes_in_group("mascotas"):
		if is_instance_valid(m) and m.get("target_peer_id") == peer_id:
			m.queue_free()
			
	print("[Escenario] Jugador remoto %d salió." % peer_id)

func _spawn_remote_player(peer_id: int, gamertag: String) -> void:
	# Verificar que no exista ya
	if is_instance_valid(PlayerRegistry.get_player(peer_id)):
		return
	var remoto = remoto_scene.instantiate()
	var spawn_pos = _pos_aleatoria() if (limite_der - limite_izq) > 0 else Vector2(200, 200)
	remoto.name = str(peer_id)
	add_child(remoto, true)
	remoto.global_position = spawn_pos
	remoto.setup(peer_id, gamertag, spawn_pos)
	print("[Escenario] Jugador remoto spawneado — ID:%d Gamertag:%s" % [peer_id, gamertag])

# ─────────────────────────────────────────────────────────────
#  LÍMITES DEL MAPA
# ─────────────────────────────────────────────────────────────
func get_current_spawn_shape() -> CollisionShape2D:
	var zonas = get_tree().get_nodes_in_group("zona_spawn_activa")
	if zonas.size() > 0:
		return zonas[0] as CollisionShape2D
	var base_spawn = get_node_or_null("SpawnMobs")
	if base_spawn is CollisionShape2D:
		return base_spawn
	return null

func _obtener_limites_zona(shape_node: CollisionShape2D) -> Dictionary:
	if not shape_node or not shape_node.shape or not (shape_node.shape is RectangleShape2D):
		return {
			"izq": -1000.0,
			"der": 1500.0,
			"arr": -1000.0,
			"aba": 800.0
		}
	var rect = shape_node.shape as RectangleShape2D
	var scale_factor = shape_node.global_scale
	var half_size = (rect.size * scale_factor) / 2.0
	var center = shape_node.global_position
	return {
		"izq": center.x - half_size.x,
		"der": center.x + half_size.x,
		"arr": center.y - half_size.y,
		"aba": center.y + half_size.y
	}

func _actualizar_paredes_fisicas(lims: Dictionary) -> void:
	var limites_node = get_node_or_null("LimitesMapa")
	if not limites_node: return
	
	var wall_izq = limites_node.get_node_or_null("izquierda")
	var wall_der = limites_node.get_node_or_null("derecha")
	var wall_arr = limites_node.get_node_or_null("arriba")
	var wall_aba = limites_node.get_node_or_null("abajo")
	
	var thickness = 200.0
	var height = (lims["aba"] - lims["arr"]) + thickness * 2
	var width = (lims["der"] - lims["izq"]) + thickness * 2
	
	if wall_izq and wall_izq.shape is RectangleShape2D:
		var s = wall_izq.shape as RectangleShape2D
		s.size = Vector2(thickness, height)
		wall_izq.global_position = Vector2(lims["izq"] - thickness / 2.0, (lims["arr"] + lims["aba"]) / 2.0)
		wall_izq.shape = null
		wall_izq.shape = s
		
	if wall_der and wall_der.shape is RectangleShape2D:
		var s = wall_der.shape as RectangleShape2D
		s.size = Vector2(thickness, height)
		wall_der.global_position = Vector2(lims["der"] + thickness / 2.0, (lims["arr"] + lims["aba"]) / 2.0)
		wall_der.shape = null
		wall_der.shape = s
		
	if wall_arr and wall_arr.shape is RectangleShape2D:
		var s = wall_arr.shape as RectangleShape2D
		s.size = Vector2(width, thickness)
		wall_arr.global_position = Vector2((lims["izq"] + lims["der"]) / 2.0, lims["arr"] - thickness / 2.0)
		wall_arr.shape = null
		wall_arr.shape = s
		
	if wall_aba and wall_aba.shape is RectangleShape2D:
		var s = wall_aba.shape as RectangleShape2D
		s.size = Vector2(width, thickness)
		wall_aba.global_position = Vector2((lims["izq"] + lims["der"]) / 2.0, lims["aba"] + thickness / 2.0)
		wall_aba.shape = null
		wall_aba.shape = s

func _calcular_limites() -> void:
	if punto_a and punto_b:
		var margen = 40.0
		limite_izq = punto_a.global_position.x + margen
		limite_der = punto_b.global_position.x - margen
		limite_arr = punto_a.global_position.y + margen
		limite_aba = punto_b.global_position.y - margen

func _pos_aleatoria() -> Vector2:
	# Priorizar la zona de spawn (por ej. ZonaSpawn en el mapa)
	var shape_node = get_current_spawn_shape()
	if shape_node:
		var lims = _obtener_limites_zona(shape_node)
		var m = 40.0
		var izq = lims["izq"] + m
		var der = lims["der"] - m
		var arr = lims["arr"] + m
		var aba = lims["aba"] - m
		if (der - izq) > 0 and (aba - arr) > 0:
			return Vector2(randf_range(izq, der), randf_range(arr, aba))

	# Fallback a los límites del mapa
	if (limite_der - limite_izq) > 0 and (limite_aba - limite_arr) > 0:
		return Vector2(
			randf_range(limite_izq, limite_der),
			randf_range(limite_arr, limite_aba)
		)

	# Fallback final si los límites no están definidos
	return Vector2(200.0, 200.0)

func _pos_aleatoria_lejos_del_player() -> Vector2:
	# En multiplayer: alejarse del jugador más cercano (cualquiera)
	var distancia_minima = 400.0
	for _intento in range(40):
		var pos = _pos_aleatoria()
		var nearest = PlayerRegistry.get_nearest_player_to(pos)
		if not nearest:
			return pos
		if pos.distance_to(nearest.global_position) >= distancia_minima:
			return pos
		distancia_minima -= 5.0
	return _pos_aleatoria()

# ─────────────────────────────────────────────────────────────
#  UI CONTADOR
# ─────────────────────────────────────────────────────────────
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

# ─────────────────────────────────────────────────────────────
#  ENEMIES — Solo host
# ─────────────────────────────────────────────────────────────
func _on_enemigo_murio(_pos) -> void:
	enemigos_derrotados += 1
	caballeros_vivos    -= 1
	_subir_dificultad()
	get_tree().call_group("mascotas", "registrar_muerte_enemigo")
	await get_tree().create_timer(1.0).timeout
	_mantener_caballeros()

func _mantener_caballeros() -> void:
	if jefe_activo: return
	while caballeros_vivos < max_caballeros_simultaneos and PlayerRegistry.any_player_alive():
		_spawnear_un_enemigo()
		await get_tree().create_timer(0.5).timeout

func _spawnear_un_enemigo() -> void:
	if not enemigo_scene or not PlayerRegistry.any_player_alive() or jefe_activo: return
	var nuevo = enemigo_scene.instantiate()
	nuevo.name = "CaballeroMalo_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 1000)
	add_child(nuevo, true)
	nuevo.global_position = _pos_aleatoria_lejos_del_player()
	nuevo.add_to_group("enemigos")
	caballeros_vivos += 1
	_aplicar_stats_enemigo(nuevo)
	if not nuevo.murio.is_connected(_on_enemigo_murio):
		nuevo.murio.connect(_on_enemigo_murio)

# ─────────────────────────────────────────────────────────────
#  VIKINGOS — Solo host (aparecen desde kill 70)
# ─────────────────────────────────────────────────────────────
func _on_vikingo_murio(_pos) -> void:
	vikingos_derrotados += 1
	vikingos_vivos      -= 1
	_subir_dificultad()
	get_tree().call_group("mascotas", "registrar_muerte_enemigo")
	await get_tree().create_timer(1.2).timeout
	_mantener_vikingos()

func _mantener_vikingos() -> void:
	if jefe_activo: return
	while vikingos_vivos < max_vikingos_simultaneos and PlayerRegistry.any_player_alive():
		_spawnear_un_vikingo()
		await get_tree().create_timer(0.8).timeout

func _spawnear_un_vikingo() -> void:
	if not vikingo_scene or not PlayerRegistry.any_player_alive() or jefe_activo: return
	if vikingos_vivos >= max_vikingos_simultaneos: return
	var nuevo = vikingo_scene.instantiate()
	nuevo.name = "Vikingo_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 1000)
	add_child(nuevo, true)
	nuevo.global_position = _pos_aleatoria_lejos_del_player()
	nuevo.add_to_group("enemigos")
	vikingos_vivos += 1
	# El vikingo tiene stats propios elevados; el escenario solo escala daño y vida base
	_aplicar_stats_vikingo(nuevo)
	if not nuevo.murio.is_connected(_on_vikingo_murio):
		nuevo.murio.connect(_on_vikingo_murio)

func _aplicar_stats_vikingo(node: Node) -> void:
	# El vikingo multiplica los stats del escenario × su factor de mejora inherente
	if "poder_ataque" in node: node.poder_ataque = max(2, int(fuerza_actual * 1.5))
	if "vida_maxima"  in node:
		node.vida_maxima  = max(22, int(vida_actual * 2.2))
		if "salud_actual" in node:
			node.salud_actual = node.vida_maxima
	# La velocidad base del vikingo (115) se preserva; solo la escala si supera el mínimo
	if "speed" in node:
		node.speed = max(115.0, velocidad_actual * 1.35)

# ─────────────────────────────────────────────────────────────
#  LANCERS — Solo host
# ─────────────────────────────────────────────────────────────
func _mantener_lanceros() -> void:
	if jefe_activo: return
	while lanceros_vivos < max_lanceros_simultaneos and PlayerRegistry.any_player_alive():
		_spawnear_un_lancero()
		await get_tree().create_timer(0.5).timeout

func _spawnear_un_lancero() -> void:
	if not lancero_scene or not PlayerRegistry.any_player_alive() or jefe_activo: return
	if lanceros_vivos >= max_lanceros_simultaneos: return
	var nuevo = lancero_scene.instantiate()
	nuevo.name = "Lancero_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 1000)
	add_child(nuevo, true)
	nuevo.global_position = _pos_aleatoria_lejos_del_player()
	nuevo.add_to_group("enemigos")
	lanceros_vivos += 1
	_aplicar_stats_enemigo(nuevo, 0.82)
	if not nuevo.murio.is_connected(_on_lancero_murio):
		nuevo.murio.connect(_on_lancero_murio)

func _aplicar_stats_enemigo(node: Node, speed_mult: float = 1.0) -> void:
	if "poder_ataque" in node: node.poder_ataque = fuerza_actual
	if "vida_maxima"  in node:
		node.vida_maxima = vida_actual
		if "salud_actual" in node:
			node.salud_actual = vida_actual
	if "speed" in node:
		node.speed = velocidad_actual * speed_mult

# ─────────────────────────────────────────────────────────────
#  ARCHERS — Solo host
# ─────────────────────────────────────────────────────────────
func _iniciar_timer_arqueros() -> void:
	timer_arqueros = Timer.new()
	timer_arqueros.wait_time  = tiempo_entre_arqueros
	timer_arqueros.one_shot   = false
	timer_arqueros.timeout.connect(_spawnear_arquero)
	add_child(timer_arqueros)
	timer_arqueros.start()

func _spawnear_arquero() -> void:
	if not arquero_scene or not PlayerRegistry.any_player_alive() or jefe_activo: return
	if arqueros_vivos >= max_arqueros_simultaneos: return
	var nuevo = arquero_scene.instantiate()
	nuevo.name = "Arquero_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 1000)
	add_child(nuevo, true)
	nuevo.global_position = _pos_aleatoria_lejos_del_player()
	nuevo.add_to_group("enemigos")
	arqueros_vivos += 1
	_aplicar_stats_enemigo(nuevo)
	if nuevo.has_signal("murio"):
		if not nuevo.murio.is_connected(_on_arquero_murio):
			nuevo.murio.connect(_on_arquero_murio)

func _on_arquero_murio(_pos) -> void:
	arqueros_vivos    -= 1
	arqueros_derrotados += 1
	_subir_dificultad()
	get_tree().call_group("mascotas", "registrar_muerte_enemigo")

func _on_lancero_murio(_pos) -> void:
	lanceros_vivos    -= 1
	lanceros_derrotados += 1
	_subir_dificultad()
	get_tree().call_group("mascotas", "registrar_muerte_enemigo")
	await get_tree().create_timer(1.0).timeout
	_mantener_lanceros.call_deferred()

# ─────────────────────────────────────────────────────────────
#  DIFFICULTY SCALING
# ─────────────────────────────────────────────────────────────
func _subir_dificultad() -> void:
	oleada_actual += 1
	var muertes_totales = enemigos_derrotados + arqueros_derrotados + lanceros_derrotados + vikingos_derrotados

	# Escalar multiplicador por cantidad de jugadores vivos
	var alive_players_count = max(1, PlayerRegistry.get_alive_players().size())
	
	# Si estamos en el Mapa 2 ("Tierras Oscuras"), aplicar multiplicador 1.5 a las estadísticas base
	var map_multiplier = 1.0
	if get_tree().get_nodes_in_group("zona_spawn_activa").size() > 0:
		map_multiplier = 1.5
		
	# Factor de tiempo de supervivencia (cada minuto aumenta estadísticas)
	var tiempo_factor = floor(tiempo_partida / 60.0)

	fuerza_actual    = int((1 + floor(muertes_totales / 12.0) + tiempo_factor) * map_multiplier)
	vida_actual      = int((3 + floor(muertes_totales / 8.0) + (tiempo_factor * 2)) * map_multiplier)
	velocidad_actual = min(velocidad_actual + 0.1, 100.0)

	# ── Caballeros Malos ──────────────────────────────────────────
	# Base normal hasta kill 50; luego se vuelven más raros (cap reducido)
	var cap_base_caballero = (2 + int(floor(muertes_totales / 12.0))) * alive_players_count
	if muertes_totales >= 50:
		# A partir de 50 kills los caballeros bajan al 40% de su cap normal, mínimo 1
		var reduccion = 0.4 - clampf(float(muertes_totales - 50) / 200.0, 0.0, 0.35)
		cap_base_caballero = max(1, int(cap_base_caballero * reduccion))
	max_caballeros_simultaneos = min(5 + alive_players_count, cap_base_caballero)

	# ── Arqueros ─────────────────────────────────────────────────
	if muertes_totales >= 15:
		var cap_arquero = (1 + int(floor((muertes_totales - 15) / 15.0))) * alive_players_count
		if muertes_totales >= 50:
			# A partir de kill 50 se limita el cap de arqueros para aliviar la presión
			cap_arquero = min(cap_arquero, 2 * alive_players_count)
		max_arqueros_simultaneos = min(3 + alive_players_count, cap_arquero)
	else:
		max_arqueros_simultaneos = 0

	# ── Lanceros ─────────────────────────────────────────────────
	if muertes_totales >= 50:
		max_lanceros_simultaneos = min(2 + alive_players_count, (1 + int(floor((muertes_totales - 50) / 15.0))) * alive_players_count)
	else:
		max_lanceros_simultaneos = 0

	# ── Vikingos ─────────────────────────────────────────────────
	# Aparecen a partir de kill 70; escalan gradualmente
	if muertes_totales >= 70:
		max_vikingos_simultaneos = min(3 + alive_players_count, (1 + int(floor((muertes_totales - 70) / 20.0))) * alive_players_count)
	else:
		max_vikingos_simultaneos = 0

	_mantener_caballeros.call_deferred()
	_mantener_lanceros.call_deferred()
	_mantener_vikingos.call_deferred()

	if muertes_totales >= 15 and is_instance_valid(timer_arqueros):
		if muertes_totales >= 50:
			# Después de kill 50 el timer baja más lento: mínimo 6s en vez de 3s
			tiempo_entre_arqueros = max(6.0, 14.0 - floor((muertes_totales - 50) / 8.0))
		else:
			tiempo_entre_arqueros = max(6.0, 10.0 - floor((muertes_totales - 15) / 5.0))
		timer_arqueros.wait_time = tiempo_entre_arqueros

	if is_instance_valid(label_contador_muertes):
		label_contador_muertes.text = "Enemigos Derrotados: %d\nNivel de Dificultad: %d" % [muertes_totales, oleada_actual]
		if NetworkManager.is_multiplayer_active() and NetworkManager.is_server():
			rpc_sync_difficulty.rpc(muertes_totales, oleada_actual)

	if indice_mapa_actual < progresion_mapas.size():
		var siguiente = progresion_mapas[indice_mapa_actual]
		if muertes_totales >= siguiente["umbral"]:
			indice_mapa_actual += 1
			_cambiar_mapa.call_deferred(siguiente)

@rpc("authority", "reliable", "call_remote")
func rpc_sync_difficulty(muertes: int, oleada: int) -> void:
	if is_instance_valid(label_contador_muertes):
		label_contador_muertes.text = "Enemigos Derrotados: %d\nNivel de Dificultad: %d" % [muertes, oleada]

# ─────────────────────────────────────────────────────────────
#  POTIONS — Solo host
# ─────────────────────────────────────────────────────────────
func _iniciar_timer_pociones() -> void:
	timer_pociones = Timer.new()
	timer_pociones.wait_time = randf_range(intervalo_pocion_min, intervalo_pocion_max)
	timer_pociones.one_shot  = true
	timer_pociones.timeout.connect(_spawnear_pocion)
	add_child(timer_pociones)
	timer_pociones.start()

func _spawnear_pocion() -> void:
	timer_pociones.wait_time = randf_range(intervalo_pocion_min, intervalo_pocion_max)
	timer_pociones.start()
	if not PlayerRegistry.any_player_alive(): return
	if not pocion_scene: return
	var pociones_vivas = get_tree().get_nodes_in_group("pociones").size()
	if pociones_vivas >= max_pociones_en_escena: return
	var nueva_pocion = pocion_scene.instantiate()
	nueva_pocion.name = "Pocion_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 1000)
	add_child(nueva_pocion, true)
	nueva_pocion.global_position = _pos_aleatoria()
	nueva_pocion.add_to_group("pociones")
	if "cantidad_curacion" in nueva_pocion:
		nueva_pocion.cantidad_curacion = 2

# ─────────────────────────────────────────────────────────────
#  NPCs — Solo host
# ─────────────────────────────────────────────────────────────
func _spawnear_curandero() -> void:
	_do_spawnear_curandero.call_deferred()

func _do_spawnear_curandero() -> void:
	if not curandero_scene or not PlayerRegistry.any_player_alive(): return
	var curanderos_activos = get_tree().get_nodes_in_group("curanderos")
	if curanderos_activos.size() > 0: return
	var nuevo = curandero_scene.instantiate()
	nuevo.name = "Curandero_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 1000)
	nuevo.add_to_group("curanderos")
	add_child(nuevo, true)
	nuevo.global_position = _pos_aleatoria_lejos_del_player()

func _obtener_gatas_vivas() -> Array:
	var result = []
	for m in get_tree().get_nodes_in_group("mascotas"):
		if is_instance_valid(m) and m.get("state") != 2: # State.DEAD is 2
			result.append(m)
	return result

func _spawnear_gata() -> void:
	if not gata_scene or not PlayerRegistry.any_player_alive(): return
	
	var num_jugadores = NetworkManager.get_player_count()
	var gatas_vivas = _obtener_gatas_vivas().size()
	
	if gatas_vivas < num_jugadores:
		var nueva_gata = gata_scene.instantiate()
		nueva_gata.name = "Gata_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 1000)
		add_child(nueva_gata, true)
		nueva_gata.global_position = _pos_aleatoria_lejos_del_player()
		print("[SPAWN GATA] Spawned cat. Active cats: %d / %d" % [gatas_vivas + 1, num_jugadores])

func _spawnear_gatas_iniciales() -> void:
	if not _should_run_host_logic(): return
	var num_jugadores = NetworkManager.get_player_count()
	for i in range(num_jugadores):
		_spawnear_gata()

# ─────────────────────────────────────────────────────────────
#  BOSS EVENT — Solo host
# ─────────────────────────────────────────────────────────────
func _cambiar_mapa(config: Dictionary) -> void:
	jefe_activo = true
	print("[EVENTO] ¡50 muertes! Preparando al Jefe.")

	# Flash visual
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

	# Limpiar enemigos pequeños
	for n in get_tree().get_nodes_in_group("enemigos"):
		if is_instance_valid(n):
			if n.has_method("desvanecer_y_morir"):
				n.desvanecer_y_morir()
			else:
				n.queue_free()

	caballeros_vivos = 0
	lanceros_vivos   = 0
	arqueros_vivos   = 0
	vikingos_vivos   = 0

	await get_tree().create_timer(3.0).timeout

	if jefe_scene and PlayerRegistry.any_player_alive():
		var jefe = jefe_scene.instantiate()
		jefe.name = "Jefe_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 1000)
		add_child(jefe, true)
		jefe.global_position = _pos_aleatoria_lejos_del_player()
		if jefe.has_signal("murio"):
			jefe.murio.connect(func(_pos_jefe): _cargar_siguiente_escena_real(config))
		print("[JEFE] ¡El Lord Caballero de la Sombra ha aparecido!")

func _cargar_siguiente_escena_real(config: Dictionary) -> void:
	print("[RECOMPENSA] Jefe derrotado. Pasando a: %s" % config["nombre"])
	var tilemap_viejo = get_node_or_null("TileMapLayer")
	if tilemap_viejo:
		tilemap_viejo.queue_free()
	var nuevo_mapa = config["escena"].instantiate()
	nuevo_mapa.name = "TileMapLayer"
	add_child(nuevo_mapa)
	move_child(nuevo_mapa, 0)
	jefe_activo = false
	
	# Sincronizar el cambio de mapa con todos los clientes
	if NetworkManager.is_multiplayer_active() and NetworkManager.is_server():
		rpc_cargar_mapa.rpc(indice_mapa_actual - 1)
	
	# Recalcular límites y paredes físicas del nuevo mapa
	await get_tree().create_timer(0.1).timeout
	_calcular_limites()
	
	# Teletransportar jugadores a la nueva zona de spawn
	_teletransportar_jugadores_a_zona_spawn()
	
	await get_tree().create_timer(1.9).timeout
	if PlayerRegistry.any_player_alive():
		_mantener_caballeros()

func _teletransportar_jugadores_a_zona_spawn() -> void:
	var shape_node = get_current_spawn_shape()
	if not shape_node: return
	var center = shape_node.global_position
	
	# Teletransportar local
	if is_instance_valid(player):
		player.global_position = center
		
	# Teletransportar remotos (sólo host lo hace y sincroniza)
	if NetworkManager.is_multiplayer_active() and NetworkManager.is_server():
		for pid in NetworkManager.players:
			if pid != NetworkManager.get_my_peer_id():
				var r_node = PlayerRegistry.get_player(pid)
				if is_instance_valid(r_node):
					r_node.global_position = center
		rpc_teleport_all_players.rpc(center)

@rpc("authority", "reliable")
func rpc_teleport_all_players(pos: Vector2) -> void:
	var local_player = PlayerRegistry.get_local_player()
	if is_instance_valid(local_player):
		local_player.global_position = pos

@rpc("authority", "reliable")
func rpc_cargar_mapa(map_index: int) -> void:
	if NetworkManager.is_server(): return
	print("[Cliente] Cargando nuevo mapa index: %d" % map_index)
	if map_index < progresion_mapas.size():
		var config = progresion_mapas[map_index]
		var tilemap_viejo = get_node_or_null("TileMapLayer")
		if tilemap_viejo:
			tilemap_viejo.queue_free()
		var nuevo_mapa = config["escena"].instantiate()
		nuevo_mapa.name = "TileMapLayer"
		add_child(nuevo_mapa)
		move_child(nuevo_mapa, 0)
		
		await get_tree().create_timer(0.1).timeout
		_calcular_limites()

# ─────────────────────────────────────────────────────────────
#  LEGACY COMPAT — mantener _hay_jugadores_vivos para NPC scripts
# ─────────────────────────────────────────────────────────────
func _hay_jugadores_vivos() -> bool:
	return PlayerRegistry.any_player_alive()

func _exit_tree() -> void:
	if NetworkManager.is_multiplayer_active():
		NetworkManager.cleanup()
	PlayerRegistry.clear()
