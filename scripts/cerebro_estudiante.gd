class_name CerebroEstudiante
extends RefCounted

# === TU CEREBRO (M1, M2, M3) ===
#
# Contrato: game.gd llama paso(raton) en cada tick y tu cerebro ejecuta UNA
# acción (girar_izquierda / girar_derecha / avanzar). Solo puedes usar la API
# pública del ratón — sensar paredes de la celda actual y moverte. Nada de
# leer el laberinto real.
#
# Para activarlo: en el Inspector de la escena game.tscn, marca la casilla
# "Usar Cerebro Estudiante" del nodo raíz (o cambia el valor por defecto en
# game.gd).
#
# Plan sugerido (es el algoritmo clásico de la competencia micromouse):
#
#   FASE 1 — EXPLORAR (M1):
#     - Mantén tu propio mapa: un Laberinto.vacio(ancho, alto) donde anotas
#       (con poner_pared) cada pared que sensas, y un diccionario de celdas
#       visitadas. El ratón conoce su celda y rumbo (raton.celda, raton.rumbo).
#     - Flood-fill: calcula la distancia de CADA celda a la meta inundando
#       desde la meta sobre tu mapa (las celdas no exploradas se asumen sin
#       paredes — por eso se vuelve a calcular cada vez que descubres una).
#     - Muévete siempre hacia la celda vecina accesible con menor distancia.
#     - Cuando llegues a la meta, puedes seguir explorando o volver al inicio.
#
#   FASE 2 — SPEED RUN (M3):
#     - De vuelta en el inicio, calcula la mejor ruta sobre el mapa que
#       DESCUBRISTE (otro flood-fill, esta vez solo por celdas conocidas) y
#       ejecútala sin sensar. Compárala en pantalla con la ruta de exploración.
#
#   El mapa que mantienes aquí es exactamente lo que la vista "mapa del ratón"
#   (M2) debe dibujar: expón tu Laberinto descubierto y tus visitadas para que
#   game.gd se los pase a la vista derecha.

# TODO (PARCIAL · M1): declara aquí tu estado: el mapa descubierto
# (Laberinto.vacio), las celdas visitadas, las distancias del flood-fill y la
# fase actual (EXPLORANDO / VOLVIENDO / SPEED_RUN).

# TODO (PARCIAL · M1): necesitarás saber dónde están la meta y el inicio. El
# tamaño del laberinto, las metas y la celda de inicio son datos "del
# concurso" (se conocen de antemano): game.gd te los entrega en preparar().
# Las PAREDES no.
var ancho: int = 0
var alto: int = 0
var metas: Array[Vector2i] = []
var inicio: Vector2i = Vector2i.ZERO


func preparar(ancho_: int, alto_: int, metas_: Array[Vector2i],
		inicio_: Vector2i = Vector2i.ZERO) -> void:
	ancho = ancho_
	alto = alto_
	metas = metas_
	inicio = inicio_
	# TODO (PARCIAL · M1): inicializa tu mapa descubierto y tu estado aquí.


func paso(raton: Raton) -> void:
	# TODO (PARCIAL · M1): 1) sensa y anota las paredes de la celda actual en
	# tu mapa; 2) recalcula el flood-fill; 3) ejecuta UNA acción hacia la
	# vecina con menor distancia.
	# Mientras no implementes nada, el ratón se queda quieto.
	pass


# TODO (PARCIAL · M1): funciones sugeridas.
# func _anotar_paredes(raton: Raton) -> void:
# func _flood_fill(hasta: Array[Vector2i], solo_conocidas: bool) -> Array:
# func _mejor_vecina(desde: Vector2i, distancias: Array) -> int:  # rumbo

# TODO (PARCIAL · M3): cuando termines de explorar y estés en el inicio,
# calcula la ruta del speed run y guárdala para que game.gd la dibuje.
# func ruta_speed_run() -> Array[Vector2i]:
