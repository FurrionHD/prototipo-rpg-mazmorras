# ============================================================
#  comer_cristales.gd
#  LOS ENEMIGOS SE COMEN LOS CRISTALES DEL SUELO y mutan a fuerza de comerlos (05/10, idea suya sacada
#  de DanMachi: "si tu no recoges los cristales magicos o los dejas en la mazmorra, los monstruos se los
#  comen, lo cual los mejora o muta").
#
#  Cada Enemy lleva uno de estos (Enemy.comer). Aqui vive TODO lo de comer: buscar, ir, reclamar el
#  cristal, masticar, la carga acumulada y la tirada de mutar. El Enemy solo le cede el movimiento
#  mientras esta en su estado COMER y se deja convertir (Enemy.mutar) cuando sale la tirada.
#
#  Lo acordado con el:
#    - Cristales al suelo: el cadaver que se pudre (DAÑADO, ver Enemy.cristal_podrido) y lo que sueltas tu.
#    - Lo ven y van a por el AUNQUE TE ESTEN PERSIGUIENDO: un cristal tirado es un CEBO para huir que cuesta
#      dinero. Lo que no rompe es un golpe ya comprometido (el aviso o la embestida).
#    - Comen TODOS, jefes incluidos (los dejas en su sala antes de que reaparezca y se los come), pero el
#      jefe NO sale de su sala a por ellos: si no, el cebo serviria para sacarlo de su sitio.
#    - Mutar se tira EN CADA BOCADO con la carga acumulada (PROB_POR_CARGA, tabla aprobada).
# ============================================================
class_name ComerCristales
extends RefCounted

# Cada cuanto mira si hay cristales a la vista. No cada fotograma: con veinte bichos y sesenta cosas en
# el suelo serian mil comprobaciones por fotograma para algo que no corre ninguna prisa.
const MIRAR_CADA := 0.3
# Lo que HUELE: un cristal a esta distancia lo nota mire hacia donde mire (la vista es su cono). Corto a
# proposito: el cebo funciona porque te esta mirando a ti y lo tiras delante, no porque lo huela de lejos.
const OLFATO := 48.0
# Lo que tarda en zamparselo, ya pegado a el. Es lo que te regala el cebo.
const COMER_DUR := 1.2
# Lo que se espera a que el anfitrion le diga si el cristal sigue ahi (multi). Pasado esto, se rinde.
const ESPERA_RED_MAX := 2.0
# Lo que dura la TRANSFORMACION en el mapa (quieto, temblando y creciendo hasta su tamaño de mutante).
const TRANSFORMACION_DUR := 1.8
# Lo cerca que tiene que estar de su borde para empezar a comer.
const ALCANCE_BOCADO := 6.0
# Lo que se aleja el jefe de su sitio para ir a por uno: su sala y poco mas.
const MARGEN_SALA_JEFE := 1.15

# LA TABLA (aprobada el 05/10): probabilidad de mutar en el bocado que deja la carga en N. Entre dos
# casillas se interpola, porque la carga no va de uno en uno (un dañado suma medio, uno de mas categoria
# que la suya suma dos). 5 o mas = muta seguro.
const PROB_POR_CARGA := [0.0, 0.10, 0.25, 0.45, 0.70, 1.0]

# El color del brillo de "cargado" y de las esquirlas al morder: el cian de los cristales (IconoItem).
const COLOR_CRISTAL := Color(0.55, 0.95, 1.0)

var e: Node2D                       # el Enemy dueño (no se tipa: Enemy no tiene class_name)
var carga: float = 0.0              # lo que lleva comido, ya ponderado. Se guarda con el piso.
var objetivo: Node2D = null         # el drop_pickup al que va
var t_mirar: float = 0.0
var t_comer: float = -1.0           # >= 0: masticando
var t_red: float = -1.0             # >= 0: esperando que el anfitrion se lo conceda
var t_transformar: float = -1.0     # >= 0: mutando, quieto
var _bocado: Cristal = null         # lo que esta masticando (ya fuera del suelo)


func _init(dueno: Node2D) -> void:
	e = dueno


# ¿Esta ocupado en algo de comer y hay que dejarle el movimiento?
func ocupado() -> bool:
	return objetivo != null or t_comer >= 0.0 or t_red >= 0.0 or t_transformar >= 0.0


# Lo llama el Enemy cada fotograma que NO esta comiendo ya ni comprometido con un golpe. true = ha visto
# uno y se va a por el (el Enemy pasa a su estado COMER).
func mirar(delta: float) -> bool:
	t_mirar -= delta
	if t_mirar > 0.0:
		return false
	t_mirar = MIRAR_CADA
	var mejor: Node2D = null
	var mejor_d: float = INF
	for p in e.get_tree().get_nodes_in_group("pickup"):
		if not _es_cristal(p) or p.has_meta("reservado"):
			continue
		var d: float = e.global_position.distance_to(p.global_position)
		if d < mejor_d and _lo_ve(p, d):
			mejor_d = d
			mejor = p
	if mejor == null:
		return false
	objetivo = mejor
	return true


func _es_cristal(p: Node) -> bool:
	return is_instance_valid(p) and p is Node2D and ("item" in p) and p.item is Cristal


