extends Control

# =============================================================
# CONSTANTES DE DIFICULTAD  (ajustar aquí para calibrar el juego)
# =============================================================
const TAMANO_GRILLA_INICIAL  := 3      # grilla inicial NxN
const TAMANO_GRILLA_MAX      := 6      # grilla máxima
const CELDAS_LIT_INICIALES   := 2      # celdas iluminadas en nivel 1
const NIVELES_POR_CELDA_EXTRA := 2     # cada N niveles sube 1 celda iluminada
const NIVELES_POR_GRILLA     := 5      # cada N niveles crece la grilla
const TIEMPO_ILUMINAR_BASE   := 2.5    # segundos visibles en nivel 1
const TIEMPO_ILUMINAR_MIN    := 0.6    # mínimo de tiempo visible
const REDUCCION_TIEMPO       := 0.05   # reducción por nivel
const PUNTOS_POR_ACIERTO     := 10     # puntos al acertar una celda
const TAMANO_CELDA           := 90.0   # píxeles por celda (cuadrado)
const SEP_GRILLA             := 8      # separación entre celdas

# =============================================================
# MÁQUINA DE ESTADOS
# =============================================================
enum Estado { MOSTRANDO, JUGANDO, GAME_OVER }

var estado: Estado = Estado.MOSTRANDO
var nivel:  int    = 1
var puntaje: int   = 0

# Índices de las celdas que el jugador debe recordar
var celdas_objetivo:  Array = []
# Índices que el jugador ya acertó en la ronda actual
var celdas_acertadas: Array = []

# Instancias de todos los Tiles de la grilla actual
var tiles: Array = []

var tile_escena := preload("res://mosaico_memoria/Tile.tscn")

# =============================================================
# REFERENCIAS A NODOS
# =============================================================
@onready var label_nivel:         Label         = $MainVBox/InfoBar/LabelNivel
@onready var label_puntaje:       Label         = $MainVBox/InfoBar/LabelPuntaje
@onready var label_mensaje:       Label         = $MainVBox/LabelMensaje
@onready var grilla:              GridContainer = $MainVBox/GrillaCenter/Grilla
@onready var timer_iluminar:      Timer         = $TimerIluminar
@onready var timer_mensaje:       Timer         = $TimerMensaje
@onready var panel_game_over:     Panel         = $GameOverPanel
@onready var label_puntaje_final: Label         = $GameOverPanel/VBoxCenter/LabelPuntajeFinal
@onready var boton_reintentar:    Button        = $GameOverPanel/VBoxCenter/BotonReintentar
@onready var boton_menu:          Button        = $GameOverPanel/VBoxCenter/BotonMenu

func _ready() -> void:
	boton_reintentar.pressed.connect(_reiniciar_juego)
	boton_menu.pressed.connect(_ir_al_menu)
	timer_iluminar.timeout.connect(_apagar_grilla)
	timer_mensaje.timeout.connect(_iniciar_ronda)
	_reiniciar_juego()

# =============================================================
# FLUJO PRINCIPAL
# =============================================================

# Reinicia todo desde el nivel 1
func _reiniciar_juego() -> void:
	nivel   = 1
	puntaje = 0
	panel_game_over.visible = false
	_preparar_ronda()

# Construye la grilla del nivel actual y muestra "¡Memoriza!"
func _preparar_ronda() -> void:
	estado = Estado.MOSTRANDO
	celdas_objetivo.clear()
	celdas_acertadas.clear()
	_actualizar_ui()
	_construir_grilla()
	label_mensaje.text = "¡Memoriza!"
	# Breve pausa antes de iluminar las celdas
	timer_mensaje.wait_time = 0.9
	timer_mensaje.start()

# Elige las celdas objetivo e inicia el timer de iluminación
func _iniciar_ronda() -> void:
	_elegir_celdas_objetivo()
	_iluminar_celdas()
	var tiempo: float = maxf(
		TIEMPO_ILUMINAR_MIN,
		TIEMPO_ILUMINAR_BASE - (nivel - 1) * REDUCCION_TIEMPO
	)
	timer_iluminar.wait_time = tiempo
	timer_iluminar.start()

