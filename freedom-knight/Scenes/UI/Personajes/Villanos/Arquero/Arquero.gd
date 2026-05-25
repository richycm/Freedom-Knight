## ============================================================
##  Arquero.gd  — Freedom Knight
##  IA del arquero enemigo.
##  En solitario: funciona exactamente igual que antes.
##  En multijugador:
##    - HOST: ejecuta IA, dispara flechas, aplica daño, muere.
##    - CLIENTE: NO ejecuta nada. Recibe posición via red.
##  Usa PlayerRegistry para encontrar al jugador más cercano
##  (funciona automáticamente con múltiples jugadores).
## ============================================================
extends CharacterBody2D

signal murio(posicion_muerte)

# ─────────────────────────────────────────────────────────────
#  EXPORTS
# ─────────────────────────────────────────────────────────────
@export_group("Configuración IA")
@export var speed          : float = 100.0
@export var stop_distance  : float = 500.0
@export var attack_cooldown: float = 2.2

@export_group("Combate IA")
@export var vida_maxima  : int = 5
@export var poder_ataque : int = 1
var salud_actual         : int

# ─────────────────────────────────────────────────────────────
#  NODOS
# ─────────────────────────────────────────────────────────────
@onready var sprite       : AnimatedSprite2D = $AnimatedSprite
@onready var rango_ataque : Area2D           = $RangoAtaque

# ─────────────────────────────────────────────────────────────
#  ESTADO
# ─────────────────────────────────────────────────────────────
var player       : Node2D = null
var is_attacking : bool   = false
var is_dead      : bool   = false
var is_spawning  : bool   = true
var attack_timer : float  = 0.0

# Sincronización de red (para clientes)
var net_position : Vector2 = Vector2.ZERO
var net_anim     : String  = "idle"
var net_flip     : bool    = false
const INTERP_SPEED : float = 12.0

var flecha_scene  = preload("res://Scenes/UI/Personajes/Villanos/Arquero/Flecha.tscn")
var sound_disparo = preload("res://Sonidos/Efectos/ArcoFlechaDisparada.mp3")
var _sfx_player   : AudioStreamPlayer2D

# ─────────────────────────────────────────────────────────────
#  LIFECYCLE
# ─────────────────────────────────────────────────────────────
func _ready() -> void:
	_sfx_player = AudioStreamPlayer2D.new()
	_sfx_player.stream = sound_disparo
	add_child(_sfx_player)

	add_to_group("enemigos")
	salud_actual = vida_maxima
	y_sort_enabled = true
	
	# Efecto de aparición (Fade In)
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.4)
	
	if sprite:
		sprite.sprite_frames.set_animation_loop("attack", false)
		sprite.sprite_frames.set_animation_loop("death", false)

	# Capas de físicas
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_layer_value(3, true)
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, false)
	set_collision_mask_value(3, false)

	rango_ataque.set_collision_layer_value(1, false)
	rango_ataque.set_collision_mask_value(1, false)
	rango_ataque.set_collision_mask_value(2, true)
	rango_ataque.set_collision_mask_value(3, false)

	# ── En modo cliente: deshabilitar IA completamente ──
	if _is_client_only():
		set_physics_process(false)
		rango_ataque.set_deferred("monitoring", false)
		net_position = global_position
		return

	# Solo en host/solitario: buscar jugador y spawnear
	player = _obtener_jugador_mas_cercano()
	if player:
		var dir = global_position.direction_to(player.global_position)
		_update_visuals(dir, "idle")

	_ejecutar_spawn_magico()

func _is_client_only() -> bool:
	return NetworkManager.is_multiplayer_active() and not NetworkManager.is_server()

# ─────────────────────────────────────────────────────────────
#  SPAWN ANIMATION
# ─────────────────────────────────────────────────────────────
func _ejecutar_spawn_magico() -> void:
	is_spawning = true
	if sprite:
		sprite.play("death")
		var duracion = sprite.sprite_frames.get_frame_count("death") / sprite.sprite_frames.get_animation_speed("death")
		await get_tree().create_timer(duracion * 0.5).timeout
		sprite.play("idle")
		sprite.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)
		await tween.finished
	is_spawning = false

# ─────────────────────────────────────────────────────────────
#  AI PHYSICS (solo host/solitario)
# ─────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if is_dead: return

	if not is_spawning:
		# Buscar el jugador VIVO más cercano usando PlayerRegistry
		player = _obtener_jugador_mas_cercano()
		if not is_instance_valid(player): return

		if attack_timer > 0:
			attack_timer -= delta

		var distance  = global_position.distance_to(player.global_position)
		var direction = global_position.direction_to(player.global_position)

		if is_attacking:
			velocity = Vector2.ZERO
		elif distance > stop_distance:
			velocity = direction * speed
			_update_visuals(direction, "move")
		else:
			velocity = Vector2.ZERO
			if attack_timer <= 0:
				_atacar()
			else:
				_update_visuals(direction, "idle")

		move_and_slide()

	# Sincronizar estado a clientes (host → broadcast)
	if NetworkManager.is_multiplayer_active() and NetworkManager.is_server():
		var anim : String = "idle"
		var flip : bool   = false
		if is_instance_valid(sprite):
			anim = str(sprite.animation)
			flip = sprite.flip_h
		_rpc_sync_enemy.rpc(global_position, anim, flip, salud_actual, is_dead)

