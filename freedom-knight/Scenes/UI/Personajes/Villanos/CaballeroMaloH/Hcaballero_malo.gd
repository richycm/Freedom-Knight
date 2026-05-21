extends CharacterBody2D

# 1. LA SEÑAL (Fundamental para que el mapa la escuche)
signal murio(posicion_muerte)

@export var velocidad: float = 85.0
@export var distancia_parada: float = 35.0
@export var vida_maxima: int = 10
@export var poder_ataque: int = 1
@export var attack_cooldown: float = 0.8

@onready var sprite: AnimatedSprite2D = $AnimatedSprite
@onready var zona_deteccion: Area2D = $ZonaDeteccion
@onready var rango_ataque: Area2D = $RangoAtaque

var objetivo: Node2D = null
var esta_muerto: bool = false
var esta_atacando: bool = false
var salud_actual: int
var attack_timer: float = 0.0

var sound_espada = preload("res://Sonidos/Efectos/espada.mp3")
var _sfx_player: AudioStreamPlayer2D

func _play_sword_sound() -> void:
	if _sfx_player:
		_sfx_player.play()

func _ready():
	_sfx_player = AudioStreamPlayer2D.new()
	_sfx_player.stream = sound_espada
	add_child(_sfx_player)
	
	salud_actual = vida_maxima
	if not zona_deteccion.body_entered.is_connected(_on_detectar):
		zona_deteccion.body_entered.connect(_on_detectar)
	if not zona_deteccion.body_exited.is_connected(_on_perder):
		zona_deteccion.body_exited.connect(_on_perder)
		
	rango_ataque.monitoring = false
	
	# FÍSICA: El enemigo está en la Capa 3 y choca con el mapa (Capa 1)
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_layer_value(3, true)
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, false)
	set_collision_mask_value(3, false)
	
	# DETECCIÓN: Rango y zona detectan al jugador (Capa 2)
	zona_deteccion.set_collision_layer_value(1, false)
	zona_deteccion.set_collision_mask_value(1, false)
	zona_deteccion.set_collision_mask_value(2, true)
	zona_deteccion.set_collision_mask_value(3, false)
	
	rango_ataque.set_collision_layer_value(1, false)
	rango_ataque.set_collision_mask_value(1, false)
	rango_ataque.set_collision_mask_value(2, true)
	rango_ataque.set_collision_mask_value(3, false)
	
	modulate.a = 1.0 
	sprite.play("idle")

func _physics_process(_delta):
	if esta_muerto or esta_atacando: return
	
	if attack_timer > 0:
		attack_timer -= _delta
	
	if objetivo:
		var distancia = global_position.distance_to(objetivo.global_position)
		var direccion = global_position.direction_to(objetivo.global_position)
		
		if distancia > distancia_parada:
			velocity = direccion * velocidad
			sprite.play("move")
			sprite.flip_h = direccion.x < 0
		else:
			velocity = Vector2.ZERO
			if attack_timer <= 0:
				_atacar()
			else:
				sprite.play("idle")
	else:
		velocity = Vector2.ZERO
		sprite.play("idle")
	
	move_and_slide()

# --- NUEVAS FUNCIONES DE VIDA Y MUERTE ---

func recibir_dano(cantidad: int):
	if esta_muerto: return
	salud_actual -= cantidad
	
	# Efecto visual rápido de daño
	var t = create_tween()
	sprite.modulate = Color.RED
	t.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	
	if salud_actual <= 0:
		_morir()

func _morir():
	if esta_muerto: return
	esta_muerto = true
	
	# 2. EMITIR LA SEÑAL (Para que el Mapa ponga al Monje2)
	murio.emit(global_position)
	
	velocity = Vector2.ZERO
	sprite.play("death") # Asegúrate de que la animación se llame death
	
	# Esperar a que termine la animación antes de borrarlo
	await sprite.animation_finished
	queue_free()

# --- DETECCIÓN ---

func _on_detectar(body):
	if body.is_in_group("jugador"):
		objetivo = body

func _on_perder(body):
	if body == objetivo:
		objetivo = null

func _atacar() -> void:
	if esta_atacando or esta_muerto: return
	esta_atacando = true
	sprite.play("attack")
	_play_sword_sound()
	
	await get_tree().create_timer(0.2).timeout
	rango_ataque.monitoring = true
	
	await sprite.animation_finished
	
	rango_ataque.monitoring = false
	esta_atacando = false
	attack_timer = attack_cooldown

func _on_zona_deteccion_body_entered(body: Node2D) -> void:
	if body.is_in_group("jugador"):
		objetivo = body

func _on_rango_ataque_body_entered(body: Node2D) -> void:
	if esta_muerto: return
	if body.is_in_group("jugador"):
		if body.has_method("recibir_dano"):
			body.recibir_dano(poder_ataque)
