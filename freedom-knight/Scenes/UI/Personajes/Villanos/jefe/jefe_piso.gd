extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D

var player: CharacterBody2D = null

# Sincronización de red (para clientes)
var net_position : Vector2 = Vector2.ZERO
var net_anim     : String  = "correr"
var net_flip     : bool    = false
const INTERP_SPEED : float = 12.0

var speed: float = 65.0 # Un poco lento pero imponente
var vida_maxima: float = 120.0
var salud_actual: float = 120.0
var poder_ataque: int = 5

var esta_atacando: bool = false
var is_dead: bool = false

var attack_cooldown: float = 1.5
var attack_timer: float = 0.0

var barra_vida: ProgressBar = null

# Señal para avisarle al mapa cuando el jefe sea derrotado
signal murio(posicion)

func _ready() -> void:
	# En modo cliente: deshabilitar IA
	if _is_client_only():
		set_physics_process(false)
		net_position = global_position
		_configurar_animaciones()
		_crear_barra_vida()
		return

	add_to_group("jefe")
	add_to_group("enemigos")
	salud_actual = vida_maxima
	
	# Configurar colisiones para que sea un enemigo de Capa 3 y choque con el mapa (Capa 1)
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_layer_value(3, true)
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, false)
	set_collision_mask_value(3, false)
	
	# Configurar las animaciones del jefe dinámicamente
	_configurar_animaciones()
	
	# Crear barra de vida flotante sobre la cabeza del jefe
	_crear_barra_vida()
	
	player = _obtener_jugador()

func _configurar_animaciones() -> void:
	# Ocultar el sprite neutro estático
	var boss_neutro = get_node_or_null("BossNeutro")
	if boss_neutro:
		boss_neutro.visible = false
	
	# Alinear el sprite animado donde estaba el estático
	animated_sprite.position = Vector2(3, -8)
	
	# Crear SpriteFrames programáticamente
	var sf = SpriteFrames.new()
	sf.add_animation("default")
	sf.add_animation("correr")
	sf.add_animation("atacar")
	
	# Cargar texturas de los archivos del jefe
	var tex_neutro = load("res://Scenes/UI/Personajes/Villanos/jefe/boss-neutro.png")
	var tex_correr1 = load("res://Scenes/UI/Personajes/Villanos/jefe/correr-1.png")
	var tex_correr2 = load("res://Scenes/UI/Personajes/Villanos/jefe/correr-2.png")
	var tex_correr3 = load("res://Scenes/UI/Personajes/Villanos/jefe/correr-3.png")
	var tex_correr4 = load("res://Scenes/UI/Personajes/Villanos/jefe/correr-4.png")
	
	var tex_ataque1 = load("res://Scenes/UI/Personajes/Villanos/jefe/ataque-1.png")
	var tex_ataque2 = load("res://Scenes/UI/Personajes/Villanos/jefe/ataque-2.png")
	var tex_ataque3 = load("res://Scenes/UI/Personajes/Villanos/jefe/ataque-3.png")
	var tex_ataque4 = load("res://Scenes/UI/Personajes/Villanos/jefe/ataque-4.png")
	var tex_ataque5 = load("res://Scenes/UI/Personajes/Villanos/jefe/ataque-5.png")
	var tex_ataque6 = load("res://Scenes/UI/Personajes/Villanos/jefe/ataque-6.png")
	var tex_ataque7 = load("res://Scenes/UI/Personajes/Villanos/jefe/ataque-7.png")
	
	if tex_neutro:
		sf.add_frame("default", tex_neutro)
	if tex_correr1:
		sf.add_frame("correr", tex_correr1)
	if tex_correr2:
		sf.add_frame("correr", tex_correr2)
	if tex_correr3:
		sf.add_frame("correr", tex_correr3)
	if tex_correr4:
		sf.add_frame("correr", tex_correr4)
		
	if tex_ataque1: sf.add_frame("atacar", tex_ataque1)
	if tex_ataque2: sf.add_frame("atacar", tex_ataque2)
	if tex_ataque3: sf.add_frame("atacar", tex_ataque3)
	if tex_ataque4: sf.add_frame("atacar", tex_ataque4)
	if tex_ataque5: sf.add_frame("atacar", tex_ataque5)
	if tex_ataque6: sf.add_frame("atacar", tex_ataque6)
	if tex_ataque7: sf.add_frame("atacar", tex_ataque7)
		
	# Configurar velocidad e iteración de la animación
	sf.set_animation_speed("correr", 6.0) # 6 frames por segundo para que luzca pesado e imponente
	sf.set_animation_loop("correr", true)
	
	sf.set_animation_speed("atacar", 10.0) # 10 frames por segundo para el ataque
	sf.set_animation_loop("atacar", false) # El ataque no debe repetirse en bucle
	
	animated_sprite.sprite_frames = sf
	
	# Iniciar reproducción
	if sf.has_animation("correr"):
		animated_sprite.play("correr")

