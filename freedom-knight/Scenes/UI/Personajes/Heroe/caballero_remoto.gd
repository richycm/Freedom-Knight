## ============================================================
##  caballero_remoto.gd  — Freedom Knight
##  Representación visual de un jugador REMOTO.
##  NO tiene controles locales. Su posición es recibida
##  via RPC desde el host y se interpola suavemente.
##  Renderiza nombre, nivel, animaciones y efectos de daño.
## ============================================================
extends CharacterBody2D

# ─────────────────────────────────────────────────────────────
#  REFERENCIAS
# ─────────────────────────────────────────────────────────────
@onready var sprite: AnimatedSprite2D = $AnimatedSprite

# ─────────────────────────────────────────────────────────────
#  IDENTIDAD
# ─────────────────────────────────────────────────────────────
var peer_id    : int    = 0
var gamertag   : String = "???"
var is_dead    : bool   = false

# ─────────────────────────────────────────────────────────────
#  ESTADO SINCRONIZADO (recibido del host)
# ─────────────────────────────────────────────────────────────
var net_position   : Vector2 = Vector2.ZERO
var net_velocity   : Vector2 = Vector2.ZERO
var net_anim       : String  = "idle"
var net_flip       : bool    = false
var salud_actual   : int     = 10
var vida_maxima    : int     = 10
var nivel          : int     = 1
var poder_ataque   : int     = 2

# Interpolation speed (higher = snappier, lower = smoother)
const INTERP_SPEED : float = 12.0

# ─────────────────────────────────────────────────────────────
#  UI
# ─────────────────────────────────────────────────────────────
var label_nombre : Label = null
var label_nivel  : Label = null

# Player color palette (index = player slot)
const PLAYER_COLORS := [
	Color(0.35, 0.75, 1.00),   # Azul hielo  (slot 0)
	Color(0.45, 1.00, 0.60),   # Verde neón  (slot 1)
	Color(1.00, 0.65, 0.25),   # Naranja     (slot 2)
	Color(1.00, 0.40, 0.80),   # Rosa        (slot 3)
]

var _is_first_sync: bool = true

# ─────────────────────────────────────────────────────────────
#  LIFECYCLE
# ─────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("jugador")
	# Física: solo se mueve por interpolación, no por move_and_slide
	set_physics_process(false)
	
	# Ocultamos el nodo hasta que reciba su primera posición real de la red
	visible = false

	# Collision: misma capa que el caballero local para que los
	# enemigos puedan targetear a ambos jugadores
	set_collision_layer_value(2, true)
	set_collision_mask_value(1, true)

	# Crear labels UI
	_create_labels()

	# Aura de color para distinguir del jugador local
	_apply_player_color()

func _process(delta: float) -> void:
	# Interpolación de posición siempre activa (incluso muerto, para mantener el fantasma en lugar correcto)
	global_position = global_position.lerp(net_position, INTERP_SPEED * delta)

	if is_dead:
		# Muerto: solo mantener posición, no actualizar animación
		return

	# Animation sync
	if sprite.animation != net_anim:
		sprite.play(net_anim)
	sprite.flip_h = net_flip

func _exit_tree() -> void:
	PlayerRegistry.unregister(peer_id)

# ─────────────────────────────────────────────────────────────
#  SETUP
# ─────────────────────────────────────────────────────────────
func setup(p_peer_id: int, p_gamertag: String, p_pos: Vector2) -> void:
	peer_id  = p_peer_id
	gamertag = p_gamertag
	global_position = p_pos
	net_position    = p_pos
	name = str(p_peer_id)   # Nodo se llama por peer_id para lookups

	if is_instance_valid(label_nombre):
		label_nombre.text = gamertag

	PlayerRegistry.register(peer_id, self)

