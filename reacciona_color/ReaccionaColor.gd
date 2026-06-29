extends Control

# =============================================================
# CONSTANTES DE DIFICULTAD
# =============================================================
const VIDAS_INICIALES         := 3
const PUNTOS_ACIERTO          := 1
const INTERVALO_INICIAL       := 1.0    # segundos entre cambios de color
const INTERVALO_MIN           := 0.3
const REDUCCION_INTERVALO     := 0.02   # reducción por cada acierto
const OPORTUNIDADES_MAX       := 3      # coincidencias ignoradas antes de perder vida
const DURACION_FEEDBACK       := 0.25   # segundos del flash visual

const COLORES: Dictionary = {
	"Rojo":     Color(0.90, 0.15, 0.15),
	"Azul":     Color(0.15, 0.35, 0.90),
	"Verde":    Color(0.15, 0.75, 0.25),
	"Amarillo": Color(0.95, 0.85, 0.10),
	"Naranja":  Color(0.95, 0.50, 0.10),
	"Morado":   Color(0.60, 0.15, 0.90),
}
const COLORES_INICIALES: Array = ["Rojo", "Azul", "Verde", "Amarillo"]
const UMBRAL_NARANJA          := 10
const UMBRAL_MORADO           := 20
const ARCHIVO_SAVE            := "user://reacciona_color_save.dat"

# =============================================================
# MÁQUINA DE ESTADOS
# =============================================================
enum Estado { JUGANDO, FEEDBACK, GAME_OVER }

var estado: Estado = Estado.JUGANDO
var puntaje:               int   = 0
var vidas:                 int   = VIDAS_INICIALES
var puntaje_maximo:        int   = 0
var intervalo_actual:      float = INTERVALO_INICIAL
var color_objetivo:        String = ""
var color_boton:           String = ""
var oportunidades_perdidas: int  = 0
var pool_colores:          Array  = []

# =============================================================
# REFERENCIAS A NODOS
# =============================================================
@onready var boton_menu_juego:      Button    = $MainVBox/InfoBar/BotonMenuJuego
@onready var label_puntaje:         Label     = $MainVBox/InfoBar/LabelPuntaje
@onready var label_vidas:           Label     = $MainVBox/InfoBar/LabelVidas
@onready var color_rect_objetivo:   ColorRect = $MainVBox/ObjetivoSection/CenterRectObjetivo/ColorRectObjetivo
@onready var label_nombre_objetivo: Label     = $MainVBox/ObjetivoSection/LabelNombreObjetivo
@onready var boton_color:           Button    = $MainVBox/CenterBoton/BotonColor
@onready var timer_cambio:          Timer     = $TimerCambio
@onready var panel_game_over:       Panel     = $GameOverPanel
@onready var label_puntaje_final:   Label     = $GameOverPanel/VBoxCenter/LabelPuntajeFinal
@onready var label_maximo:          Label     = $GameOverPanel/VBoxCenter/LabelMaximo
@onready var boton_reintentar:      Button    = $GameOverPanel/VBoxCenter/BotonReintentar
@onready var boton_menu:            Button    = $GameOverPanel/VBoxCenter/BotonMenu

func _ready() -> void:
	boton_menu_juego.pressed.connect(_ir_al_menu)
	boton_color.pressed.connect(_al_presionar_boton)
	boton_reintentar.pressed.connect(_reiniciar_juego)
	boton_menu.pressed.connect(_ir_al_menu)
	timer_cambio.timeout.connect(_al_cambiar_color)
	_cargar_puntaje_maximo()
	_reiniciar_juego()

# =============================================================
# FLUJO PRINCIPAL
# =============================================================

func _reiniciar_juego() -> void:
	puntaje                = 0
	vidas                  = VIDAS_INICIALES
	intervalo_actual       = INTERVALO_INICIAL
	oportunidades_perdidas = 0
	pool_colores           = COLORES_INICIALES.duplicate()
	panel_game_over.visible = false
	boton_color.disabled    = false
	estado = Estado.JUGANDO
	_elegir_nuevo_objetivo()
	_cambiar_color_boton_aleatorio()
	timer_cambio.wait_time = intervalo_actual
	timer_cambio.start()
	_actualizar_ui()

func _elegir_nuevo_objetivo() -> void:
	var candidatos: Array = pool_colores.filter(func(c): return c != color_objetivo)
	if candidatos.is_empty():
		candidatos = pool_colores.duplicate()
	candidatos.shuffle()
	color_objetivo = candidatos[0]
	color_rect_objetivo.color = COLORES[color_objetivo]
	label_nombre_objetivo.text = color_objetivo.to_upper()

