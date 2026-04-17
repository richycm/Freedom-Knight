extends CharacterBody2D

@export_group("Configuración IA")
@export var speed: float = 85.0
@export var stop_distance: float = 70.0 # Valor ajustado para estar cerca
@export var attack_cooldown: float = 0.8

@onready var sprite: AnimatedSprite2D = $AnimatedSprite

var player: CharacterBody2D = null
var is_attacking: bool = false
var attack_timer: float = 0.0

func _ready() -> void:
	# Buscamos al caballero en la escena raíz
	player = get_tree().current_scene.find_child("Caballero", true)
	if sprite:
		sprite.sprite_frames.set_animation_loop("attack", false)

func _physics_process(delta: float) -> void:
	if not player: return
	
	# Control del reloj de ataque
	if attack_timer > 0:
		attack_timer -= delta

	# CALCULOS ESPACIALES GLOBALES
	var distance = global_position.distance_to(player.global_position)
	var direction = global_position.direction_to(player.global_position)

	# Lógica de estados
	if is_attacking:
		velocity = Vector2.ZERO
	elif distance > stop_distance:
		velocity = direction * speed
		_update_visuals(direction, "move")
	else:
		velocity = Vector2.ZERO
		if attack_timer <= 0:
			_atacar()
		else:
			_update_visuals(direction, "idle")
	
	move_and_slide()

func _update_visuals(dir: Vector2, anim: String) -> void:
	if dir.x != 0:
		sprite.flip_h = (dir.x < 0)
	sprite.play(anim)

func _atacar() -> void:
	is_attacking = true
	sprite.play("attack")
	await sprite.animation_finished
	is_attacking = false
	attack_timer = attack_cooldown