func _crear_barra_vida() -> void:
	barra_vida = ProgressBar.new()
	barra_vida.max_value = vida_maxima
	barra_vida.value = salud_actual
	barra_vida.show_percentage = false
	
	# Estilo visual de la barra (Rojo oscuro para el fondo, Rojo brillante para la salud)
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.2, 0.05, 0.05, 0.7)
	style_bg.set_border_width_all(1)
	style_bg.border_color = Color.BLACK
	
	var style_fg = StyleBoxFlat.new()
	style_fg.bg_color = Color(0.8, 0.1, 0.1) # Rojo de jefe
	style_fg.set_border_width_all(1)
	style_fg.border_color = Color.BLACK
	
	barra_vida.add_theme_stylebox_override("background", style_bg)
	barra_vida.add_theme_stylebox_override("fill", style_fg)
	
	# Ubicar sobre la cabeza (el jefe mide unos 488 de altura de colisión, y = 6 - 244 es la cima)
	barra_vida.position = Vector2(-75, -280)
	barra_vida.custom_minimum_size = Vector2(150, 10)
	add_child(barra_vida)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
		
	# Si el jugador no existe (murió) o no es válido, intentamos buscarlo
	if not is_instance_valid(player) or player.get("is_dead") == true:
		player = _obtener_jugador()
		if not is_instance_valid(player):
			velocity = Vector2.ZERO
			if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("default"):
				animated_sprite.play("default")
			return
			
	if attack_timer > 0:
		attack_timer -= delta
		
	# Calcular la dirección hacia donde está el jugador para perseguirlo
	var direccion = (player.global_position - global_position).normalized()
	var distancia = global_position.distance_to(player.global_position)
	
	# Distancia de parada para no encimarse y poder atacar
	var stop_distance = 150.0
	
	if esta_atacando:
		velocity = Vector2.ZERO
	elif distancia > stop_distance:
		velocity = direccion * speed
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("correr") and animated_sprite.animation != "correr":
			animated_sprite.play("correr")
	else:
		velocity = Vector2.ZERO
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("default") and animated_sprite.animation != "default":
			animated_sprite.play("default")
		if attack_timer <= 0:
			_atacar_jugador()
			
	move_and_slide()

	# Sincronizar estado a clientes (host → broadcast)
	if NetworkManager.is_multiplayer_active() and NetworkManager.is_server():
		var anim = animated_sprite.animation if animated_sprite else "default"
		var flip = animated_sprite.flip_h if animated_sprite else false
		_rpc_sync_enemy.rpc(global_position, anim, flip, salud_actual, is_dead)
	
	# Voltear el sprite en el eje X dependiendo de si va a la izquierda o derecha
	if direccion.x < 0:
		animated_sprite.flip_h = true
	elif direccion.x > 0:
		animated_sprite.flip_h = false

