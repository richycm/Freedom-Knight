extends CharacterBody2D

@export var speed: float = 200.0

# Esta línea es la clave: busca CUALQUIER nodo que sea un AnimatedSprite2D
# así no importa si se llama "AnimatedSprite2D", "Sprite" o "CaballeroAnim"
@onready var sprite = find_child("*", true) as AnimatedSprite2D

var last_direction: String = "down"

func _physics_process(_delta: float) -> void:
	# 1. Movimiento
	var direction := Input.get_vector("left", "right", "up", "down")
	velocity = direction * speed
	move_and_slide()
	
	# 2. Animaciones (Solo si encontró el nodo sprite)
	if sprite:
		update_animations(direction)
	else:
		print("ERROR: ¡No tienes un nodo AnimatedSprite2D dentro de Caballero!")

func update_animations(direction: Vector2):
	if direction != Vector2.ZERO:
		# Prioridad horizontal para las diagonales
		if direction.x != 0:
			last_direction = "right" if direction.x > 0 else "left"
		else:
			last_direction = "down" if direction.y > 0 else "up"
		
		# Intentar reproducir animación de movimiento
		_play_if_exists("move_" + last_direction)
	else:
		# Intentar reproducir animación de idle
		_play_if_exists("idle_" + last_direction)

# Función de seguridad para que el juego no se cierre si falta una animación
func _play_if_exists(anim_name: String):
	if sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
	else:
		# Si no existe la animación, al menos imprime un aviso en la consola
		# pero NO detiene el juego.
		print("Aviso: Falta la animación: ", anim_name)
