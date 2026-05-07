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
	if sprite:
		sprite.play("idle")
		
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
	# Ignoramos al arquero que la disparó
	if is_destroyed or body == tirador: 
		return 
		
	if body.is_in_group("jugador") and body.has_method("recibir_dano"):
		body.recibir_dano(dano)
		_explotar()
	elif body is TileMapLayer or "Limite" in body.name:
		_explotar()

func _on_area_entered(area):
	if is_destroyed: return
	
	# ¡MECÁNICA DE PARRY PERFECTO!
	if area.name == "HitboxEspada":
		print("¡PARRY PERFECTO! Flecha destruida.")
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
