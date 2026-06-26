## ============================================================
##  flecha.gd  — Freedom Knight
##  SISTEMA DE PROYECTILES MULTIJUGADOR
##
##  ARCHITECTURE:
##    - El HOST es el único que calcula física, colisiones y daño.
##    - Los CLIENTES solo renderizan la posición interpolada.
##    - Cada flecha tiene un projectile_id único para evitar
##      duplicados y sincronizar destrucción correctamente.
##    - Anti-ghost: is_destroyed es la única fuente de verdad.
##    - Sin double-damage: recibir_dano() solo se llama en el host.
##
##  SOLITARIO: funciona exactamente igual que antes.
## ============================================================
extends Area2D

# ─────────────────────────────────────────────────────────────
#  EXPORTS
# ─────────────────────────────────────────────────────────────
@export var velocidad         : float = 260.0
@export var fuerza_persecucion: float = 1.2

# ─────────────────────────────────────────────────────────────
#  ESTADO
# ─────────────────────────────────────────────────────────────
var objetivo     : Node2D = null
var dano         : int    = 1
var direccion    : Vector2 = Vector2.RIGHT
var tirador      : Node2D = null
var is_destroyed : bool   = false

## ID único para sincronización en red (host lo asigna al spawnear)
var projectile_id : int = 0
var _is_first_sync: bool = true

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var sound_impacto  = preload("res://Sonidos/Efectos/ArcoFlechaEscudo.mp3")
var _impact_player : AudioStreamPlayer2D

# ─────────────────────────────────────────────────────────────
#  LIFECYCLE
# ─────────────────────────────────────────────────────────────
func _ready() -> void:
	_impact_player = AudioStreamPlayer2D.new()
	_impact_player.stream = sound_impacto
	get_tree().current_scene.add_child.call_deferred(_impact_player)

	sprite.play("idle")

	# Capas de colisión (igual que antes)
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_layer_value(3, true)
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	set_collision_mask_value(3, false)
	set_collision_mask_value(4, true)

	# ── CLAVE: En modo cliente, desactivar física y colisiones ──
	# El cliente solo renderiza; el host procesa todo.
	if _is_client_only():
		set_physics_process(false)
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		visible = false
	else:
		# Host o solitario: conectar señales de colisión
		if not body_entered.is_connected(_on_body_entered):
			body_entered.connect(_on_body_entered)
		if not area_entered.is_connected(_on_area_entered):
			area_entered.connect(_on_area_entered)
		get_tree().create_timer(5.0).timeout.connect(_destruccion_por_tiempo)

func _is_client_only() -> bool:
	return NetworkManager.is_multiplayer_active() and not NetworkManager.is_server()

func _exit_tree() -> void:
	if _impact_player and is_instance_valid(_impact_player):
		if not _impact_player.playing:
			_impact_player.queue_free()

# ─────────────────────────────────────────────────────────────
#  INICIALIZACIÓN (llamada por el Arquero)
# ─────────────────────────────────────────────────────────────
func iniciar_flecha(target: Node2D, poder: int, quien_dispara: Node2D) -> void:
	objetivo = target
	dano     = poder
	tirador  = quien_dispara

	if objetivo and is_instance_valid(objetivo):
		direccion = global_position.direction_to(objetivo.global_position)
		rotation  = direccion.angle()

	# Generar ID único: timestamp_millis + nodo instance_id
	projectile_id = int(Time.get_ticks_msec()) ^ get_instance_id()

# ─────────────────────────────────────────────────────────────
#  PHYSICS (solo HOST o solitario)
# ─────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if is_destroyed: return

	if objetivo and is_instance_valid(objetivo) and not objetivo.is_queued_for_deletion() and not objetivo.get("is_dead"):
		var dir_ideal = global_position.direction_to(objetivo.global_position)
		direccion = direccion.slerp(dir_ideal, fuerza_persecucion * delta)

	position += direccion * velocidad * delta
	rotation  = direccion.angle()

	# ── Sincronizar posición a clientes (host → broadcast) ──
	if NetworkManager.is_multiplayer_active() and NetworkManager.is_server():
		_rpc_sync_position.rpc(global_position, rotation)

