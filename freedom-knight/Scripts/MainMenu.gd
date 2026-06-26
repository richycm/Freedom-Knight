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
var mostrando_configuracion = false
var mostrando_partidas = false

func _ready():
	if music_player:
		music_player.play()
		
	for boton in lista_botones:
		if boton != null:
			boton.focus_entered.connect(_oscurecer_boton.bind(boton))
			boton.focus_exited.connect(_aclarar_boton.bind(boton))

	# Configurar vecinos de foco explícitos para navegación con mando/teclado en cuadrícula 2x2 perfecta
	if btn_nuevo and btn_continuar and btn_prueba and btn_config:
		# Top-Left: Modo Historia (btn_nuevo)
		btn_nuevo.focus_neighbor_right = btn_prueba.get_path()
		btn_nuevo.focus_neighbor_bottom = btn_continuar.get_path()
		btn_nuevo.focus_neighbor_left = btn_prueba.get_path() # Wrap horizontal
		btn_nuevo.focus_neighbor_top = btn_continuar.get_path() # Wrap vertical
		
		# Bottom-Left: Continuar Partida (btn_continuar)
		btn_continuar.focus_neighbor_right = btn_config.get_path()
		btn_continuar.focus_neighbor_top = btn_nuevo.get_path()
		btn_continuar.focus_neighbor_left = btn_config.get_path() # Wrap horizontal
		btn_continuar.focus_neighbor_bottom = btn_nuevo.get_path() # Wrap vertical
		
		# Top-Right: Arcade (btn_prueba)
		btn_prueba.focus_neighbor_left = btn_nuevo.get_path()
		btn_prueba.focus_neighbor_bottom = btn_config.get_path()
		btn_prueba.focus_neighbor_right = btn_nuevo.get_path() # Wrap horizontal
		btn_prueba.focus_neighbor_top = btn_config.get_path() # Wrap vertical
		
		# Bottom-Right: Configuración (btn_config)
		btn_config.focus_neighbor_left = btn_continuar.get_path()
		btn_config.focus_neighbor_top = btn_prueba.get_path()
		btn_config.focus_neighbor_right = btn_continuar.get_path() # Wrap horizontal
		btn_config.focus_neighbor_bottom = btn_prueba.get_path() # Wrap vertical

	# Desactivar salir directo
	get_tree().quit_on_go_back = false

# --- FUNCIONES DE COLOR ---
func _oscurecer_boton(boton_seleccionado):
	boton_seleccionado.modulate = Color(0.5, 0.5, 0.5) 

func _aclarar_boton(boton_seleccionado):
	boton_seleccionado.modulate = Color(1, 1, 1)

# --- LÓGICA DE ENTRADA HÍBRIDA ---
func _input(event):
	if mostrando_configuracion: return
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

# --- FUNCIONES DE LOS BOTONES ---

func _on_texture_button_pressed_nuevojuego() -> void:
	if mostrando_configuracion or mostrando_partidas: return
	print("CLICK MODO HISTORIA")
	if music_player: music_player.stop()
	get_tree().change_scene_to_file("res://Scenes/Cinematica/C1_inicio.tscn")

func _on_texture_button_pressed_prueba() -> void:
	if mostrando_configuracion or mostrando_partidas: return
	print("CLICK ARCADE → ArcadeMenu")
	if music_player: music_player.stop()
	get_tree().change_scene_to_file("res://Scenes/UI/Escenas/ArcadeMenu.tscn")

func _on_texture_button_pressed_continuarjuego() -> void:
	if mostrando_configuracion or mostrando_partidas: return
	print("CLICK CONTINUAR")
	if SaveManager.existe_partida():
		_mostrar_menu_partidas()
	else:
		print("No hay datos guardados")
		var lbl = Label.new()
		lbl.text = "No hay partidas guardadas"
		lbl.add_theme_color_override("font_color", Color.RED)
		lbl.add_theme_font_size_override("font_size", 24)
		lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.offset_top = -150
		add_child(lbl)
		var tween = create_tween()
		tween.tween_property(lbl, "modulate:a", 0.0, 2.0).set_delay(1.0)
		tween.finished.connect(func(): lbl.queue_free())

func _on_texture_button_pressed_configuracion() -> void:
	if mostrando_configuracion or mostrando_partidas: return
	print("CLICK CONFIG")
	_mostrar_menu_configuracion()

# --- ESTILOS MINIMALISTAS ---
func _crear_estilo_panel() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.05, 0.9)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.5, 0.5, 0.5, 0.3)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style

