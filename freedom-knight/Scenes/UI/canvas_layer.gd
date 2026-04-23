extends CanvasLayer

# --- REFERENCIAS ---
@onready var contenedor_corazones = $BarraVidas
@onready var controles_tactiles = $Control # Nodo que agrupa Joystick y Botón Attack

# --- RUTAS DE IMÁGENES ---
var tex_lleno = preload("res://Scenes/Efectos/corazon uno.png")
var tex_mitad = preload("res://Scenes/Efectos/Corazon medio.png")
var tex_vacio = preload("res://Scenes/Efectos/corazon vacio.png")

# --- VARIABLES JOYSTICK ---
@onready var palo = $Control/VirtualJoystick/Palo
@onready var base = $Control/VirtualJoystick/Base
var radio = 60.0 
var direccion = Vector2.ZERO
var dragging = false
var touch_index: int = -1 
var centro_palo = Vector2(-27.333, -34.667)

func _ready() -> void:
	if palo:
		palo.position = centro_palo
	
	# Al inicio mostramos los botones por si acaso
	controles_tactiles.show()

func _input(event: InputEvent) -> void:
	# 1. DETECTAR TIPO DE ENTRADA PARA MOSTRAR/OCULTAR UI
	
	# Si toca la pantalla (Touch), mostramos los controles
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if not controles_tactiles.visible:
			controles_tactiles.show()
	
	# Si presiona una tecla o mueve un stick de mando, los ocultamos
	elif event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		# Filtramos un poco el movimiento del Joypad para que no se oculte por error 
		# si el stick tiene un poquito de "drift"
		if event is InputEventJoypadMotion and abs(event.axis_value) < 0.2:
			return
			
		if controles_tactiles.visible:
			controles_tactiles.hide()

	# 2. LÓGICA DEL JOYSTICK (Solo si la UI es visible)
	if controles_tactiles.visible:
		_procesar_joystick(event)

func _procesar_joystick(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not dragging:
			var dist = base.global_position.distance_to(event.position)
			if dist < radio * 2:
				dragging = true
				touch_index = event.index 
				
		elif not event.pressed and event.index == touch_index:
			dragging = false
			touch_index = -1 
			direccion = Vector2.ZERO
			var tween = create_tween()
			tween.tween_property(palo, "position", centro_palo, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if event is InputEventScreenDrag and dragging and event.index == touch_index:
		var centro_global = base.global_position
		var vector = event.position - centro_global
		var vector_limitado = vector.limit_length(radio)
		
		palo.position = centro_palo + vector_limitado
		direccion = vector_limitado.normalized()

# --- SISTEMA DE CORAZONES (Siempre visible) ---
func actualizar_vidas(salud: int) -> void:
	if not contenedor_corazones: return
	var corazones = contenedor_corazones.get_children()
	for i in range(corazones.size()):
		var corazon = corazones[i]
		var valor_minimo = i * 2 
		if salud >= valor_minimo + 2:
			corazon.texture = tex_lleno
		elif salud >= valor_minimo + 1:
			corazon.texture = tex_mitad
		else:
			corazon.texture = tex_vacio
