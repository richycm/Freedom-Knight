extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D

var player: CharacterBody2D = null

# Sincronización de red (para clientes)
var net_position : Vector2 = Vector2.ZERO
var net_anim     : String  = "vuelo"
var net_flip     : bool    = false
const INTERP_SPEED : float = 12.0

var speed: float = 110.0 # Más rápido ya que es un dragón volador
var vida_maxima: float = 200.0 # Jefe imponente
var salud_actual: float = 200.0
var poder_ataque: int = 6

var esta_atacando: bool = false
var is_dead: bool = false

var attack_cooldown: float = 1.8
var attack_timer: float = 0.0

var barra_vida: ProgressBar = null

# Señal para avisarle al mapa cuando el jefe sea derrotado
signal murio(posicion)

func _ready() -> void:
	add_to_group("jefe")
	add_to_group("enemigos")
	
	# Ajustar estadísticas dinámicamente según la fuerza del jugador
	_escalar_stats_jefe()
	
	# Configurar colisiones para que sea un enemigo de Capa 3 y choque con el mapa (Capa 1)
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_layer_value(3, true)
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, false)
	set_collision_mask_value(3, false)
	
	# Configurar las animaciones del dragón dinámicamente
	_configurar_animaciones()
	
	# Crear barra de vida flotante sobre la cabeza del dragón
	_crear_barra_vida()

func _escalar_stats_jefe() -> void:
	# Obtener stats del caballero
	var player_dmg = 2
	var player_lvl = 1
	var num_jugadores = 1
	
	var jugadores = PlayerRegistry.get_all_players()
	if jugadores.size() > 0:
		num_jugadores = jugadores.size()
		for p in jugadores:
			if is_instance_valid(p):
				if p.get("nivel") > player_lvl:
					player_lvl = p.get("nivel")
				if p.get("poder_ataque") > player_dmg:
					player_dmg = p.get("poder_ataque")
	else:
		var local_player = PlayerRegistry.get_local_player()
		if is_instance_valid(local_player):
			player_lvl = local_player.get("nivel")
			player_dmg = local_player.get("poder_ataque")
			
	# Multiplicador por cantidad de jugadores en multijugador
	var mult_jugadores = 0.6 + 0.4 * num_jugadores
	
	# Escalar vida del Dragón: aprox 50 golpes del caballero. Rango: de 100 a 1500 HP.
	vida_maxima = clampf(player_dmg * 50.0 * mult_jugadores, 100.0, 1500.0)
	salud_actual = vida_maxima
	
	# Escalar daño del Dragón: defensa del caballero (nivel / 3) + 4 puntos (2 corazones enteros de daño real constante)
	# Mínimo de 5 para que siga siendo un combate de jefe final.
	var defensa_estimada = floor(player_lvl / 3.0)
	poder_ataque = clampi(int(defensa_estimada + 4), 5, 30)
	
	print("[DRAGÓN ESCALADO] Jugadores: %d | DMG Caballero: %d | LVL Caballero: %d | Vida: %d | Poder Ataque: %d" % [num_jugadores, player_dmg, player_lvl, vida_maxima, poder_ataque])

	# En modo cliente: deshabilitar IA
	if _is_client_only():
		set_physics_process(false)
		net_position = global_position
		return
	
	player = _obtener_jugador_mas_cercano()

func _configurar_animaciones() -> void:
	# Crear SpriteFrames programáticamente
	var sf = SpriteFrames.new()
	
	# Asegurar que existan las animaciones
	sf.add_animation("vuelo")
	sf.add_animation("ataque-1")
	sf.add_animation("ataque-2")
	sf.add_animation("muerte")
	
	# Cargar vuelo
	for i in range(1, 5):
		var tex = load("res://Scenes/UI/Personajes/Villanos/dragon/vuelo/vuela-%d.png" % i)
		if tex:
			sf.add_frame("vuelo", tex)
	
	# Cargar ataque-1 (1.1 a 1.6)
	for i in range(1, 7):
		var tex = load("res://Scenes/UI/Personajes/Villanos/dragon/ataque-1/ataque-1.%d.png" % i)
		if tex:
			sf.add_frame("ataque-1", tex)
	# Cargar llamas de ataque-1 (1.6 a 1.7)
	for i in range(6, 8):
		var tex = load("res://Scenes/UI/Personajes/Villanos/dragon/ataque-1/llamas-ataque-1.%d.png" % i)
		if tex:
			sf.add_frame("ataque-1", tex)
			
	# Cargar ataque-2
	for i in range(1, 6):
		var tex = load("res://Scenes/UI/Personajes/Villanos/dragon/ataque-2/ataque-2.%d.png" % i)
		if tex:
			sf.add_frame("ataque-2", tex)
			
	# Cargar muerte
	for i in range(1, 5):
		var tex = load("res://Scenes/UI/Personajes/Villanos/dragon/muerte/muerte-%d.png" % i)
		if tex:
			sf.add_frame("muerte", tex)
			
	# Configurar velocidad e iteración de las animaciones
	sf.set_animation_speed("vuelo", 8.0)
	sf.set_animation_loop("vuelo", true)
	
	sf.set_animation_speed("ataque-1", 10.0)
	sf.set_animation_loop("ataque-1", false)
	
	sf.set_animation_speed("ataque-2", 10.0)
	sf.set_animation_loop("ataque-2", false)
	
	sf.set_animation_speed("muerte", 6.0)
	sf.set_animation_loop("muerte", false)
	
	animated_sprite.sprite_frames = sf
	animated_sprite.play("vuelo")

