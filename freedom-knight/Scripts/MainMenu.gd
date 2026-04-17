extends Control

# @onready asegura que el script encuentre los nodos al cargar la escena
@onready var music_player = $MusicPlayer

func _ready():
	# La música empezará a sonar apenas se abra el menú
	if music_player:
		music_player.play()
	else:
		print("Error: No se encontró el nodo MusicPlayer")

# --- FUNCIONES DE LOS BOTONES ---

func _on_options_button_pressed():
	# Aquí podrías abrir un panel de opciones más adelante
	print("Abriendo opciones...")

func _on_credits_button_pressed():
	print("Freedom Knight")

func _on_exit_button_pressed():
	# Cierra la ventana del juego
	get_tree().quit()

func _on_prueba_pressed() -> void:
	get_tree().change_scene_to_file("res://escenario_pruebas.tscn")


func _on_music_player_finished() -> void:
	$MusicPlayer.play()
