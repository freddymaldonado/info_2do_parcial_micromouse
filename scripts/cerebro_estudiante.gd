class_name CerebroEstudiante
extends RefCounted

# mi cerebro para el raton (M1, M2, M3)
# game.gd me llama paso(raton) cada tick y yo hago una sola cosa: girar o avanzar
# solo puedo sensar las paredes de mi celda y moverme, nada de mirar el lab real.
#
# la idea es la del micromouse de verdad:
#   explorando -> voy armando mi mapa con lo que senso y uso flood fill
#     (distancia de cada celda a la meta) para ir siempre a la vecina mas cerca
#   volviendo -> cuando toco la meta vuelvo al inicio con otro flood fill
#   speed run -> ya con el mapa armado saco la mejor ruta y la corro sin sensar

# esto si me lo dan de antemano (el tamaño, las metas y el inicio). las paredes no
var ancho: int = 0
var alto: int = 0
var metas: Array[Vector2i] = []
var inicio: Vector2i = Vector2i.ZERO

# el mapa que voy descubriendo solo con lo que senso (lo dibuja la vista M2)
var mapa: Laberinto = null
# celdas por donde ya pase
var visitadas: Dictionary = {}
# en que fase estoy (lo muestra el hud)
var fase: String = "EXPLORANDO"

# guardo las dos rutas para dibujarlas encimadas (M3)
var ruta_exploracion: Array[Vector2i] = []
var ruta_speed: Array[Vector2i] = []

# para comparar pasos de exploracion vs speed run
var pasos_exploracion: int = 0
var pasos_speed: int = 0

# cositas internas del speed run
var _base_pasos_speed: int = 0
var _indice_speed: int = 0


func preparar(ancho_: int, alto_: int, metas_: Array[Vector2i],
		inicio_: Vector2i = Vector2i.ZERO) -> void:
	ancho = ancho_
	alto = alto_
	metas = metas_
	inicio = inicio_
	# mi mapa arranca vacio (solo el borde) y lo voy llenando al sensar
	mapa = Laberinto.vacio(ancho, alto)
	# le paso inicio y metas asi la vista los pinta
	mapa.inicio = inicio
	mapa.metas = metas
	visitadas = {}
	visitadas[inicio] = 1
	fase = "EXPLORANDO"
	ruta_exploracion = []
	ruta_exploracion.append(inicio)
	ruta_speed = []
	pasos_exploracion = 0
	pasos_speed = 0
	_indice_speed = 0


func paso(raton: Raton) -> void:
	match fase:
		"EXPLORANDO":
			_paso_explorar(raton)
		"VOLVIENDO":
			_paso_volver(raton)
		"SPEED RUN":
			_paso_speed(raton)
		_:
			pass


# M1: exploracion con flood fill
func _paso_explorar(raton: Raton) -> void:
	_anotar_paredes(raton)
	# voy guardando por donde paso para despues dibujar la ruta
	if ruta_exploracion.is_empty() or ruta_exploracion[-1] != raton.celda:
		ruta_exploracion.append(raton.celda)
	if raton.celda in metas:
		# llegue a la meta, anoto los pasos y me devuelvo al inicio
		pasos_exploracion = raton.pasos
		fase = "VOLVIENDO"
		return
	var distancias = _flood_fill(metas, false)
	var dir = _mejor_vecina(raton.celda, distancias)
	if dir == -1:
		fase = "FIN"
		return
	_mover_hacia(raton, dir)


func _paso_volver(raton: Raton) -> void:
	_anotar_paredes(raton)
	if raton.celda == inicio:
		_calcular_ruta_speed()
		_base_pasos_speed = raton.pasos
		_indice_speed = 0
		fase = "SPEED RUN"
		return
	var distancias = _flood_fill([inicio], false)
	var dir = _mejor_vecina(raton.celda, distancias)
	if dir == -1:
		_calcular_ruta_speed()
		_base_pasos_speed = raton.pasos
		_indice_speed = 0
		fase = "SPEED RUN"
		return
	_mover_hacia(raton, dir)


