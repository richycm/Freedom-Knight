extends CanvasLayer

# --- REFERENCIAS ---
@onready var contenedor_corazones = $BarraVidas
@onready var controles_tactiles = $Control
@onready var boton_attack = $Control/attack  # Asegúrate de que la ruta sea correcta
@onready var boton_interact = $Control/interact # Asegúrate de que la ruta sea correcta
@onready var boton_menu = $Control/menu
var escena_menu = preload("res://Scenes/UI/MenuPausa.tscn")
var menu_pausa = null

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
	
	# Forzamos que siempre sea visible al iniciar
	controles_tactiles.show()
	
	menu_pausa = escena_menu.instantiate()
	self.call_deferred("add_child", menu_pausa)
	menu_pausa.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	menu_pausa.hide()
	menu_pausa.z_index = 999


func _process(_delta: float) -> void:
	# 1. FEEDBACK VISUAL DE BOTONES (Teclado/Control -> Pantalla)
	# Si se presiona la acción, cambiamos el color o estado del botón táctil
	_actualizar_feedback_boton(boton_attack, "attack")
	_actualizar_feedback_boton(boton_interact, "interact")
	
	# 2. FEEDBACK VISUAL DEL JOYSTICK
	# Si el jugador se mueve con WASD o el Stick del mando, movemos el "palo" visual
	if not dragging:
		# --- EL CAMBIO ESTÁ AQUÍ ---
		# Usamos "left", "right", "up", "down" (igual que en tu Caballero)
		var input_dir = Input.get_vector("left", "right", "up", "down")
		
		if input_dir != Vector2.ZERO:
			palo.position = centro_palo + (input_dir * (radio * 0.8)) # Se mueve visualmente
		else:
			palo.position = centro_palo

func _actualizar_feedback_boton(boton: TouchScreenButton, accion: String):
	if boton:
		if Input.is_action_pressed(accion):
			boton.modulate = Color(0.5, 0.5, 0.5, 1) # Se oscurece al pulsarlo (feedback)
		else:
			boton.modulate = Color(1, 1, 1, 1) # Color normal

func _input(event: InputEvent) -> void:
	# ANULADO: Ya no ocultamos nada. 
	# Los controles táctiles siempre procesan el joystick si hay toque.
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

# --- SISTEMA DE CORAZONES ---
func actualizar_vidas(salud: int) -> void:
	if not contenedor_corazones: return
	var corazones = contenedor_corazones.get_children()
	
	for i in range(corazones.size()):
		var corazon = corazones[i]
		# Cada corazón 'i' representa un rango de 2 puntos
		# Corazón 0: vida 1-2
		# Corazón 1: vida 3-4...
		var valor_base = i * 2 
		
		if salud >= valor_base + 2:
			corazon.texture = tex_lleno
		elif salud >= valor_base + 1:
			corazon.texture = tex_mitad
		else:
			corazon.texture = tex_vacio	


func _on_resume_pressed():
	menu_pausa.hide()
	get_tree().paused = false	


func _on_menu_pressed() -> void:
	if get_tree().paused:
		menu_pausa.hide()
		get_tree().paused = false
	else:
		menu_pausa.show()
		await get_tree().process_frame
		get_tree().paused = true
