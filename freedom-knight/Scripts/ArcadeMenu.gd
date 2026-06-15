## ============================================================
##  ArcadeMenu.gd — Freedom Knight
##  Pantalla de selección Arcade: Solitario / Multijugador
##  Diseño glassmorphism oscuro. Sin dependencias de red hasta
##  que el jugador elija Multijugador.
## ============================================================
extends Control

# ─────────────────────────────────────────────────────────────
#  CONSTANTES DE ESCENAS
# ─────────────────────────────────────────────────────────────
const SCENE_SOLO       = "res://Scenes/UI/Escenas/escenario_pruebas.tscn"
const SCENE_MAIN_MENU  = "res://Scenes/UI/MainMenu.tscn"

# ─────────────────────────────────────────────────────────────
#  PALETA DE COLORES
# ─────────────────────────────────────────────────────────────
const COL_BG_DARK    := Color(0.04, 0.04, 0.08, 1.0)
const COL_PANEL      := Color(0.10, 0.10, 0.18, 0.88)
const COL_BORDER     := Color(0.40, 0.40, 0.80, 0.30)
const COL_ACCENT     := Color(0.35, 0.55, 1.00, 1.00)
const COL_ACCENT2    := Color(0.55, 0.30, 1.00, 1.00)
const COL_TEXT       := Color(0.90, 0.92, 1.00, 1.00)
const COL_SUBTEXT    := Color(0.60, 0.62, 0.78, 1.00)
const COL_BTN_HOVER  := Color(0.20, 0.20, 0.36, 0.95)
const COL_BTN_PRESS  := Color(0.12, 0.12, 0.24, 0.95)
const COL_SUCCESS    := Color(0.30, 0.85, 0.55, 1.00)
const COL_WARNING    := Color(1.00, 0.75, 0.20, 1.00)
const COL_DANGER     := Color(0.90, 0.30, 0.30, 1.00)

# ─────────────────────────────────────────────────────────────
#  STATE
# ─────────────────────────────────────────────────────────────
var _host_list_container : VBoxContainer    = null
var _status_label        : Label            = null
var _start_btn           : Button           = null
var _panel_mp            : Control          = null
var _host_scroll         : ScrollContainer  = null  # referencia directa, evita find_child
var _discovery_active    : bool             = false
var _connecting          : bool             = false
var _transitioning       : bool             = false

var _panel_diff          : Control          = null
var _panel_main          : Control          = null
var _diff_knight_tex     : TextureRect      = null
var _btn_facil           : Button           = null
var _btn_medio           : Button           = null
var _btn_dificil         : Button           = null
var _btn_start_solo      : Button           = null
var _selected_diff       : int              = 1

var _tex_facil = preload("res://Imagenes/Dificultad facil.png")
var _tex_medio = preload("res://Imagenes/Dificultad medio.png")
var _tex_dificil = preload("res://Imagenes/Dificultad dificil.png")

var _btn_solo            : Button           = null
var _btn_mp              : Button           = null
var _btn_back            : Button           = null
var _btn_host            : Button           = null
var _btn_join            : Button           = null
var _usando_mando_o_teclado: bool           = false

# ─────────────────────────────────────────────────────────────
#  LIFECYCLE
# ─────────────────────────────────────────────────────────────
func _ready() -> void:
	NetworkManager.cleanup()
	PlayerRegistry.clear()
	_build_ui()

func _exit_tree() -> void:
	_stop_discovery()
	NetworkManager.connection_succeeded.disconnect(_on_connection_succeeded)
	NetworkManager.connection_failed.disconnect(_on_connection_failed)
	NetworkManager.host_list_updated.disconnect(_on_host_list_updated)

