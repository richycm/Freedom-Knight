extends StaticBody2D

# Configuración del diálogo
var lista_mensajes: PackedStringArray = [
	"¡Hola caballero! Se te ve cansado.",
	"Déjame restaurar tus fuerzas con una oración...",
	"¡Listo! Que la sabiduría te acompañe.",
	"Ya puedes seguir tu camino."
]

var indice_actual = 0
var puede_interactuar = false
var ya_curado = false 
var jugador_cercano: Node2D = null # <--- LA VARIABLE SALVAVIDAS

# Peer ID del jugador dueño de este monje
var owner_peer_id: int = 0

@export var es_curandero: bool = true
@export var puntos_salud: int = 3

@onready var sprite = $sprite_visual 
@onready var globo = $GloboDialogo
@onready var etiqueta_texto = $GloboDialogo/TextoDialogo

func _ready():
	# Desactivar colisiones físicas para que sea traspasable y no bloquee a jugadores ni jefes
	collision_layer = 0
	collision_mask = 0

	# Iniciamos la animación
	if sprite:
		sprite.play("idle")
		
	# Es buena práctica ocultar el globo al inicio
	globo.visible = false
	
	# Conexiones seguras de las señales de tu zona de interacción
	if not $Zonai_interaccion.body_entered.is_connected(_on_body_entered):
		$Zonai_interaccion.body_entered.connect(_on_body_entered)
	if not $Zonai_interaccion.body_exited.is_connected(_on_body_exited):
		$Zonai_interaccion.body_exited.connect(_on_body_exited)

	# Si es multijugador, por defecto lo ocultamos hasta recibir su dueño oficial
	if NetworkManager.is_multiplayer_active():
		visible = false

func _on_body_entered(body):
	# ¡Atrapamos al caballero exacto que entró en la zona!
	if body.is_in_group("jugador"):
		# Si es multijugador y tiene dueño asignado, validar que sea el dueño
		if NetworkManager.is_multiplayer_active() and owner_peer_id != 0:
			var body_peer = body.get("my_peer_id") if "my_peer_id" in body else (body.get("peer_id") if "peer_id" in body else 0)
			if body_peer != owner_peer_id:
				return
		puede_interactuar = true
		jugador_cercano = body

func _on_body_exited(body):
	# Soltamos al caballero cuando se va
	if body.is_in_group("jugador"):
		if NetworkManager.is_multiplayer_active() and owner_peer_id != 0:
			var body_peer = body.get("my_peer_id") if "my_peer_id" in body else (body.get("peer_id") if "peer_id" in body else 0)
			if body_peer != owner_peer_id:
				return
		puede_interactuar = false
		globo.visible = false
		indice_actual = 0 
		ya_curado = false
		jugador_cercano = null

func _process(_delta):
	if puede_interactuar and Input.is_action_just_pressed("interact"):
		hablar()

func hablar():
	if indice_actual < lista_mensajes.size():
		etiqueta_texto.text = lista_mensajes[indice_actual]
		globo.visible = true
		
		# Verificamos si es momento de curar
		if es_curandero and not ya_curado and indice_actual == 1:
			ejecutar_curacion()
		
		# Ajuste dinámico del tamaño del globo de diálogo
		etiqueta_texto.size = Vector2.ZERO 
		await get_tree().process_frame
		
		var margen = Vector2(30, 20)
		var tamano_real_texto = etiqueta_texto.get_minimum_size()
		
		globo.size = tamano_real_texto + margen
		etiqueta_texto.position = margen / 2
		
		var distancia_colita = 25 
		globo.global_position = $PosicionDialogo.global_position - Vector2(distancia_colita, globo.size.y + 5)
		globo.z_index = 50 
		
		indice_actual += 1
	else:
		globo.visible = false
		indice_actual = 0 
		ya_curado = false

func ejecutar_curacion():
	print("[SISTEMA] Intentando curar al caballero...")
	
	# Usamos la variable directa que atrapamos en la colisión
	if jugador_cercano:
		if NetworkManager.is_multiplayer_active() and not NetworkManager.is_server():
			rpc_request_curar_monje.rpc_id(1)
			ya_curado = true
			print("[SISTEMA-RED] Solicitada curación al servidor para el cliente.")
			return

		if jugador_cercano.has_method("curar"):
			var curacion_total = jugador_cercano.vida_maxima if "vida_maxima" in jugador_cercano else 100
			jugador_cercano.curar(curacion_total)
			ya_curado = true
			print("[SISTEMA] ¡Curación al 100% exitosa!")
			
			# Efecto de desaparición
			var tween = create_tween()
			tween.tween_property(self, "modulate:a", 0.0, 1.0)
			tween.tween_callback(self.queue_free)
		else:
			print("[ERROR] El nodo que está enfrente no tiene método 'curar'")
	else:
		print("[ERROR] No hay nadie cerca para curar.")

@rpc("authority", "reliable", "call_local")
func rpc_setup_monje(pos: Vector2, p_owner_id: int) -> void:
	global_position = pos
	owner_peer_id = p_owner_id
	var my_peer_id = NetworkManager.get_my_peer_id()
	if my_peer_id == owner_peer_id:
		visible = true
	else:
		visible = false

@rpc("any_peer", "reliable")
func rpc_request_curar_monje() -> void:
	if not NetworkManager.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	
	# Validar que el que solicita curarse sea el dueño de este monje
	if owner_peer_id != 0 and sender_id != owner_peer_id:
		print("[SISTEMA-RED] Rechazada curación: peer %d no es dueño de este monje (dueño: %d)" % [sender_id, owner_peer_id])
		return
		
	if ya_curado: return
	
	var player_node = PlayerRegistry.get_player(sender_id)
	if player_node and is_instance_valid(player_node):
		var dist = global_position.distance_to(player_node.global_position)
		if dist <= 200.0:
			if player_node.has_method("curar"):
				var curacion_total = player_node.vida_maxima if "vida_maxima" in player_node else 100
				player_node.curar(curacion_total)
				ya_curado = true
				print("[SISTEMA-RED] Curado cliente %d vía monje" % sender_id)
				
				var tween = create_tween()
				tween.tween_property(self, "modulate:a", 0.0, 1.0)
				tween.tween_callback(queue_free)
