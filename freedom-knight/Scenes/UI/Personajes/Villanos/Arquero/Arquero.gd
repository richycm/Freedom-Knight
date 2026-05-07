extends CharacterBody2D

@export var attack_cooldown: float = 1.5
@export var poder_ataque: int = 1
@export var vida_maxima: int = 5 # ¡Agregamos su vida!

@onready var sprite = $AnimatedSprite
@onready var rango_ataque = $RangoAtaque 

var is_attacking = false
var is_dead = false 
var is_spawning = true 
var attack_timer = 0.0
var salud_actual: int # Variable para rastrear la vida

var jugador_en_rango: Node2D = null
var flecha_scene = preload("res://Scenes/UI/Personajes/Villanos/Arquero/Flecha.tscn")

func _ready():
	salud_actual = vida_maxima # Llenamos su vida al inicio
	
	sprite.sprite_frames.set_animation_loop("attack", false)
	sprite.sprite_frames.set_animation_loop("death", false) # Para que no reviva como zombie
	
	if not rango_ataque.body_entered.is_connected(_on_rango_ataque_body_entered):
		rango_ataque.body_entered.connect(_on_rango_ataque_body_entered)
		
	if not rango_ataque.body_exited.is_connected(_on_rango_ataque_body_exited):
		rango_ataque.body_exited.connect(_on_rango_ataque_body_exited)
		
	rango_ataque.monitoring = true
	
	await get_tree().create_timer(1.0).timeout
	is_spawning = false

func _physics_process(delta):
	if is_dead or is_spawning: return
	
	if attack_timer > 0:
		attack_timer -= delta

	if jugador_en_rango and attack_timer <= 0 and not is_attacking:
		_atacar()
	elif not is_attacking:
		sprite.play("idle")

func _atacar():
	is_attacking = true
	sprite.play("attack")
	
	var direccion_x = jugador_en_rango.global_position.x - global_position.x
	sprite.flip_h = direccion_x < 0
	
	_disparar_flecha_perseguidora()
	
	await sprite.animation_finished
	is_attacking = false
	attack_timer = attack_cooldown

func _disparar_flecha_perseguidora():
	var flecha = flecha_scene.instantiate()
	get_tree().current_scene.add_child(flecha) 
	flecha.global_position = global_position
	
	if flecha.has_method("iniciar_flecha"):
		flecha.iniciar_flecha(jugador_en_rango, poder_ataque, self)

func _on_rango_ataque_body_entered(body):
	if body.is_in_group("jugador"):
		jugador_en_rango = body

func _on_rango_ataque_body_exited(body):
	if body.is_in_group("jugador"):
		jugador_en_rango = null

# --- ¡SISTEMA DE DAÑO RESTAURADO! ---
func recibir_dano(cantidad: int):
	if is_dead or is_spawning: return
	
	salud_actual -= cantidad
	
	# Efecto de daño visual (parpadeo rojo)
	sprite.modulate = Color.RED
	await get_tree().create_timer(0.2).timeout
	if not is_dead:
		sprite.modulate = Color.WHITE
		
	if salud_actual <= 0:
		_morir()

func _morir():
	is_dead = true
	# Apagamos sus colisiones para que ya no estorbe
	set_collision_layer_value(2, false)
	set_collision_mask_value(1, false)
	rango_ataque.set_deferred("monitoring", false)
	
	sprite.play("death")
	await sprite.animation_finished
	queue_free()