func _crear_barra_vida() -> void:
	barra_vida = ProgressBar.new()
	barra_vida.max_value = vida_maxima
	barra_vida.value = salud_actual
	barra_vida.show_percentage = false
	
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.2, 0.05, 0.05, 0.7)
	style_bg.set_border_width_all(1)
	style_bg.border_color = Color.BLACK
	
	var style_fg = StyleBoxFlat.new()
	style_fg.bg_color = Color(0.9, 0.15, 0.15) # Rojo fuego de dragón
	style_fg.set_border_width_all(1)
	style_fg.border_color = Color.BLACK
	
	barra_vida.add_theme_stylebox_override("background", style_bg)
	barra_vida.add_theme_stylebox_override("fill", style_fg)
	
	# Mide unos 174 de alto, por lo que -130 a -150 está bien
	barra_vida.position = Vector2(-75, -130)
	barra_vida.custom_minimum_size = Vector2(150, 10)
	add_child(barra_vida)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
		
	player = _obtener_jugador_mas_cercano()
	if not is_instance_valid(player):
		velocity = Vector2.ZERO
		if animated_sprite.animation != "vuelo":
			animated_sprite.play("vuelo")
		return
			
	if attack_timer > 0:
		attack_timer -= delta
		
	var direccion = (player.global_position - global_position).normalized()
	var distancia = global_position.distance_to(player.global_position)
	
	# Distancia de parada del dragón (un poco mayor para dar espacio a sus llamas y mordidas)
	var stop_distance = 180.0
	
	if esta_atacando:
		velocity = Vector2.ZERO
	elif distancia > stop_distance:
		velocity = direccion * speed
		if animated_sprite.animation != "vuelo":
			animated_sprite.play("vuelo")
	else:
		velocity = Vector2.ZERO
		if animated_sprite.animation != "vuelo":
			animated_sprite.play("vuelo")
		if attack_timer <= 0:
			_atacar_jugador()
			
	move_and_slide()

	# Sincronizar estado a clientes (host → broadcast)
	if NetworkManager.is_multiplayer_active() and NetworkManager.is_server():
		var anim = animated_sprite.animation if animated_sprite else "vuelo"
		var flip = animated_sprite.flip_h if animated_sprite else false
		_rpc_sync_enemy.rpc(global_position, anim, flip, salud_actual, is_dead, vida_maxima)
	
	# Voltear sprite y área de ataque según dirección
	if direccion.x < 0:
		animated_sprite.flip_h = true
		if has_node("Area2D"):
			$Area2D.scale.x = -1
	elif direccion.x > 0:
		animated_sprite.flip_h = false
		if has_node("Area2D"):
			$Area2D.scale.x = 1

func _obtener_jugador_mas_cercano() -> CharacterBody2D:
	return PlayerRegistry.get_nearest_player_to(global_position) as CharacterBody2D

func _atacar_jugador() -> void:
	if not is_instance_valid(player) or player.get("is_dead") == true:
		return
		
	esta_atacando = true
	
	# Elegir un ataque aleatorio
	var tipo_ataque = randi() % 2
	var anim_nombre = "ataque-1" if tipo_ataque == 0 else "ataque-2"
	
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_nombre):
		animated_sprite.play(anim_nombre)
		
		# Para ataque-1 (llamas), aplicar daño a mitad de la animación cuando salen las llamas
		if anim_nombre == "ataque-1":
			await get_tree().create_timer(0.5).timeout
			_aplicar_dano_area(220.0) # Mayor rango para llamas
		else:
			await get_tree().create_timer(0.3).timeout
			_aplicar_dano_area(180.0)
			
		await animated_sprite.animation_finished
	else:
		# Fallback
		await get_tree().create_timer(0.5).timeout
		_aplicar_dano_area(180.0)
			
	esta_atacando = false
	attack_timer = attack_cooldown

func _aplicar_dano_area(rango_maximo: float) -> void:
	if is_dead: return
	for p in PlayerRegistry.get_all_players():
		if is_instance_valid(p) and p.get("is_dead") != true:
			if global_position.distance_to(p.global_position) <= rango_maximo:
				if p.has_method("recibir_dano"):
					p.recibir_dano(poder_ataque)

func recibir_dano(cantidad: int) -> void:
	if is_dead:
		return
		
	salud_actual -= cantidad
	
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
		PlayerRegistry.crear_explosion(global_position, 3.5) # Explosión más grande!
		
	if NetworkManager.is_multiplayer_active() and NetworkManager.is_server():
		_rpc_sync_enemy.rpc(global_position, "muerte", false, 0, true, vida_maxima)
	
	if animated_sprite.sprite_frames.has_animation("muerte"):
		animated_sprite.play("muerte")
		await animated_sprite.animation_finished
	
	# Desvanecer al dragón suavemente
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.5)
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
	
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_layer_value(3, false)
	set_collision_mask_value(1, false)
	set_collision_mask_value(2, false)
	set_collision_mask_value(3, false)
	
	if PlayerRegistry.has_method("crear_explosion"):
		PlayerRegistry.crear_explosion(net_position, 3.5)
		
	if animated_sprite.sprite_frames.has_animation("muerte"):
		animated_sprite.play("muerte")
		await animated_sprite.animation_finished
		
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.5)
	await tween.finished
	queue_free()

@rpc("authority", "unreliable_ordered")
func _rpc_sync_enemy(pos: Vector2, anim: String, flip: bool, salud: float, dead: bool, v_max: float) -> void:
	if NetworkManager.is_server(): return
	net_position = pos
	net_anim = anim
	net_flip = flip
	
	if salud < salud_actual:
		_efecto_dano()
	salud_actual = salud
	vida_maxima = v_max
	
	if is_instance_valid(barra_vida):
		if barra_vida.max_value != v_max:
			barra_vida.max_value = v_max
		barra_vida.value = salud_actual
		
	if dead and not is_dead:
		_morir_client()
