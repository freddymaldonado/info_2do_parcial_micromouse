class_name VistaMapa
extends VistaLaberinto

# Vista derecha: "el mapa del ratón" (M2). Dibuja lo que el cerebro SABE:
#   - celdas visitadas vs. no visitadas (a simple vista),
#   - solo las paredes que el ratón ya sensó,
#   - y, superpuestas, la ruta de exploración y la del speed run (M3).
#
# Es una subclase de VistaLaberinto: reusa sus colores y su origen/tam, pero
# redefine _draw() para pintar el conocimiento parcial del ratón.

# game.gd nos pasa estas referencias (las comparte con el cerebro y se
# actualizan solas a medida que el ratón explora).
var visitadas: Dictionary = {}
var ruta_exploracion: Array = []
var ruta_speed: Array = []
var celda_raton: Vector2i = Vector2i.ZERO
# Bonus: si está activo, las celdas se colorean por cuántas veces se pisaron.
var mostrar_heatmap: bool = false

@export var color_visitada := Color(0.20, 0.45, 0.38, 0.55)
@export var color_no_visitada := Color(0.12, 0.12, 0.16, 1.0)
@export var color_ruta_expl := Color(1.0, 0.6, 0.2, 0.9)
@export var color_ruta_speed := Color(0.35, 1.0, 1.0, 0.95)
@export var color_raton := Color(0.95, 0.80, 0.25)


func _draw() -> void:
	if laberinto == null:
		return
	# Fondo: visitadas resaltadas, no visitadas oscuras (M2). Con heat-map activo,
	# las visitadas se pintan según su número de visitas (bonus).
	var max_visitas = 1
	if mostrar_heatmap:
		for v in visitadas.values():
			max_visitas = max(max_visitas, int(v))
	for fila in laberinto.alto:
		for col in laberinto.ancho:
			var celda = Vector2i(col, fila)
			var rect = Rect2(origen + Vector2(celda) * tam, Vector2(tam, tam))
			if visitadas.has(celda):
				if mostrar_heatmap:
					draw_rect(rect, _color_calor(int(visitadas[celda]), max_visitas))
				else:
					draw_rect(rect, color_visitada)
			else:
				draw_rect(rect, color_no_visitada)
	# Rejilla tenue.
	for col in laberinto.ancho + 1:
		draw_line(origen + Vector2(col * tam, 0),
				origen + Vector2(col * tam, laberinto.alto * tam), color_rejilla, 1.0)
	for fila in laberinto.alto + 1:
		draw_line(origen + Vector2(0, fila * tam),
				origen + Vector2(laberinto.ancho * tam, fila * tam), color_rejilla, 1.0)
	# Inicio y metas (datos del concurso).
	draw_rect(Rect2(origen + Vector2(laberinto.inicio) * tam, Vector2(tam, tam)), color_inicio)
	for meta in laberinto.metas:
		draw_rect(Rect2(origen + Vector2(meta) * tam, Vector2(tam, tam)), color_meta)
	# Paredes que el ratón YA descubrió (las que no sensó no aparecen).
	for fila in laberinto.alto:
		for col in laberinto.ancho:
			var celda = Vector2i(col, fila)
			var esquina = origen + Vector2(celda) * tam
			if laberinto.tiene_pared(celda, Laberinto.NORTE):
				draw_line(esquina, esquina + Vector2(tam, 0), color_paredes, grosor_pared)
			if laberinto.tiene_pared(celda, Laberinto.OESTE):
				draw_line(esquina, esquina + Vector2(0, tam), color_paredes, grosor_pared)
			if fila == laberinto.alto - 1 and laberinto.tiene_pared(celda, Laberinto.SUR):
				draw_line(esquina + Vector2(0, tam), esquina + Vector2(tam, tam),
						color_paredes, grosor_pared)
			if col == laberinto.ancho - 1 and laberinto.tiene_pared(celda, Laberinto.ESTE):
				draw_line(esquina + Vector2(tam, 0), esquina + Vector2(tam, tam),
						color_paredes, grosor_pared)
	# Rutas superpuestas: exploración (naranja) y speed run (cian) (M3).
	_dibujar_ruta(ruta_exploracion, color_ruta_expl, 2.0)
	_dibujar_ruta(ruta_speed, color_ruta_speed, 4.0)
	# Posición actual del ratón.
	draw_circle(celda_a_pixel(celda_raton), tam * 0.18, color_raton)


# Une los centros de las celdas consecutivas de una ruta con líneas.
func _dibujar_ruta(ruta: Array, color: Color, grosor: float) -> void:
	if ruta.size() < 2:
		return
	for i in range(ruta.size() - 1):
		draw_line(celda_a_pixel(ruta[i]), celda_a_pixel(ruta[i + 1]), color, grosor)


# Bonus heat-map: de azul frío (pocas visitas) a rojo caliente (muchas).
func _color_calor(conteo: int, maximo: int) -> Color:
	var t = clampf(float(conteo) / float(max(1, maximo)), 0.0, 1.0)
	var frio = Color(0.15, 0.35, 0.70)
	var caliente = Color(0.90, 0.20, 0.10)
	var c = frio.lerp(caliente, t)
	c.a = 0.65
	return c
