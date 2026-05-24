extends CharacterBody2D

signal adopted
signal died

enum State { IDLE, ADOPTED, DEAD, FLEE, AGGRESSIVE }
var state: State = State.IDLE

@export var speed: float = 120.0
@export var max_health: int = 3
var current_health: int

var player: CharacterBody2D = null
var target_peer_id: int = 0
var can_interact: bool = false
var enemies_killed_since_heal: int = 0
var heals_every: int = 5

@onready var sprite = $AnimatedSprite
@onready var label_interact = $LabelInteract

# Sincronización de red (para clientes)
var net_position : Vector2 = Vector2.ZERO
var net_anim     : String  = "idle"
var net_flip     : bool    = false
const INTERP_SPEED : float = 12.0

# Aggressive & Flee state variables
var flee_direction: Vector2 = Vector2.ZERO
var flee_time_remaining: float = 0.0
var aggressive_target: Node = null
var aggressive_timer: float = 0.0
var attack_cooldown: float = 0.0

# Throttle del sync de red (no mandar RPC cada frame)
const CAT_SYNC_RATE : float = 0.05  # 20 Hz
var _sync_timer     : float = 0.0

func _ready() -> void:
	current_health = max_health
	add_to_group("mascotas")
	
	# FÍSICA: En la Capa 3, detecta mapa en Capa 1 y jugador en Capa 2
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_layer_value(3, true)
	set_collision_mask_value(1, true)
	
	if not $ZonaInteraccion.body_entered.is_connected(_on_body_entered):
		$ZonaInteraccion.body_entered.connect(_on_body_entered)
	if not $ZonaInteraccion.body_exited.is_connected(_on_body_exited):
		$ZonaInteraccion.body_exited.connect(_on_body_exited)
	
	label_interact.visible = false
	label_interact.text = "Interactuar para adoptar"
	
	# Desactivar ZonaDeAtaque por defecto si existe
	var attack_shape = get_node_or_null("ZonaInteraccion/ZonaDeAtaque")
	if attack_shape:
		attack_shape.disabled = true
	
	# Efecto de spawn
	modulate.a = 0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 1.0)
	
	if _is_client_only():
		set_physics_process(false)
		net_position = global_position

func _is_client_only() -> bool:
	return NetworkManager.is_multiplayer_active() and not NetworkManager.is_server()

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
		
	if state == State.ADOPTED:
		# Si player se vuelve inválido, recuperarlo por su peer_id
		if not is_instance_valid(player) or player.is_queued_for_deletion():
			player = PlayerRegistry.get_player(target_peer_id)
			
		if is_instance_valid(player):
			var distance = global_position.distance_to(player.global_position)
			if distance > 60.0:
				var direction = global_position.direction_to(player.global_position)
				velocity = direction * speed
				if direction.x != 0:
					sprite.flip_h = direction.x < 0
				if sprite.animation != "move":
					sprite.play("move")
			else:
				velocity = Vector2.ZERO
				if sprite.animation != "idle":
					sprite.play("idle")
		else:
			velocity = Vector2.ZERO
			if sprite.animation != "idle":
				sprite.play("idle")
		move_and_slide()
		
	elif state == State.FLEE:
		flee_time_remaining -= delta
		if flee_time_remaining <= 0:
			state = State.IDLE
			velocity = Vector2.ZERO
			sprite.play("idle")
		else:
			velocity = flee_direction * (speed * 1.6)
			if flee_direction.x != 0:
				sprite.flip_h = flee_direction.x < 0
			if sprite.animation != "move":
				sprite.play("move")
			move_and_slide()
			
	elif state == State.AGGRESSIVE:
		if attack_cooldown > 0:
			attack_cooldown -= delta
			
		if is_instance_valid(aggressive_target) and not aggressive_target.get("is_dead"):
			aggressive_timer -= delta
			if aggressive_timer <= 0:
				# Dejar de perseguir
				state = State.IDLE
				aggressive_target = null
				velocity = Vector2.ZERO
				sprite.play("idle")
			else:
				var dist = global_position.distance_to(aggressive_target.global_position)
				var dir = global_position.direction_to(aggressive_target.global_position)
				
				if dist > 45.0:
					# Perseguir
					velocity = dir * (speed * 1.3)
					if dir.x != 0:
						sprite.flip_h = dir.x < 0
					if sprite.animation != "move" and sprite.animation != "attack":
						sprite.play("move")
				else:
					# Atacar
					velocity = Vector2.ZERO
					if attack_cooldown <= 0:
						_perform_attack(aggressive_target)
		else:
			# Target muerto o inválido, volver a IDLE
			state = State.IDLE
			aggressive_target = null
			velocity = Vector2.ZERO
			sprite.play("idle")
		move_and_slide()
			
	else:
		velocity = Vector2.ZERO
		if sprite.animation != "idle":
			sprite.play("idle")
		move_and_slide()
		
	# Sincronizar estado a clientes (host → broadcast, throttled a 20 Hz)
	if NetworkManager.is_multiplayer_active() and NetworkManager.is_server():
		_sync_timer += delta
		if _sync_timer >= CAT_SYNC_RATE:
			_sync_timer = 0.0
			var anim : String = str(sprite.animation) if sprite else "idle"
			var flip = sprite.flip_h if sprite else false
			_rpc_sync_cat.rpc(global_position, anim, flip, state, target_peer_id, current_health)

