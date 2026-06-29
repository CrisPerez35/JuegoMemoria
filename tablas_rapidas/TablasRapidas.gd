extends Control

# =============================================================
# CONSTANTES DE DIFICULTAD (ajustar aquí para calibrar el juego)
# =============================================================
const VIDAS_INICIALES    := 3     # vidas al comenzar la partida
const ACIERTOS_POR_NIVEL := 5     # respuestas correctas para subir de nivel
const PUNTOS_ACIERTO     := 10    # puntos por respuesta correcta
const PENALIZACION_ERROR := 5     # puntos que se restan al equivocarse
const PAUSA_FEEDBACK     := 0.65  # segundos de feedback visual antes de la siguiente pregunta

# Rangos de factores por nivel: [min_A, max_A, min_B, max_B]
# El último elemento se reutiliza para todos los niveles superiores al array
const RANGOS_POR_NIVEL := [
	[1,  9,  1,  9],    # Nivel 1: un dígito × un dígito       (ej. 7×6)
	[1,  9,  10, 20],   # Nivel 2: un dígito × dos dígitos      (ej. 8×14)
	[10, 30, 10, 30],   # Nivel 3: dos dígitos × dos dígitos    (ej. 12×23)
	[10, 50, 10, 50],   # Nivel 4: dos dígitos hasta 50         (ej. 34×47)
	[10, 99, 10, 99],   # Nivel 5+: dos dígitos completos       (ej. 76×83)
]

# =============================================================
# MÁQUINA DE ESTADOS
# =============================================================
enum Estado { ESPERANDO, FEEDBACK, GAME_OVER }

var estado: Estado = Estado.ESPERANDO
var nivel:          int = 1
var puntaje:        int = 0
var vidas:          int = VIDAS_INICIALES
var aciertos_nivel: int = 0   # aciertos acumulados en el nivel actual

# Datos de la pregunta activa
var factor_a:           int = 0
var factor_b:           int = 0
var resultado_correcto: int = 0
var indice_correcto:    int = 0   # índice (0-3) del botón con la respuesta correcta

# Los cuatro botones de respuesta
var botones: Array = []

# =============================================================
# REFERENCIAS A NODOS
# =============================================================
@onready var label_nivel:         Label = $MainVBox/InfoBar/LabelNivel
@onready var label_vidas:         Label = $MainVBox/InfoBar/LabelVidas
@onready var label_puntaje:       Label = $MainVBox/InfoBar/LabelPuntaje
@onready var label_multi:         Label = $MainVBox/CenterMulti/LabelMultiplicacion
@onready var panel_game_over:     Panel = $GameOverPanel
@onready var label_puntaje_final: Label = $GameOverPanel/VBoxCenter/LabelPuntajeFinal
@onready var boton_reintentar:    Button = $GameOverPanel/VBoxCenter/BotonReintentar
@onready var boton_menu:          Button = $GameOverPanel/VBoxCenter/BotonMenu

func _ready() -> void:
	botones = [
		$MainVBox/CenterGrid/GridRespuestas/Btn0,
		$MainVBox/CenterGrid/GridRespuestas/Btn1,
		$MainVBox/CenterGrid/GridRespuestas/Btn2,
		$MainVBox/CenterGrid/GridRespuestas/Btn3,
	]
	# Conectar cada botón pasando su índice mediante bind()
	for i in range(botones.size()):
		botones[i].pressed.connect(_al_presionar_respuesta.bind(i))
	boton_reintentar.pressed.connect(reiniciar_juego)
	boton_menu.pressed.connect(_ir_al_menu)
	reiniciar_juego()

# =============================================================
# FLUJO PRINCIPAL
# =============================================================

# Reinicia la partida desde cero
func reiniciar_juego() -> void:
	nivel          = 1
	puntaje        = 0
	vidas          = VIDAS_INICIALES
	aciertos_nivel = 0
	panel_game_over.visible = false
	_nueva_pregunta()

# Prepara y muestra una nueva multiplicación
func _nueva_pregunta() -> void:
	estado = Estado.ESPERANDO
	_resetear_colores_botones()
	_set_botones_habilitados(true)
	var factores      := generar_multiplicacion(nivel)
	factor_a           = factores[0]
	factor_b           = factores[1]
	resultado_correcto = factor_a * factor_b
	label_multi.text   = "%d  ×  %d  = ?" % [factor_a, factor_b]
	var opciones := generar_opciones_respuesta(resultado_correcto, factor_a, factor_b)
	indice_correcto = opciones.find(resultado_correcto)
	for i in range(botones.size()):
		botones[i].text = str(opciones[i])
	_actualizar_ui()

# =============================================================
# GENERACIÓN DE PREGUNTA Y OPCIONES
# =============================================================

