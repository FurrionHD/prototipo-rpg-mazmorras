# ============================================================
#  party_trail.gd
#  EL SEQUITO: los companeros que van detras de ti por el mapa.
#
#  No tienen IA: van por un RASTRO. Se apuntan las posiciones por las que pasa el que va en
#  cabeza y cada companero camina hacia el punto por el que pasaste hace X pixeles. Es la
#  solucion de siempre para los seguidores (Pokemon, Chrono Trigger, Lost Vikings) y da justo lo
#  que se quiere aqui: van en fila india por sitio pisable (porque pisan donde ya pisaste tu) y
#  no hay que resolver nada de pathfinding.
#
#  Los cuerpos SI son fisicos (companion.gd, CharacterBody2D): chocan con la roca y estan en el
#  grupo "aliado", asi que un bicho puede ir a por ellos y empezar el combate. Este nodo no los
#  teletransporta: les dice a que punto ir y ellos se mueven con move_and_slide.
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

const CompanionScript := preload("res://scripts/actors/player/companion.gd")

var _rastro: PackedVector2Array = PackedVector2Array()
var _cuerpos: Array[CharacterBody2D] = []
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
	# Faltan cuerpos (alguien nuevo baja contigo): se crean YA colocados en su hueco del rastro
	# (si nacieran en el origen, cruzarian el mapa entero corriendo hasta su sitio).
	while _cuerpos.size() < comps.size():
		var c: CharacterBody2D = CompanionScript.new()
		add_child(c)
		c.plantar(_punto_a_distancia(SEPARACION * float(_cuerpos.size() + 1)))
		_cuerpos.append(c)
		_pintados.append(null)
	# Y el aspecto de cada uno, solo si ha cambiado de dueño.
	for i in comps.size():
		if _pintados[i] != comps[i]:
			_pintados[i] = comps[i]
			_cuerpos[i].pintar(comps[i])


# El rastro arranca EXTENDIDO desde donde estas, para que nazcan ya en fila detras de ti y se vean
# desde el primer frame (amontonados en tu mismo punto, y con z_index -1, serian invisibles hasta
# que anduvieras: parece que no te sigue nadie).
#
# Pero la direccion ya NO es "hacia arriba" a ciegas. Con cuerpos fantasma daba igual; ahora son
# cuerpos con colision, y sembrar hacia la roca los planta DENTRO de la piedra, de donde no pueden
# salir: bajabas al piso y te habias quedado solo. Asi que se prueban los cuatro lados y se coge
# el primero que este despejado de verdad (un rayo contra la capa de la roca). Si no hay ninguno
# -naces en un hueco de tu tamaño-, se amontonan en tu punto, que es pisable siempre porque estas
# tu de pie en el; ya se desplegaran al andar.
const CAPA_ROCA := 1


func _sembrar_rastro() -> void:
	var p: Vector2 = _pos_lider()
	var largo: float = SEPARACION * float(maxi(1, Game.PARTY_MAX - 1)) + LADO
	var dir: Vector2 = Vector2.ZERO
	for candidata in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		if _despejado(p, p + candidata * largo):
			dir = candidata
			break
	_rastro = PackedVector2Array()
	for i in RASTRO_MAX:
		_rastro.append(p + dir * (PASO * float(i)))


# ¿Se llega del punto a al b sin roca de por medio? Mismo criterio que el cono de vision del
# enemigo (ver enemy._linea_de_vision_libre): un rayo contra la capa de los muros.
func _despejado(a: Vector2, b: Vector2) -> bool:
	var mundo: World2D = get_world_2d()
	if mundo == null:
		return false
	var query := PhysicsRayQueryParameters2D.create(a, b, CAPA_ROCA)
	# El propio jugador comparte capa con la roca: sin excluirlo, el rayo choca contigo al salir.
	var padre := get_parent()
	if padre is CollisionObject2D:
		query.exclude = [(padre as CollisionObject2D).get_rid()]
	return mundo.direct_space_state.intersect_ray(query).is_empty()


