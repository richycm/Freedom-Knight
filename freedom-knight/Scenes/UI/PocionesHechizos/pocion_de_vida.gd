extends Area2D

@export var cantidad_curacion: int = 2

var jugador_cerca: Node = null  # quién está en rango

func _ready() -> void:
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
	queue_free()
