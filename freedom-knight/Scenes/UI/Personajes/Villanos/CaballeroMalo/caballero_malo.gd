extends CharacterBody2D

signal murio(posicion_muerte)

@export_group("Configuración IA")
@export var speed: float = 85.0
@export var stop_distance: float = 70.0 
@export var attack_cooldown: float = 0.8

@export_group("Combate IA")
@export var vida_maxima: int = 10
@export var poder_ataque: int = 1
var salud_actual: int

@onready var sprite: AnimatedSprite2D = $AnimatedSprite
@onready var rango_ataque: Area2D = $RangoAtaque 

var player: CharacterBody2D = null
var is_attacking: bool = false
var is_dead: bool = false 
var is_spawning: bool = true 
var attack_timer: float = 0.0

func _ready() -> void:
	add_to_group("enemigos")
	salud_actual = vida_maxima
	player = _obtener_jugador_mas_cercano()
	
	# Forzar Y-Sort en el caballero
	y_sort_enabled = true
	
	if sprite:
		sprite.sprite_frames.set_animation_loop("attack", false)
		sprite.sprite_frames.set_animation_loop("death", false)
	
	# Conectar ataque sí o sí
	if not rango_ataque.body_entered.is_connected(_on_rango_ataque_body_entered):
		rango_ataque.body_entered.connect(_on_rango_ataque_body_entered)
	rango_ataque.monitoring = false
	
	# FÍSICA: El enemigo está en la Capa 3 y solo choca con el mapa (Capa 1)
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_layer_value(3, true)
	set_collision_mask_value(1, true) 
	set_collision_mask_value(2, false)
	set_collision_mask_value(3, false)
	
	# COMBATE: El rango de ataque debe detectar al jugador (Capa 2)
	rango_ataque.set_collision_layer_value(1, false)
	rango_ataque.set_collision_mask_value(1, false)
	rango_ataque.set_collision_mask_value(2, true)
	rango_ataque.set_collision_mask_value(3, false)
	
	if player:
		_actualizar_orientacion(global_position.direction_to(player.global_position))
	
	_ejecutar_spawn_magico()

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

func _physics_process(delta: float) -> void:
	if is_dead or is_spawning: return
	
	# Actualizar el target siempre al jugador más cercano
	player = _obtener_jugador_mas_cercano()
	if not is_instance_valid(player): return
	
	if attack_timer > 0:
		attack_timer -= delta

	var distance = global_position.distance_to(player.global_position)
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

func _actualizar_orientacion(dir: Vector2) -> void:
	if dir.x != 0:
		sprite.flip_h = dir.x < 0
		rango_ataque.scale.x = -1 if dir.x < 0 else 1

func _update_visuals(dir: Vector2, anim: String) -> void:
	if is_attacking: return
	sprite.play(anim)
	_actualizar_orientacion(dir)

func _atacar() -> void:
	if is_attacking or is_dead: return
	is_attacking = true
	sprite.play("attack")
	
	await get_tree().create_timer(0.2).timeout
	rango_ataque.monitoring = true
	
	await sprite.animation_finished
	
	rango_ataque.monitoring = false
	is_attacking = false
	attack_timer = attack_cooldown

func recibir_dano(cantidad: int) -> void:
	if is_dead or is_spawning: return
	
	salud_actual -= cantidad
	_efecto_dano()
	
	if salud_actual <= 0:
		_morir()

func _morir() -> void:
	if is_dead: return
	is_dead = true
	
	murio.emit(global_position)
	
	set_collision_layer_value(2, false)
	set_collision_mask_value(1, false)
	rango_ataque.set_deferred("monitoring", false)
	velocity = Vector2.ZERO
	
	sprite.play("death")
	await sprite.animation_finished
	queue_free()

func _efecto_dano() -> void:
	var flash_tween = create_tween()
	sprite.modulate = Color.RED
	flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)

func _on_rango_ataque_body_entered(body: Node2D) -> void:
	if is_dead or is_spawning: return
	
	# --- LA MAGIA ESTÁ AQUÍ ---
	# Preguntamos: ¿El cuerpo que acabo de tocar es el jugador?
	if body.is_in_group("jugador"):
		if body.has_method("recibir_dano"):
			body.recibir_dano(poder_ataque)

func _obtener_jugador_mas_cercano() -> CharacterBody2D:
	var jugadores = get_tree().get_nodes_in_group("jugador")
	var mas_cercano = null
	var min_dist = INF
	for j in jugadores:
		if j is CharacterBody2D and is_instance_valid(j) and not (j.get("is_dead") == true):
			var dist = global_position.distance_to(j.global_position)
			if dist < min_dist:
				min_dist = dist
				mas_cercano = j
	return mas_cercano
