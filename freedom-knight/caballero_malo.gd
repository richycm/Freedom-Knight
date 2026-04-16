extends CharacterBody2D

@export_group("Configuración de IA")
@export var speed: float = 85.0
@export var stop_distance: float = 45.0
@export var turn_duration: float = 0.12
@export var attack_cooldown: float = 0.7 

@onready var sprite = find_child("*", true) as AnimatedSprite2D

var player: CharacterBody2D = null
var is_turning: bool = false
var is_attacking: bool = false 
var attack_timer: float = 0.0 # NUEVO: Control de enfriamiento matemático
var last_direction: String = "down"

func _ready() -> void:
	player = get_tree().current_scene.find_child("Caballero", true)
	
	if sprite:
		if sprite.animation_finished.is_connected(_on_animation_finished):
			sprite.animation_finished.disconnect(_on_animation_finished)
		sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float) -> void:
	if not player or is_turning:
		return
	
	# 1. ACTUALIZACIÓN DETERMINISTA: El reloj siempre avanza
	if attack_timer > 0:
		attack_timer -= delta

	var distance_to_player = global_position.distance_to(player.global_position)
	var direction_to_player = global_position.direction_to(player.global_position)

	# 2. MANEJO DE INTERRUPCIONES (Aquí estaba el bug)
	if is_attacking and distance_to_player > (stop_distance + 15.0):
		is_attacking = false
		# Si el jugador huye, penalizamos a la IA iniciando el cooldown inmediatamente
		attack_timer = attack_cooldown 

	# 3. BLOQUEO FÍSICO
	if is_attacking:
		velocity = Vector2.ZERO
		return

	# 4. RESOLUCIÓN DE ESTADOS
	if distance_to_player > stop_distance:
		velocity = direction_to_player * speed
		move_and_slide()
		update_animations(direction_to_player)
	else:
		velocity = Vector2.ZERO
		actualizar_direccion_mirada(direction_to_player)
		
		# Verificamos si el reloj llegó a cero
		if attack_timer <= 0:
			ejecutar_ataque()
		else:
			_play_if_exists("idle_" + last_direction)

func actualizar_direccion_mirada(direction: Vector2):
	if abs(direction.x) > abs(direction.y):
		last_direction = "right" if direction.x > 0 else "left"
	else:
		last_direction = "down" if direction.y > 0 else "up"

func ejecutar_ataque():
	is_attacking = true
	var anim_ataque = "attack_" + last_direction
	
	if sprite.sprite_frames.has_animation(anim_ataque):
		# REINICIO SEGURO: Detenemos la animación anterior para obligar a Godot a reproducirla desde el frame 0
		sprite.stop() 
		sprite.sprite_frames.set_animation_loop(anim_ataque, false)
		sprite.play(anim_ataque)
	else:
		push_warning("Falta animación: " + anim_ataque)
		is_attacking = false
		attack_timer = attack_cooldown

func _on_animation_finished():
	if sprite.animation.begins_with("attack"):
		is_attacking = false
		# El golpe natural terminó, iniciamos el tiempo de espera para el siguiente
		attack_timer = attack_cooldown 

# --- LÓGICA DE ANIMACIÓN Y GIRO (Sin cambios estructurales) ---

func update_animations(direction: Vector2):
	if not sprite or is_attacking: return
	
	if direction == Vector2.ZERO:
		_play_if_exists("idle_" + last_direction)
		return

	var new_dir = last_direction
	if abs(direction.x) > 0.1:
		new_dir = "right" if direction.x > 0 else "left"
	else:
		new_dir = "down" if direction.y > 0 else "up"

	if new_dir != last_direction:
		var is_x_flip = (last_direction in ["left", "right"]) and (new_dir in ["left", "right"])
		var is_y_flip = (last_direction in ["up", "down"]) and (new_dir in ["up", "down"])
		
		if is_x_flip or is_y_flip:
			ejecutar_giro_fluido(new_dir, is_x_flip)
			return 

	last_direction = new_dir
	_play_if_exists("move_" + last_direction)

func ejecutar_giro_fluido(target_dir: String, axis_horizontal: bool):
	is_turning = true
	var transition_anim: String
	
	if axis_horizontal:
		transition_anim = "idle_up" if randf() > 0.5 else "idle_down"
	else:
		transition_anim = "idle_left" if randf() > 0.5 else "idle_right"
	
	if sprite.sprite_frames.has_animation(transition_anim):
		sprite.play(transition_anim)
		sprite.frame = randi() % sprite.sprite_frames.get_frame_count(transition_anim)
		await get_tree().create_timer(turn_duration).timeout
	
	last_direction = target_dir
	is_turning = false

func _play_if_exists(anim_name: String):
	if sprite and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
