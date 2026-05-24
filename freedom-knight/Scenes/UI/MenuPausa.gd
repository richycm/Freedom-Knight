extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_conectar_botones_recursivo(self)

func _conectar_botones_recursivo(nodo: Node) -> void:
	for child in nodo.get_children():
		if child is TextureButton or child is Button:
			child.button_down.connect(func(): child.modulate = Color(0.6, 0.6, 0.6, 1.0))
			child.button_up.connect(func(): child.modulate = Color(1.0, 1.0, 1.0, 1.0))
		_conectar_botones_recursivo(child)

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

func _on_texture_button_pressed_salir() -> void:
	get_tree().paused = false
	if NetworkManager.has_method("cleanup"):
		NetworkManager.cleanup()
	get_tree().change_scene_to_file("res://Scenes/UI/MainMenu.tscn")


func _on_texture_button_pressed_guardar() -> void:
	var player = get_tree().get_first_node_in_group("Jugador")
	if not player:
		player = get_tree().get_first_node_in_group("jugador")
	if not player:
		push_error("No se encontró el nodo del jugador para guardar.")
		return
		
	# Bloquear controles
	SaveManager.escribiendo_texto = true
	
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 100
	
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(450, 250)
	panel.add_theme_stylebox_override("panel", _crear_estilo_panel())
	overlay.add_child(panel)
	
	# Centrado forzado responsivo
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
	label.text = "¿Nombrar partida?"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(label)
	
	var input = LineEdit.new()
	input.placeholder_text = "Nombre..."
	if SaveManager.partida_actual != "":
		input.text = SaveManager.partida_actual # Sugerir sobrescribir
	input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	input.add_theme_font_size_override("font_size", 24)
	input.custom_minimum_size = Vector2(300, 50)
	input.context_menu_enabled = true
	
	var style_input = StyleBoxFlat.new()
	style_input.bg_color = Color(0, 0, 0, 0.5)
	style_input.border_width_bottom = 1
	style_input.border_color = Color(1, 1, 1, 0.5)
	input.add_theme_stylebox_override("normal", style_input)
	vbox.add_child(input)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 15)
	vbox.add_child(hbox)
	
	var btn_cancelar = Button.new()
	btn_cancelar.text = "Cancelar"
	btn_cancelar.add_theme_font_size_override("font_size", 18)
	btn_cancelar.custom_minimum_size = Vector2(120, 45)
	btn_cancelar.add_theme_stylebox_override("normal", _crear_estilo_boton(Color(0.2, 0.2, 0.2)))
	btn_cancelar.add_theme_stylebox_override("hover", _crear_estilo_boton(Color(0.3, 0.3, 0.3)))
	btn_cancelar.add_theme_stylebox_override("pressed", _crear_estilo_boton(Color(0.1, 0.1, 0.1)))
	hbox.add_child(btn_cancelar)
	
	var btn_guardar = Button.new()
	btn_guardar.text = "Guardar"
	btn_guardar.add_theme_font_size_override("font_size", 18)
	btn_guardar.custom_minimum_size = Vector2(120, 45)
	btn_guardar.add_theme_stylebox_override("normal", _crear_estilo_boton(Color(1, 1, 1, 0.1)))
	btn_guardar.add_theme_stylebox_override("hover", _crear_estilo_boton(Color(1, 1, 1, 0.2)))
	btn_guardar.add_theme_stylebox_override("pressed", _crear_estilo_boton(Color(1, 1, 1, 0.05)))
	hbox.add_child(btn_guardar)
	
	var btn_action = func():
		var nombre_partida = input.text.strip_edges()
		if nombre_partida == "":
			nombre_partida = "Autoguardado"
			
		var datos_a_guardar = {
			"escena": get_tree().current_scene.scene_file_path,
			"pos_x": player.global_position.x,
			"pos_y": player.global_position.y,
			"nivel": player.nivel if "nivel" in player else 1,
			"experiencia": player.experiencia if "experiencia" in player else 0,
			"fuerza": player.fuerza if "fuerza" in player else 0,
			"salud_actual": player.salud_actual if "salud_actual" in player else 10,
		}
		
		# Guardar progreso del escenario actual si existe
		var escenario = get_tree().current_scene
		if escenario:
			if "enemigos_derrotados" in escenario:
				datos_a_guardar["enemigos_derrotados"] = escenario.enemigos_derrotados
			if "arqueros_derrotados" in escenario:
				datos_a_guardar["arqueros_derrotados"] = escenario.arqueros_derrotados
			if "lanceros_derrotados" in escenario:
				datos_a_guardar["lanceros_derrotados"] = escenario.lanceros_derrotados
			if "oleada_actual" in escenario:
				datos_a_guardar["oleada_actual"] = escenario.oleada_actual
		
		SaveManager.guardar_datos_con_nombre(nombre_partida, datos_a_guardar)
		print("Partida guardada con éxito: " + nombre_partida)
		
		# Feedback visual
		label.text = "¡Guardado Exitoso!"
		label.add_theme_color_override("font_color", Color.GREEN)
		input.hide()
		hbox.hide()
		
		var tween = create_tween()
		tween.tween_property(overlay, "modulate:a", 0.0, 1.0).set_delay(1.0)
		tween.finished.connect(func(): 
			SaveManager.escribiendo_texto = false
			overlay.queue_free()
		)
	
	btn_guardar.pressed.connect(btn_action)
	input.text_submitted.connect(func(_t): btn_action.call())
	btn_cancelar.pressed.connect(func(): 
		SaveManager.escribiendo_texto = false
		overlay.queue_free()
	)
	
	add_child(overlay)
	
	# Asegurar mouse interactivo
	input.mouse_filter = Control.MOUSE_FILTER_STOP
	btn_guardar.mouse_filter = Control.MOUSE_FILTER_STOP
	btn_cancelar.mouse_filter = Control.MOUSE_FILTER_STOP
	
	input.grab_focus()
