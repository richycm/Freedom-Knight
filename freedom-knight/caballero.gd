extends CharacterBody2D

@export_group("Ajustes de Movimiento")
@export var speed: float = 200.0
@export var attack_speed_multiplier: float = 0.2
@export var pos_x: float = -12.0
@export var pos_y: float = 120.0
@export var turn_duration: float = 0.12 

@onready var sprite = find_child("*", true) as AnimatedSprite2D

var is_attacking: bool = false
var is_turning: bool = false 
var last_direction: String = "down"

func _ready():
	if sprite:
		sprite.position = Vector2(pos_x, pos_y)
		# IMPORTANTE: Asegúrate de que la señal esté conectada una sola vez
		if not sprite.animation_finished.is_connected(_on_finish):
			sprite.animation_finished.connect(_on_finish)

func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("left", "right", "up", "down")
	
	if Input.is_action_just_pressed("attack") and not is_attacking:
		iniciar_ataque()

	var current_speed = speed
	if is_attacking:
		current_speed = speed * attack_speed_multiplier
	
	velocity = direction * current_speed
	move_and_slide()
	
	# El ataque tiene prioridad absoluta sobre el giro y el movimiento
	if not is_attacking and not is_turning:
		update_animations(direction)

# --- LÓGICA DE ATAQUE ---

func iniciar_ataque():
	is_attacking = true
	var anim_ataque = "attack_" + last_direction
	
	if sprite and sprite.sprite_frames.has_animation(anim_ataque):
		# SOLUCIÓN TÉCNICA: Forzamos que el ataque NO sea un bucle por código
		# Esto evita que el personaje se quede trabado si olvidaste quitar el loop en el editor
		sprite.sprite_frames.set_animation_loop(anim_ataque, false)
		sprite.play(anim_ataque)
	else:
		# Si no existe la animación, liberamos el estado inmediatamente
		is_attacking = false

func _on_finish():
	# Verificamos que lo que terminó sea un ataque antes de liberar el estado
	if is_attacking:
		is_attacking = false
		# Forzamos actualización de animaciones tras el ataque
		var direction := Input.get_vector("left", "right", "up", "down")
		update_animations(direction)

# --- LÓGICA DE MOVIMIENTO Y TRANSICIÓN ---

func update_animations(direction: Vector2):
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
	if is_attacking: return # Seguridad: No girar si estamos atacando
	
	is_turning = true
	var transition_anim: String
	
	if axis_horizontal:
		transition_anim = "idle_up" if randf() > 0.5 else "idle_down"
	else:
		transition_anim = "idle_left" if randf() > 0.5 else "idle_right"
	
	if sprite and sprite.sprite_frames.has_animation(transition_anim):
		sprite.play(transition_anim)
		var max_frames = sprite.sprite_frames.get_frame_count(transition_anim)
		sprite.frame = randi() % max_frames
		
		await get_tree().create_timer(turn_duration).timeout
	
	is_turning = false
	last_direction = target_dir
	
	# Al terminar el giro, si el jugador ya inició un ataque, no forzamos 'move'
	if not is_attacking:
		var current_dir = Input.get_vector("left", "right", "up", "down")
		update_animations(current_dir)

func _play_if_exists(anim_name: String):
	if sprite and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
