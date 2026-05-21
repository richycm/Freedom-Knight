extends Node

const DEFAULT_PORT = 8910
const BROADCAST_PORT = 8911

var peer: ENetMultiplayerPeer
var is_host: bool = false

# Variables para descubrimiento de LAN
var udp_broadcaster: PacketPeerUDP
var udp_listener: PacketPeerUDP
var discovered_servers = {} # IP: { name, player_count }

signal server_found(ip, info)
signal connection_failed
signal connection_succeeded

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta):
	# Si estamos buscando servidores (cliente)
	if udp_listener and udp_listener.is_bound():
		while udp_listener.get_available_packet_count() > 0:
			var packet = udp_listener.get_packet().get_string_from_utf8()
			var server_ip = udp_listener.get_packet_ip()
			
			if packet.begins_with("FK_SERVER:"):
				var data = packet.replace("FK_SERVER:", "")
				if not discovered_servers.has(server_ip):
					discovered_servers[server_ip] = data
					emit_signal("server_found", server_ip, data)

	# Si somos el host, enviar broadcasts
	if is_host and udp_broadcaster:
		# Enviar cada pocos frames
		if Engine.get_frames_drawn() % 60 == 0:
			var host_name = SaveManager.nombre_jugador if SaveManager.nombre_jugador != "" else "Host"
			var data = ("FK_SERVER:" + host_name).to_utf8_buffer()
			
			# Broadcast LAN
			udp_broadcaster.set_dest_address("255.255.255.255", BROADCAST_PORT)
			udp_broadcaster.put_packet(data)
			
			# Broadcast Localhost (para pruebas en la misma PC)
			udp_broadcaster.set_dest_address("127.0.0.1", BROADCAST_PORT)
			udp_broadcaster.put_packet(data)

func host_game():
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(DEFAULT_PORT, 4) # Max 4 jugadores
	if error != OK:
		print("Error creando server: ", error)
		return false
	
	multiplayer.multiplayer_peer = peer
	is_host = true
	
	# Iniciar broadcaster
	udp_broadcaster = PacketPeerUDP.new()
	udp_broadcaster.set_broadcast_enabled(true)
	udp_broadcaster.set_dest_address("255.255.255.255", BROADCAST_PORT)
	
	print("Servidor iniciado!")
	return true

func join_game(ip: String):
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip, DEFAULT_PORT)
	if error != OK:
		print("Error conectando al server: ", error)
		return false
	
	multiplayer.multiplayer_peer = peer
	is_host = false
	
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnect)
	return true

func start_discovery():
	discovered_servers.clear()
	udp_listener = PacketPeerUDP.new()
	var err = udp_listener.bind(BROADCAST_PORT)
	if err != OK:
		print("Error bindeando puerto UDP: ", err)

func stop_discovery():
	if udp_listener:
		udp_listener.close()
		udp_listener = null

func _on_connected_ok():
	emit_signal("connection_succeeded")

func _on_connected_fail():
	emit_signal("connection_failed")

func _on_server_disconnect():
	print("Desconectado del servidor")
	get_tree().change_scene_to_file("res://Scenes/UI/MainMenu.tscn")
	multiplayer.multiplayer_peer = null
