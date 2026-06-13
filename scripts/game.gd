extends Node2D

# Controlador principal. Carga el laberinto, coloca al ratón y hace avanzar el
# cerebro un paso por tick. Sobre el núcleo provisto (laberinto, sensado,
# movimiento, vista de dios) añadimos lo que pedía el parcial:
#   B1 telemetría, B2 controles, B3 máquina de estados + pantalla final,
#   B4 sonidos, M2 mapa del ratón, M3 rutas/comparación, M4 selector + récords.

# Señales de telemetría que escucha el HUD (B1/B3).
signal pasos_cambiados(pasos: int)
signal visitadas_cambiadas(cantidad: int)
signal fase_cambiada(nombre: String)
signal tiempo_cambiado(segundos: float)
signal record_cambiado(pasos: int)
signal corrida_terminada(exito: bool, pasos_expl: int, pasos_speed: int)

@export_file("*.maz") var archivo_laberinto: String = "res://mazes/01_entrenamiento.maz"
# Activado por defecto: la entrega corre nuestro micromouse de verdad.
@export var usar_cerebro_estudiante: bool = true

const ORIGEN := Vector2(28, 44)
const VELOCIDADES := [1.0, 2.0, 4.0]
const RUTA_RECORDS := "user://records.json"

var tam_celda := 38.0
var laberinto: Laberinto
var cerebro = null

# Estado de la corrida (B3).
var fase_actual: String = "EXPLORANDO"
var tiempo: float = 0.0
var corriendo: bool = false
var indice_velocidad: int = 0
var pasos_previos: int = 0
var es_estudiante: bool = false
var records: Dictionary = {}

@onready var vista_dios: VistaLaberinto = $vista_dios
@onready var vista_mapa_raton = $vista_mapa_raton
@onready var raton: Raton = $raton
@onready var paso_timer: Timer = $paso_timer
@onready var boton_pausa: Button = $ui/hud/margen/columna/botones/boton_pausa
@onready var boton_velocidad: Button = $ui/hud/margen/columna/botones/boton_velocidad

# Creados por código (B4 sonidos, M4 selector, B3 pantalla final).
var snd_paso: AudioStreamPlayer
var snd_choque: AudioStreamPlayer
var snd_meta: AudioStreamPlayer
var selector: OptionButton
var pantalla_final: ColorRect
var label_final: Label


func _ready() -> void:
	_crear_sonidos()
	_crear_selector()
	_crear_pantalla_final()
	_cargar_records()
	raton.choque.connect(_on_raton_choque)
	_iniciar_corrida()


# Arranca (o reinicia) una corrida completa con el laberinto actual.
func _iniciar_corrida() -> void:
	laberinto = Laberinto.desde_archivo(archivo_laberinto)
	tam_celda = minf(56.0, 608.0 / maxf(laberinto.ancho, laberinto.alto))
	vista_dios.configurar(laberinto, ORIGEN, tam_celda)
	raton.configurar(laberinto, ORIGEN, tam_celda)
	es_estudiante = usar_cerebro_estudiante
	if es_estudiante:
		cerebro = CerebroEstudiante.new()
		cerebro.preparar(laberinto.ancho, laberinto.alto, laberinto.metas,
				laberinto.inicio)
		# M2: la vista derecha dibuja el mapa que el cerebro va descubriendo.
		vista_mapa_raton.configurar(cerebro.mapa, ORIGEN, tam_celda)
		vista_mapa_raton.visitadas = cerebro.visitadas
		vista_mapa_raton.ruta_exploracion = cerebro.ruta_exploracion
		vista_mapa_raton.ruta_speed = cerebro.ruta_speed
		vista_mapa_raton.celda_raton = raton.celda
		vista_mapa_raton.queue_redraw()
	else:
		cerebro = CerebroWallFollower.new()
	fase_actual = "EXPLORANDO"
	tiempo = 0.0
	pasos_previos = 0
	corriendo = true
	paso_timer.wait_time = 0.12 / VELOCIDADES[indice_velocidad]
	raton.duracion_paso = 0.10 / VELOCIDADES[indice_velocidad]
	paso_timer.start()
	pantalla_final.visible = false
	boton_pausa.text = "Pausa"
	_emitir_telemetria()
	fase_cambiada.emit(fase_actual)
	tiempo_cambiado.emit(tiempo)
	record_cambiado.emit(_record_actual())


