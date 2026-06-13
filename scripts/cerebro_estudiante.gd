class_name CerebroEstudiante
extends RefCounted

# === TU CEREBRO (M1, M2, M3) ===
#
# Contrato: game.gd llama paso(raton) en cada tick y este cerebro ejecuta UNA
# acción (girar_izquierda / girar_derecha / avanzar). Solo usamos la API
# pública del ratón — sensar las paredes de la celda actual y movernos. Nunca
# leemos el laberinto real: todo lo que sabemos sale del sensado.
#
# Algoritmo (el clásico de la competencia micromouse):
#   FASE EXPLORANDO (M1): mantenemos nuestro propio mapa, anotamos las paredes
#     que sensamos y usamos flood-fill (distancia de cada celda a la meta) para
#     avanzar siempre hacia la vecina con menor distancia.
#   FASE VOLVIENDO: al llegar a la meta volvemos al inicio (otro flood-fill).
#   FASE SPEED RUN (M3): desde el inicio calculamos la mejor ruta sobre el mapa
#     que descubrimos (solo celdas conocidas) y la ejecutamos sin sensar.

# Datos del concurso que se conocen de antemano (NO las paredes).
var ancho: int = 0
var alto: int = 0
var metas: Array[Vector2i] = []
var inicio: Vector2i = Vector2i.ZERO

# Mapa que el ratón construye solo con lo que sensa (lo dibuja la vista M2).
var mapa: Laberinto = null
# Celdas por las que ya pasó el ratón.
var visitadas: Dictionary = {}
# Fase actual; el HUD la muestra (B3).
var fase: String = "EXPLORANDO"

# Rutas para dibujarlas superpuestas (M3).
var ruta_exploracion: Array[Vector2i] = []
var ruta_speed: Array[Vector2i] = []

# Comparación de pasos exploración vs speed run (M3).
var pasos_exploracion: int = 0
var pasos_speed: int = 0

# Internos del speed run.
var _base_pasos_speed: int = 0
var _indice_speed: int = 0


func preparar(ancho_: int, alto_: int, metas_: Array[Vector2i],
		inicio_: Vector2i = Vector2i.ZERO) -> void:
	ancho = ancho_
	alto = alto_
	metas = metas_
	inicio = inicio_
	# Mapa descubierto: empieza vacío (solo el borde) y se llena al sensar.
	mapa = Laberinto.vacio(ancho, alto)
	# El inicio y las metas son datos del concurso, así la vista los muestra.
	mapa.inicio = inicio
	mapa.metas = metas
	visitadas = {}
	visitadas[inicio] = true
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


# --- M1: exploración con flood-fill ---

func _paso_explorar(raton: Raton) -> void:
	_anotar_paredes(raton)
	# Guardamos la ruta de exploración (solo la ida) para dibujarla.
	if ruta_exploracion.is_empty() or ruta_exploracion[-1] != raton.celda:
		ruta_exploracion.append(raton.celda)
	if raton.celda in metas:
		# Primera llegada a la meta: anotamos los pasos y volvemos al inicio.
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


# --- M3: speed run sobre el mapa descubierto ---

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
	# Flood-fill solo por celdas conocidas (visitadas): la mejor ruta segura.
	var distancias = _flood_fill(metas, true)
	# Usamos clear()+append para no romper la referencia que comparte la vista.
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


# --- helpers ---

# Sensa las paredes de la celda actual y las anota en nuestro mapa.
func _anotar_paredes(raton: Raton) -> void:
	var c = raton.celda
	var r = raton.rumbo
	if raton.pared_frente():
		mapa.poner_pared(c, r)
	if raton.pared_derecha():
		mapa.poner_pared(c, (r + 1) % 4)
	if raton.pared_izquierda():
		mapa.poner_pared(c, (r + 3) % 4)
	visitadas[c] = true


# Flood-fill: distancia de cada celda a los objetivos sobre nuestro mapa.
# solo_conocidas = true ignora celdas que aún no visitamos (para el speed run).
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


# Devuelve el rumbo hacia la vecina accesible con menor distancia (o -1).
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


# Una sola acción por tick: si ya miramos hacia 'dir' avanzamos, si no giramos.
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


# Rumbo (N/E/S/O) para ir de una celda a su vecina contigua.
func _direccion_hacia(desde: Vector2i, hasta: Vector2i) -> int:
	var delta = hasta - desde
	for dir in 4:
		if Laberinto.DELTAS[dir] == delta:
			return dir
	return -1
