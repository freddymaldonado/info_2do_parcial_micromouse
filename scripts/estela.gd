class_name Estela
extends Node2D

# bonus: la estela que va dejando el raton en la vista de dios. guardo los
# ultimos puntos por donde paso y los dibujo como una linea que se va apagando
# (mientras mas vieja, mas transparente).

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
		# los puntos mas nuevos (al final) se ven mas opacos
		var t = float(i) / float(_puntos.size())
		var c = Color(color.r, color.g, color.b, t * 0.6)
		draw_line(_puntos[i], _puntos[i + 1], c, 3.0)