# ─────────────────────────────────────────────────────────────
#  UI BUILDER
# ─────────────────────────────────────────────────────────────
func _build_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = COL_BG_DARK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Animated gradient overlay
	var grad = _make_gradient_overlay()
	add_child(grad)

	# Center container
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	center.add_child(vbox)

	# Title
	_add_title(vbox)

	# Panels horizontal container
	var panels_hbox = HBoxContainer.new()
	panels_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panels_hbox.add_theme_constant_override("separation", 24)
	vbox.add_child(panels_hbox)

	# Main panel
	_panel_main = _make_glass_panel(Vector2(450, 0))
	panels_hbox.add_child(_panel_main)
	var panel_inner = VBoxContainer.new()
	panel_inner.add_theme_constant_override("separation", 20)
	_panel_main.add_child(panel_inner)

	_add_section_label(panel_inner, "SELECCIONA MODO DE JUEGO")

	# Solitario button
	_btn_solo = _make_mode_button(
		"⚔  SOLITARIO",
		"Juega solo contra oleadas de enemigos",
		COL_ACCENT
	)
	_btn_solo.pressed.connect(_on_solo_pressed)
	panel_inner.add_child(_btn_solo)
	_connect_focus_feedback(_btn_solo)

	# Multijugador button
	_btn_mp = _make_mode_button(
		"🌐  MULTIJUGADOR",
		"Juega en LAN con amigos en la misma red",
		COL_ACCENT2
	)
	_btn_mp.pressed.connect(_on_multiplayer_pressed)
	panel_inner.add_child(_btn_mp)
	_connect_focus_feedback(_btn_mp)

	# Back button
	_btn_back = _make_small_button("← Volver al Menú")
	_btn_back.pressed.connect(_on_back_pressed)
	panel_inner.add_child(_btn_back)
	_connect_focus_feedback(_btn_back)

	# Multiplayer sub-panel (hidden initially)
	_panel_mp = _build_multiplayer_panel()
	_panel_mp.visible = false
	panels_hbox.add_child(_panel_mp)
	
	# Difficulty sub-panel (hidden initially)
	_panel_diff = _build_difficulty_panel()
	_panel_diff.visible = false
	add_child(_panel_diff)

	# Connect network signals
	NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.host_list_updated.connect(_on_host_list_updated)
	NetworkManager.game_start_requested.connect(_on_game_start)

	# Entrance animation
	modulate.a = 0.0
	var t = create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)

func _make_gradient_overlay() -> Control:
	var c = ColorRect.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.color = Color(0, 0, 0, 0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Subtle radial vignette simulation with a dark border
	c.material = null
	return c

func _add_title(parent: Control) -> void:
	var lbl = Label.new()
	lbl.text = "ARCADE"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 52)
	lbl.add_theme_color_override("font_color", COL_ACCENT)
	lbl.add_theme_color_override("font_outline_color", COL_ACCENT2)
	lbl.add_theme_constant_override("outline_size", 6)
	parent.add_child(lbl)

	var sub = Label.new()
	sub.text = "Freedom Knight"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", COL_SUBTEXT)
	parent.add_child(sub)

func _add_section_label(parent: Control, text: String) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", COL_SUBTEXT)
	parent.add_child(lbl)

func _make_glass_panel(min_size: Vector2 = Vector2(0, 0)) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if min_size != Vector2.ZERO:
		panel.custom_minimum_size = min_size

	var style = StyleBoxFlat.new()
	style.bg_color = COL_PANEL
	style.border_width_left   = 1
	style.border_width_right  = 1
	style.border_width_top    = 1
	style.border_width_bottom = 1
	style.border_color = COL_BORDER
	style.corner_radius_top_left     = 16
	style.corner_radius_top_right    = 16
	style.corner_radius_bottom_left  = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left   = 28
	style.content_margin_right  = 28
	style.content_margin_top    = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _make_mode_button(title: String, subtitle: String, accent: Color) -> Button:
	var btn = Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 80)
	btn.text = ""  # We'll use a custom layout via label

	# Style
	var s_normal = _make_btn_style(COL_PANEL.darkened(0.1))
	s_normal.border_color = accent.darkened(0.3)
	s_normal.border_width_left   = 2
	s_normal.border_width_bottom = 2
	var s_hover  = _make_btn_style(COL_BTN_HOVER)
	s_hover.border_color = accent
	s_hover.border_width_left   = 3
	s_hover.border_width_bottom = 3
	var s_press  = _make_btn_style(COL_BTN_PRESS)
	btn.add_theme_stylebox_override("normal", s_normal)
	btn.add_theme_stylebox_override("hover",  s_hover)
	btn.add_theme_stylebox_override("pressed", s_press)

	# Inner VBox layout
	var inner = VBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.add_child(inner)

	var lbl_title = Label.new()
	lbl_title.text = title
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_size_override("font_size", 22)
	lbl_title.add_theme_color_override("font_color", COL_TEXT)
	lbl_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(lbl_title)

	var lbl_sub = Label.new()
	lbl_sub.text = subtitle
	lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sub.add_theme_font_size_override("font_size", 12)
	lbl_sub.add_theme_color_override("font_color", COL_SUBTEXT)
	lbl_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(lbl_sub)

	return btn