func _process(delta: float) -> void:
	# Cronómetro de la corrida (B1): solo corre mientras no esté en pausa/fin.
	if corriendo and fase_actual != "FIN":
		tiempo += delta
		tiempo_cambiado.emit(tiempo)


func _on_paso_timer_timeout() -> void:
	_tick()


# Un paso del cerebro + actualización de telemetría, mapa y máquina de estados.
func _tick() -> void:
	if raton.ocupado():
		return
	if fase_actual == "FIN":
		return
	cerebro.paso(raton)
	# B4: tic de paso si el ratón realmente avanzó (raton.pasos solo sube al avanzar).
	if raton.pasos > pasos_previos:
		pasos_previos = raton.pasos
		snd_paso.play()
	_emitir_telemetria()
	if es_estudiante:
		# M2: refrescamos la vista del mapa con lo nuevo que aprendió el ratón.
		vista_mapa_raton.celda_raton = raton.celda
		vista_mapa_raton.queue_redraw()
		if cerebro.fase != fase_actual:
			_cambiar_fase(cerebro.fase)
	else:
		if laberinto.es_meta(raton.celda):
			_cambiar_fase("FIN")


func _emitir_telemetria() -> void:
	pasos_cambiados.emit(raton.pasos)
	var cantidad = 0
	if es_estudiante:
		cantidad = cerebro.visitadas.size()
	visitadas_cambiadas.emit(cantidad)


# B3: máquina de estados (EXPLORANDO -> VOLVIENDO -> SPEED RUN -> FIN).
func _cambiar_fase(nueva: String) -> void:
	fase_actual = nueva
	fase_cambiada.emit(nueva)
	if nueva == "FIN":
		_terminar()


func _terminar() -> void:
	corriendo = false
	paso_timer.stop()
	snd_meta.play()
	var expl = raton.pasos
	var speed = 0
	if es_estudiante:
		expl = cerebro.pasos_exploracion
		speed = cerebro.pasos_speed
	# M4: el récord guarda los pasos del speed run (o de la corrida si es wall-follower).
	_guardar_record(speed if es_estudiante else expl)
	corrida_terminada.emit(true, expl, speed)
	_mostrar_pantalla_final(expl, speed)


# --- B2: controles de ejecución ---

func _on_boton_pausa_pressed() -> void:
	if fase_actual == "FIN":
		return
	corriendo = not corriendo
	if corriendo:
		paso_timer.start()
		boton_pausa.text = "Pausa"
	else:
		paso_timer.stop()
		boton_pausa.text = "Reanudar"


func _on_boton_paso_pressed() -> void:
	# Solo con la corrida pausada: ejecuta UN paso del cerebro (depuración).
	if corriendo or fase_actual == "FIN":
		return
	_tick()


func _on_boton_velocidad_pressed() -> void:
	indice_velocidad = (indice_velocidad + 1) % VELOCIDADES.size()
	var v = VELOCIDADES[indice_velocidad]
	paso_timer.wait_time = 0.12 / v
	raton.duracion_paso = 0.10 / v
	boton_velocidad.text = "Vel x%d" % int(v)


func _on_boton_reiniciar_pressed() -> void:
	_iniciar_corrida()


func _on_raton_choque() -> void:
	# B4: sonido de choque cuando el ratón intenta atravesar una pared.
	snd_choque.play()


# --- B4: sonidos creados por código ---

