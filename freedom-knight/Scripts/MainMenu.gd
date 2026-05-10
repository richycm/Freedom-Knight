extends Control

@onready var music_player = $MusicPlayer

# --- RUTAS DE BOTONES ---
@onready var btn_nuevo = $NuevaPartida/TextureButton
@onready var btn_continuar = $ContinuarPartida/TextureButton
@onready var btn_prueba = $Prueba/TextureButton
@onready var btn_config = $Configuracion/TextureButton

@onready var lista_botones = [btn_nuevo, btn_continuar, btn_prueba, btn_config]

# Variable para saber qué estamos usando
var usando_mando_o_teclado = false

func _ready():
	if music_player:
		music_player.play()
		
	for boton in lista_botones:
		if boton != null:
			boton.focus_entered.connect(_oscurecer_boton.bind(boton))
			boton.focus_exited.connect(_aclarar_boton.bind(boton))

	# ¡QUITAMOS el grab_focus() inicial! 
	# Así empieza en modo Mouse/Touch y no hay ningún botón oscuro al abrir el juego.

# --- FUNCIONES DE COLOR ---
func _oscurecer_boton(boton_seleccionado):
	boton_seleccionado.modulate = Color(0.5, 0.5, 0.5) 

func _aclarar_boton(boton_seleccionado):
	boton_seleccionado.modulate = Color(1, 1, 1)

# --- LÓGICA DE ENTRADA HÍBRIDA ---
func _input(event):
	# 1. Si el usuario toca la pantalla o mueve el mouse: MODO TOUCH
	if event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventScreenTouch:
		if usando_mando_o_teclado:
			usando_mando_o_teclado = false
			var boton_actual = get_viewport().gui_get_focus_owner()
			if boton_actual:
				boton_actual.release_focus() # Quitamos la selección oscura
				
	# 2. Si el usuario presiona una tecla o mueve el joystick: MODO MANDO/TECLADO
	elif event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		# Filtro para ignorar pequeños movimientos (drift) de los joysticks viejos
		if event is InputEventJoypadMotion and abs(event.axis_value) < 0.2:
			return
			
		if not usando_mando_o_teclado:
			usando_mando_o_teclado = true
			if btn_nuevo:
				btn_nuevo.grab_focus() # Iluminamos "Nueva Partida" para empezar a navegar

	# 3. El botón "Interactuar" (¡Sin el error rojo!)
	if event.is_action_pressed("interact"):
		var boton_actual = get_viewport().gui_get_focus_owner()
		
		if boton_actual and boton_actual is BaseButton:
			boton_actual.emit_signal("pressed") 
			# ¡Eliminamos set_input_as_handled() que era el que daba el error en rojo!

# --- FUNCIONES DE LOS BOTONES ---

func _on_texture_button_pressed_nuevojuego() -> void:
	print("CLICK NUEVA PARTIDA")
	if music_player: music_player.stop()
	get_tree().change_scene_to_file("res://Scenes/Cinematica/C1_inicio.tscn")

func _on_texture_button_pressed_prueba() -> void:
	print("CLICK PRUEBA")
	if music_player: music_player.stop()
	get_tree().change_scene_to_file("res://Scenes/UI/Escenas/escenario_pruebas.tscn")

func _on_texture_button_pressed_continuarjuego() -> void:
	print("CLICK CONTINUAR")
	if SaveManager.existe_partida():
		SaveManager.cargar_y_posicionar()
	else:
		print("No hay datos guardados")

func _on_texture_button_pressed_configuracion() -> void:
	print("CLICK CONFIG")
	pass
