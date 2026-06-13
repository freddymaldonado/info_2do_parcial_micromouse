extends Node2D

# controlador principal. carga el lab, pone al raton y mueve al cerebro un paso
# por tick. sobre lo que ya venia hecho (lab, sensado, movimiento, vista de dios)
# le agregue lo del parcial: telemetria (B1), controles (B2), maquina de estados
# y pantalla final (B3), sonidos (B4), mapa del raton (M2), rutas (M3) y el
# selector con records (M4). mas los bonus de juice.

# señales que escucha el hud
signal pasos_cambiados(pasos: int)
signal visitadas_cambiadas(cantidad: int)
signal fase_cambiada(nombre: String)
signal tiempo_cambiado(segundos: float)
signal record_cambiado(pasos: int)
signal corrida_terminada(exito: bool, pasos_expl: int, pasos_speed: int)

@export_file("*.maz") var archivo_laberinto: String = "res://mazes/01_entrenamiento.maz"
# lo dejo prendido para que corra mi cerebro y no el de ejemplo
@export var usar_cerebro_estudiante: bool = true

const ORIGEN := Vector2(28, 44)
const VELOCIDADES := [1.0, 2.0, 4.0]
const RUTA_RECORDS := "user://records.json"
# cuanto dura y cuanto se mueve la sacudida al chocar (bonus)
const SHAKE_DUR := 0.35
const SHAKE_MAG := 8.0

var tam_celda := 38.0
var laberinto: Laberinto
var cerebro = null

# estado de la corrida
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

# cosas que creo por codigo: sonidos, selector, pantalla final
var snd_paso: AudioStreamPlayer
var snd_choque: AudioStreamPlayer
var snd_meta: AudioStreamPlayer
var selector: OptionButton
var pantalla_final: ColorRect
var label_final: Label
# cosas del bonus: camara para la sacudida, la estela y el boton de heat map
var camara: Camera2D
var estela: Estela
var boton_heatmap: Button
var shake_tiempo: float = 0.0


func _ready() -> void:
	_crear_sonidos()
	_crear_selector()
	_crear_boton_heatmap()
	_crear_pantalla_final()
	_crear_camara()
	_crear_estela()
	_cargar_records()
	raton.choque.connect(_on_raton_choque)
	_iniciar_corrida()


# arranca (o reinicia) una corrida nueva con el lab que este elegido
func _iniciar_corrida() -> void:
	laberinto = Laberinto.desde_archivo(archivo_laberinto)
	tam_celda = minf(56.0, 608.0 / maxf(laberinto.ancho, laberinto.alto))
	vista_dios.configurar(laberinto, ORIGEN, tam_celda)
	raton.configurar(laberinto, ORIGEN, tam_celda)
	estela.limpiar()  # borro la estela de la corrida anterior
	es_estudiante = usar_cerebro_estudiante
	if es_estudiante:
		cerebro = CerebroEstudiante.new()
		cerebro.preparar(laberinto.ancho, laberinto.alto, laberinto.metas,
				laberinto.inicio)
		# M2: la vista de la derecha dibuja el mapa que va descubriendo el cerebro
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
	# cronometro: solo cuenta si esta corriendo y no termino todavia
	if corriendo and fase_actual != "FIN":
		tiempo += delta
		tiempo_cambiado.emit(tiempo)
	_actualizar_sacudida(delta)


func _on_paso_timer_timeout() -> void:
	_tick()


# un paso del cerebro y de paso actualizo telemetria, mapa y la maquina de estados
func _tick() -> void:
	if raton.ocupado():
		return
	if fase_actual == "FIN":
		return
	cerebro.paso(raton)
	# tic de sonido solo si de verdad avanzo (raton.pasos sube nada mas al avanzar)
	if raton.pasos > pasos_previos:
		pasos_previos = raton.pasos
		snd_paso.play()
		estela.agregar(raton.position)  # voy dejando la estela
	_emitir_telemetria()
	if es_estudiante:
		# refresco la vista del mapa con lo nuevo que aprendio el raton
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


