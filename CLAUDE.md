# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Proyecto

Godot 4.7 — GDScript — renderer GL Compatibility — ventana 1280×720.
El proyecto se llama **"Mis Juegos"**: una colección de minijuegos con pantalla de inicio común.

## Cómo ejecutar

Abrir el proyecto en Godot Editor:
```
godot --path "D:\MisJuegos\juegos\nuevo-proyecto-de-juego" -e
```

Correr el juego desde línea de comandos (sin editor):
```
godot --path "D:\MisJuegos\juegos\nuevo-proyecto-de-juego"
```

No hay tests automatizados ni linter externo; la validación de GDScript ocurre dentro del editor Godot.

## Arquitectura general

```
MainMenu.tscn / MainMenu.gd              ← Escena raíz (config/run/main_scene)
    └─ navega a cada juego con change_scene_to_file()

mosaico_memoria/
    Main.tscn / Main.gd                  ← Juego 1: Mosaico de Memoria
    Tile.tscn / Tile.gd                  ← Componente reutilizable: celda de grilla

tablas_rapidas/
    TablasRapidas.tscn / TablasRapidas.gd ← Juego 2: Tablas Rápidas
```

### Flujo de escenas

`MainMenu` es la escena de entrada. Cada botón llama `get_tree().change_scene_to_file("res://juego_X/...")`. Cada juego tiene su propio botón "Menú Principal" que regresa con el mismo método. Para agregar un juego nuevo: crear su carpeta, añadir un botón en `MainMenu.tscn` y conectarlo en `MainMenu.gd`.

---

## Juego 1 — Mosaico de Memoria (`mosaico_memoria/`)

### Máquina de estados (`Main.gd`)

`enum Estado { MOSTRANDO, JUGANDO, GAME_OVER }`

1. **MOSTRANDO** — grilla deshabilitada; `TimerMensaje` dispara `_iniciar_ronda()` que ilumina celdas; `TimerIluminar` llama `_apagar_grilla()`.
2. **JUGANDO** — grilla habilitada; acierto → `set_estado_correcto()` + puntos; error → revela faltantes + espera 1.3 s + GAME_OVER.
3. **GAME_OVER** — panel superpuesto visible con Reintentar / Menú.

### Tile.gd — componente de celda

Extiende `Button`. Crea un único `StyleBoxFlat` compartido entre todos los estados del botón y lo muta para cambiar color sin crear recursos extra. API pública: `set_estado_normal()`, `set_estado_iluminado()`, `set_estado_correcto()`, `set_estado_incorrecto()`. Emite `tile_pressed(index: int)`.

### Generación dinámica de la grilla

`_construir_grilla()` hace `queue_free()` de los tiles anteriores, recalcula `n = _tamano_grilla_actual()`, configura `GridContainer.columns = n` e instancia `n*n` copias de `Tile.tscn` conectando `tile_pressed` antes de añadirlas al árbol.

### Constantes de dificultad (`mosaico_memoria/Main.gd`)

| Constante | Efecto |
|---|---|
| `TAMANO_GRILLA_INICIAL` / `TAMANO_GRILLA_MAX` | rango de grillas NxN |
| `CELDAS_LIT_INICIALES` | celdas iluminadas en nivel 1 |
| `NIVELES_POR_CELDA_EXTRA` | cada N niveles sube 1 celda |
| `NIVELES_POR_GRILLA` | cada N niveles crece la grilla |
| `TIEMPO_ILUMINAR_BASE` / `TIEMPO_ILUMINAR_MIN` / `REDUCCION_TIEMPO` | curva de tiempo visible |
| `TAMANO_CELDA` / `SEP_GRILLA` | aspecto visual de la grilla |

---

## Juego 2 — Tablas Rápidas (`tablas_rapidas/`)

### Mecánica

Muestra una multiplicación grande (`A × B = ?`) con 4 botones de respuesta en grilla 2×2. Una opción es correcta; las otras tres son trampas generadas en `generar_opciones_respuesta()` basadas en errores típicos de cálculo (±una fila, ±una columna, confundir factor con el adyacente). El jugador tiene 3 vidas; un error resta una vida y penaliza el puntaje.

### Máquina de estados (`TablasRapidas.gd`)

`enum Estado { ESPERANDO, FEEDBACK, GAME_OVER }`

- **ESPERANDO** — botones habilitados, aguarda click del jugador.
- **FEEDBACK** — botones deshabilitados; correcto → verde, incorrecto → rojo + revela correcta en verde; espera `PAUSA_FEEDBACK` segundos y pasa a la siguiente pregunta (o GAME_OVER si vidas = 0).
- **GAME_OVER** — panel superpuesto con puntaje final.

### Generación de opciones

`generar_opciones_respuesta(correcto, fa, fb)` arma candidatos trampa: `correcto ± fa`, `correcto ± fb`, `(fa±1)*fb`, `fa*(fb+1)`, etc. Los mezcla, filtra negativos y duplicados, y rellena con offsets aleatorios si faltan. Devuelve un Array de 4 elementos mezclado.

### Gotcha de tipos en GDScript

Al indexar un `Array` sin tipo genérico, el resultado es `Variant`. Usar `:=` en ese contexto genera el error *"Cannot infer the type"*. Solución: declarar el tipo explícitamente (`var rango: Array = RANGOS_POR_NIVEL[idx]`). Aplica a cualquier Array de Arrays en este proyecto.

### Constantes de dificultad (`tablas_rapidas/TablasRapidas.gd`)

| Constante | Efecto |
|---|---|
| `VIDAS_INICIALES` | vidas al comenzar |
| `ACIERTOS_POR_NIVEL` | respuestas correctas para subir de nivel |
| `PUNTOS_ACIERTO` / `PENALIZACION_ERROR` | economía de puntos |
| `PAUSA_FEEDBACK` | segundos de feedback visual entre preguntas |
| `RANGOS_POR_NIVEL` | array de `[min_A, max_A, min_B, max_B]` por nivel |

---

## Convenciones del proyecto

- Código y comentarios en **español**.
- Nombres de nodos en `PascalCase`, variables/funciones en `snake_case`.
- Estilos visuales (colores, radios de esquina) definidos en GDScript con `StyleBoxFlat`, no en recursos `.tres` externos.
- Para conectar señales con índice, usar `.bind()` en lugar de lambdas con captura de variable de bucle: `boton.pressed.connect(funcion.bind(i))`.