# Selecciona aleatoriamente los índices de las celdas a iluminar
func _elegir_celdas_objetivo() -> void:
	var total: int = _tamano_grilla_actual() * _tamano_grilla_actual()
	var cantidad: int = CELDAS_LIT_INICIALES + (nivel - 1) / NIVELES_POR_CELDA_EXTRA
	cantidad = mini(cantidad, total - 1)
	# Mezclar todos los índices y tomar los primeros N
	var indices: Array = range(total)
	indices.shuffle()
	celdas_objetivo = indices.slice(0, cantidad)

# Pone los tiles objetivo en estado iluminado
func _iluminar_celdas() -> void:
	for idx in celdas_objetivo:
		tiles[idx].set_estado_iluminado()

# Se llama cuando el timer vence: apaga la grilla y habilita al jugador
func _apagar_grilla() -> void:
	for tile in tiles:
		tile.set_estado_normal()
	estado = Estado.JUGANDO
	label_mensaje.text = "¡Ahora toca!"
	_set_tiles_habilitados(true)

# =============================================================
# INTERACCIÓN DEL JUGADOR
# =============================================================

# Callback conectado a la señal tile_pressed de cada Tile
func _al_presionar_tile(index: int) -> void:
	if estado != Estado.JUGANDO:
		return
	if index in celdas_objetivo:
		_registrar_acierto(index)
	else:
		_registrar_error(index)

func _registrar_acierto(index: int) -> void:
	tiles[index].set_estado_correcto()
	tiles[index].disabled = true
	celdas_acertadas.append(index)
	puntaje += PUNTOS_POR_ACIERTO
	_actualizar_ui()
	# ¿Completó todas las celdas de la ronda?
	if celdas_acertadas.size() == celdas_objetivo.size():
		_nivel_completado()

func _registrar_error(index: int) -> void:
	_set_tiles_habilitados(false)
	tiles[index].set_estado_incorrecto()
	# Revelar las celdas que faltaban
	for idx in celdas_objetivo:
		if idx not in celdas_acertadas:
			tiles[idx].set_estado_iluminado()
	# Pequeña pausa antes de mostrar game over
	await get_tree().create_timer(1.3).timeout
	_game_over()

# =============================================================
# PROGRESIÓN DE NIVEL
# =============================================================

func _nivel_completado() -> void:
	_set_tiles_habilitados(false)
	label_mensaje.text = "¡Nivel superado!"
	nivel += 1
	await get_tree().create_timer(1.1).timeout
	_preparar_ronda()

func _game_over() -> void:
	estado = Estado.GAME_OVER
	label_puntaje_final.text = "Puntaje final: %d" % puntaje
	panel_game_over.visible = true

# =============================================================
# CONSTRUCCIÓN DE LA GRILLA
# =============================================================

# Calcula el tamaño NxN de la grilla para el nivel actual
func _tamano_grilla_actual() -> int:
	var t: int = TAMANO_GRILLA_INICIAL + (nivel - 1) / NIVELES_POR_GRILLA
	return mini(t, TAMANO_GRILLA_MAX)

# Destruye los tiles anteriores y genera una nueva grilla NxN
func _construir_grilla() -> void:
	for tile in tiles:
		tile.queue_free()
	tiles.clear()
	var n: int = _tamano_grilla_actual()
	grilla.columns = n
	grilla.add_theme_constant_override("h_separation", SEP_GRILLA)
	grilla.add_theme_constant_override("v_separation", SEP_GRILLA)
	for i in range(n * n):
		var tile = tile_escena.instantiate()
		tile.index = i
		tile.custom_minimum_size = Vector2(TAMANO_CELDA, TAMANO_CELDA)
		tile.tile_pressed.connect(_al_presionar_tile)
		grilla.add_child(tile)
		tiles.append(tile)
	_set_tiles_habilitados(false)

# Habilita o deshabilita la interacción en todos los tiles
func _set_tiles_habilitados(activo: bool) -> void:
	for tile in tiles:
		tile.disabled = not activo

# =============================================================
# UI
# =============================================================

func _actualizar_ui() -> void:
	label_nivel.text   = "Nivel: %d" % nivel
	label_puntaje.text = "Puntaje: %d" % puntaje

# =============================================================
# NAVEGACIÓN
# =============================================================

func _ir_al_menu() -> void:
	get_tree().change_scene_to_file("res://MainMenu.tscn")