func _process(delta: float) -> void:
	if _is_client_only():
		if state == State.DEAD:
			return
		global_position = global_position.lerp(net_position, INTERP_SPEED * delta)
		if sprite:
			if sprite.animation != net_anim:
				sprite.play(net_anim)
			sprite.flip_h = net_flip
			
		# Permitir que el cliente presione interact
		if state == State.IDLE and can_interact and Input.is_action_just_pressed("interact"):
			var my_id = NetworkManager.get_my_peer_id()
			rpc_request_adopt.rpc_id(1, my_id)
		return
		
	# Lógica local / Servidor
	if state == State.IDLE and can_interact and Input.is_action_just_pressed("interact"):
		var my_id = NetworkManager.get_my_peer_id()
		adoptar_gata(my_id)

func _on_body_entered(body: Node2D) -> void:
	if body == PlayerRegistry.get_local_player():
		if state == State.IDLE:
			player = body
			can_interact = true
			label_interact.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body == PlayerRegistry.get_local_player():
		if state == State.IDLE:
			can_interact = false
			label_interact.visible = false
			player = null

func adoptar_gata(p_peer_id: int) -> void:
	state = State.ADOPTED
	target_peer_id = p_peer_id
	player = PlayerRegistry.get_player(p_peer_id)
	
	_celebrar_adopcion(p_peer_id)
	
	adopted.emit()
	
	# Si somos el host, notificar a los clientes mediante la sincronización regular o rpc directo
	if NetworkManager.is_multiplayer_active() and NetworkManager.is_server():
		var anim : String = str(sprite.animation) if sprite else "idle"
		var flip = sprite.flip_h if sprite else false
		_rpc_sync_cat.rpc(global_position, anim, flip, state, target_peer_id, current_health)

func _celebrar_adopcion(p_peer_id: int) -> void:
	var gamertag = ""
	if NetworkManager.is_multiplayer_active():
		gamertag = NetworkManager.get_gamertag(p_peer_id)
	else:
		gamertag = SaveManager.nombre_jugador
	if gamertag == "": gamertag = "Caballero"
	
	label_interact.text = "Gato de %s" % gamertag
	label_interact.add_theme_color_override("font_color", Color.GOLD)
	label_interact.visible = true
	
	# Efecto de corazones
	var heart_label = Label.new()
	heart_label.text = "❤"
	heart_label.add_theme_color_override("font_color", Color.RED)
	heart_label.add_theme_font_size_override("font_size", 24)
	heart_label.position = Vector2(-10, -40)
	add_child(heart_label)
	
	var tween = create_tween()
	tween.tween_property(heart_label, "position:y", -70.0, 1.0)
	tween.parallel().tween_property(heart_label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(heart_label.queue_free)

func _play_scared_effect() -> void:
	var tween = create_tween()
	sprite.modulate = Color.RED
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)

func _perform_attack(target: Node) -> void:
	attack_cooldown = 1.5 # Cooldown entre ataques
	
	# Animación
	if sprite.sprite_frames.has_animation("attack"):
		sprite.play("attack")
	
	# Activar ZonaDeAtaque
	var attack_shape = get_node_or_null("ZonaInteraccion/ZonaDeAtaque")
	if attack_shape:
		attack_shape.disabled = false
		
	# Aplicar daño al jugador atacante (sólo en host/solitario)
	if not NetworkManager.is_multiplayer_active() or NetworkManager.is_server():
		if target.has_method("recibir_dano"):
			target.recibir_dano(1) # Quita medio corazón (1 punto)
			
	# Desactivar shape después de 0.4s
	await get_tree().create_timer(0.4).timeout
	if attack_shape:
		attack_shape.disabled = true
		
	if state == State.AGGRESSIVE and is_instance_valid(target) and not target.get("is_dead"):
		sprite.play("move")