# ─────────────────────────────────────────────────────────────
#  SINCRONIZACIÓN DE POSICIÓN (Host → Clientes)
# ─────────────────────────────────────────────────────────────
@rpc("authority", "unreliable_ordered")
func _rpc_sync_position(pos: Vector2, rot: float) -> void:
	# Solo ejecuta en clientes
	if NetworkManager.is_server(): return
	if _is_first_sync:
		_is_first_sync = false
		global_position = pos
		visible = true
	else:
		global_position = global_position.lerp(pos, 0.4)
	rotation = rot

# ─────────────────────────────────────────────────────────────
#  COLISIONES (solo HOST o solitario)
# ─────────────────────────────────────────────────────────────
func _on_body_entered(body: Node) -> void:
	if is_destroyed: return
	if body == tirador: return

	# ── PARRY CHECK: espada en el mismo frame ──
	var areas_chocando = get_overlapping_areas()
	for a in areas_chocando:
		if a.name == "HitboxEspada":
			var player = _find_player_owner_of_hitbox(a)
			if player and _flecha_frente_al_jugador(player):
				print("¡Parry salvador! Flecha destruida en el último milisegundo.")
				_explotar_y_sincronizar()
				return

	# ── DAÑO A JUGADOR O ENEMIGO ──
	if body.has_method("recibir_dano"):
		if body.is_in_group("jugador") and body.get("is_guarding"):
			print("¡FLECHA BLOQUEADA POR ESCUDO!")
		else:
			print("¡FLECHA IMPACTÓ A %s!" % body.name)
			body.recibir_dano(dano)
	elif body is TileMapLayer or (body.name and "Limite" in body.name):
		pass  # Solo explotar
	else:
		return  # No explotar contra otros objetos

	_explotar_y_sincronizar()

func _on_area_entered(area: Area2D) -> void:
	if is_destroyed: return
	if area.name != "HitboxEspada": return

	var player = _find_player_owner_of_hitbox(area)
	if player and _flecha_frente_al_jugador(player):
		print("¡PARRY! Flecha destruida por el escudo de espada.")
		_explotar_y_sincronizar()

func _find_player_owner_of_hitbox(hitbox_area: Area2D) -> Node:
	# El hitbox es hijo del caballero
	return hitbox_area.get_parent() if hitbox_area else null

func _flecha_frente_al_jugador(player: Node) -> bool:
	if not player or not player.get_node_or_null("AnimatedSprite"): return false
	var mirando_derecha = not player.get_node("AnimatedSprite").flip_h
	if mirando_derecha:
		return global_position.x >= player.global_position.x - 15
	else:
		return global_position.x <= player.global_position.x + 15

# ─────────────────────────────────────────────────────────────
#  DESTRUCCIÓN
# ─────────────────────────────────────────────────────────────

## Explotar en el host Y notificar a todos los clientes
func _explotar_y_sincronizar() -> void:
	if is_destroyed: return
	is_destroyed = true

	# Notificar destrucción a clientes ANTES de explotar visualmente
	if NetworkManager.is_multiplayer_active() and NetworkManager.is_server():
		_rpc_destroy.rpc()

	_explotar()

## Clientes reciben orden de destrucción del host
@rpc("authority", "reliable")
func _rpc_destroy() -> void:
	if is_destroyed: return
	is_destroyed = true
	_explotar()

func _explotar() -> void:
	is_destroyed = true
	_play_impact_sound()

	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	set_physics_process(false)

	if sprite and is_instance_valid(sprite):
		rotation = 0
		sprite.play("death")
		await sprite.animation_finished
		visible = false

	if is_instance_valid(self):
		if not _is_client_only():
			queue_free()

func _destruccion_por_tiempo() -> void:
	if not is_destroyed:
		_explotar_y_sincronizar()

# ─────────────────────────────────────────────────────────────
#  AUDIO
# ─────────────────────────────────────────────────────────────
func _play_impact_sound() -> void:
	if _impact_player and is_instance_valid(_impact_player):
		_impact_player.global_position = global_position
		_impact_player.play()
		_impact_player.finished.connect(_impact_player.queue_free)
