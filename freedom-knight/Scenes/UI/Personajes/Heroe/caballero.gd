extends CharacterBody2D

const ANIM_IDLE = "idle"
const ANIM_MOVE = "move"
const ANIM_ATTACK = "attack"
const ANIM_GUARD = "guard"
const ANIM_DEATH = "death"
const GUARD_MAX: float = 5.0
const GUARD_RECHARGE_RATE: float = 1.0

@export_group("Movimiento")
@export var speed: float = 200.0

@export_group("Combate")
@export var vida_maxima: int = 10 
@export var poder_ataque: int = 2
@export var fuerza: int = 0  
var dano_base: int = 2       
var salud_actual: int
var guard_energy: float = GUARD_MAX
var is_guarding: bool = false

# --- NUEVAS VARIABLES DE NIVEL ---
@export_group("Nivel y Experiencia")
var nivel: int = 1
var experiencia: int = 0
var max_nivel: int = 1000
var velocidad_base: float = 200.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite
@onready var hitbox: Area2D = $HitboxEspada 

var is_attacking: bool = false
var is_dead: bool = false 

var label_nombre: Label
var label_nivel: Label

func _ready() -> void:
	add_to_group("jugador")
	# FÍSICA: El jugador está en la Capa 2 y solo choca con el mapa (Capa 1)
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, true)
	set_collision_mask_value(1, true)
	
	salud_actual = vida_maxima
	
	# COMBATE: La espada (Capa 4) debe detectar a los enemigos (Capa 3)
	hitbox.set_collision_layer_value(1, false)
	hitbox.set_collision_layer_value(4, true) # La espada es visible en la Capa 4
	hitbox.set_collision_mask_value(3, true)
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false) # IMPORTANTE: Evita que la flecha la vea sin atacar
	
	# --- ETIQUETA DE NOMBRE ---
	label_nombre = Label.new()
	if SaveManager.nombre_jugador != "":
		label_nombre.text = SaveManager.nombre_jugador
	else:
		label_nombre.text = "Caballero"
		
	label_nombre.add_theme_font_size_override("font_size", 12)
	label_nombre.add_theme_color_override("font_outline_color", Color.BLACK)
	label_nombre.add_theme_constant_override("outline_size", 4)
	label_nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_nombre.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label_nombre.z_index = 10 
	
	label_nombre.position = Vector2(-50, -45) 
	label_nombre.custom_minimum_size = Vector2(100, 20)
	add_child(label_nombre)
	
	# --- ETIQUETA DE NIVEL Y PORCENTAJE ---
	label_nivel = Label.new()
	label_nivel.add_theme_font_size_override("font_size", 10)
	label_nivel.add_theme_color_override("font_color", Color.GOLD)
	label_nivel.add_theme_color_override("font_outline_color", Color.BLACK)
	label_nivel.add_theme_constant_override("outline_size", 3)
	label_nivel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_nivel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label_nivel.z_index = 10
	label_nivel.position = Vector2(-50, -75) 
	label_nivel.custom_minimum_size = Vector2(100, 20)
	add_child(label_nivel)
	_actualizar_ui_nivel()
	
	await get_tree().process_frame 
				
	await get_tree().process_frame 
	actualizar_ui_corazones()

func _physics_process(_delta: float) -> void:
	if is_dead:
		return

	var direction = Vector2.ZERO
	var ui = get_tree().current_scene.find_child("Botones", true)
	
	if ui and "direccion" in ui and ui.direccion != Vector2.ZERO:
		direction = ui.direccion
	else:
		direction = Input.get_vector("left", "right", "up", "down")

	if Input.is_action_just_pressed("guard"):
		_start_guard()
	elif Input.is_action_just_released("guard"):
		_stop_guard()

	if Input.is_action_just_pressed("attack") and not is_attacking and not is_guarding:
		_execute_attack()

	if is_guarding:
		velocity = Vector2.ZERO
	elif is_attacking:
		velocity = Vector2.ZERO
	else:
		velocity = direction * speed
	
	move_and_slide()

	# Guardia: drain mientras está activa, recharge mientras no
	if is_guarding:
		guard_energy = max(0.0, guard_energy - _delta)
		if guard_energy <= 0.0:
			_stop_guard()
	elif guard_energy < GUARD_MAX:
		guard_energy = min(GUARD_MAX, guard_energy + GUARD_RECHARGE_RATE * _delta)

	if not is_attacking:
		_update_animations(direction)

