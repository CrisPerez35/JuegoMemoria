extends Control

func _ready() -> void:
	$VBox/BotonMosaico.pressed.connect(_ir_a_mosaico)
	$VBox/BotonTablas.pressed.connect(_ir_a_tablas)
	$VBox/BotonJuego3.pressed.connect(_ir_a_reacciona)

func _ir_a_mosaico() -> void:
	get_tree().change_scene_to_file("res://mosaico_memoria/Main.tscn")

func _ir_a_tablas() -> void:
	get_tree().change_scene_to_file("res://tablas_rapidas/TablasRapidas.tscn")

func _ir_a_reacciona() -> void:
	get_tree().change_scene_to_file("res://reacciona_color/ReaccionaColor.tscn")