func _lo_ve(p: Node2D, d: float) -> bool:
	# EL JEFE NO SALE DE SU SALA: solo los que caen dentro de su radio de merodeo (que es su sala).
	if e.es_boss and p.global_position.distance_to(e._home) > e.wander_radius * MARGEN_SALA_JEFE:
		return false
	if d > OLFATO:
		var dir: Vector2 = (p.global_position - e.global_position) / d
		if d > e.vision_range or absf(e._facing.angle_to(dir)) > deg_to_rad(e.vision_half_angle_deg):
			return false
	# La vista no atraviesa la roca, y el olfato tampoco (como el oido tras la pared, pero sin rebaja: un
	# cristal no hace ruido).
	return e._linea_de_vision_libre(p.global_position)


# El movimiento mientras esta en COMER. Devuelve false cuando ya ha acabado (comido, perdido o mutado):
# el Enemy vuelve entonces a lo suyo.
func paso(delta: float) -> bool:
	if t_transformar >= 0.0:
		e.velocity = Vector2.ZERO
		t_transformar -= delta
		if t_transformar < 0.0:
			return false
		return true
	if t_comer >= 0.0:
		e.velocity = Vector2.ZERO
		t_comer -= delta
		if t_comer < 0.0:
			_tragar()
			return t_transformar >= 0.0
		return true
	if t_red >= 0.0:
		e.velocity = Vector2.ZERO
		t_red -= delta
		if t_red < 0.0:
			_soltar_objetivo()   # el anfitrion no contesto: se rinde
			return false
		return true
	# YENDO. Si alguien lo ha cogido (o se lo ha comido otro) por el camino, se acabo.
	if objetivo == null or not is_instance_valid(objetivo) or not objetivo.is_inside_tree():
		objetivo = null
		return false
	var hacia: Vector2 = objetivo.global_position - e.global_position
	var d: float = hacia.length()
	if d > 0.01:
		e._facing = hacia / d
	if d <= 16.0 + e.radio_extra + ALCANCE_BOCADO:
		e.velocity = Vector2.ZERO
		_reclamar()
		return true
	# Va con ganas (a velocidad de persecucion) y bordeando la roca, como cuando te persigue.
	e.velocity = e._direccion_esquivando(hacia) * e._chase_speed()
	return true


# COGERLO DEL SUELO. Solo: se lo queda ya. En multi el suelo es del anfitrion, y dos bichos (o un bicho y
# un jugador) pueden ir a por el mismo: se pide y gana el primero, como al recogerlo tu.
func _reclamar() -> void:
	if Net.activo and objetivo.has_meta("net_id"):
		objetivo.set_meta("reservado", true)
		t_red = ESPERA_RED_MAX
		Net.suelo.solicitar_comer(int(objetivo.get_meta("net_id")), e)
		return
	var item: Resource = objetivo.recoger()
	objetivo = null
	empezar_a_comer(item as Cristal)


# La respuesta del anfitrion (Net.suelo). null = llego tarde, ya no esta.
func concedido(cri: Cristal) -> void:
	if t_red < 0.0:
		return   # ya se habia rendido
	t_red = -1.0
	objetivo = null
	if cri == null:
		e._state = e.State.RETURN
		return
	empezar_a_comer(cri)


func _soltar_objetivo() -> void:
	if objetivo != null and is_instance_valid(objetivo):
		objetivo.remove_meta("reservado")
	objetivo = null
	t_red = -1.0


func empezar_a_comer(cri: Cristal) -> void:
	if cri == null:
		return
	_bocado = cri
	t_comer = COMER_DUR
	# A falta de su animacion de comer (va con los sprites de mutante, uno a uno), un picoteo: el cuerpo
	# baja y sube dos veces y saltan esquirlas de cristal.
	e.gesto_comer(COMER_DUR)


# EL BOCADO: suma a la carga y tira el dado con la carga nueva.
func _tragar() -> void:
	t_comer = -1.0
	if _bocado == null:
		return
	carga += peso_bocado(_bocado, e.data)
	_bocado = null
	e.carga_cambiada()
	if e.mutante:
		return   # un solo nivel de mutacion por ahora: el que ya muto sigue comiendo, pero no cambia
	if randf() < prob_mutar(carga):
		t_transformar = TRANSFORMACION_DUR
		e.mutar(TRANSFORMACION_DUR)


# Lo que suma un cristal a la carga. Uno de MAS CATEGORIA que lo mas alto que da su especie cuenta doble
# (le sienta mejor); uno DAÑADO, la mitad (los de los cadaveres podridos: mutan, pero despacio).
static func peso_bocado(cri: Cristal, data: EnemyData) -> float:
	var p: float = 1.0
	if data != null and cri.categoria > data.categoria_maxima_natural():
		p *= 2.0
	if cri.calidad == Cristal.Calidad.DANADO:
		p *= 0.5
	return p


static func prob_mutar(c: float) -> float:
	if c <= 0.0:
		return 0.0
	var ultimo: int = PROB_POR_CARGA.size() - 1
	if c >= float(ultimo):
		return 1.0
	var i: int = floori(c)
	return lerpf(PROB_POR_CARGA[i], PROB_POR_CARGA[i + 1], c - float(i))


# Lo que pierde si le cortas lo que estaba haciendo (le pillan en mitad de comer y empieza la pelea).
# El bocado que masticaba se lo traga igual: ya no esta en el suelo y no tiene a donde volver.
func cortar() -> void:
	if t_comer >= 0.0:
		_tragar()
	_soltar_objetivo()
	t_comer = -1.0