func _update_animations(direction: Vector2) -> void:
	if is_guarding:
		sprite.play(ANIM_GUARD)
		return

	if direction == Vector2.ZERO:
		sprite.play(ANIM_IDLE)
	else:
		sprite.play(ANIM_MOVE)
		
		if direction.x > 0:
			sprite.flip_h = false 
			hitbox.scale.x = 1
		elif direction.x < 0:
			sprite.flip_h = true  
			hitbox.scale.x = -1 

func _execute_attack() -> void:
	is_attacking = true
	# Aseguramos que la animación NO sea en bucle para que el await termine
	sprite.sprite_frames.set_animation_loop(ANIM_ATTACK, false)
	sprite.play(ANIM_ATTACK)
	
	hitbox.set_deferred("monitoring", true)
	hitbox.set_deferred("monitorable", true)
	
	await sprite.animation_finished
	
	# Resetear estados
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	is_attacking = false

func _start_guard() -> void:
	if is_dead or is_guarding:
		return
	if guard_energy <= 0.0:
		return
		
	# PRIORIDAD: El escudo interrumpe el ataque
	if is_attacking:
		is_attacking = false
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)
		
	is_guarding = true
	sprite.play(ANIM_GUARD)

func _stop_guard() -> void:
	if not is_guarding:
		return
	is_guarding = false

func get_guard_energy() -> float:
	return guard_energy

# --- SISTEMA DE DAÑO ---

func recibir_dano(cantidad: int) -> void:
	if is_dead:
		return
	if is_guarding:
		print("¡ATAQUE BLOQUEADO POR EL ESCUDO!")
		return

	# Resistencia: Reduce el daño en base al nivel (1 punto de defensa por cada 3 niveles)
	var defensa = floor(nivel / 3.0)
	var dano_recibido = max(1, cantidad - defensa) 

	print("¡EL CABALLERO RECIBIÓ DAÑO! (-", dano_recibido, " puntos. Def:", defensa, ")")
	salud_actual -= dano_recibido
	salud_actual = clampi(salud_actual, 0, vida_maxima)
	
	_efecto_dano()
	actualizar_ui_corazones()
	
	if salud_actual <= 0:
		_morir()

func _morir() -> void:
	is_dead = true
	print("[SISTEMA] Caballero caído. Regresando al menú...")
	
	velocity = Vector2.ZERO
	set_collision_layer_value(2, false)
	set_collision_mask_value(1, false) 
	hitbox.monitoring = false
	
	sprite.sprite_frames.set_animation_loop(ANIM_DEATH, false)
	sprite.play(ANIM_DEATH)

	# --- PANTALLA DE MUERTE CON ESTADÍSTICAS ---
	var muertes = 0
	var escenario = get_tree().current_scene
	if "enemigos_derrotados" in escenario and "arqueros_derrotados" in escenario:
		muertes = escenario.enemigos_derrotados + escenario.arqueros_derrotados

	var canvas = CanvasLayer.new()
	canvas.layer = 100
	escenario.add_child(canvas)
	
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)
	
	var text_muerte = Label.new()
	text_muerte.text = "¡HAS CAÍDO!\nDerrotaste a " + str(muertes) + " enemigos."
	text_muerte.add_theme_font_size_override("font_size", 24)
	text_muerte.add_theme_color_override("font_color", Color.RED)
	text_muerte.add_theme_color_override("font_outline_color", Color.BLACK)
	text_muerte.add_theme_constant_override("outline_size", 6)
	text_muerte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_muerte.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_muerte.set_anchors_preset(Control.PRESET_FULL_RECT)
	text_muerte.modulate.a = 0
	canvas.add_child(text_muerte)
	
	var tween = create_tween()
	tween.tween_property(bg, "color:a", 0.7, 1.0)
	tween.parallel().tween_property(text_muerte, "modulate:a", 1.0, 1.0)
	# ----------------------------------------

	await sprite.animation_finished
	await get_tree().create_timer(4.0).timeout # Tiempo para leer el mensaje
	
	get_tree().change_scene_to_file("res://Scenes/UI/MainMenu.tscn")

