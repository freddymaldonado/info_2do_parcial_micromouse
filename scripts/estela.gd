class_name Estela
extends Node2D

# Bonus (juice): la estela que el ratón deja atrás en la vista de dios. Guarda
# los últimos puntos por los que pasó y los dibuja como una línea que se
# desvanece (más vieja = más transparente).

const MAX_PUNTOS := 60

var _puntos: Array[Vector2] = []

@export var color := Color(1.0, 0.85, 0.35)


func limpiar() -> void:
	_puntos.clear()
	queue_redraw()


func agregar(p: Vector2) -> void:
	_puntos.append(p)
	if _puntos.size() > MAX_PUNTOS:
		_puntos.pop_front()
	queue_redraw()


func _draw() -> void:
	if _puntos.size() < 2:
		return
	for i in range(_puntos.size() - 1):
		# Los puntos más recientes (al final) se ven más opacos.
		var t = float(i) / float(_puntos.size())
		var c = Color(color.r, color.g, color.b, t * 0.6)
		draw_line(_puntos[i], _puntos[i + 1], c, 3.0)
