extends Button

# Se emite cuando el jugador presiona esta celda; lleva su índice en la grilla
signal tile_pressed(index: int)

# Colores para cada estado visual
const COLOR_NORMAL   := Color(0.78, 0.80, 0.88)   # gris azulado
const COLOR_LIT      := Color(0.20, 0.65, 1.00)   # celeste (fase memorizar)
const COLOR_CORRECTO := Color(0.18, 0.82, 0.38)   # verde (acierto)
const COLOR_INCORR   := Color(1.00, 0.22, 0.22)   # rojo (error)

var index: int = 0
var _estilo: StyleBoxFlat

func _ready() -> void:
	# Crear un StyleBoxFlat y aplicarlo a todos los estados del botón
	_estilo = StyleBoxFlat.new()
	_estilo.corner_radius_top_left     = 10
	_estilo.corner_radius_top_right    = 10
	_estilo.corner_radius_bottom_left  = 10
	_estilo.corner_radius_bottom_right = 10
	_estilo.border_width_left   = 3
	_estilo.border_width_top    = 3
	_estilo.border_width_right  = 3
	_estilo.border_width_bottom = 3
	_estilo.border_color = Color(0.35, 0.38, 0.50)
	add_theme_stylebox_override("normal",   _estilo)
	add_theme_stylebox_override("hover",    _estilo)
	add_theme_stylebox_override("pressed",  _estilo)
	add_theme_stylebox_override("focus",    _estilo)
	add_theme_stylebox_override("disabled", _estilo)
	set_estado_normal()
	pressed.connect(_al_presionar)

func _al_presionar() -> void:
	tile_pressed.emit(index)

# --- Funciones de estado visual (llamadas desde Main.gd) ---

func set_estado_normal() -> void:
	_estilo.bg_color = COLOR_NORMAL
	_estilo.border_color = Color(0.35, 0.38, 0.50)

func set_estado_iluminado() -> void:
	_estilo.bg_color = COLOR_LIT
	_estilo.border_color = Color(0.10, 0.45, 0.90)

func set_estado_correcto() -> void:
	_estilo.bg_color = COLOR_CORRECTO
	_estilo.border_color = Color(0.10, 0.55, 0.25)

func set_estado_incorrecto() -> void:
	_estilo.bg_color = COLOR_INCORR
	_estilo.border_color = Color(0.75, 0.10, 0.10)