func recibir_dano(_amount: int, attacker: Node = null) -> void:
	if NetworkManager.is_multiplayer_active() and not NetworkManager.is_server():
		return # Clientes no procesan daño directamente
		
	if state == State.DEAD or state == State.ADOPTED:
		return
		
	current_health -= 1
	_play_scared_effect()
	
	if current_health == 2:
		# Primer golpe: huir
		state = State.FLEE
		if attacker:
			flee_direction = global_position.direction_to(attacker.global_position) * -1
		else:
			flee_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		flee_time_remaining = 1.2
		sprite.play("move")
		
	elif current_health == 1:
		# Segundo golpe: modo agresivo
		state = State.AGGRESSIVE
		aggressive_target = attacker
		aggressive_timer = 4.0
		attack_cooldown = 0.0
		
	elif current_health <= 0:
		# Tercer golpe: morir
		_die()

func _die() -> void:
	state = State.DEAD
	died.emit()
	label_interact.visible = false
	
	velocity = Vector2.ZERO
	sprite.play("death")
	
	await sprite.animation_finished
	queue_free()

@rpc("any_peer", "reliable")
func rpc_request_adopt(p_peer_id: int) -> void:
	if not NetworkManager.is_server(): return
	var p_node = PlayerRegistry.get_player(p_peer_id)
	if p_node and is_instance_valid(p_node) and global_position.distance_to(p_node.global_position) <= 150.0:
		if state == State.IDLE: # Evitar doble adopción
			adoptar_gata(p_peer_id)

@rpc("authority", "unreliable_ordered")
func _rpc_sync_cat(pos: Vector2, anim: String, flip: bool, p_state: int, p_peer_id: int, health: int) -> void:
	if NetworkManager.is_server(): return
	net_position = pos
	net_anim = anim
	net_flip = flip
	
	if health < current_health:
		_play_scared_effect()
	current_health = health
	
	var old_state = state
	# Validar rango del enum antes de asignar
	if p_state >= 0 and p_state < State.size():
		state = p_state as State
	target_peer_id = p_peer_id
	
	if state == State.ADOPTED and old_state != State.ADOPTED:
		_celebrar_adopcion(p_peer_id)
	elif state == State.ADOPTED:
		# Ya está adoptado, no sobrescribir el texto. Solo asegurarse de que sea visible.
		label_interact.visible = true
	elif state == State.DEAD:
		label_interact.visible = false
		if sprite:
			sprite.visible = false
	elif state == State.AGGRESSIVE:
		label_interact.text = "¡Gato Enojado!"
		label_interact.add_theme_color_override("font_color", Color.RED)
		label_interact.visible = true
	elif state == State.FLEE:
		label_interact.text = "¡Miau asustado!"
		label_interact.add_theme_color_override("font_color", Color.ORANGE)
		label_interact.visible = true
	else:
		label_interact.text = "Interactuar para adoptar"
		label_interact.add_theme_color_override("font_color", Color.YELLOW)
		label_interact.visible = can_interact

func registrar_muerte_enemigo() -> void:
	if state != State.ADOPTED:
		return
		
	enemies_killed_since_heal += 1
	if enemies_killed_since_heal >= heals_every:
		enemies_killed_since_heal = 0
		_heal_player()

func _heal_player() -> void:
	# El host calcula la curación
	if NetworkManager.is_multiplayer_active():
		if NetworkManager.is_server():
			if is_instance_valid(player) and player.has_method("curar"):
				player.curar(2)
				rpc_play_heal_fx.rpc()
	else:
		if is_instance_valid(player) and player.has_method("curar"):
			player.curar(2)
			_show_heal_label()

@rpc("authority", "call_local", "reliable")
func rpc_play_heal_fx() -> void:
	_show_heal_label()

func _show_heal_label() -> void:
	var heal_label = Label.new()
	heal_label.text = "¡Miau!"
	heal_label.add_theme_color_override("font_color", Color.GREEN)
	heal_label.add_theme_font_size_override("font_size", 16)
	heal_label.position = Vector2(-20, -40)
	add_child(heal_label)
	
	var tween = create_tween()
	tween.tween_property(heal_label, "position:y", -60.0, 1.0)
	tween.parallel().tween_property(heal_label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(heal_label.queue_free)
