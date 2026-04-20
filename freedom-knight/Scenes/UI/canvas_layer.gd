extends CanvasLayer

@onready var palo = $Control/VirtualJoystick/Palo
@onready var base = $Control/VirtualJoystick/Base

# --- CONFIGURACIÓN ---
var radio = 60.0 
var direccion = Vector2.ZERO
var dragging = false

# EL SECRETO MULTITOUCH: Guardar qué dedo específico está usando el joystick
var touch_index: int = -1 

# Tus coordenadas exactas de centrado
var centro_palo = Vector2(-27.333, -34.667)

func _ready() -> void:
	# Colocamos el palo en su centro real al iniciar
	palo.position = centro_palo

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not dragging:
			# Calculamos distancia al centro de la base
			var dist = base.global_position.distance_to(event.position)
			if dist < radio * 2:
				dragging = true
				touch_index = event.index # Guardamos el ID de este dedo específico
				
		# Solo soltamos el joystick SI el dedo que se levanta es el nuestro
		elif not event.pressed and event.index == touch_index:
			dragging = false
			touch_index = -1 # Borramos la memoria del dedo
			direccion = Vector2.ZERO
			var tween = create_tween()
			tween.tween_property(palo, "position", centro_palo, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Solo movemos el palo si el dedo que se arrastra es el que lo agarró
	if event is InputEventScreenDrag and dragging and event.index == touch_index:
		var centro_global = base.global_position
		var vector = event.position - centro_global
		var vector_limitado = vector.limit_length(radio)
		
		# Aplicamos el movimiento sumando tu offset para que no se desplace
		palo.position = centro_palo + vector_limitado
		
		# Guardamos la dirección para el caballero
		direccion = vector_limitado.normalized()
