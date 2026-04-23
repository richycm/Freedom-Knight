extends StaticBody2D

var puede_interactuar = false

# Referencias a los nuevos nodos
@onready var globo = $GloboDialogo
@onready var etiqueta_texto = $GloboDialogo/TextoDialogo

func _ready():
	$Zonai_interaccion.body_entered.connect(_on_body_entered)
	$Zonai_interaccion.body_exited.connect(_on_body_exited)
	globo.visible = false # Aseguramos que empiece oculto

func _on_body_entered(body):
	if body.name == "Caballero":
		puede_interactuar = true
		# Opcional: Mostrar un "..." para indicar que puede hablar
		etiqueta_texto.text = "..."
		globo.visible = true 

func _on_body_exited(body):
	if body.name == "Caballero":
		puede_interactuar = false
		globo.visible = false # Se oculta si te vas

func _process(_delta):
	if puede_interactuar and Input.is_action_just_pressed("attack"):
		hablar()


func hablar():
	etiqueta_texto.text = "¡Hola caballero!"
	globo.visible = true
	
	# Truco Pro: Ajustar el tamaño del NinePatch al tamaño del texto
	# Esto hace que la nube 'crezca' con el mensaje
	globo.size = etiqueta_texto.get_combined_minimum_size() + Vector2(20, 20)
	
	# Centrar la nube sobre el monje después de que creció
	globo.position = $PosicionDialogo.position - Vector2(globo.size.x / 2, globo.size.y)
