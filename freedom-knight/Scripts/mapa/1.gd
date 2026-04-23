extends Node2D 

@export var velocidad: float = 200.0

# Usamos @onready para asegurar que el nodo esté listo antes de usarlo.
# ¡IMPORTANTE!: Cambia "Sprite2D" por el nombre real de tu nodo de imagen.
@onready var sprite = $Sprite2D 

func _physics_process(delta: float) -> void:
	# 1. Obtener dirección
	var direccion = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# 2. Voltear el sprite según la dirección
	if direccion.x != 0 and sprite != null:
		sprite.flip_h = direccion.x < 0
		
	# 3. Mover el personaje (indispensable en Node2D)
	# Multiplicamos por delta para que el movimiento sea fluido y no dependa de los FPS
	position += direccion * velocidad * delta

func _ready() -> void:
	# Verificación de seguridad para que no crashee si el nombre está mal
	if sprite == null:
		print("ERROR: No se encontró el nodo del Sprite. Revisa el nombre en el script.")

func _process(_delta: float) -> void:
	pass
