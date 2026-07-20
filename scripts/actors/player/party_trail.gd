# ============================================================
#  party_trail.gd
#  EL SEQUITO: los companeros que van detras de ti por el mapa.
#
#  No tienen IA ni fisica: van por un RASTRO. Se apuntan las posiciones por las que pasa el que
#  va en cabeza y cada companero se coloca en el punto por el que pasaste hace X pixeles. Es la
#  solucion de siempre para los seguidores (Pokemon, Chrono Trigger, Lost Vikings) y da justo lo
#  que se quiere aqui: van en fila india, no se cuelan por las paredes (porque pisan donde ya
#  pisaste tu) y no hay que resolver nada de pathfinding ni de empujones entre cuerpos.
#
#  Se pintan con el MISMO ColorRect + shader que el cuerpo del lider (Game.material_de), asi que
#  cada uno se ve con SU color, SU brillo y SU imagen: los distingues de un vistazo.
#
#  Cuelga del jugador pero es top_level: sus hijos viven en coordenadas de MUNDO, o se moverian
#  pegados a el y el rastro no serviria de nada.
# ============================================================

extends Node2D

# Cada cuantos pixeles se apunta un punto del rastro. Fino = la fila se curva bien en los
# pasillos; demasiado fino = un array enorme para nada.
const PASO := 6.0
# A que distancia (en pixeles de recorrido, no en linea recta) va cada companero. El primero a
# 34 px: lo justo para no solaparse con el cuerpo del lider, que mide 32.
const SEPARACION := 34.0
# Cuanto rastro se guarda. Da para PARTY_MAX-1 companeros con holgura de sobra.
const RASTRO_MAX := 256

const LADO := 32.0   # el cuerpo mide lo mismo que el del jugador (player.tscn)

var _rastro: PackedVector2Array = PackedVector2Array()
var _cuerpos: Array[ColorRect] = []
# A quien esta pintando cada cuerpo. Se guarda para no rehacer el material en cada frame: solo
# se repinta cuando de verdad cambia la gente (contratar, cambiar de lider, gestor de equipo).
var _pintados: Array[PersonajeData] = []


func _ready() -> void:
	top_level = true   # coordenadas de mundo: el rastro es absoluto
	# Detras del lider: el jugador es quien manda visualmente.
	z_index = -1
	_sembrar_rastro()
	refrescar()


# Rehace los cuerpos para la gente que haya AHORA en el equipo. Lo llama el jugador cuando cambia
# el lider o vuelves de un menu donde has podido tocar el equipo.
func refrescar() -> void:
	var comps: Array[PersonajeData] = Game.companeros()
	# Sobran cuerpos (alguien se ha quedado en casa): fuera los de mas.
	while _cuerpos.size() > comps.size():
		_cuerpos.pop_back().queue_free()
		_pintados.pop_back()
	# Faltan cuerpos (alguien nuevo baja contigo): se crean.
	while _cuerpos.size() < comps.size():
		var r := ColorRect.new()
		r.size = Vector2(LADO, LADO)
		# El nodo se posiciona por su ESQUINA, y el rastro son centros: se compensa aqui una vez
		# en vez de restar medio cuerpo en cada frame.
		r.pivot_offset = Vector2(LADO * 0.5, LADO * 0.5)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(r)
		_cuerpos.append(r)
		_pintados.append(null)
	# Y el aspecto de cada uno, solo si ha cambiado de dueño.
	for i in comps.size():
		if _pintados[i] != comps[i]:
			_pintados[i] = comps[i]
			_cuerpos[i].color = comps[i].color
			_cuerpos[i].material = Game.material_de(comps[i])
	_colocar()


# El rastro arranca ya EXTENDIDO hacia arriba desde donde estas, en vez de lleno de tu posicion
# a secas. Dos motivos:
#   - vacio, los companeros apareceran amontonados en el origen del mapa;
#   - todo en tu MISMO punto, aparecen exactamente DEBAJO de ti (y con z_index -1, invisibles)
#     hasta que andes lo suficiente, que da la sensacion de que no te sigue nadie.
# Sembrandolo como una linea, nacen ya colocados en fila detras y se ven desde el primer frame.
func _sembrar_rastro() -> void:
	_rastro = PackedVector2Array()
	var p: Vector2 = _pos_lider()
	for i in RASTRO_MAX:
		_rastro.append(p + Vector2(0, -PASO * float(i)))


func _pos_lider() -> Vector2:
	var padre := get_parent()
	return (padre as Node2D).global_position if padre is Node2D else Vector2.ZERO


func _process(_delta: float) -> void:
	if _cuerpos.is_empty():
		return
	var p: Vector2 = _pos_lider()
	# Un punto nuevo solo cuando te has movido lo suficiente. Si se apuntara cada frame, el rastro
	# se llenaria de puntos pegados estando quieto y los companeros se te echarian encima.
	if _rastro.is_empty() or p.distance_to(_rastro[0]) >= PASO:
		_rastro.insert(0, p)
		if _rastro.size() > RASTRO_MAX:
			_rastro.resize(RASTRO_MAX)
		_colocar()


func _colocar() -> void:
	for i in _cuerpos.size():
		# i+1 companeros detras: el primero a SEPARACION, el segundo al doble...
		var idx: int = int(round(SEPARACION * float(i + 1) / PASO))
		var pos: Vector2 = _rastro[mini(idx, _rastro.size() - 1)] if not _rastro.is_empty() else _pos_lider()
		_cuerpos[i].global_position = pos - Vector2(LADO, LADO) * 0.5


# Al cambiar de piso (o al teletransportarte) el rastro viejo no vale: sin esto, los companeros
# cruzarian el mapa nuevo en linea recta desde donde estaban en el anterior.
func teletransportar() -> void:
	_sembrar_rastro()
	_colocar()
