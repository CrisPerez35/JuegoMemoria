extends Control

func _ready() -> void:
	$VBox/BotonMosaico.pressed.connect(_ir_a_mosaico)

func _ir_a_mosaico() -> void:
	get_tree().change_scene_to_file("res://mosaico_memoria/Main.tscn")