func _efecto_dano() -> void:
	sprite.modulate = Color.RED
	await get_tree().create_timer(0.2).timeout
	if not is_dead:
		sprite.modulate = Color.WHITE
	else:
		sprite.modulate = Color(0.5, 0.5, 0.5)

func _on_hitbox_espada_body_entered(body: Node2D) -> void:
	if body == self:
		return
	if body.has_method("recibir_dano"):
		body.recibir_dano(poder_ataque)
		ganar_experiencia(1)

# --- SISTEMA DE CURACIÓN ---

func curar(cantidad: int) -> void:
	if is_dead or salud_actual >= vida_maxima:
		return

	salud_actual += cantidad
	salud_actual = clampi(salud_actual, 0, vida_maxima) 
	
	_efecto_curacion()
	actualizar_ui_corazones()

func _efecto_curacion() -> void:
	sprite.modulate = Color.GREEN
	await get_tree().create_timer(0.3).timeout
	sprite.modulate = Color.WHITE

func actualizar_ui_corazones() -> void:
	var ui = get_tree().current_scene.find_child("Botones", true)
	if ui and ui.has_method("actualizar_vidas"):
		ui.actualizar_vidas(salud_actual)

# --- SISTEMA DE PROGRESO Y EXPERIENCIA ---

func ganar_experiencia(cantidad: int) -> void:
	if is_dead or nivel >= max_nivel:
		return
		
	experiencia += cantidad
	var exp_necesaria = 5 * nivel 
	
	while experiencia >= exp_necesaria and nivel < max_nivel:
		experiencia -= exp_necesaria
		nivel += 1
		exp_necesaria = 5 * nivel
		_subir_de_nivel()
	
	_actualizar_ui_nivel()

func _subir_de_nivel() -> void:
	# Aumentar velocidad rápidamente
	speed = min(600.0, velocidad_base + (nivel * 5.0))
	
	# Aumentar daño agresivamente
	poder_ataque = dano_base + floor(fuerza / 3.0) + floor(nivel / 2.0)
	
	# Efecto visual de Level Up
	var tween = create_tween()
	sprite.modulate = Color.YELLOW
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.4)
	
	var aura = sprite.duplicate()
	add_child(aura)
	aura.modulate = Color(1.0, 0.8, 0.0, 0.6) 
	aura.z_index = -1
	var tween_aura = create_tween()
	tween_aura.tween_property(aura, "scale", Vector2(1.8, 1.8), 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_aura.parallel().tween_property(aura, "modulate:a", 0.0, 1.0)
	tween_aura.tween_callback(aura.queue_free)
	
	# Curación por subir de nivel
	curar(2)
	
	print("[SISTEMA] ¡Nivel ", nivel, "! Vel: ", speed, " Daño: ", poder_ataque)

func _actualizar_ui_nivel() -> void:
	if is_instance_valid(label_nivel):
		var exp_necesaria = 5 * nivel
		var porcentaje = (float(experiencia) / float(exp_necesaria)) * 100.0
		if nivel >= max_nivel:
			label_nivel.text = "Lvl: MAX"
		else:
			label_nivel.text = "Lvl: %d [%d%%]" % [nivel, porcentaje]

func mejorar_fuerza(cantidad: int) -> void:
	fuerza += cantidad
	poder_ataque = dano_base + floor(fuerza / 3.0) + floor(nivel / 2.0)
	print("[SISTEMA] Fuerza Total: ", fuerza, " | Daño Actual: ", poder_ataque)
	var escenario = get_tree().current_scene
	if "fuerza_jugador" in escenario:
		escenario.fuerza_jugador = self.fuerza