# M3: speed run usando el mapa que ya descubri
func _paso_speed(raton: Raton) -> void:
	if ruta_speed.size() < 2 or _indice_speed >= ruta_speed.size() - 1:
		pasos_speed = raton.pasos - _base_pasos_speed
		fase = "FIN"
		return
	var siguiente = ruta_speed[_indice_speed + 1]
	var dir = _direccion_hacia(raton.celda, siguiente)
	if dir == -1:
		pasos_speed = raton.pasos - _base_pasos_speed
		fase = "FIN"
		return
	if dir == raton.rumbo:
		if raton.avanzar():
			_indice_speed += 1
		else:
			pasos_speed = raton.pasos - _base_pasos_speed
			fase = "FIN"
	else:
		_girar_hacia(raton, dir)


func _calcular_ruta_speed() -> void:
	# flood fill pero solo por celdas que ya conozco, asi la ruta es segura
	var distancias = _flood_fill(metas, true)
	# uso clear()+append y no = [] para no perder la referencia que tiene la vista
	ruta_speed.clear()
	ruta_speed.append(inicio)
	var actual = inicio
	var limite = ancho * alto
	while not (actual in metas) and limite > 0:
		var dir = _mejor_vecina(actual, distancias)
		if dir == -1:
			break
		actual = actual + Laberinto.DELTAS[dir]
		ruta_speed.append(actual)
		limite -= 1


# senso las paredes de donde estoy y las anoto en mi mapa
func _anotar_paredes(raton: Raton) -> void:
	var c = raton.celda
	var r = raton.rumbo
	if raton.pared_frente():
		mapa.poner_pared(c, r)
	if raton.pared_derecha():
		mapa.poner_pared(c, (r + 1) % 4)
	if raton.pared_izquierda():
		mapa.poner_pared(c, (r + 3) % 4)
	# cuento cuantas veces piso cada celda, eso lo usa el heat map del bonus
	visitadas[c] = int(visitadas.get(c, 0)) + 1


# flood fill: saca la distancia de cada celda a los objetivos sobre mi mapa
# si solo_conocidas es true ignoro las celdas que todavia no visite (speed run)
func _flood_fill(objetivos, solo_conocidas: bool) -> Array:
	var dist = []
	for f in alto:
		var fila = []
		fila.resize(ancho)
		fila.fill(-1)
		dist.append(fila)
	var cola = []
	for o in objetivos:
		dist[o.y][o.x] = 0
		cola.append(o)
	var i = 0
	while i < cola.size():
		var c = cola[i]
		i += 1
		var d = dist[c.y][c.x]
		for dir in 4:
			if mapa.tiene_pared(c, dir):
				continue
			var v = c + Laberinto.DELTAS[dir]
			if not mapa.en_rango(v):
				continue
			if solo_conocidas and not visitadas.has(v):
				continue
			if dist[v.y][v.x] == -1:
				dist[v.y][v.x] = d + 1
				cola.append(v)
	return dist


# me dice hacia que lado esta la vecina con menor distancia (o -1 si no hay)
func _mejor_vecina(desde: Vector2i, dist: Array) -> int:
	var mejor_dir = -1
	var mejor_dist = 1 << 30
	for dir in 4:
		if mapa.tiene_pared(desde, dir):
			continue
		var v = desde + Laberinto.DELTAS[dir]
		if not mapa.en_rango(v):
			continue
		var d = dist[v.y][v.x]
		if d == -1:
			continue
		if d < mejor_dist:
			mejor_dist = d
			mejor_dir = dir
	return mejor_dir


# una sola accion por tick: si ya miro hacia dir avanzo, si no giro
func _mover_hacia(raton: Raton, dir: int) -> void:
	if dir == raton.rumbo:
		raton.avanzar()
	else:
		_girar_hacia(raton, dir)


func _girar_hacia(raton: Raton, dir: int) -> void:
	var diff = (dir - raton.rumbo + 4) % 4
	if diff == 1:
		raton.girar_derecha()
	else:
		raton.girar_izquierda()


# que rumbo (N/E/S/O) tengo que tener para pasar de una celda a la de al lado
func _direccion_hacia(desde: Vector2i, hasta: Vector2i) -> int:
	var delta = hasta - desde
	for dir in 4:
		if Laberinto.DELTAS[dir] == delta:
			return dir
	return -1
