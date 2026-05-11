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

@onready var sprite: AnimatedSprite2D = $AnimatedSprite
@onready var hitbox: Area2D = $HitboxEspada 

var is_attacking: bool = false
var is_dead: bool = false 

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

	if Input.is_action_just_pressed("attack") and not is_attacking:
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
	sprite.sprite_frames.set_animation_loop(ANIM_ATTACK, false)
	sprite.play(ANIM_ATTACK)
	
	hitbox.set_deferred("monitoring", true)
	hitbox.set_deferred("monitorable", true)
	
	await sprite.animation_finished
	
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

	print("¡EL CABALLERO RECIBIÓ DAÑO! (-", cantidad, " puntos)")
	salud_actual -= cantidad
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

	await sprite.animation_finished
	await get_tree().create_timer(0.5).timeout
	
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

# --- SISTEMA DE PROGRESO ---

func mejorar_fuerza(cantidad: int) -> void:
	# 1. Sumamos los puntos al Caballero
	fuerza += cantidad
	
	# 2. REGLA: Cada 3 puntos de fuerza subimos 1 de daño (antes era cada 10, era muy lento)
	poder_ataque = dano_base + floor(fuerza / 3.0)
	
	print("[SISTEMA] Fuerza Total: ", fuerza, " | Daño Actual: ", poder_ataque)

	# 3. SINCRONIZACIÓN: Avisamos al script del escenario (Dificultad)
	var escenario = get_tree().current_scene
	if "fuerza" in escenario:
		escenario.fuerza = self.fuerza
		print("[CONEXIÓN] Estadísticas sincronizadas con el Escenario")
	
