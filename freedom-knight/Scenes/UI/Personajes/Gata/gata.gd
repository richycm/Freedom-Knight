extends CharacterBody2D

signal adopted
signal died

enum State { IDLE, ADOPTED, DEAD }
var state: State = State.IDLE

@export var speed: float = 120.0
@export var max_health: int = 4
var current_health: int

var player: CharacterBody2D = null
var can_interact: bool = false
var enemies_killed_since_heal: int = 0
var heals_every: int = 5

@onready var sprite = $AnimatedSprite
@onready var label_interact = $LabelInteract

func _ready() -> void:
	current_health = max_health
	add_to_group("mascotas")
	
	# FÍSICA: En la Capa 3, detecta mapa en Capa 1 y jugador en Capa 2
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_layer_value(3, true)
	set_collision_mask_value(1, true)
	
	if not $ZonaInteraccion.body_entered.is_connected(_on_body_entered):
		$ZonaInteraccion.body_entered.connect(_on_body_entered)
	if not $ZonaInteraccion.body_exited.is_connected(_on_body_exited):
		$ZonaInteraccion.body_exited.connect(_on_body_exited)
	
	label_interact.visible = false
	label_interact.text = "Interactuar para adoptar"
	
	# Efecto de spawn
	modulate.a = 0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 1.0)
	
func _physics_process(_delta: float) -> void:
	if state == State.DEAD:
		return
		
	if state == State.ADOPTED and is_instance_valid(player):
		var distance = global_position.distance_to(player.global_position)
		if distance > 60.0:
			var direction = global_position.direction_to(player.global_position)
			velocity = direction * speed
			if direction.x != 0:
				sprite.flip_h = direction.x < 0
			if sprite.animation != "move":
				sprite.play("move")
		else:
			velocity = Vector2.ZERO
			if sprite.animation != "idle":
				sprite.play("idle")
	else:
		velocity = Vector2.ZERO
		if sprite.animation != "idle":
			sprite.play("idle")
		
	move_and_slide()

func _process(_delta: float) -> void:
	if state == State.IDLE and can_interact and Input.is_action_just_pressed("interact"):
		_adopt()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("jugador"):
		player = body
		if state == State.IDLE:
			can_interact = true
			label_interact.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("jugador"):
		if state == State.IDLE:
			can_interact = false
			label_interact.visible = false

func _adopt() -> void:
	state = State.ADOPTED
	label_interact.visible = false
	adopted.emit()
	
	# Efecto de corazones / celebración
	var heart_label = Label.new()
	heart_label.text = "❤"
	heart_label.add_theme_color_override("font_color", Color.RED)
	heart_label.add_theme_font_size_override("font_size", 24)
	heart_label.position = Vector2(-10, -40)
	add_child(heart_label)
	
	var tween = create_tween()
	tween.tween_property(heart_label, "position:y", -70.0, 1.0)
	tween.parallel().tween_property(heart_label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(heart_label.queue_free)

func registrar_muerte_enemigo() -> void:
	if state != State.ADOPTED:
		return
		
	enemies_killed_since_heal += 1
	if enemies_killed_since_heal >= heals_every:
		enemies_killed_since_heal = 0
		_heal_player()

func _heal_player() -> void:
	if is_instance_valid(player) and player.has_method("curar"):
		player.curar(2) # Cura 1 corazón completo (2 puntos)
		
		var heal_label = Label.new()
		heal_label.text = "¡Miau!"
		heal_label.add_theme_color_override("font_color", Color.GREEN)
		heal_label.add_theme_font_size_override("font_size", 16)
		heal_label.position = Vector2(-20, -40)
		add_child(heal_label)
		
		var tween = create_tween()
		tween.tween_property(heal_label, "position:y", -60.0, 1.0)
		tween.parallel().tween_property(heal_label, "modulate:a", 0.0, 1.0)
		tween.tween_callback(heal_label.queue_free)

func recibir_dano(amount: int) -> void:
	if state == State.DEAD or state == State.ADOPTED:
		return
		
	current_health -= amount
	
	var tween = create_tween()
	sprite.modulate = Color.RED
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	
	if current_health <= 0:
		_die()

func _die() -> void:
	state = State.DEAD
	died.emit()
	label_interact.visible = false
	
	velocity = Vector2.ZERO
	sprite.play("death")
	
	await sprite.animation_finished
	queue_free()
