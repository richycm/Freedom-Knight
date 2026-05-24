## ============================================================
##  PlayerRegistry.gd  — Freedom Knight
##  Autoload singleton.
##  Centraliza el registro de nodos CharacterBody2D por peer_id.
##  Elimina todas las búsquedas hardcodeadas por nombre ("Caballero").
##  Compatible 100% con modo Solitario (sin red activa).
## ============================================================
extends Node

# peer_id → Node (CharacterBody2D del jugador)
var _registry: Dictionary = {}

# peer_id del jugador LOCAL en esta instancia
var _local_peer_id: int = 1

# ─────────────────────────────────────────────────────────────
#  INIT
# ─────────────────────────────────────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

# Llamar desde el caballero en su _ready() para registrarse
func register(peer_id: int, node: Node) -> void:
	if _registry.has(peer_id):
		push_warning("[PlayerRegistry] Peer %d ya registrado. Sobreescribiendo." % peer_id)
	_registry[peer_id] = node
	print("[PlayerRegistry] Registrado peer_id=%d nodo=%s" % [peer_id, node.name])

# Llamar desde _exit_tree() del caballero
func unregister(peer_id: int) -> void:
	if _registry.has(peer_id):
		_registry.erase(peer_id)
		print("[PlayerRegistry] Desregistrado peer_id=%d" % peer_id)

# ─────────────────────────────────────────────────────────────
#  LOCAL PLAYER
# ─────────────────────────────────────────────────────────────
func set_local_peer_id(id: int) -> void:
	_local_peer_id = id

func get_local_peer_id() -> int:
	return _local_peer_id

## Retorna el nodo del jugador LOCAL (el que mueve este dispositivo).
## En solitario siempre retorna el único Caballero.
func get_local_player() -> Node:
	if _registry.has(_local_peer_id):
		var node = _registry[_local_peer_id]
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			return node
	# Fallback para solitario: buscar en grupo "jugador"
	var nodes = get_tree().get_nodes_in_group("jugador")
	for n in nodes:
		if is_instance_valid(n) and not n.is_queued_for_deletion():
			return n
	return null

# ─────────────────────────────────────────────────────────────
#  LOOKUP
# ─────────────────────────────────────────────────────────────
func get_player(peer_id: int) -> Node:
	if _registry.has(peer_id):
		var node = _registry[peer_id]
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			return node
		else:
			_registry.erase(peer_id)
	return null

func get_all_players() -> Array:
	var result: Array = []
	var to_remove: Array = []
	for pid in _registry:
		var node = _registry[pid]
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			result.append(node)
		else:
			to_remove.append(pid)
	for pid in to_remove:
		_registry.erase(pid)
	return result

func get_alive_players() -> Array:
	var result: Array = []
	for node in get_all_players():
		if not node.get("is_dead"):
			result.append(node)
	return result

func get_nearest_player_to(pos: Vector2) -> Node:
	var nearest = null
	var min_dist = INF
	
	# Buscar jugadores vivos
	for node in get_alive_players():
		var d = pos.distance_to(node.global_position)
		if d < min_dist:
			min_dist = d
			nearest = node
			
	# Buscar aliados vivos
	var nodes = get_tree().get_nodes_in_group("aliados")
	for n in nodes:
		if is_instance_valid(n) and not n.is_queued_for_deletion():
			if not n.get("is_dead") and not n.get("esta_muerto"):
				var d = pos.distance_to(n.global_position)
				if d < min_dist:
					min_dist = d
					nearest = n
					
	return nearest

func any_player_alive() -> bool:
	return get_alive_players().size() > 0

# ─────────────────────────────────────────────────────────────
#  OWNERSHIP HELPERS
# ─────────────────────────────────────────────────────────────

## Retorna true si este peer es dueño del nodo (solitario o peer_id == local)
func is_local_peer(peer_id: int) -> bool:
	return peer_id == _local_peer_id

## Retorna true si estamos en modo red
func is_networked() -> bool:
	return NetworkManager.is_multiplayer_active()

# ─────────────────────────────────────────────────────────────
#  CLEANUP
# ─────────────────────────────────────────────────────────────
func clear() -> void:
	_registry.clear()
	_local_peer_id = 1

## Genera un efecto de explosión visual (usando Explosion_02.png) y se auto-elimina
func crear_explosion(pos: Vector2, scale_factor: float = 1.0) -> void:
	var parent = get_tree().current_scene
	if not parent: return
	
	var exp_sprite = AnimatedSprite2D.new()
	exp_sprite.scale = Vector2(scale_factor, scale_factor)
	exp_sprite.z_index = 5
	
	# Configurar SpriteFrames
	var frames = SpriteFrames.new()
	frames.add_animation("default")
	frames.set_animation_speed("default", 24.0)
	frames.set_animation_loop("default", false)
	
	var texture = load("res://Scenes/Efectos/Explosion_02.png")
	if texture:
		for i in range(10):
			var atlas = AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(i * 192, 0, 192, 192)
			frames.add_frame("default", atlas)
			
	exp_sprite.sprite_frames = frames
	parent.add_child(exp_sprite)
	exp_sprite.global_position = pos
	exp_sprite.play("default")
	exp_sprite.animation_finished.connect(exp_sprite.queue_free)