func _obtener_jugador() -> CharacterBody2D:
	for g in ["jugador", "Jugador"]:
		var nodos = get_tree().get_nodes_in_group(g)
		for n in nodos:
			if n is CharacterBody2D and is_instance_valid(n) and not (n.get("is_dead") == true):
				return n
	return null

func _atacar_jugador() -> void:
	if not is_instance_valid(player) or player.get("is_dead") == true:
		return
		
	esta_atacando = true
	
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("atacar"):
		animated_sprite.play("atacar")
		await animated_sprite.animation_finished
	else:
		# Animación ficticia de lunge (embestida rápida hacia adelante y atrás) usando Tweens
		var original_pos = position
		var target_pos = position + (player.global_position - global_position).normalized() * 40.0
		var tween = create_tween()
		tween.tween_property(self, "position", target_pos, 0.12)
		tween.tween_property(self, "position", original_pos, 0.12)
		await tween.finished
		
	# Hacer daño si el jugador sigue estando cerca
	if is_instance_valid(player) and global_position.distance_to(player.global_position) <= 180.0:
		if player.has_method("recibir_dano"):
			player.recibir_dano(poder_ataque)
			
	esta_atacando = false
	attack_timer = attack_cooldown

func recibir_dano(cantidad: int) -> void:
	if is_dead:
		return
		
	salud_actual -= cantidad
	
	# Actualizar la barra de vida flotante
	if is_instance_valid(barra_vida):
		barra_vida.value = salud_actual
		
	_efecto_dano()
	
	if salud_actual <= 0:
		_morir()

func _efecto_dano() -> void:
	var tween = create_tween()
	modulate = Color.RED
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)

func _morir() -> void:
	if is_dead:
		return
	is_dead = true
	
	# Eliminar la barra de vida
	if is_instance_valid(barra_vida):
		barra_vida.queue_free()
	
	# Desactivar colisiones
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_layer_value(3, false)
	set_collision_mask_value(1, false)
	set_collision_mask_value(2, false)
	set_collision_mask_value(3, false)
	
	velocity = Vector2.ZERO
	murio.emit(global_position)
	
	if PlayerRegistry.has_method("crear_explosion"):
		PlayerRegistry.crear_explosion(global_position, 2.5)
		
	# Enviar RPC de muerte explícito a los clientes
	if NetworkManager.is_multiplayer_active() and NetworkManager.is_server():
		_rpc_sync_enemy.rpc(global_position, "default", false, 0, true)
	
	# Desvanecer al jefe de forma suave
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.2)
	await tween.finished
	queue_free()

func _is_client_only() -> bool:
	return NetworkManager.is_multiplayer_active() and not NetworkManager.is_server()

func _process(delta: float) -> void:
	if _is_client_only():
		if is_dead: return
		global_position = global_position.lerp(net_position, INTERP_SPEED * delta)
		if animated_sprite:
			if animated_sprite.animation != net_anim:
				animated_sprite.play(net_anim)
			animated_sprite.flip_h = net_flip

func _morir_client() -> void:
	is_dead = true
	if is_instance_valid(barra_vida):
		barra_vida.queue_free()
	
	# Desactivar colisiones
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_layer_value(3, false)
	set_collision_mask_value(1, false)
	set_collision_mask_value(2, false)
	set_collision_mask_value(3, false)
	
	if PlayerRegistry.has_method("crear_explosion"):
		PlayerRegistry.crear_explosion(net_position, 2.5)
		
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.2)
	await tween.finished
	queue_free()

@rpc("authority", "unreliable_ordered")
func _rpc_sync_enemy(pos: Vector2, anim: String, flip: bool, salud: float, dead: bool) -> void:
	if NetworkManager.is_server(): return
	net_position = pos
	net_anim = anim
	net_flip = flip
	
	if salud < salud_actual:
		_efecto_dano()
	salud_actual = salud
	
	if is_instance_valid(barra_vida):
		barra_vida.value = salud_actual
		
	if dead and not is_dead:
		_morir_client()
