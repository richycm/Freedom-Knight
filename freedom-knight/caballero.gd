extends CharacterBody2D

@export_group("Ajustes de Movimiento")
@export var speed: float = 200.0
@export var attack_speed_multiplier: float = 0.2 # Se moverá al 20% de su velocidad
@export var pos_x: float = -12.0
@export var pos_y: float = 120.0

@onready var sprite = find_child("*", true) as AnimatedSprite2D

var is_attacking: bool = false
var last_direction: String = "down"

func _ready():
	if sprite:
		sprite.position = Vector2(pos_x, pos_y)
		# Conectamos la señal una sola vez aquí para mayor eficiencia
		sprite.animation_finished.connect(_on_finish)

func _physics_process(_delta: float) -> void:
	# 1. ENTRADA DE MOVIMIENTO
	var direction := Input.get_vector("left", "right", "up", "down")
	
	# 2. ATAQUE (Space o tu acción "attack")
	if Input.is_action_just_pressed("attack") and not is_attacking:
		iniciar_ataque()

	# 3. LÓGICA DE VELOCIDAD
	var current_speed = speed
	if is_attacking:
		current_speed = speed * attack_speed_multiplier
	
	velocity = direction * current_speed
	move_and_slide()
	
	# 4. ACTUALIZAR ANIMACIONES (Solo si no está atacando)
	if not is_attacking:
		update_animations(direction)

# --- LÓGICA DE ATAQUE ---

func iniciar_ataque():
	is_attacking = true
	
	# Construimos el nombre de la animación según la última dirección:
	# attack_up, attack_down, attack_left, attack_right
	var anim_ataque = "attack_" + last_direction
	
	if sprite and sprite.sprite_frames.has_animation(anim_ataque):
		sprite.sprite_frames.set_animation_loop(anim_ataque, false)
		sprite.play(anim_ataque)
	else:
		# Si la animación específica no existe, usamos una por defecto o terminamos
		_on_finish()

func _on_finish():
	# Solo resetear si la animación que terminó era un ataque
	if sprite and sprite.animation.begins_with("attack"):
		is_attacking = false
		update_animations(Vector2.ZERO)

# --- ANIMACIONES DE MOVIMIENTO ---

func update_animations(direction: Vector2):
	if direction != Vector2.ZERO:
		# Prioridad lateral: si hay X, manda X.
		if abs(direction.x) > 0.1:
			last_direction = "right" if direction.x > 0 else "left"
		else:
			last_direction = "down" if direction.y > 0 else "up"
		
		_play_if_exists("move_" + last_direction)
	else:
		_play_if_exists("idle_" + last_direction)

func _play_if_exists(anim_name: String):
	if sprite and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
