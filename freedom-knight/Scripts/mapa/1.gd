extends Node2D

@export_group("Movimiento Caballero Bueno")
@export var velocidad: float = 250.0

@export_group("Sistema de Aliados")
@export var monje_escena: PackedScene # Arrastra el Monje2.tscn aquí en el Inspector

@onready var sprite = $Caballero 

var enemigos_muertos: int = 0

func _ready() -> void:
	y_sort_enabled = true
	
	# Buscamos en el grupo CaballeroMalo (por compatibilidad)
	var enemigos = get_tree().get_nodes_in_group("CaballeroMalo")
	
	# También buscamos de forma directa si no están en el grupo (excluyendo al aliado HCaballeroMalo)
	for nombre_enemigo in ["CaballeroMalo"]:
		var nodo = get_node_or_null(nombre_enemigo)
		if nodo and not nodo in enemigos:
			enemigos.append(nodo)
			
	# Instanciar un segundo enemigo CaballeroMalo para mantener la meta de 2 enemigos en el mapa
	var enemigo_escena = load("res://Scenes/UI/Personajes/Villanos/CaballeroMalo/caballero_malo.tscn")
	if enemigo_escena:
		var nuevo_malo = enemigo_escena.instantiate()
		nuevo_malo.name = "CaballeroMalo2"
		add_child(nuevo_malo)
		var base_enemigo = get_node_or_null("CaballeroMalo")
		if base_enemigo:
			nuevo_malo.global_position = base_enemigo.global_position + Vector2(150, -50)
		else:
			nuevo_malo.global_position = Vector2(2335, 1145)
		enemigos.append(nuevo_malo)
			
	# O buscamos a cualquier hijo directo que tenga la señal "murio" (excluyendo a HCaballeroMalo)
	for hijo in get_children():
		if hijo.name != "HCaballeroMalo" and hijo.has_signal("murio") and not hijo in enemigos:
			enemigos.append(hijo)
			
	# Conectamos las señales
	for enemigo in enemigos:
		if enemigo.has_signal("murio") and not enemigo.murio.is_connected(_on_enemigo_murio):
			enemigo.murio.connect(_on_enemigo_murio)
			print("Conectado con éxito a: ", enemigo.name)

func _physics_process(delta: float) -> void:
	# Tu movimiento original (sin lag)
	var direccion = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if direccion != Vector2.ZERO:
		position += direccion.normalized() * velocidad * delta

	if direccion.x != 0 and sprite != null:
		sprite.flip_h = direccion.x < 0

# Esta función se activa automáticamente cuando un CaballeroMalo muere
func _on_enemigo_murio(posicion_muerte: Vector2) -> void:
	enemigos_muertos += 1
	print("Enemigo muerto. Total derrotados: ", enemigos_muertos)
	
	# El primer caballero que muere invoca al monje aliado
	if enemigos_muertos == 1:
		if monje_escena:
			var monje = monje_escena.instantiate()
			add_child(monje)
			monje.global_position = Vector2(2335, 1145) 
			print("Mapa: Monje programado para aparecer en el siguiente frame.")
			
	# El segundo caballero que muere corta la escena y regresa al menú
	if enemigos_muertos >= 2:
		_mostrar_continuara()

func _mostrar_continuara() -> void:
	print("Límite alcanzado: Cortando escena para mostrar 'Continuará...'")
	
	# Desactivar el procesamiento del jugador para evitar movimientos
	var jugador = get_tree().get_first_node_in_group("jugador")
	if not jugador:
		jugador = get_tree().get_first_node_in_group("Jugador")
	if not jugador:
		jugador = get_node_or_null("Caballero")
	if jugador:
		jugador.set_physics_process(false)
		jugador.set_process(false)
		if "velocity" in jugador:
			jugador.velocity = Vector2.ZERO
		if "sprite" in jugador and jugador.sprite:
			jugador.sprite.play("idle")
			
	# Crear un CanvasLayer para la pantalla de transición
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	
	# Fondo negro
	var fondo = ColorRect.new()
	fondo.color = Color(0, 0, 0, 0) # Empieza transparente para el fade in
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(fondo)
	
	# Mensaje "Continuará..."
	var label = Label.new()
	label.text = "Continuará..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5)) # Dorado elegante
	label.modulate.a = 0.0 # Empieza transparente
	canvas.add_child(label)
	
	# Transición de desvanecimiento
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(fondo, "color:a", 1.0, 1.5)
	tween.tween_property(label, "modulate:a", 1.0, 1.5)
	
	await tween.finished
	await get_tree().create_timer(2.0).timeout
	
	# Redirigir al menú principal
	get_tree().change_scene_to_file("res://Scenes/UI/MainMenu.tscn")
