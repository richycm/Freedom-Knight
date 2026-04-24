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
var ya_curado = false # Para que solo cure una vez por charla

# --- CONFIGURACIÓN DE INGENIERÍA ---
@export var es_curandero: bool = true
@export var puntos_salud: int = 3

@onready var globo = $GloboDialogo
@onready var etiqueta_texto = $GloboDialogo/TextoDialogo

func _ready():
	$Zonai_interaccion.body_entered.connect(_on_body_entered)
	$Zonai_interaccion.body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.name == "Caballero":
		puede_interactuar = true

func _on_body_exited(body):
	if body.name == "Caballero":
		puede_interactuar = false
		globo.visible = false
		indice_actual = 0 # Reiniciamos el diálogo para la próxima vez
		ya_curado = false

func _process(_delta):
	if puede_interactuar and Input.is_action_just_pressed("attack"):
		hablar()

func hablar():
	if indice_actual < lista_mensajes.size():
		etiqueta_texto.text = lista_mensajes[indice_actual]
		globo.visible = true
		
		# --- LÓGICA DE CURACIÓN ---
		# Queremos que cure justo en el segundo mensaje (índice 1)
		if es_curandero and not ya_curado and indice_actual == 1:
			ejecutar_curacion()
		
		# Ajuste de la nube (usando el truco del frame que vimos)
		await get_tree().process_frame
		globo.reset_size()
		var center_offset = globo.size.x / 2
		globo.position = $PosicionDialogo.position - Vector2(center_offset, globo.size.y)
		
		indice_actual += 1
	else:
		globo.visible = false

func ejecutar_curacion():
	print("[SISTEMA] Intentando curar al caballero...")
	var caballero = get_tree().get_first_node_in_group("jugador")
	
	if caballero:
		print("[SISTEMA] Caballero encontrado: ", caballero.name)
		if caballero.has_method("curar"):
			caballero.curar(puntos_salud)
			ya_curado = true
			print("[SISTEMA] ¡Curación exitosa!")
		else:
			print("[ERROR] El caballero no tiene la función 'curar'")
	else:
		print("[ERROR] No se encontró a nadie en el grupo 'jugador'")
