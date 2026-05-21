extends Area2D

@export var cantidad_curacion: int = 2

var jugador_cerca: Node = null  # quién está en rango

var sound_pocion = preload("res://Sonidos/Efectos/TomarPocion.mp3")
var _sfx_player: AudioStreamPlayer2D

func _ready() -> void:
	_sfx_player = AudioStreamPlayer2D.new()
	_sfx_player.stream = sound_pocion
	
	var target_parent = get_tree().current_scene if (get_tree() and get_tree().current_scene) else get_tree().root
	if target_parent:
		target_parent.add_child.call_deferred(_sfx_player)

	add_to_group("pociones")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Caballero":
		jugador_cerca = body

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Caballero":
		jugador_cerca = null

func _process(_delta: float) -> void:
	# El jugador presiona interact estando cerca
	if jugador_cerca and Input.is_action_just_pressed("interact"):
		_usar_pocion()

func _play_potion_sound() -> void:
	if _sfx_player:
		_sfx_player.global_position = global_position
		_sfx_player.play()
		_sfx_player.finished.connect(_sfx_player.queue_free)

func _usar_pocion() -> void:
	if jugador_cerca == null:
		return
	if not jugador_cerca.has_method("curar"):
		return
	if jugador_cerca.salud_actual >= jugador_cerca.vida_maxima:
		print("[POCION] Vida llena, no se usó.")
		return

	print("[POCION] ¡Usada! Curando %d puntos." % cantidad_curacion)
	jugador_cerca.curar(cantidad_curacion)
	_play_potion_sound()
	queue_free()

func _exit_tree() -> void:
	if _sfx_player and not _sfx_player.playing:
		_sfx_player.queue_free()

