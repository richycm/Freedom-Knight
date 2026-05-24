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
	if body.is_in_group("jugador"):
		# Solo registrar jugador_cerca si es el jugador LOCAL de este cliente
		# para que el process detecte la tecla de interact del jugador local
		if NetworkManager.is_multiplayer_active():
			if body == PlayerRegistry.get_local_player():
				jugador_cerca = body
		else:
			if body.name == "Caballero":
				jugador_cerca = body

func _on_body_exited(body: Node2D) -> void:
	if body == jugador_cerca:
		jugador_cerca = null

func _process(_delta: float) -> void:
	if jugador_cerca and Input.is_action_just_pressed("interact"):
		if NetworkManager.is_multiplayer_active():
			if NetworkManager.is_server():
				_usar_pocion_server(1)
			else:
				rpc_request_use_potion.rpc_id(1)
		else:
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
	_apply_potion_to(jugador_cerca)

func _usar_pocion_server(peer_id: int) -> void:
	if not NetworkManager.is_server(): return
	var player_node = PlayerRegistry.get_player(peer_id)
	if player_node and is_instance_valid(player_node):
		# Verificar distancia y salud en el servidor para evitar exploits/desync
		if global_position.distance_to(player_node.global_position) < 100.0:
			if player_node.salud_actual < player_node.vida_maxima:
				_apply_potion_to(player_node)

func _apply_potion_to(player_node: Node) -> void:
	player_node.curar(cantidad_curacion)
	if NetworkManager.is_multiplayer_active():
		rpc_play_potion_sound.rpc()
	else:
		_play_potion_sound()
	queue_free()

@rpc("any_peer", "reliable")
func rpc_request_use_potion() -> void:
	if not NetworkManager.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	_usar_pocion_server(sender_id)

@rpc("authority", "call_local", "reliable")
func rpc_play_potion_sound() -> void:
	_play_potion_sound()

func _exit_tree() -> void:
	if _sfx_player and not _sfx_player.playing:
		_sfx_player.queue_free()
