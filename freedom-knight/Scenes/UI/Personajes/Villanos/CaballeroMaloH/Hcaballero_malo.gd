extends CharacterBody2D

# 1. LA SEÑAL (Fundamental para que el mapa la escuche)
signal murio(posicion_muerte)

@export var velocidad: float = 85.0
@export var distancia_parada: float = 35.0
@export var vida_maxima: int = 10
@export var poder_ataque: int = 1

@onready var sprite: AnimatedSprite2D = $AnimatedSprite
@onready var zona_deteccion: Area2D = $ZonaDeteccion
@onready var rango_ataque: Area2D = $RangoAtaque

var objetivo: Node2D = null
var esta_muerto: bool = false
var esta_atacando: bool = false
var salud_actual: int

func _ready():
	salud_actual = vida_maxima
	if not zona_deteccion.body_entered.is_connected(_on_detectar):
		zona_deteccion.body_entered.connect(_on_detectar)
	if not zona_deteccion.body_exited.is_connected(_on_perder):
		zona_deteccion.body_exited.connect(_on_perder)
	
	modulate.a = 1.0 
	sprite.play("idle")

func _physics_process(_delta):
	if esta_muerto or esta_atacando: return
	
	if objetivo:
		var distancia = global_position.distance_to(objetivo.global_position)
		var direccion = global_position.direction_to(objetivo.global_position)
		
		if distancia > distancia_parada:
			velocity = direccion * velocidad
			sprite.play("move")
			sprite.flip_h = direccion.x < 0
		else:
			velocity = Vector2.ZERO
			# Aquí podrías llamar a una función de ataque
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
