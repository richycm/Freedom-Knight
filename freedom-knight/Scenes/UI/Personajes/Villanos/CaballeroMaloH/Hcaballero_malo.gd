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
var is_spawning: bool = true
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
	add_to_group("aliados")
	
	# Efecto de aparición (Fade In)
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.4)
	
	get_tree().create_timer(0.5).timeout.connect(func(): is_spawning = false)
	
	if not zona_deteccion.body_entered.is_connected(_on_detectar):
		zona_deteccion.body_entered.connect(_on_detectar)
	if not zona_deteccion.body_exited.is_connected(_on_perder):
		zona_deteccion.body_exited.connect(_on_perder)
		
	rango_ataque.monitoring = false
	
	# FÍSICA: El aliado está en la Capa 2 (Jugador/Aliado) y choca con el mapa (Capa 1) y enemigos (Capa 3)
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, true)
	set_collision_layer_value(3, false)
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, false)
	set_collision_mask_value(3, true)
	
	# DETECCIÓN: Rango y zona detectan a los villanos (Capa 3)
	zona_deteccion.set_collision_layer_value(1, false)
	zona_deteccion.set_collision_mask_value(1, false)
	zona_deteccion.set_collision_mask_value(2, false)
	zona_deteccion.set_collision_mask_value(3, true)
	
	rango_ataque.set_collision_layer_value(1, false)
	rango_ataque.set_collision_mask_value(1, false)
	rango_ataque.set_collision_mask_value(2, false)
	rango_ataque.set_collision_mask_value(3, true)
	
	modulate.a = 1.0 
	sprite.play("idle")

func _physics_process(delta: float):
	if is_spawning or esta_muerto: return
	
	if attack_timer > 0:
		attack_timer -= delta
		
	if esta_atacando:
		return
		
	objetivo = _obtener_siguiente_objetivo()
	
	if objetivo:
		var es_enemigo = objetivo.is_in_group("enemigos")
		var distancia = global_position.distance_to(objetivo.global_position)
		var direccion = global_position.direction_to(objetivo.global_position)
		
		# Si es enemigo, nos acercamos hasta distancia_parada y atacamos
		if es_enemigo:
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
		# Si es jugador, solo lo seguimos a una distancia amigable
		else:
			if distancia > 60.0:
				velocity = direccion * velocidad
				sprite.play("move")
				sprite.flip_h = direccion.x < 0
			else:
				velocity = Vector2.ZERO
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
	
	if sprite and sprite.sprite_frames:
		sprite.sprite_frames.set_animation_loop("death", false)
		sprite.play("death")
		
		if PlayerRegistry.has_method("crear_explosion"):
			PlayerRegistry.crear_explosion(global_position)
			
		# Timer de respaldo
		var duracion = 0.5
		if sprite.sprite_frames.has_animation("death"):
			var frames_count = sprite.sprite_frames.get_frame_count("death")
			var anim_speed = sprite.sprite_frames.get_animation_speed("death")
			if anim_speed > 0:
				duracion = frames_count / anim_speed
				
		get_tree().create_timer(duracion).timeout.connect(func():
			if is_instance_valid(sprite):
				sprite.visible = false
			queue_free()
		)
	else:
		queue_free()

# --- DETECCIÓN ---

func _obtener_siguiente_objetivo() -> Node2D:
	# 1. Buscar el enemigo más cercano
	var enemigos = get_tree().get_nodes_in_group("enemigos")
	var nearest_enemy: Node2D = null
	var min_dist = INF
	for enemy in enemigos:
		if is_instance_valid(enemy) and enemy != self and not enemy.get("is_dead") and not enemy.get("esta_muerto"):
			var dist = global_position.distance_to(enemy.global_position)
			if dist < min_dist:
				min_dist = dist
				nearest_enemy = enemy
	if nearest_enemy:
		return nearest_enemy
		
	# 2. Si no hay enemigos, buscar al jugador más cercano para seguirlo
	return PlayerRegistry.get_nearest_player_to(global_position)

func _on_detectar(body):
	if body.is_in_group("enemigos"):
		if not objetivo or not is_instance_valid(objetivo) or not objetivo.is_in_group("enemigos"):
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
	if body.is_in_group("enemigos"):
		if not objetivo or not is_instance_valid(objetivo) or not objetivo.is_in_group("enemigos"):
			objetivo = body

func _on_rango_ataque_body_entered(body: Node2D) -> void:
	if esta_muerto: return
	if body.is_in_group("enemigos"):
		if body.has_method("recibir_dano"):
			body.recibir_dano(poder_ataque)
