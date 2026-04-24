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

@export var es_curandero: bool = true
@export var puntos_salud: int = 3

# --- LO NUEVO: Referencia al sprite animado ---
@onready var sprite = $sprite_visual # Ojo: Asegúrate de que el nodo se llame exactamente así en tu escena

@onready var globo = $GloboDialogo
@onready var etiqueta_texto = $GloboDialogo/TextoDialogo

func _ready():
	# --- LO NUEVO: Iniciamos la animación ---
	if sprite:
		sprite.play("idle")
		
	# Es buena práctica ocultar el globo al inicio
	globo.visible = false
	$Zonai_interaccion.body_entered.connect(_on_body_entered)
	$Zonai_interaccion.body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.name == "Caballero":
		puede_interactuar = true

func _on_body_exited(body):
	if body.name == "Caballero":
		puede_interactuar = false
		globo.visible = false
		indice_actual = 0 
		ya_curado = false

func _process(_delta):
	if puede_interactuar and Input.is_action_just_pressed("interact"):
		hablar()

func hablar():
	if indice_actual < lista_mensajes.size():
		etiqueta_texto.text = lista_mensajes[indice_actual]
		globo.visible = true
		
		if es_curandero and not ya_curado and indice_actual == 1:
			ejecutar_curacion()
		
		# --- LA CURA PARA EL GLOBO GIGANTE ---
		# Forzamos al texto a que se reduzca a cero. Godot automáticamente 
		# lo ajustará al tamaño estrictamente necesario para la frase actual.
		etiqueta_texto.size = Vector2.ZERO 
		
		await get_tree().process_frame
		
		var margen = Vector2(30, 20)
		
		# En lugar de usar .size, usamos get_minimum_size() que nos da 
		# el tamaño real de las letras sin estiramientos raros.
		var tamano_real_texto = etiqueta_texto.get_minimum_size()
		
		globo.size = tamano_real_texto + margen
		etiqueta_texto.position = margen / 2
		
		# Aquí definimos a cuántos píxeles del lado izquierdo está la "colita" del globo.
		# (Aproximadamente unos 25 píxeles, pero puedes cambiar este número si lo quieres mover más).
		var distancia_colita = 25 

		# Le sumamos unos 5 píxeles extra en "Y" para que no quede aplastado contra la cabeza
		globo.global_position = $PosicionDialogo.global_position - Vector2(distancia_colita, globo.size.y + 5)
		
		globo.z_index = 50 
		
		indice_actual += 1
	else:
		globo.visible = false
		indice_actual = 0 
		ya_curado = false

func ejecutar_curacion():
	print("[SISTEMA] Intentando curar al caballero...")
	var caballero = get_tree().get_first_node_in_group("jugador")
	
	if caballero:
		if caballero.has_method("curar"):
			caballero.curar(puntos_salud)
			ya_curado = true
			print("[SISTEMA] ¡Curación exitosa!")
		else:
			print("[ERROR] El nodo en grupo 'jugador' no tiene método 'curar'")
	else:
		print("[ERROR] No se encontró al jugador en el grupo 'jugador'")