func _crear_sonidos() -> void:
	snd_paso = _nuevo_sonido("res://assets/sounds/paso.wav")
	snd_choque = _nuevo_sonido("res://assets/sounds/choque.wav")
	snd_meta = _nuevo_sonido("res://assets/sounds/meta.wav")


func _nuevo_sonido(ruta: String) -> AudioStreamPlayer:
	var reproductor = AudioStreamPlayer.new()
	reproductor.stream = load(ruta)
	add_child(reproductor)
	return reproductor


# --- M4: selector de laberintos (lee la carpeta mazes/ sin tocar código) ---

func _crear_selector() -> void:
	selector = OptionButton.new()
	selector.position = Vector2(940, 8)
	selector.size = Vector2(176, 28)
	for nombre in _listar_mazes():
		selector.add_item(nombre)
	# Dejamos seleccionado el laberinto con el que arrancamos.
	var actual = archivo_laberinto.get_file()
	for i in selector.item_count:
		if selector.get_item_text(i) == actual:
			selector.select(i)
	selector.item_selected.connect(_on_selector_cambiado)
	$ui.add_child(selector)


func _listar_mazes() -> Array:
	var nombres = []
	var dir = DirAccess.open("res://mazes")
	if dir:
		dir.list_dir_begin()
		var f = dir.get_next()
		while f != "":
			if f.ends_with(".maz"):
				nombres.append(f)
			f = dir.get_next()
		dir.list_dir_end()
	nombres.sort()
	return nombres


func _on_selector_cambiado(idx: int) -> void:
	archivo_laberinto = "res://mazes/" + selector.get_item_text(idx)
	_iniciar_corrida()


# --- M4: récords persistentes en user:// ---

func _cargar_records() -> void:
	records = {}
	if FileAccess.file_exists(RUTA_RECORDS):
		var texto = FileAccess.get_file_as_string(RUTA_RECORDS)
		var datos = JSON.parse_string(texto)
		if typeof(datos) == TYPE_DICTIONARY:
			records = datos


func _record_actual() -> int:
	var clave = archivo_laberinto.get_file()
	if records.has(clave):
		return int(records[clave])
	return -1


func _guardar_record(pasos: int) -> void:
	if pasos <= 0:
		return
	var clave = archivo_laberinto.get_file()
	if not records.has(clave) or pasos < int(records[clave]):
		records[clave] = pasos
		var archivo = FileAccess.open(RUTA_RECORDS, FileAccess.WRITE)
		if archivo:
			archivo.store_string(JSON.stringify(records))
	record_cambiado.emit(_record_actual())


# --- B3: pantalla final (creada por código) ---

func _crear_pantalla_final() -> void:
	pantalla_final = ColorRect.new()
	pantalla_final.set_anchors_preset(Control.PRESET_FULL_RECT)
	pantalla_final.color = Color(0, 0, 0, 0.65)
	pantalla_final.visible = false
	var centro = CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	pantalla_final.add_child(centro)
	var panel = PanelContainer.new()
	centro.add_child(panel)
	var columna = VBoxContainer.new()
	columna.add_theme_constant_override("separation", 12)
	panel.add_child(columna)
	label_final = Label.new()
	label_final.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(label_final)
	var boton = Button.new()
	boton.text = "Reiniciar"
	boton.pressed.connect(_on_boton_reiniciar_pressed)
	columna.add_child(boton)
	$ui.add_child(pantalla_final)


func _mostrar_pantalla_final(expl: int, speed: int) -> void:
	var texto = "¡META ALCANZADA!\n\n"
	if es_estudiante:
		# M3: comparación de pasos exploración vs. speed run.
		texto += "Exploración: %d pasos\n" % expl
		texto += "Speed run: %d pasos\n" % speed
		texto += "Ahorro: %d pasos" % (expl - speed)
	else:
		texto += "Pasos: %d" % expl
	label_final.text = texto
	pantalla_final.visible = true
