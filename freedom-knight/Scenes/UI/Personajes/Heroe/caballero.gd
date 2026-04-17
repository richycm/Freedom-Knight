extends CharacterBody2D

const ANIM_IDLE = "idle"
const ANIM_MOVE = "move"
const ANIM_ATTACK = "attack"

@export_group("Movimiento")
@export var speed: float = 200.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite

var is_attacking: bool = false

func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("left", "right", "up", "down")
	
	# 1. ENTRADA DE ATAQUE
	if Input.is_action_just_pressed("attack") and not is_attacking:
		_execute_attack()

	# 2. PROCESAMIENTO DE VELOCIDAD
	# Si ataca, velocidad cero. Si no, movemos normal.
	if is_attacking:
		velocity = Vector2.ZERO
	else:
		velocity = direction * speed
	
	move_and_slide()
	
	# 3. ACTUALIZACIÓN VISUAL (Solo si no está bloqueado por ataque)
	if not is_attacking:
		_update_animations(direction)

func _update_animations(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		sprite.play(ANIM_IDLE)
	else:
		sprite.play(ANIM_MOVE)
		
		# Lógica de Orientación (Flip)
		# Solo cambia el flip si hay movimiento en X. 
		# Si solo te mueves en Y, mantiene el último flip horizontal.
		if direction.x > 0:
			sprite.flip_h = false # Derecha
		elif direction.x < 0:
			sprite.flip_h = true  # Izquierda

func _execute_attack() -> void:
	# 1. Bloqueo inmediato de estado
	is_attacking = true
	
	# 2. Configuración forzada por código (Ingeniería de control)
	# Esto sobreescribe cualquier configuración errónea que tengas en el editor
	sprite.sprite_frames.set_animation_loop(ANIM_ATTACK, false)
	
	# 3. Reinicio y ejecución
	sprite.stop() # Detenemos cualquier animación previa
	sprite.play(ANIM_ATTACK)
	
	# 4. Espera reactiva
	# Usamos la señal directamente ahora que aseguramos que el loop es falso
	await sprite.animation_finished
	
	# 5. Liberación de estado
	is_attacking = false