func _pos_lider() -> Vector2:
	var padre := get_parent()
	return (padre as Node2D).global_position if padre is Node2D else Vector2.ZERO


# Va en _physics_process y no en _process porque el jugador se mueve con move_and_slide, que es
# fisica: leyendo su posicion en el frame de dibujo se lee a destiempo y el sequito tiembla.
func _physics_process(delta: float) -> void:
	if _cuerpos.is_empty():
		return
	var p: Vector2 = _pos_lider()
	# Un punto nuevo solo cuando te has movido lo suficiente. Si se apuntara cada frame, el rastro
	# se llenaria de puntos pegados estando quieto y los companeros se te echarian encima.
	if _rastro.is_empty() or p.distance_to(_rastro[0]) >= PASO:
		_rastro.insert(0, p)
		if _rastro.size() > RASTRO_MAX:
			_rastro.resize(RASTRO_MAX)
	# Colocar SIEMPRE, no solo al añadir un punto: el rastro avanza a saltos de PASO, pero tu te
	# mueves de forma continua, y si los companeros solo se recolocaran al añadir punto irian a
	# tirones. Lo caro no es esto (dos interpolaciones), era el temblor.
	_colocar(delta)


# Manda a cada companero al punto que le toca: a una distancia FIJA por detras de ti, medida A LO
# LARGO del rastro. El punto es un DESTINO, no una posicion: el cuerpo va andando (con su colision)
# y si hay una esquina de por medio, se despega de la fila hasta rodearla.
#
# Antes esto cogia el punto numero N del array (idx = SEPARACION/PASO) y ahi estaba el temblor:
# al insertar un punto nuevo, TODOS los indices se corren uno, asi que el punto N pasaba a ser
# otro y el companero daba un salto de hasta PASO pixeles hacia atras. Como se insertaba un punto
# cada PASO pixeles recorridos, el salto se repetia sin parar: vibracion pura.
#
# Ahora se recorre el rastro sumando distancias reales hasta llegar a la que toca y se INTERPOLA
# entre los dos puntos que la rodean. El resultado no depende de donde caigan los puntos del
# array, asi que insertar uno nuevo no mueve a nadie: la posicion es continua.
func _colocar(delta: float) -> void:
	for i in _cuerpos.size():
		# i+1 companeros detras: el primero a SEPARACION, el segundo al doble...
		_cuerpos[i].seguir(_punto_a_distancia(SEPARACION * float(i + 1)), delta)


# Colocacion DURA de toda la fila sobre el rastro (teletransporte, cambio de piso, cambio de
# lider): aqui no se anda, se aparece.
func _plantar_en_rastro() -> void:
	for i in _cuerpos.size():
		_cuerpos[i].plantar(_punto_a_distancia(SEPARACION * float(i + 1)))


# El punto que esta a 'dist' pixeles por detras de ti, recorriendo el camino tramo a tramo.
# Si el rastro se acaba antes (recien sembrado), devuelve el ultimo que haya.
#
# El recorrido arranca en tu posicion VIVA, no en _rastro[0], y eso importa: el rastro solo gana
# un punto cada PASO pixeles, asi que su cabeza se queda vieja entre insercion e insercion. Si se
# midiera desde ella, el camino no crece mientras tanto y los companeros se quedan clavados... para
# pegar un tiron de PASO pixeles justo al insertar el punto siguiente. Metiendo tu posicion actual
# como primer tramo, el camino crece de forma continua y ellos avanzan a tu mismo ritmo.
func _punto_a_distancia(dist: float) -> Vector2:
	if _rastro.is_empty():
		return _pos_lider()
	var recorrido: float = 0.0
	var a: Vector2 = _pos_lider()
	for i in _rastro.size():
		var b: Vector2 = _rastro[i]
		var tramo: float = a.distance_to(b)
		if tramo > 0.0:
			if recorrido + tramo >= dist:
				# El objetivo cae DENTRO de este tramo: se interpola por donde toque.
				return a.lerp(b, (dist - recorrido) / tramo)
			recorrido += tramo
		a = b
	return a


