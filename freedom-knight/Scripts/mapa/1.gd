extends Node2D # O Node2D, dependiendo de cómo lo muevas

@export var velocidad: float = 200.0

func _physics_process(_delta):
	var direccion = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if direccion.x != 0:
		$Sprite2D.flip_h = direccion.x < 0

func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
