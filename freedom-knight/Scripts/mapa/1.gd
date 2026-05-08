extends Node2D

@export var velocidad: float = 250.0
@onready var sprite = $Caballero 

func _ready() -> void:
	# Mantenemos la base que ya sabes que funciona sin lag
	y_sort_enabled = true

func _physics_process(delta: float) -> void:
	# 1. Obtener dirección (Usa los nombres de tus acciones en Input Map)
	var direccion = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# 2. Movimiento lineal directo (sin aceleraciones que pesen)
	if direccion != Vector2.ZERO:
		position += direccion.normalized() * velocidad * delta

	# 3. Voltear el sprite según la dirección
	if direccion.x != 0 and sprite != null:
		sprite.flip_h = direccion.x < 0