# Al cambiar de piso (o al teletransportarte) el rastro viejo no vale: sin esto, los companeros
# cruzarian el mapa nuevo en linea recta desde donde estaban en el anterior.
func teletransportar() -> void:
	_sembrar_rastro()
	_plantar_en_rastro()


# ============================================================
#  CAMBIO DE LIDER (teclas 1/2/3)
#  El cuerpo que TU mueves es uno solo: cambiar de lider lo planta donde estaba el elegido. Para
#  que eso no se lea como un pestañeo, los demas tienen que quedarse EXACTAMENTE donde estaban y
#  empezar a seguir al nuevo desde ahi (el ex-lider incluido, que hereda el sitio que dejas).
#  Estas dos funciones son las dos mitades de esa maniobra; las usa player.refrescar_lider().
# ============================================================

# Donde esta ahora mismo cada companero: {PersonajeData: posicion}. Se pide ANTES de cambiar nada.
func posiciones() -> Dictionary:
	var out: Dictionary = {}
	for i in _cuerpos.size():
		if i < _pintados.size() and _pintados[i] != null:
			out[_pintados[i]] = _cuerpos[i].global_position
	return out


# Recoloca la fila tras el cambio de lider. A cada companero se le devuelve la posicion que ya
# tenia ('previas') y el rastro se resiembra como la POLILINEA que los une, EN SU ORDEN DE HUECO
# (el de party, no el de cercania): los huecos son fijos, y tender el rastro por cercania hacia
# que el hueco 1 recibiera el punto del que estaba mas cerca del lider aunque fuera el hueco 2 ->
# la fila se cruzaba y el que se quedaba atras salia disparado hacia delante.
#
# Nadie da un salto (cada cuerpo se planta donde ya estaba) y desde ahi caminan hasta su sitio en
# la formacion: eso es "empiezan a seguir al nuevo desde donde estaban".
func reordenar(previas: Dictionary) -> void:
	refrescar()   # los cuerpos ya son los de AHORA (el ex-lider tiene el suyo, el nuevo ya no)
	var lider_pos: Vector2 = _pos_lider()
	# A quien no le conozcamos posicion (acaba de entrar al equipo) se le manda al sitio del lider:
	# nace pegado a el y se descuelga andando, en vez de aparecer en el origen del mapa.
	var puntos: Array = []
	for i in _cuerpos.size():
		var pj: PersonajeData = _pintados[i] if i < _pintados.size() else null
		var p: Vector2 = previas[pj] if pj != null and previas.has(pj) else lider_pos
		_cuerpos[i].plantar(p)
		puntos.append(p)
	# El rastro: del lider a cada companero, hueco a hueco.
	_rastro = PackedVector2Array()
	var anterior: Vector2 = lider_pos
	for p in puntos:
		_tender_rastro(anterior, p)
		anterior = p
	# Y detras del ultimo, mas rastro en linea recta: si el array se quedara corto, el que va en
	# la cola se agolparia sobre el de delante en cuanto empieces a andar.
	_tender_rastro(anterior, anterior + (anterior - lider_pos).normalized() * SEPARACION)
	while _rastro.size() < RASTRO_MAX:
		_rastro.append(_rastro[_rastro.size() - 1] if not _rastro.is_empty() else lider_pos)


# Añade al rastro el tramo a->b picado en pasos de PASO (el rastro se mide por distancia real
# recorrida, asi que un tramo largo tiene que llevar sus puntos intermedios).
func _tender_rastro(a: Vector2, b: Vector2) -> void:
	var largo: float = a.distance_to(b)
	var n: int = maxi(1, ceili(largo / PASO))
	for i in range(1, n + 1):
		if _rastro.size() >= RASTRO_MAX:
			return
		_rastro.append(a.lerp(b, float(i) / float(n)))
