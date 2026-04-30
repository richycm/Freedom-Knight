extends CharacterBody2D

const ANIM_IDLE = "idle"
const ANIM_MOVE = "move"
const ANIM_ATTACK = "attack"
const ANIM_DEATH = "death" 

@export_group("Movimiento")
@export var speed: float = 200.0

@export_group("Combate")
@export var vida_maxima: int = 10 
@export var poder_ataque: int = 2
var salud_actual: int

@onready var sprite: AnimatedSprite2D = $AnimatedSprite
@onready var hitbox: Area2D = $HitboxEspada 

var is_attacking: bool = false
var is_dead: bool = false 

func _ready() -> void:
	salud_actual = vida_maxima
	hitbox.monitoring = false
	
	# Pintar los corazones al iniciar el nivel
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
	
	if Input.is_action_just_pressed("attack") and not is_attacking:
		_execute_attack()

	if is_attacking:
		velocity = Vector2.ZERO
	else:
		velocity = direction * speed
	
	move_and_slide()
	
	if not is_attacking:
		_update_animations(direction)

func _update_animations(direction: Vector2) -> void:
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
	
	hitbox.monitoring = true
	await sprite.animation_finished
	
	hitbox.monitoring = false
	is_attacking = false

# --- SISTEMA DE DAÑO ---

func recibir_dano(cantidad: int) -> void:
	if is_dead:
		return

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
