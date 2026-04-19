extends CharacterBody2D

# Señal necesaria para avisar al escenario que debe spawnear más
signal murio(posicion_muerte)

@export_group("Configuración IA")
@export var speed: float = 85.0
@export var stop_distance: float = 70.0 
@export var attack_cooldown: float = 0.8

@export_group("Combate IA")
@export var vida_maxima: int = 10
@export var poder_ataque: int = 1
var salud_actual: int

@onready var sprite: AnimatedSprite2D = $AnimatedSprite
@onready var rango_ataque: Area2D = $RangoAtaque 

var player: CharacterBody2D = null
var is_attacking: bool = false
var is_dead: bool = false 
var attack_timer: float = 0.0

func _ready() -> void:
	salud_actual = vida_maxima
	# Busca al jugador por nombre en la escena
	player = get_tree().current_scene.find_child("Caballero", true)
	
	if sprite:
		sprite.sprite_frames.set_animation_loop("attack", false)
		sprite.sprite_frames.set_animation_loop("death", false)
	
	rango_ataque.monitoring = false

func _physics_process(delta: float) -> void:
	if is_dead or not player: return
	
	if attack_timer > 0:
		attack_timer -= delta

	var distance = global_position.distance_to(player.global_position)
	var direction = global_position.direction_to(player.global_position)

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
	sprite.play(anim)
	if dir.x != 0:
		sprite.flip_h = dir.x < 0
		rango_ataque.scale.x = -1 if dir.x < 0 else 1

func _atacar() -> void:
	is_attacking = true
	sprite.play("attack")
	rango_ataque.monitoring = true
	await sprite.animation_finished
	rango_ataque.monitoring = false
	is_attacking = false
	attack_timer = attack_cooldown

func recibir_dano(cantidad: int) -> void:
	if is_dead: return
	salud_actual -= cantidad
	_efecto_dano()
	if salud_actual <= 0:
		_morir()

func _morir() -> void:
	if is_dead: return
	is_dead = true
	
	# Emitimos la señal antes de cualquier otra cosa
	murio.emit(global_position)
	
	collision_layer = 0
	collision_mask = 0
	rango_ataque.monitoring = false
	velocity = Vector2.ZERO
	
	sprite.play("death")
	await sprite.animation_finished
	await get_tree().create_timer(0.2).timeout
	queue_free()

func _efecto_dano() -> void:
	sprite.modulate = Color.RED
	await get_tree().create_timer(0.2).timeout
	if not is_dead:
		sprite.modulate = Color.WHITE

func _on_rango_ataque_body_entered(body: Node2D) -> void:
	if is_dead: return
	if body == self: return
	if body.has_method("recibir_dano"):
		body.recibir_dano(poder_ataque)