# ─────────────────────────────────────────────────────────────
#  COMBAT
# ─────────────────────────────────────────────────────────────
func _update_visuals(dir: Vector2, anim: String) -> void:
	if is_attacking: return
	sprite.play(anim)
	if dir.x != 0:
		sprite.flip_h = dir.x < 0

func _atacar() -> void:
	if is_attacking or is_dead: return
	is_attacking = true
	sprite.play("attack")
	var dir_ataque = global_position.direction_to(player.global_position)
	sprite.flip_h = dir_ataque.x < 0
	_disparar_flecha_perseguidora()
	await sprite.animation_finished
	is_attacking  = false
	attack_timer  = attack_cooldown

func _disparar_flecha_perseguidora() -> void:
	# Solo el host dispara flechas — en solitario siempre ejecuta
	if _is_client_only(): return
	if not player or not is_instance_valid(player): return

	var flecha = flecha_scene.instantiate()
	get_tree().current_scene.add_child(flecha, true)
	flecha.global_position = global_position

	if _sfx_player:
		_sfx_player.play()

	if flecha.has_method("iniciar_flecha"):
		# Nerfear el daño de la flecha para que no aumente demasiado (escala 1/3 del poder del arquero, mín 1, máx 3)
		var dano_flecha = clampi(int(poder_ataque / 3.0) + 1, 1, 3)
		flecha.iniciar_flecha(player, dano_flecha, self)

# ─────────────────────────────────────────────────────────────
#  DAMAGE
# ─────────────────────────────────────────────────────────────
func recibir_dano(cantidad: int) -> void:
	if is_dead or is_spawning: return
	# En red: solo el host procesa daño en enemigos
	if _is_client_only(): return

	salud_actual -= cantidad
	_efecto_dano()
	if salud_actual <= 0:
		_morir()

func _efecto_dano() -> void:
	var flash = create_tween()
	sprite.modulate = Color.RED
	flash.tween_property(sprite, "modulate", Color.WHITE, 0.2)

func _morir() -> void:
	if is_dead: return
	is_dead = true
	murio.emit(global_position)

	set_collision_layer_value(3, false)
	set_collision_mask_value(1, false)
	rango_ataque.set_deferred("monitoring", false)
	velocity = Vector2.ZERO

	if sprite:
		sprite.play("death")

	# Enviar RPC explícito de muerte a los clientes antes de liberar el nodo
	if NetworkManager.is_multiplayer_active() and NetworkManager.is_server():
		_rpc_sync_enemy.rpc(global_position, "death", false, 0, true)
		
	# Esperar a que termine la animación de muerte
	if sprite:
		await sprite.animation_finished
	else:
		await get_tree().create_timer(0.5).timeout

	queue_free()

func desvanecer_y_morir() -> void:
	if is_dead: return
	is_dead = true
	var t = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.5)
	t.tween_callback(queue_free)

# ─────────────────────────────────────────────────────────────
#  PLAYER LOOKUP  — usa PlayerRegistry (multi-target automático)
# ─────────────────────────────────────────────────────────────
func _obtener_jugador_mas_cercano() -> Node:
	return PlayerRegistry.get_nearest_player_to(global_position)

# ─────────────────────────────────────────────────────────────
#  RANGE SIGNAL
# ─────────────────────────────────────────────────────────────
func _on_rango_ataque_body_entered(body: Node2D) -> void:
	if _is_client_only(): return
	if body.is_in_group("jugador") or body.is_in_group("Jugador"):
		player = body
		if not is_attacking and not is_dead and not is_spawning and attack_timer <= 0:
			_atacar()

func _process(delta: float) -> void:
	if _is_client_only():
		if is_dead: return
		global_position = global_position.lerp(net_position, INTERP_SPEED * delta)
		if sprite:
			if sprite.animation != net_anim:
				sprite.play(net_anim)
			sprite.flip_h = net_flip

@rpc("authority", "unreliable_ordered")
func _rpc_sync_enemy(pos: Vector2, anim: String, flip: bool, salud: int, dead: bool) -> void:
	if NetworkManager.is_server(): return
	net_position = pos
	net_anim = anim
	net_flip = flip
	
	if salud < salud_actual:
		_efecto_dano()
	salud_actual = salud
	
	if dead and not is_dead:
		_morir_client()
	is_dead = dead

func _morir_client() -> void:
	is_dead = true
	set_collision_layer_value(3, false)
	set_collision_mask_value(1, false)
	rango_ataque.set_deferred("monitoring", false)
	if sprite:
		sprite.play("death")
