extends CharacterBody2D

signal murio(posicion_muerte)

@export_group("Configuración IA")
@export var speed: float = 70.0
@export var min_distance: float = 50.0   # Si el jugador está más cerca que esto, retrocede
@export var stop_distance: float = 135.0 # Distancia ideal para atacar
@export var attack_cooldown: float = 1.2

@export_group("Combate IA")
@export var vida_maxima: int = 8
@export var poder_ataque: int = 1
var salud_actual: int

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var rango_ataque: Area2D = $Rangoataque 

var player: CharacterBody2D = null
var is_attacking: bool = false
var is_dead: bool = false 
var is_spawning: bool = true 
var attack_timer: float = 0.0

# Sincronización de red (para clientes)
var net_position : Vector2 = Vector2.ZERO
var net_anim     : String  = "idle"
var net_flip     : bool    = false
const INTERP_SPEED : float = 12.0

func _ready() -> void:
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
	
	# FÍSICA: Capa 3, choca con mapa (Capa 1)
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_layer_value(3, true)
	set_collision_mask_value(1, true) 
	set_collision_mask_value(2, false)
	set_collision_mask_value(3, false)
	
	# COMBATE: Rango detecta jugador (Capa 2)
	rango_ataque.set_collision_layer_value(1, false)
	rango_ataque.set_collision_mask_value(1, false)
	rango_ataque.set_collision_mask_value(2, true)
	rango_ataque.set_collision_mask_value(3, false)
	
	# En modo cliente: deshabilitar IA
	if _is_client_only():
		set_physics_process(false)
		rango_ataque.set_deferred("monitoring", false)
		net_position = global_position
		return
	
	if not rango_ataque.body_entered.is_connected(_on_rango_ataque_body_entered):
		rango_ataque.body_entered.connect(_on_rango_ataque_body_entered)
	rango_ataque.monitoring = false
	
	_ejecutar_spawn_magico()

func _is_client_only() -> bool:
	return NetworkManager.is_multiplayer_active() and not NetworkManager.is_server()

func _physics_process(delta: float) -> void:
	if is_dead: return
	
	if not is_spawning:
		player = _obtener_jugador_mas_cercano()
		if not is_instance_valid(player): return
		
		if attack_timer > 0: attack_timer -= delta

		var distance = global_position.distance_to(player.global_position)
		var direction = global_position.direction_to(player.global_position)

		if is_attacking:
			velocity = Vector2.ZERO
		else:
			# LÓGICA DE LANCERO: 
			# 1. Si está muy cerca, retrocede
			if distance < min_distance:
				velocity = -direction * speed
				_update_visuals(-direction, "move")
			# 2. Si está en rango, ataca
			elif distance <= stop_distance:
				velocity = Vector2.ZERO
				if attack_timer <= 0:
					_atacar()
				else:
					_update_visuals(direction, "idle")
			# 3. Si está lejos, persigue
			else:
				velocity = direction * speed
				_update_visuals(direction, "move")
		
		move_and_slide()

	# Sincronizar estado a clientes (host → broadcast)
	if NetworkManager.is_multiplayer_active() and NetworkManager.is_server():
		var anim : String = "idle"
		var flip : bool   = false
		if is_instance_valid(sprite):
			anim = str(sprite.animation)
			flip = sprite.flip_h
		_rpc_sync_enemy.rpc(global_position, anim, flip, salud_actual, is_dead)

func _atacar() -> void:
	if is_attacking or is_dead: return
	is_attacking = true
	sprite.play("attack")
	
	# Delay un poco más largo para que coincida con el estirón de la lanza
	await get_tree().create_timer(0.3).timeout
	rango_ataque.monitoring = true
	
	# Golpe rápido (duración del hitbox)
	await get_tree().create_timer(0.2).timeout
	rango_ataque.monitoring = false
	
	await sprite.animation_finished
	is_attacking = false
	attack_timer = attack_cooldown

# --- MÉTODOS DE APOYO (Mantener igual que el caballero) ---
func _update_visuals(dir: Vector2, anim: String) -> void:
	sprite.play(anim)
	if dir.x != 0:
		sprite.flip_h = dir.x < 0
		# Ajusta la escala del rango según la dirección
		rango_ataque.scale.x = -1 if dir.x < 0 else 1

func recibir_dano(cantidad: int) -> void:
	if is_dead or is_spawning: return
	if _is_client_only(): return  # Solo host aplica daño
	salud_actual -= cantidad
	if salud_actual <= 0: _morir()
	else: _efecto_dano()

func _efecto_dano() -> void:
	var tween = create_tween()
	sprite.modulate = Color.RED
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)

func _morir() -> void:
	if is_dead: return
	is_dead = true
	
	murio.emit(global_position)
	
	set_collision_layer_value(2, false)
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

func _on_rango_ataque_body_entered(body: Node2D) -> void:
	if body.is_in_group("jugador") and body.has_method("recibir_dano"):
		body.recibir_dano(poder_ataque)

func _obtener_jugador_mas_cercano() -> Node:
	return PlayerRegistry.get_nearest_player_to(global_position)

func desvanecer_y_morir() -> void:
	if is_dead: return
	is_dead = true
	var t = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.5)
	t.tween_callback(queue_free)

func _ejecutar_spawn_magico() -> void:
	# (Misma lógica de spawn que tenías)
	is_spawning = true
	await get_tree().create_timer(0.5).timeout
	is_spawning = false

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
	set_collision_layer_value(2, false)
	set_collision_mask_value(1, false)
	rango_ataque.set_deferred("monitoring", false)
	if sprite:
		sprite.play("death")