func _make_small_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", COL_SUBTEXT)
	var s = _make_btn_style(Color(0,0,0,0))
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("hover", _make_btn_style(Color(1,1,1,0.06)))
	btn.add_theme_stylebox_override("pressed", _make_btn_style(Color(1,1,1,0.02)))
	return btn

func _make_btn_style(bg: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_radius_top_left     = 10
	s.corner_radius_top_right    = 10
	s.corner_radius_bottom_left  = 10
	s.corner_radius_bottom_right = 10
	s.content_margin_left   = 12
	s.content_margin_right  = 12
	s.content_margin_top    = 8
	s.content_margin_bottom = 8
	return s

# ─────────────────────────────────────────────────────────────
#  MULTIPLAYER PANEL
# ─────────────────────────────────────────────────────────────
func _build_multiplayer_panel() -> Control:
	var panel = _make_glass_panel(Vector2(450, 0))

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	_add_section_label(vbox, "MULTIJUGADOR LAN")

	# Two sub-buttons: Host / Join
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)

	_btn_host = _make_action_btn("🛡  SER HOST", COL_ACCENT)
	_btn_host.pressed.connect(_on_host_pressed)
	_btn_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_btn_host)
	_connect_focus_feedback(_btn_host)

	_btn_join = _make_action_btn("🔍  UNIRSE", COL_ACCENT2)
	_btn_join.pressed.connect(_on_join_pressed)
	_btn_join.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_btn_join)
	_connect_focus_feedback(_btn_join)

	# Status label
	_status_label = Label.new()
	_status_label.text = "Selecciona una opción."
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", COL_SUBTEXT)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_status_label)

	# Host list scroll area (hidden until join)
	_host_scroll = ScrollContainer.new()
	_host_scroll.custom_minimum_size = Vector2(0, 180)
	_host_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_host_scroll.visible = false
	_host_scroll.name = "HostScroll"
	vbox.add_child(_host_scroll)

	_host_list_container = VBoxContainer.new()
	_host_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_host_list_container.add_theme_constant_override("separation", 8)
	_host_scroll.add_child(_host_list_container)

	# Start game button (host only, hidden initially)
	_start_btn = _make_action_btn("▶  INICIAR PARTIDA", COL_SUCCESS)
	_start_btn.pressed.connect(_on_start_game_pressed)
	_start_btn.visible = false
	vbox.add_child(_start_btn)
	_connect_focus_feedback(_start_btn)

	# Gamertag info
	var gt_label = Label.new()
	gt_label.text = "Tu gamertag: %s" % (SaveManager.nombre_jugador if SaveManager.nombre_jugador != "" else "Caballero")
	gt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gt_label.add_theme_font_size_override("font_size", 11)
	gt_label.add_theme_color_override("font_color", COL_SUBTEXT)
	vbox.add_child(gt_label)

	return panel

func _make_action_btn(text: String, accent: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 52)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", COL_TEXT)
	var s_n = _make_btn_style(accent.darkened(0.4))
	s_n.border_color = accent.darkened(0.1)
	s_n.border_width_bottom = 2
	var s_h = _make_btn_style(accent.darkened(0.2))
	var s_p = _make_btn_style(accent.darkened(0.6))
	btn.add_theme_stylebox_override("normal", s_n)
	btn.add_theme_stylebox_override("hover",  s_h)
	btn.add_theme_stylebox_override("pressed", s_p)
	return btn