# Devuelve [factor_a, factor_b] con rangos según el nivel actual
func generar_multiplicacion(nv: int) -> Array:
	var idx   := mini(nv - 1, RANGOS_POR_NIVEL.size() - 1)
	var rango: Array = RANGOS_POR_NIVEL[idx]
	var a     := randi_range(rango[0], rango[1])
	var b     := randi_range(rango[2], rango[3])
	return [a, b]

# Genera 4 opciones: la correcta más 3 trampas cercanas al resultado real
func generar_opciones_respuesta(correcto: int, fa: int, fb: int) -> Array:
	var opciones: Array = [correcto]
	# Candidatos basados en errores típicos de multiplicación (no valores absurdos)
	var candidatos: Array = [
		correcto + fa,          # sumar una fila de más
		correcto - fa,          # restar una fila
		correcto + fb,          # sumar una columna de más
		correcto - fb,          # restar una columna
		correcto + fa + fb,     # error doble de conteo
		(fa + 1) * fb,          # confundir factor A con el siguiente
		fa * (fb + 1),          # confundir factor B con el siguiente
		(fa - 1) * fb,          # confundir factor A con el anterior
	]
	candidatos.shuffle()
	for c in candidatos:
		if c > 0 and c != correcto and c not in opciones:
			opciones.append(c)
			if opciones.size() == 4:
				break
	# Relleno de seguridad si los candidatos anteriores no alcanzaron
	var margen := maxi(3, correcto / 8)
	while opciones.size() < 4:
		var offset    := randi_range(1, margen)
		var signo     := 1 if randf() > 0.5 else -1
		var candidato := correcto + signo * offset
		if candidato > 0 and candidato not in opciones:
			opciones.append(candidato)
	opciones.shuffle()
	return opciones

# =============================================================
# INTERACCIÓN DEL JUGADOR
# =============================================================

# Callback conectado a cada botón de respuesta
func _al_presionar_respuesta(indice: int) -> void:
	if estado != Estado.ESPERANDO:
		return
	estado = Estado.FEEDBACK
	_set_botones_habilitados(false)
	verificar_respuesta(indice == indice_correcto, indice)

# Aplica feedback visual y actualiza puntaje/vidas según la respuesta
func verificar_respuesta(es_correcta: bool, indice_elegido: int) -> void:
	if es_correcta:
		_pintar_boton(indice_correcto, Color(0.18, 0.82, 0.38))   # verde
		puntaje        += PUNTOS_ACIERTO
		aciertos_nivel += 1
		avanzar_nivel()
	else:
		_pintar_boton(indice_elegido,  Color(1.00, 0.22, 0.22))   # rojo
		_pintar_boton(indice_correcto, Color(0.18, 0.82, 0.38))   # revela la correcta
		puntaje = maxi(0, puntaje - PENALIZACION_ERROR)
		vidas  -= 1
	_actualizar_ui()
	# Esperar el feedback antes de continuar
	if vidas <= 0:
		await get_tree().create_timer(PAUSA_FEEDBACK).timeout
		_game_over()
	else:
		await get_tree().create_timer(PAUSA_FEEDBACK).timeout
		_nueva_pregunta()

# Sube de nivel si el jugador alcanzó el umbral de aciertos
func avanzar_nivel() -> void:
	if aciertos_nivel >= ACIERTOS_POR_NIVEL:
		nivel         += 1
		aciertos_nivel = 0

func _game_over() -> void:
	estado = Estado.GAME_OVER
	label_puntaje_final.text = "Puntaje final: %d" % puntaje
	panel_game_over.visible  = true

# =============================================================
# UTILIDADES DE UI
# =============================================================

func _actualizar_ui() -> void:
	label_nivel.text   = "Nivel: %d" % nivel
	label_puntaje.text = "Puntaje: %d" % puntaje
	# Corazones llenos para vidas restantes, vacíos para las perdidas
	var txt := ""
	for _i in range(vidas):
		txt += "♥ "
	for _i in range(VIDAS_INICIALES - vidas):
		txt += "♡ "
	label_vidas.text = txt.strip_edges()

# Aplica un color de fondo sólido a un botón específico
func _pintar_boton(indice: int, color: Color) -> void:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color                   = color
	estilo.corner_radius_top_left     = 10
	estilo.corner_radius_top_right    = 10
	estilo.corner_radius_bottom_left  = 10
	estilo.corner_radius_bottom_right = 10
	botones[indice].add_theme_stylebox_override("normal",   estilo)
	botones[indice].add_theme_stylebox_override("disabled", estilo)

# Elimina los overrides de color para volver al estilo por defecto del tema
func _resetear_colores_botones() -> void:
	for btn in botones:
		btn.remove_theme_stylebox_override("normal")
		btn.remove_theme_stylebox_override("disabled")

func _set_botones_habilitados(activo: bool) -> void:
	for btn in botones:
		btn.disabled = not activo

func _ir_al_menu() -> void:
	get_tree().change_scene_to_file("res://MainMenu.tscn")