func _crear_estilo_boton(color_base: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color_base
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style

func _mostrar_menu_configuracion() -> void:
	mostrando_configuracion = true
	
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.9)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 100
	
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(450, 250)
	panel.add_theme_stylebox_override("panel", _crear_estilo_panel())
	overlay.add_child(panel)
	
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)
	
	var label = Label.new()
	label.text = "CONFIGURACIÓN"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(label)
	
	var label_tag = Label.new()
	label_tag.text = "Gamertag:"
	label_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label_tag)
	
	var input = LineEdit.new()
	input.placeholder_text = "Tu nombre..."
	input.text = SaveManager.nombre_jugador
	input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	input.custom_minimum_size = Vector2(300, 45)
	
	var style_input = StyleBoxFlat.new()
	style_input.bg_color = Color(0, 0, 0, 0.5)
	style_input.border_width_bottom = 1
	style_input.border_color = Color(1, 1, 1, 0.5)
	input.add_theme_stylebox_override("normal", style_input)
	vbox.add_child(input)
	
	var btn_guardar = Button.new()
	btn_guardar.text = "Guardar y Salir"
	btn_guardar.custom_minimum_size = Vector2(200, 50)
	btn_guardar.add_theme_stylebox_override("normal", _crear_estilo_boton(Color(0.2, 0.2, 0.2)))
	btn_guardar.add_theme_stylebox_override("hover", _crear_estilo_boton(Color(0.3, 0.3, 0.3)))
	btn_guardar.add_theme_stylebox_override("pressed", _crear_estilo_boton(Color(0.1, 0.1, 0.1)))
	btn_guardar.focus_entered.connect(func(): btn_guardar.modulate = Color(0.75, 0.75, 1.0))
	btn_guardar.focus_exited.connect(func(): btn_guardar.modulate = Color(1.0, 1.0, 1.0))
	vbox.add_child(btn_guardar)
	
	# Establecer enlaces de navegación explícitos para el mando
	input.focus_neighbor_bottom = btn_guardar.get_path()
	btn_guardar.focus_neighbor_top = input.get_path()
	
	btn_guardar.pressed.connect(func():
		var nombre = input.text.strip_edges()
		if nombre == "": nombre = "Caballero"
		SaveManager.nombre_jugador = nombre
		if SaveManager.has_method("guardar_config"):
			SaveManager.call("guardar_config")
		mostrando_configuracion = false
		overlay.queue_free()
	)
	input.text_submitted.connect(func(_t): btn_guardar.emit_signal("pressed"))
	
	add_child(overlay)
	input.grab_focus()

func _mostrar_menu_partidas() -> void:
	mostrando_partidas = true
	var partidas = SaveManager.obtener_lista_partidas()
	
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 1.0) # Totalmente opaco
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 100
	add_child(overlay)
	
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(480, 320) # Tamaño base
	panel.add_theme_stylebox_override("panel", _crear_estilo_panel())
	overlay.add_child(panel)
	
	# Centrado forzado responsivo
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 15)
	panel.add_child(main_vbox)
	
	var titulo = Label.new()
	titulo.text = "PARTIDAS"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 24)
	titulo.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	main_vbox.add_child(titulo)
	
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 200) # Más pequeño para dar espacio al botón
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)
	
	var list_vbox = VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 15)
	scroll.add_child(list_vbox)
	
	for partida in partidas:
		var item_hbox = HBoxContainer.new()
		item_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_hbox.add_theme_constant_override("separation", 5)
		
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 60)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.add_theme_stylebox_override("normal", _crear_estilo_boton(Color(1, 1, 1, 0.05)))
		btn.add_theme_stylebox_override("hover", _crear_estilo_boton(Color(1, 1, 1, 0.1)))
		btn.add_theme_stylebox_override("pressed", _crear_estilo_boton(Color(1, 1, 1, 0.02)))
		
		var modo = partida.get("modo", "Historia")
		var texto = "[%s] %s - %s" % [modo.to_upper(), partida.get("nombre_partida", "Auto"), partida.get("fecha", "")]
		btn.text = texto
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		
		btn.pressed.connect(func():
			overlay.queue_free()
			mostrando_partidas = false
			if music_player: music_player.stop()
			SaveManager.cargar_y_posicionar_datos(partida)
		)
		
		var btn_borrar = Button.new()
		btn_borrar.text = "X"
		btn_borrar.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
		btn_borrar.add_theme_font_size_override("font_size", 16)
		btn_borrar.custom_minimum_size = Vector2(40, 60)
		btn_borrar.mouse_filter = Control.MOUSE_FILTER_STOP
		
		btn_borrar.add_theme_stylebox_override("normal", _crear_estilo_boton(Color(0.1, 0.1, 0.1)))
		btn_borrar.add_theme_stylebox_override("hover", _crear_estilo_boton(Color(0.3, 0.1, 0.1)))
		btn_borrar.add_theme_stylebox_override("pressed", _crear_estilo_boton(Color(0.2, 0.05, 0.05)))
		
		btn_borrar.pressed.connect(func():
			if not is_instance_valid(item_hbox): return
			btn_borrar.disabled = true
			SaveManager.borrar_partida(partida.get("archivo", ""))
			var t = create_tween()
			t.tween_property(item_hbox, "modulate:a", 0.0, 0.3)
			t.finished.connect(func(): 
				if is_instance_valid(item_hbox):
					item_hbox.queue_free()
			)
		)
		
		item_hbox.add_child(btn)
		item_hbox.add_child(btn_borrar)
		list_vbox.add_child(item_hbox)
		
	var btn_cerrar = Button.new()
	btn_cerrar.text = "Volver al Menú"
	btn_cerrar.add_theme_font_size_override("font_size", 18)
	btn_cerrar.custom_minimum_size = Vector2(0, 45)
	btn_cerrar.mouse_filter = Control.MOUSE_FILTER_STOP
	btn_cerrar.add_theme_stylebox_override("normal", _crear_estilo_boton(Color(0.2, 0.2, 0.2)))
	btn_cerrar.add_theme_stylebox_override("hover", _crear_estilo_boton(Color(0.3, 0.3, 0.3)))
	btn_cerrar.add_theme_stylebox_override("pressed", _crear_estilo_boton(Color(0.1, 0.1, 0.1)))
	btn_cerrar.pressed.connect(func(): 
		var t = create_tween()
		t.tween_property(overlay, "modulate:a", 0.0, 0.2)
		t.finished.connect(func(): 
			mostrando_partidas = false
			overlay.queue_free()
		)
	)
	main_vbox.add_child(btn_cerrar)
	
	# Animación entrada
	overlay.modulate.a = 0
	create_tween().tween_property(overlay, "modulate:a", 1.0, 0.2)


# --- FIN DEL SCRIPT ---