# ─────────────────────────────────────────────────────────────
#  DIFFICULTY PANEL (FULL SCREEN IMAGE)
# ─────────────────────────────────────────────────────────────
func _build_difficulty_panel() -> Control:
	var panel = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_diff_knight_tex = TextureRect.new()
	_diff_knight_tex.texture = _tex_medio
	_diff_knight_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_diff_knight_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_diff_knight_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(_diff_knight_tex)

	# Basado en las proporciones de la imagen 16:9
	_btn_facil = _make_inv_btn(0.35, 0.65, 0.38, 0.52)
	_btn_facil.pressed.connect(_on_diff_facil_pressed)

	_btn_medio = _make_inv_btn(0.35, 0.65, 0.54, 0.68)
	_btn_medio.pressed.connect(_on_diff_medio_pressed)

	_btn_dificil = _make_inv_btn(0.35, 0.65, 0.70, 0.84)
	_btn_dificil.pressed.connect(_on_diff_dificil_pressed)

	_btn_start_solo = _make_inv_btn(0.35, 0.49, 0.86, 0.94)
	_btn_start_solo.pressed.connect(_on_start_solo_pressed)

	var btn_diff_back = _make_inv_btn(0.51, 0.65, 0.86, 0.94)
	btn_diff_back.pressed.connect(_on_diff_back_pressed)

	return panel

func _make_inv_btn(left: float, right: float, top: float, bottom: float) -> Button:
	var b = Button.new()
	b.flat = true
	# Para que no tenga fondo ni bordes por defecto, solo el outline de focus
	b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.anchor_left = left
	b.anchor_right = right
	b.anchor_top = top
	b.anchor_bottom = bottom
	b.offset_left = 0
	b.offset_right = 0
	b.offset_top = 0
	b.offset_bottom = 0
	
	# Cursor de click
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_diff_knight_tex.add_child(b)
	return b

func _actualizar_imagen_dificultad(idx: int) -> void:
	if not _diff_knight_tex: return
	_selected_diff = idx
	if idx == 0:
		_diff_knight_tex.texture = _tex_facil
	elif idx == 1:
		_diff_knight_tex.texture = _tex_medio
	elif idx == 2:
		_diff_knight_tex.texture = _tex_dificil

# ─────────────────────────────────────────────────────────────
#  HOST LIST ENTRIES
# ─────────────────────────────────────────────────────────────
func _rebuild_host_list() -> void:
	for child in _host_list_container.get_children():
		child.queue_free()

	var hosts = NetworkManager.get_known_hosts()

	if hosts.is_empty():
		var lbl = Label.new()
		lbl.text = "Buscando partidas en la red local..."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", COL_SUBTEXT)
		lbl.add_theme_font_size_override("font_size", 13)
		_host_list_container.add_child(lbl)
		return

	for ip in hosts:
		var info = hosts[ip]
		var entry = _make_host_entry(ip, info)
		_host_list_container.add_child(entry)

