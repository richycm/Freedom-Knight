extends CharacterBody2D

signal murio(posicion_muerte)

@export_group("Configuración IA")
@export var speed: float = 85.0
@export var stop_distance: float = 35.0 # Lo bajamos para que se acerque más
@export var attack_cooldown: float = 0.8

@export_group("Combate IA")
@export var vida_maxima: int = 10
@export var poder_ataque: int = 1

var salud_actual: int
var objetivo: CharacterBody2D = null # Cambiamos 'player' por 'objetivo'

@onready var sprite: AnimatedSprite2D = $AnimatedSprite
@onready var rango_ataque: Area2D = $RangoAtaque 
@onready var zona_deteccion: Area2D = $ZonaDeteccion # Nodo clave para la detección

var is_attacking: bool = false
var is_dead: bool = false 
var is_spawning: bool = true 
var attack_timer: float = 0.0

func _ready() -> void:
	salud_actual = vida_maxima
	y_sort_enabled = true
	
	if sprite:
		sprite.sprite_frames.set_animation_loop("attack", false)
		sprite.sprite_frames.set_animation_loop("death", false)
	
	# Conexión segura de señales (evita errores si ya están conectadas en el editor)
	if not zona_deteccion.body_entered.is_connected(_on_zona_deteccion_body_entered):
		zona_deteccion.body_entered.connect(_on_zona_deteccion_body_entered)
	if not zona_deteccion.body_exited.is_connected(_on_zona_deteccion_body_exited):
		zona_deteccion.body_exited.connect(_on_zona_deteccion_body_exited)
	if not rango_ataque.body_entered.is_connected(_on_rango_ataque_body_entered):
		rango_ataque.body_entered.connect(_on_rango_ataque_body_entered)
	
	rango_ataque.monitoring = false
	_ejecutar_spawn_magico()

func _physics_process(delta: float) -> void:
	if is_dead or is_spawning: return
	
	# Si no hay nadie cerca, se queda quieto
	if not objetivo:
		velocity = Vector2.ZERO
		sprite.play("idle")
		return

	if attack_timer > 0:
		attack_timer -= delta

	var distance = global_position.distance_to(objetivo.global_position)
	var direction = global_position.direction_to(objetivo.global_position)

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

# --- SISTEMA DE DETECCIÓN ---
func _on_zona_deteccion_body_entered(body: Node2D) -> void:
	if body.is_in_group("jugador"): # Asegúrate que el grupo sea "jugador" en minúsculas
		objetivo = body
		print("¡Jugador en la mira!")

func _on_zona_deteccion_body_exited(body: Node2D) -> void:
	if body == objetivo:
		objetivo = null
		print("El jugador escapó")

# --- SISTEMA DE COMBATE ---
func _atacar() -> void:
	if is_attacking or is_dead: return
	is_attacking = true
	sprite.play("attack")
	
	# Tiempo exacto en el que aparece la espada (ajusta si es necesario)
	await get_tree().create_timer(0.2).timeout
	rango_ataque.monitoring = true
	
	await sprite.animation_finished
	
	rango_ataque.monitoring = false
	is_attacking = false
	attack_timer = attack_cooldown

func _on_rango_ataque_body_entered(body: Node2D) -> void:
	if is_dead or is_spawning: return
	
	# Si lo que entró en el área de ataque es nuestro objetivo
	if body == objetivo:
		if body.has_method("recibir_dano"):
			body.recibir_dano(poder_ataque)
			print("¡Golpe acertado!")

# --- OTROS ---
func _actualizar_orientacion(dir: Vector2) -> void:
	if dir.x != 0:
		sprite.flip_h = dir.x < 0
		rango_ataque.scale.x = -1 if dir.x < 0 else 1

func _update_visuals(dir: Vector2, anim: String) -> void:
	if is_attacking: return
	sprite.play(anim)
	_actualizar_orientacion(dir)

func recibir_dano(cantidad: int) -> void:
	if is_dead or is_spawning: return
	salud_actual -= cantidad
	_efecto_dano()
	if salud_actual <= 0:
		_morir()

func _morir() -> void:
	if is_dead: return
	is_dead = true
	murio.emit(global_position)
	
	set_collision_layer_value(2, false)
	set_collision_mask_value(1, false)
	rango_ataque.set_deferred("monitoring", false)
	velocity = Vector2.ZERO
	
	sprite.play("death")
	await sprite.animation_finished
	queue_free()

func _efecto_dano() -> void:
	var flash_tween = create_tween()
	sprite.modulate = Color.RED
	flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)

func _ejecutar_spawn_magico() -> void:
	is_spawning = true
	if sprite:
		sprite.play("death")
		var duracion = sprite.sprite_frames.get_frame_count("death") / sprite.sprite_frames.get_animation_speed("death")
		await get_tree().create_timer(duracion * 0.5).timeout
		sprite.play("idle")
		sprite.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)
		await tween.finished
	is_spawning = false
