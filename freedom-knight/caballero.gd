extends CharacterBody2D

@export var speed: float = 200.0 # 400 suele ser muy rápido para sprites RPG

# Referencia al nodo de animación
@onready var sprite = $AnimatedSprite
# Variable para guardar la última dirección (por defecto hacia abajo)
var last_direction = "down"

func _physics_process(_delta: float) -> void:
	# 1. Obtener dirección
	var direction := Input.get_vector("left", "right", "up", "down")
	
	# 2. Aplicar movimiento
	velocity = direction * speed
	move_and_slide()
	
	# 3. Gestionar Animaciones
	update_animations(direction)

func update_animations(direction: Vector2):
	if direction != Vector2.ZERO:
		# El personaje se está moviendo
		if abs(direction.x) > abs(direction.y):
			# Movimiento horizontal predominante
			last_direction = "right" if direction.x > 0 else "left"
		else:
			# Movimiento vertical predominante
			last_direction = "down" if direction.y > 0 else "up"
		
		sprite.play("move_" + last_direction)
	else:
		# El personaje está quieto
		sprite.play("idle_" + last_direction)
