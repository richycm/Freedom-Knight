extends CharacterBody2D

@export_group("Configuración de IA")
@export var speed: float = 110.0 # Un poco más lento para que el jugador pueda escapar
@export var stop_distance: float = 45.0
@export var turn_duration: float = 0.12 # Duración del frame de transición

@onready var sprite = find_child("*", true) as AnimatedSprite2D

var player: CharacterBody2D = null
var is_turning: bool = false
var last_direction: String = "down"

func _ready() -> void:
	# IMPORTANTE: Tu nodo jugador en la escena debe llamarse exactamente "Caballero"
	player = get_tree().current_scene.find_child("Caballero", true)
	
	if not player:
		push_warning("IA Error: No se encontró al nodo 'Caballero'. Revisa el nombre en la escena.")

func _physics_process(_delta: float) -> void:
	if not player or is_turning:
		return
	
	# 1. CÁLCULO DE DIRECCIÓN HACIA EL JUGADOR
	var direction_to_player = global_position.direction_to(player.global_position)
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# 2. LÓGICA DE MOVIMIENTO
	if distance_to_player > stop_distance:
		velocity = direction_to_player * speed
		move_and_slide()
		update_animations(direction_to_player)
	else:
		velocity = Vector2.ZERO
		update_animations(Vector2.ZERO)

# --- LÓGICA DE ANIMACIÓN Y GIRO ---

func update_animations(direction: Vector2):
	if not sprite: return
	
	if direction == Vector2.ZERO:
		_play_if_exists("idle_" + last_direction)
		return

	var new_dir = last_direction
	
	# PRIORIDAD LATERAL: Si hay movimiento en X, manda X (Perfil)
	if abs(direction.x) > 0.1:
		new_dir = "right" if direction.x > 0 else "left"
	else:
		new_dir = "down" if direction.y > 0 else "up"

	# DETECCIÓN DE GIRO (180 grados)
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
	
	# Elegir frame de giro aleatorio según el eje
	if axis_horizontal:
		transition_anim = "idle_up" if randf() > 0.5 else "idle_down"
	else:
		transition_anim = "idle_left" if randf() > 0.5 else "idle_right"
	
	if sprite.sprite_frames.has_animation(transition_anim):
		sprite.play(transition_anim)
		# Frame aleatorio dentro de la animación de transición
		sprite.frame = randi() % sprite.sprite_frames.get_frame_count(transition_anim)
		
		# Pausa para que se vea el giro
		await get_tree().create_timer(turn_duration).timeout
	
	last_direction = target_dir
	is_turning = false
	
	# Al terminar el giro, re-evaluamos la animación
	if player:
		var current_dir = global_position.direction_to(player.global_position)
		update_animations(current_dir)

func _play_if_exists(anim_name: String):
	if sprite and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
