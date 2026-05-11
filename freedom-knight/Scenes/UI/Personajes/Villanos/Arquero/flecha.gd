extends Area2D

@export var velocidad: float = 300.0
@export var fuerza_persecucion: float = 2.0 

var objetivo: Node2D = null
var dano: int = 1
var direccion: Vector2 = Vector2.RIGHT
var tirador: Node2D = null
var is_destroyed: bool = false

# El código buscará un nodo llamado EXACTAMENTE "AnimatedSprite2D"
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D 

func _ready():
	# Reproducimos la animación de vuelo por defecto
	sprite.play("idle")
	
	# CONFIGURACIÓN DE COLISIONES DE LA FLECHA
	# La flecha es un proyectil enemigo (Capa 3)
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_layer_value(3, true)
	# Debe detectar al mapa (Capa 1), al jugador (Capa 2), y la ESPADA (Capa 4)
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	set_collision_mask_value(3, false)
	set_collision_mask_value(4, true)
		
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
		
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
		
	get_tree().create_timer(5.0).timeout.connect(_destruccion_por_tiempo)

func iniciar_flecha(target: Node2D, poder: int, quien_dispara: Node2D):
	objetivo = target
	dano = poder
	tirador = quien_dispara 
	
	if objetivo:
		direccion = global_position.direction_to(objetivo.global_position)
		rotation = direccion.angle()

func _physics_process(delta):
	# Si ya explotó, se detiene en el aire
	if is_destroyed: return
	
	if objetivo and is_instance_valid(objetivo):
		var dir_ideal = global_position.direction_to(objetivo.global_position)
		direccion = direccion.slerp(dir_ideal, fuerza_persecucion * delta)
	
	position += direccion * velocidad * delta
	rotation = direccion.angle()

func _on_body_entered(body):
	# Ignoramos a quien disparó la flecha (original o parry)
	if is_destroyed or body == tirador: 
		return 
		
	# PREVENCIÓN DE DAÑO INJUSTO (Si el cuerpo y la espada chocan en el mismo frame)
	var areas_chocando = get_overlapping_areas()
	for a in areas_chocando:
		if a.name == "HitboxEspada":
			var player = get_tree().current_scene.find_child("Caballero", true)
			if player:
				var mirando_derecha = not player.get_node("AnimatedSprite").flip_h
				var flecha_frente = false
				if mirando_derecha and global_position.x >= player.global_position.x - 5: flecha_frente = true
				elif not mirando_derecha and global_position.x <= player.global_position.x + 5: flecha_frente = true
				
				if flecha_frente:
					print("¡Parry salvador! Golpeaste la flecha en el último milisegundo.")
					is_destroyed = true
					_explotar()
					return
		
	# Si choca con alguien que recibe daño (Jugador o Enemigo)
	if body.has_method("recibir_dano"):
		print("¡LA FLECHA IMPACTÓ A ", body.name, "!")
		body.recibir_dano(dano)
		_explotar()
	# Si choca con el mapa o límites
	elif body is TileMapLayer or "Limite" in body.name:
		_explotar()

func _on_area_entered(area):
	if is_destroyed: return
	
	# ¡MECÁNICA DE PARRY! 
	if area.name == "HitboxEspada":
		var player = get_tree().current_scene.find_child("Caballero", true)
		if player:
			var mirando_derecha = not player.get_node("AnimatedSprite").flip_h
			var flecha_frente = false
			
			if mirando_derecha and global_position.x >= player.global_position.x - 5:
				flecha_frente = true
			elif not mirando_derecha and global_position.x <= player.global_position.x + 5:
				flecha_frente = true
				
			if not flecha_frente:
				return # Ignorar si viene por la espalda
				
		is_destroyed = true # Bloqueamos daño inmediato
		print("¡PARRY! Flecha destruida por el escudo de espada.")
		_explotar()

func _explotar():
	is_destroyed = true
	
	# Apagamos sus colisiones para que no quite vida mientras explota
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	if sprite:
		rotation = 0 # Enderezamos la explosión para que no se vea chueca
		sprite.play("death")
		await sprite.animation_finished
		
	queue_free()

func _destruccion_por_tiempo():
	if not is_destroyed:
		queue_free()