# maquina de estados: EXPLORANDO -> VOLVIENDO -> SPEED RUN -> FIN
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
	# guardo el record con los pasos del speed run (o de la corrida si es wall follower)
	_guardar_record(speed if es_estudiante else expl)
	corrida_terminada.emit(true, expl, speed)
	_celebrar()  # fiesta de particulas en la meta
	_mostrar_pantalla_final(expl, speed)


# --- botones del panel ---

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
	# solo si esta en pausa: doy un paso del cerebro para depurar
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
	# suena el choque cuando intenta atravesar una pared
	snd_choque.play()
	shake_tiempo = SHAKE_DUR  # y tiembla la pantalla


# --- sonidos ---

func _crear_sonidos() -> void:
	snd_paso = _nuevo_sonido("res://assets/sounds/paso.wav")
	snd_choque = _nuevo_sonido("res://assets/sounds/choque.wav")
	snd_meta = _nuevo_sonido("res://assets/sounds/meta.wav")


func _nuevo_sonido(ruta: String) -> AudioStreamPlayer:
	var reproductor = AudioStreamPlayer.new()
	reproductor.stream = load(ruta)
	add_child(reproductor)
	return reproductor


# --- selector de laberintos (lee la carpeta mazes/ sola) ---

func _crear_selector() -> void:
	selector = OptionButton.new()
	selector.position = Vector2(940, 8)
	selector.size = Vector2(176, 28)
	for nombre in _listar_mazes():
		selector.add_item(nombre)
	# dejo marcado el lab con el que arranque
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


# --- records que se guardan en user:// ---

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


# --- pantalla final ---

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
		# comparo los pasos de exploracion con los del speed run
		texto += "Exploración: %d pasos\n" % expl
		texto += "Speed run: %d pasos\n" % speed
		texto += "Ahorro: %d pasos" % (expl - speed)
	else:
		texto += "Pasos: %d" % expl
	label_final.text = texto
	pantalla_final.visible = true


# --- bonus: estela, sacudida, heat map y la fiesta de la meta ---

func _crear_camara() -> void:
	# camara fija (no mueve la escena), la uso solo para la sacudida
	camara = Camera2D.new()
	camara.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	camara.position = Vector2.ZERO
	add_child(camara)
	camara.make_current()


func _crear_estela() -> void:
	estela = Estela.new()
	add_child(estela)


func _crear_boton_heatmap() -> void:
	boton_heatmap = Button.new()
	boton_heatmap.text = "Heat-map"
	boton_heatmap.toggle_mode = true
	boton_heatmap.position = Vector2(810, 8)
	boton_heatmap.size = Vector2(120, 28)
	boton_heatmap.toggled.connect(_on_heatmap_toggled)
	$ui.add_child(boton_heatmap)


func _on_heatmap_toggled(activado: bool) -> void:
	# pinto las celdas segun cuantas veces las piso el raton
	vista_mapa_raton.mostrar_heatmap = activado
	vista_mapa_raton.queue_redraw()


func _actualizar_sacudida(delta: float) -> void:
	if shake_tiempo > 0.0:
		shake_tiempo -= delta
		var f = clampf(shake_tiempo / SHAKE_DUR, 0.0, 1.0)
		camara.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SHAKE_MAG * f
	else:
		camara.offset = Vector2.ZERO


func _celebrar() -> void:
	# Ráfaga de partículas doradas en la meta al terminar.
	if laberinto.metas.is_empty():
		return
	var fiesta = CPUParticles2D.new()
	fiesta.position = vista_dios.celda_a_pixel(laberinto.metas[0])
	fiesta.one_shot = true
	fiesta.explosiveness = 0.9
	fiesta.amount = 48
	fiesta.lifetime = 1.2
	fiesta.initial_velocity_min = 70.0
	fiesta.initial_velocity_max = 180.0
	fiesta.gravity = Vector2(0, 220)
	fiesta.scale_amount_min = 2.0
	fiesta.scale_amount_max = 4.0
	fiesta.color = Color(1.0, 0.85, 0.3)
	add_child(fiesta)
	fiesta.emitting = true