func _create_labels() -> void:
	label_nombre = Label.new()
	label_nombre.text = gamertag
	label_nombre.add_theme_font_size_override("font_size", 12)
	label_nombre.add_theme_color_override("font_outline_color", Color.BLACK)
	label_nombre.add_theme_constant_override("outline_size", 4)
	label_nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_nombre.position = Vector2(-50, -48)
	label_nombre.custom_minimum_size = Vector2(100, 20)
	label_nombre.z_index = 10
	add_child(label_nombre)

	label_nivel = Label.new()
	label_nivel.add_theme_font_size_override("font_size", 10)
	label_nivel.add_theme_color_override("font_color", Color.CYAN)
	label_nivel.add_theme_color_override("font_outline_color", Color.BLACK)
	label_nivel.add_theme_constant_override("outline_size", 3)
	label_nivel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_nivel.position = Vector2(-50, -65)
	label_nivel.custom_minimum_size = Vector2(100, 20)
	label_nivel.z_index = 10
	add_child(label_nivel)

func _apply_player_color() -> void:
	# Asignar color según slot (peer_id hash modulo colores)
	var slot = (peer_id % PLAYER_COLORS.size())
	var col  = PLAYER_COLORS[slot]
	if is_instance_valid(label_nombre):
		label_nombre.add_theme_color_override("font_color", col)

# ─────────────────────────────────────────────────────────────
#  SINCRONIZACIÓN DE ESTADO (llamado desde escenario_pruebas)
# ─────────────────────────────────────────────────────────────

## Actualiza posición y animación del jugador remoto (host → todos)
@rpc("authority", "unreliable_ordered", "call_local")
func sync_state(pos: Vector2, vel: Vector2, anim: String, flip: bool, salud: int, nivel_val: int) -> void:
	if _is_first_sync:
		_is_first_sync = false
		global_position = pos
		visible = true
		
	net_position  = pos
	net_velocity  = vel
	net_anim      = anim
	net_flip      = flip
	salud_actual  = salud
	nivel         = nivel_val
	poder_ataque  = 2 + floor(nivel / 2.0) # Calculate approx attack power on host
	# Update guarding status based on animation
	is_guarding = (anim == "guard")
	_update_level_label()

## El host notifica daño a este cliente
@rpc("authority", "reliable")
func notify_damage() -> void:
	_efecto_dano()

## El host notifica muerte
@rpc("authority", "reliable")
func notify_death(enemy_kills: int) -> void:
	is_dead = true
	net_anim = "death"
	if sprite and sprite.sprite_frames:
		# Forzar que la animación de muerte no loopee
		sprite.sprite_frames.set_animation_loop("death", false)
		sprite.play("death")
	_show_death_overlay(enemy_kills)

## El host notifica curación
@rpc("authority", "reliable")
func notify_heal() -> void:
	_efecto_curacion()

# ─────────────────────────────────────────────────────────────
#  EFECTOS VISUALES
# ─────────────────────────────────────────────────────────────
func _efecto_dano() -> void:
	if not is_instance_valid(sprite): return
	sprite.modulate = Color.RED
	var t = create_tween()
	t.tween_property(sprite, "modulate", Color.WHITE, 0.2)

func _efecto_curacion() -> void:
	if not is_instance_valid(sprite): return
	sprite.modulate = Color.GREEN
	var t = create_tween()
	t.tween_property(sprite, "modulate", Color.WHITE, 0.3)

func _update_level_label() -> void:
	if is_instance_valid(label_nivel):
		label_nivel.text = "Lvl: %d" % nivel

func _show_death_overlay(_kills: int) -> void:
	# Mostrar etiqueta "CAÍDO" sobre el personaje remoto
	var lbl = Label.new()
	lbl.text = "💀 CAÍDO"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color.RED)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.position = Vector2(-50, -85)
	lbl.custom_minimum_size = Vector2(100, 20)
	lbl.z_index = 15
	add_child(lbl)
	_desvanecerse_y_morir()

func _desvanecerse_y_morir() -> void:
	if is_instance_valid(self):
		var t = create_tween()
		t.tween_property(self, "modulate:a", 0.4, 1.0)
		# No hacemos queue_free, se queda como fantasma
		set_deferred("collision_layer", 0)
		set_deferred("collision_mask", 0)

