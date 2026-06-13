extends PanelContainer

# Panel lateral de telemetría (B1). Las etiquetas ya existen en la escena; aquí
# nos conectamos a las señales de game.gd y refrescamos su texto en cada cambio.

@onready var fase_label: Label = $margen/columna/fase_label
@onready var pasos_label: Label = $margen/columna/pasos_label
@onready var visitadas_label: Label = $margen/columna/visitadas_label
@onready var tiempo_label: Label = $margen/columna/tiempo_label
@onready var record_label: Label = $margen/columna/record_label


func _ready() -> void:
	# CanvasLayer -> Game: nos suscribimos a las señales de telemetría.
	var game = get_parent().get_parent()
	game.pasos_cambiados.connect(update_pasos)
	game.visitadas_cambiadas.connect(update_visitadas)
	game.fase_cambiada.connect(update_fase)
	game.tiempo_cambiado.connect(update_tiempo)
	game.record_cambiado.connect(update_record)


func update_fase(nombre: String) -> void:
	fase_label.text = "fase: " + nombre


func update_pasos(pasos: int) -> void:
	pasos_label.text = "pasos: %d" % pasos


func update_visitadas(cantidad: int) -> void:
	visitadas_label.text = "visitadas: %d" % cantidad


func update_tiempo(segundos: float) -> void:
	tiempo_label.text = "tiempo: %.1f s" % segundos


func update_record(pasos: int) -> void:
	# -1 significa que todavía no hay récord guardado para este laberinto (M4).
	if pasos < 0:
		record_label.text = "récord: —"
	else:
		record_label.text = "récord: %d" % pasos