func _make_host_entry(ip: String, info: Dictionary) -> Control:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.12, 0.12, 0.22, 0.9)
	s.border_color = COL_BORDER
	s.border_width_left   = 1
	s.border_width_bottom = 1
	s.corner_radius_top_left     = 8
	s.corner_radius_top_right    = 8
	s.corner_radius_bottom_left  = 8
	s.corner_radius_bottom_right = 8
	s.content_margin_left   = 12
	s.content_margin_right  = 12
	s.content_margin_top    = 8
	s.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", s)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	# Status dot
	var dot = Label.new()
	var is_lobby = info.get("state", "lobby") == "lobby"
	dot.text = "🟢" if is_lobby else "🔴"
	dot.add_theme_font_size_override("font_size", 16)
	hbox.add_child(dot)

	# Info
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var name_lbl = Label.new()
	name_lbl.text = info.get("gamertag", "Desconocido")
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", COL_TEXT)
	info_vbox.add_child(name_lbl)

	var detail_lbl = Label.new()
	detail_lbl.text = "%d/%d jugadores  •  %s" % [
		info.get("player_count", 0),
		info.get("max_players", 4),
		"En sala" if is_lobby else "En partida"
	]
	detail_lbl.add_theme_font_size_override("font_size", 11)
	detail_lbl.add_theme_color_override("font_color", COL_SUBTEXT)
	info_vbox.add_child(detail_lbl)

	# Connect button
	if is_lobby and not _connecting:
		var btn = _make_action_btn("UNIRSE", COL_ACCENT)
		btn.custom_minimum_size = Vector2(90, 40)
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(_on_connect_to_host.bind(ip))
		hbox.add_child(btn)
		_connect_focus_feedback(btn)
	else:
		var lbl = Label.new()
		lbl.text = "Lleno" if not is_lobby else ""
		lbl.add_theme_color_override("font_color", COL_DANGER)
		hbox.add_child(lbl)

	return panel

# ─────────────────────────────────────────────────────────────
#  BUTTON HANDLERS
# ─────────────────────────────────────────────────────────────
func _on_solo_pressed() -> void:
	if _transitioning: return
	if _panel_mp and _panel_mp.visible:
		_panel_mp.visible = false
		
	if _panel_main:
		_panel_main.visible = false
		
	_panel_diff.visible = false
	_panel_diff.modulate.a = 0.0
	_panel_diff.visible = true
	var t = create_tween()
	t.tween_property(_panel_diff, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE)
	_actualizar_imagen_dificultad(1)

func _on_diff_back_pressed() -> void:
	if _transitioning: return
	_panel_diff.visible = false
	if _panel_main:
		_panel_main.modulate.a = 0.0
		_panel_main.visible = true
		var t = create_tween()
		t.tween_property(_panel_main, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE)

func _on_diff_facil_pressed() -> void:
	if _transitioning: return
	_actualizar_imagen_dificultad(0)

func _on_diff_medio_pressed() -> void:
	if _transitioning: return
	_actualizar_imagen_dificultad(1)

func _on_diff_dificil_pressed() -> void:
	if _transitioning: return
	_actualizar_imagen_dificultad(2)

func _on_start_solo_pressed() -> void:
	if _transitioning: return
	SaveManager.dificultad_juego = _selected_diff
	_iniciar_partida_solitario()

func _iniciar_partida_solitario() -> void:
	NetworkManager.cleanup()
	PlayerRegistry.clear()
	PlayerRegistry.set_local_peer_id(1)
	_transition_to(SCENE_SOLO)

func _on_multiplayer_pressed() -> void:
	if _transitioning: return
	if _panel_diff and _panel_diff.visible:
		_panel_diff.visible = false

	if _panel_mp.visible:
		_panel_mp.visible = false
		return
	_panel_mp.visible = false
	_panel_mp.modulate.a = 0.0
	_panel_mp.visible = true
	var t = create_tween()
	t.tween_property(_panel_mp, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE)

func _on_back_pressed() -> void:
	if _transitioning: return
	NetworkManager.cleanup()
	_transition_to(SCENE_MAIN_MENU)

func _on_host_pressed() -> void:
	if _transitioning: return
	_stop_discovery()
	_set_status("Creando sala...", COL_WARNING)
	_get_scroll().visible = false
	_start_btn.visible = false

	var err = NetworkManager.host_game()
	if err != OK:
		_set_status("❌ Error al crear sala (Error %d). ¿Permisos o puerto ocupado?" % err, COL_DANGER)
		return

	var my_id = NetworkManager.get_my_peer_id()
	PlayerRegistry.set_local_peer_id(my_id)

	_set_status("✅ Sala creada. Esperando jugadores...\nIP de tu sala: LAN (broadcast automático)", COL_SUCCESS)
	_start_btn.visible = true
	NetworkManager.player_registered.connect(_on_player_registered)