func _cambiar_color_boton_aleatorio() -> void:
	var candidatos: Array = pool_colores.duplicate()
	candidatos.shuffle()
	color_boton = candidatos[0]
	_aplicar_color_boton(COLORES[color_boton])

# Callback del timer: cambia el color del botón automáticamente
func _al_cambiar_color() -> void:
	if estado != Estado.JUGANDO:
		return
	# Si el color actual coincidía con el objetivo y el jugador no tocó, es oportunidad perdida
	if color_boton == color_objetivo:
		oportunidades_perdidas += 1
		if oportunidades_perdidas >= OPORTUNIDADES_MAX:
			oportunidades_perdidas = 0
			vidas -= 1
			_actualizar_ui()
			if vidas <= 0:
				_game_over()
				return
	_cambiar_color_boton_aleatorio()
	timer_cambio.wait_time = intervalo_actual
	timer_cambio.start()

# =============================================================
# INTERACCIÓN DEL JUGADOR
# =============================================================

func _al_presionar_boton() -> void:
	if estado != Estado.JUGANDO:
		return
	estado = Estado.FEEDBACK
	timer_cambio.stop()
	boton_color.disabled = true

	if color_boton == color_objetivo:
		_aplicar_color_boton(Color(0.18, 0.82, 0.38))  # flash verde
		puntaje += PUNTOS_ACIERTO
		oportunidades_perdidas = 0
		intervalo_actual = maxf(INTERVALO_MIN, intervalo_actual - REDUCCION_INTERVALO)
		_actualizar_pool_colores()
		_elegir_nuevo_objetivo()
		_actualizar_ui()
		await get_tree().create_timer(DURACION_FEEDBACK).timeout
	else:
		_aplicar_color_boton(Color(1.0, 0.20, 0.20))   # flash rojo
		vidas -= 1
		_actualizar_ui()
		await get_tree().create_timer(DURACION_FEEDBACK).timeout
		if not is_inside_tree():
			return
		if vidas <= 0:
			_game_over()
			return

	if not is_inside_tree():
		return
	boton_color.disabled = false
	estado = Estado.JUGANDO
	_cambiar_color_boton_aleatorio()
	timer_cambio.wait_time = intervalo_actual
	timer_cambio.start()

# =============================================================
# PROGRESIÓN
# =============================================================

func _actualizar_pool_colores() -> void:
	if puntaje >= UMBRAL_NARANJA and "Naranja" not in pool_colores:
		pool_colores.append("Naranja")
	if puntaje >= UMBRAL_MORADO and "Morado" not in pool_colores:
		pool_colores.append("Morado")

func _game_over() -> void:
	estado = Estado.GAME_OVER
	timer_cambio.stop()
	boton_color.disabled = true
	if puntaje > puntaje_maximo:
		puntaje_maximo = puntaje
		_guardar_puntaje_maximo()
	label_puntaje_final.text = "Puntaje: %d" % puntaje
	label_maximo.text        = "Mejor: %d" % puntaje_maximo
	panel_game_over.visible  = true

# =============================================================
# UTILIDADES VISUALES
# =============================================================

func _aplicar_color_boton(color: Color) -> void:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color                   = color
	estilo.corner_radius_top_left     = 20
	estilo.corner_radius_top_right    = 20
	estilo.corner_radius_bottom_left  = 20
	estilo.corner_radius_bottom_right = 20
	boton_color.add_theme_stylebox_override("normal",   estilo)
	boton_color.add_theme_stylebox_override("hover",    estilo)
	boton_color.add_theme_stylebox_override("pressed",  estilo)
	boton_color.add_theme_stylebox_override("disabled", estilo)

func _actualizar_ui() -> void:
	label_puntaje.text = "Puntaje: %d" % puntaje
	var txt := ""
	for _i in range(vidas):
		txt += "♥ "
	for _i in range(VIDAS_INICIALES - vidas):
		txt += "♡ "
	label_vidas.text = txt.strip_edges()

# =============================================================
# PERSISTENCIA (high score)
# =============================================================

func _cargar_puntaje_maximo() -> void:
	var archivo := FileAccess.open(ARCHIVO_SAVE, FileAccess.READ)
	if archivo == null:
		return
	puntaje_maximo = archivo.get_32()
	archivo.close()

func _guardar_puntaje_maximo() -> void:
	var archivo := FileAccess.open(ARCHIVO_SAVE, FileAccess.WRITE)
	if archivo == null:
		return
	archivo.store_32(puntaje_maximo)
	archivo.close()

# =============================================================
# NAVEGACIÓN
# =============================================================

func _ir_al_menu() -> void:
	timer_cambio.stop()
	get_tree().change_scene_to_file("res://MainMenu.tscn")