# ─────────────────────────────────────────────────────────────
#  DAÑO Y CURACIÓN AUTORITATIVOS (Sólo HOST los ejecuta)
# ─────────────────────────────────────────────────────────────
func recibir_dano(cantidad: int) -> void:
	if is_dead: return
	if is_guarding:
		print("[Host] Daño bloqueado por el escudo del peer %d" % peer_id)
		return

	# Solo el host calcula el daño
	if not NetworkManager.is_server(): return

	var defensa = floor(nivel / 3.0)
	var dano_recibido = max(1, cantidad - defensa)
	salud_actual = clampi(salud_actual - dano_recibido, 0, vida_maxima)

	_efecto_dano()

	# Notificar al cliente dueño de este peer para que actualice su Caballero local
	var local_player_node = get_node_or_null("/root/EscenarioPruebas/Caballero")
	if local_player_node and local_player_node.has_method("rpc_apply_damage"):
		local_player_node.rpc_apply_damage.rpc_id(peer_id, salud_actual)

	# Notificar a los demás peers de que este remoto recibió daño (para efecto visual)
	notify_damage.rpc()

	if salud_actual <= 0:
		_morir_host()

func curar(cantidad: int) -> void:
	if is_dead or salud_actual >= vida_maxima: return
	if not NetworkManager.is_server(): return

	salud_actual = clampi(salud_actual + cantidad, 0, vida_maxima)
	_efecto_curacion()

	# Notificar al cliente dueño
	var local_player_node = get_node_or_null("/root/EscenarioPruebas/Caballero")
	if local_player_node and local_player_node.has_method("rpc_apply_heal"):
		local_player_node.rpc_apply_heal.rpc_id(peer_id, salud_actual)

	# Sincronizar con los demás peers
	notify_heal.rpc()

func _morir_host() -> void:
	if is_dead: return
	is_dead = true
	net_anim = "death"
	if sprite and sprite.sprite_frames:
		# Forzar que la animación de muerte NO cicle
		sprite.sprite_frames.set_animation_loop("death", false)
		sprite.play("death")
		# Desvanecer a fantasma visual
		var t = create_tween()
		t.tween_property(sprite, "modulate:a", 0.4, 1.0)
	# Notificar a la red del estado muerto
	NetworkManager.rpc_set_player_alive.rpc(peer_id, false)
	# Notificar al cliente dueño de su muerte
	var local_player_node = get_node_or_null("/root/EscenarioPruebas/Caballero")
	if local_player_node and local_player_node.has_method("rpc_apply_death"):
		local_player_node.rpc_apply_death.rpc_id(peer_id, _get_kill_count())
	# Notificar a los demás peers
	notify_death.rpc(_get_kill_count())
	# Mostrar notificación en la pantalla del host
	_mostrar_notificacion_muerte_en_pantalla()

func _mostrar_notificacion_muerte_en_pantalla() -> void:
	var escenario = get_tree().current_scene
	if not escenario: return
	var canvas = CanvasLayer.new()
	canvas.layer = 90
	escenario.add_child(canvas)
	
	var lbl = Label.new()
	lbl.text = "💀 ¡%s ha caído!" % gamertag
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color.RED)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.modulate.a = 0.0
	canvas.add_child(lbl)
	
	var tw = create_tween()
	tw.tween_property(lbl, "modulate:a", 1.0, 0.5)
	tw.tween_interval(2.0)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.0)
	tw.tween_callback(canvas.queue_free)

func _get_kill_count() -> int:
	var escenario = get_tree().current_scene
	var total = 0
	if "enemigos_derrotados" in escenario:
		total += escenario.enemigos_derrotados
	if "arqueros_derrotados" in escenario:
		total += escenario.arqueros_derrotados
	if "lanceros_derrotados" in escenario:
		total += escenario.lanceros_derrotados
	return total

func get_guard_energy() -> float:
	return 0.0  # Stub para HUD compatibility

var is_guarding: bool = false
