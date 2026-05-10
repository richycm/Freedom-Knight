extends Node2D

@export_group("Movimiento Caballero Bueno")
@export var velocidad: float = 250.0

@export_group("Sistema de Aliados")
@export var monje_escena: PackedScene # Arrastra el Monje2.tscn aquí en el Inspector

@onready var sprite = $Caballero 

func _ready() -> void:
	y_sort_enabled = true
		# Buscamos a todos los nodos que tengan la etiqueta "CaballeroMalo"
	for enemigo in get_tree().get_nodes_in_group("CaballeroMalo"):
		if enemigo.has_signal("murio"):
			enemigo.murio.connect(_on_enemigo_murio)
			print("Conectado con éxito a: ", enemigo.name)

func _physics_process(delta: float) -> void:
	# Tu movimiento original (sin lag)
	var direccion = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if direccion != Vector2.ZERO:
		position += direccion.normalized() * velocidad * delta

	if direccion.x != 0 and sprite != null:
		sprite.flip_h = direccion.x < 0

# Esta función se activa automáticamente cuando un CaballeroMalo muere
func _on_enemigo_murio(posicion_muerte: Vector2) -> void:
	if monje_escena:
		var monje = monje_escena.instantiate()
		monje.global_position = Vector2(2335, 1145)
		add_child.call_deferred(monje) 
		
		print("Mapa: Monje programado para aparecer en el siguiente frame.")