func _on_join_pressed() -> void:
	if _transitioning: return
	_stop_discovery()
	_set_status("🔍 Buscando partidas en la red local...", COL_SUBTEXT)
	_get_scroll().visible = true
	_start_btn.visible = false
	NetworkManager.start_discovery()
	_discovery_active = true
	_rebuild_host_list()

func _on_connect_to_host(ip: String) -> void:
	if _transitioning or _connecting: return
	_connecting = true
	_set_status("Conectando a %s..." % ip, COL_WARNING)
	_stop_discovery()
	NetworkManager.join_game(ip)

func _on_start_game_pressed() -> void:
	if _transitioning: return
	if not NetworkManager.is_server():
		return
	if NetworkManager.get_player_count() < 1:
		return
	NetworkManager.rpc_start_game.rpc()

func _on_player_registered(_peer_id: int, gamertag: String) -> void:
	var count = NetworkManager.get_player_count()
	_set_status("✅ Sala activa — %d jugador(es) conectado(s)\n%s se unió!" % [count, gamertag], COL_SUCCESS)

# ─────────────────────────────────────────────────────────────
#  NETWORK CALLBACKS
# ─────────────────────────────────────────────────────────────
func _on_connection_succeeded() -> void:
	_connecting = false
	var my_id = NetworkManager.get_my_peer_id()
	PlayerRegistry.set_local_peer_id(my_id)
	_set_status("✅ Conectado! Esperando que el host inicie...", COL_SUCCESS)

func _on_connection_failed() -> void:
	_connecting = false
	_set_status("❌ No se pudo conectar. Verifica la red.", COL_DANGER)

func _on_host_list_updated() -> void:
	if _discovery_active:
		_rebuild_host_list()

func _on_game_start() -> void:
	_transition_to(SCENE_SOLO)  # Escena del juego Arcade

# ─────────────────────────────────────────────────────────────
#  HELPERS
# ─────────────────────────────────────────────────────────────
func _set_status(text: String, color: Color) -> void:
	if _status_label:
		_status_label.text = text
		_status_label.add_theme_color_override("font_color", color)

func _stop_discovery() -> void:
	if _discovery_active:
		NetworkManager.stop_discovery()
		_discovery_active = false

func _get_scroll() -> ScrollContainer:
	return _host_scroll  # referencia directa; find_child fallaba en runtime

func _transition_to(scene_path: String) -> void:
	if _transitioning: return
	_transitioning = true
	var t = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func(): get_tree().change_scene_to_file(scene_path))

func _connect_focus_feedback(btn: Button) -> void:
	if not btn: return
	btn.focus_entered.connect(func():
		var t = create_tween()
		t.tween_property(btn, "modulate", Color(0.75, 0.75, 1.0), 0.1)
	)
	btn.focus_exited.connect(func():
		var t = create_tween()
		t.tween_property(btn, "modulate", Color(1.0, 1.0, 1.0), 0.1)
	)

func _dar_foco_inicial() -> void:
	var focused = get_viewport().gui_get_focus_owner()
	if focused and focused.visible and focused.is_inside_tree():
		return
		
	if _panel_mp and _panel_mp.visible:
		if _start_btn and _start_btn.visible:
			_start_btn.grab_focus()
		elif _btn_host:
			_btn_host.grab_focus()
	else:
		if _btn_solo:
			_btn_solo.grab_focus()

func _input(event: InputEvent) -> void:
	if _transitioning: return
	
	if event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventScreenTouch:
		if _usando_mando_o_teclado:
			_usando_mando_o_teclado = false
			var focused = get_viewport().gui_get_focus_owner()
			if focused:
				focused.release_focus()
				
	elif event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event is InputEventJoypadMotion and abs(event.axis_value) < 0.2:
			return
			
		if not _usando_mando_o_teclado:
			_usando_mando_o_teclado = true
			_dar_foco_inicial()

	if event.is_action_pressed("interact"):
		var focused = get_viewport().gui_get_focus_owner()
		if focused and focused is BaseButton:
			focused.emit_signal("pressed")
