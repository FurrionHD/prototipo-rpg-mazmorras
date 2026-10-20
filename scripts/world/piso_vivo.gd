# ============================================================
#  PISO VIVO: la raiz de un sitio jugable (un piso, la arena o el pueblo)
# ============================================================
# FASE 2 DEL PLAN DE OPTIMIZACION (19/10): un solo servidor llevara MUCHOS pisos a la vez, cada uno en su mundo. Hasta
# ahora cada Godot tenia UN piso vivo y medio juego lo daba por hecho: el grupo "enemy" eran los enemigos DEL piso,
# Game.current_floor era EL piso, get_first_node_in_group("dungeon_floor") era EL suelo. Con dos pisos en el mismo
# arbol eso mezcla los enemigos de uno con los del otro.
#
# Esto es lo que cada cosa pregunta en vez de mirar globales: "¿de que piso soy?" (PisoVivo.de(self)) y luego a SU piso
# por sus grupos (nodos / primero / lista_fisica) y su numero.
#
# MIENTRAS HAYA UN SOLO PISO VIVO EN EL PROCESO (todos los clientes; tambien jugando solo) todo devuelve lo mismo que
# antes, sin coste: los grupos son los del arbol entero y el numero es Game.current_floor. Solo con varios (el servidor)
# se filtra por quien cuelga de cada piso.
#
# Va en la raiz de main.tscn (pisos y arena: la escena es la misma) y el pueblo hereda de ella (town.gd).
# Pruebas: tools/unitarias/test_piso_vivo.gd
class_name PisoVivo
extends Node2D

const GRUPO := &"piso_vivo"

static var _vivos: Array[PisoVivo] = []

# EL SERVIDOR (la sala, etapa 2) lo enciende: cada pregunta va SIEMPRE a cada piso, aunque solo lleve uno. Sin el, con
# un piso montado la sala caeria en "un sitio por maquina" y miraria Net._mi_lugar, que en ella es "sala".
static var por_piso: bool = false

# El numero de este piso cuando lo fija quien lo monta (el servidor). -1 = el de Game.current_floor, que es lo de
# siempre en un cliente: el piso se reutiliza al bajar (dungeon_floor.regenerar) y Game.fijar_piso es quien lo cambia.
var numero_fijo: int = -1
var numero: int:
	get:
		return numero_fijo if numero_fijo >= 0 else Game.current_floor

# EL LUGAR PARA LA RED ("pueblo", "piso:N") y SI SOY SU DUEÑO (quien simula sus enemigos). En un cliente son los de la
# maquina (Net._mi_lugar, Net._soy_dueno): un sitio y un dueño por proceso. El servidor los fija en cada piso.
var lugar_fijo: String = ""
var lugar: String:
	get:
		return lugar_fijo if lugar_fijo != "" else Net._mi_lugar
var dueno_fijo: int = -1   # -1 = el de la maquina; 0 = no; 1 = si
var soy_dueno: bool:
	get:
		return Net._soy_dueno if dueno_fijo < 0 else dueno_fijo == 1

# EL NUMERO PARA LA RED (el de su lugar: 1000 en la arena, Game.PISO_ARENA) y si es la arena. Sin lugar fijado, los de la
# maquina (Game.piso_de_red, Game.es_arena), como siempre. En la arena 'numero' es el piso de juego que imita.
var piso_red: int:
	get:
		if lugar_fijo.begins_with("piso:"):
			return int(lugar_fijo.substr(5))
		return Game.piso_de_red()
var es_arena: bool:
	get:
		if lugar_fijo != "":
			return piso_red == Game.PISO_ARENA
		return Game.es_arena()

# Las listas por fotograma de fisica: grupo -> [fotograma, Array]. Ver lista_fisica.
var _listas: Dictionary = {}


func _enter_tree() -> void:
	add_to_group(GRUPO)
	if not _vivos.has(self):
		_vivos.append(self)


func _exit_tree() -> void:
	_vivos.erase(self)
	_listas.clear()


# ------------------------------------------------------------
#  ¿DE QUE PISO ES ESTE NODO?
# ------------------------------------------------------------
# Sube por el arbol hasta su piso. Lo que no cuelga de ninguno (Game, los menus, la pantalla de combate, que va en
# su propia capa) se queda con el UNICO piso vivo si solo hay uno; con varios no se puede adivinar: null.
static func de(n: Node) -> PisoVivo:
	var p: Node = n
	while p != null:
		if p is PisoVivo:
			return p as PisoVivo
		p = p.get_parent()
	return null if por_piso else unico()


# El piso vivo si solo hay uno (lo normal fuera del servidor); null si no hay ninguno o hay varios.
static func unico() -> PisoVivo:
	return _vivos[0] if _vivos.size() == 1 else null


static func hay_varios() -> bool:
	return _vivos.size() > 1


# ¿Va esta maquina con "un sitio por proceso" (todo cliente, tambien jugando solo)? Entonces las preguntas son las de
# siempre, a Net y al arbol entero. En el servidor (por_piso) o con varios pisos vivos, NO.
static func un_sitio() -> bool:
	return not por_piso and _vivos.size() <= 1


static func vivos() -> Array[PisoVivo]:
	return _vivos


# LO MISMO, DESDE UN NODO CUALQUIERA: su piso, o el arbol entero si no es de ninguno (pruebas y visores que montan
# enemigos sueltos, sin main.tscn). Es lo que usan las piezas que antes llamaban a get_tree() a pelo.
static func nodos_de(n: Node, grupo: StringName) -> Array[Node]:
	var p: PisoVivo = de(n)
	return p.nodos(grupo) if p != null else n.get_tree().get_nodes_in_group(grupo)


static func primero_de(n: Node, grupo: StringName) -> Node:
	var p: PisoVivo = de(n)
	return p.primero(grupo) if p != null else n.get_tree().get_first_node_in_group(grupo)


# El numero del piso de 'n' (Game.current_floor si no es de ninguno).
static func numero_de(n: Node) -> int:
	var p: PisoVivo = de(n)
	return p.numero if p != null else Game.current_floor


# Donde se cuelga lo que nace en el piso de 'n' (marcas, drops, proyectiles): su piso, o la escena actual.
static func raiz_de(n: Node) -> Node:
	var p: PisoVivo = de(n)
	return p if p != null else n.get_tree().current_scene


# ------------------------------------------------------------
#  POR LUGAR: lo que llega por red dice A QUE SITIO va ("piso:N")
# ------------------------------------------------------------
# Con UN piso vivo (o ninguno) es EXACTAMENTE lo de antes: Net._mi_lugar == lugar, Net._soy_dueno y current_scene,
# tambien en mitad de un cambio de escena (el lugar cambia antes de que exista la escena nueva y eso no se toca aqui).
# Con varios, el piso que lleva ese lugar.
static func del_lugar(l: String) -> PisoVivo:
	if un_sitio():
		return unico() if Net._mi_lugar == l else null
	for p in _vivos:
		if p.lugar == l:
			return p
	return null


# ¿Llevo yo ese lugar? (antes: Net._mi_lugar == lugar)
static func lleva(l: String) -> bool:
	if un_sitio():
		return Net._mi_lugar == l
	return del_lugar(l) != null


# ¿Llevo ese lugar Y soy su dueño? (antes: Net._mi_lugar == lugar and Net._soy_dueno)
static func dueno_de(l: String) -> bool:
	if un_sitio():
		return Net._mi_lugar == l and Net._soy_dueno
	var p: PisoVivo = del_lugar(l)
	return p != null and p.soy_dueno


# ¿Llevo ese lugar SIN ser su dueño (lo espejo)? (antes: Net._mi_lugar == lugar and not Net._soy_dueno)
static func espejo_de(l: String) -> bool:
	if un_sitio():
		return Net._mi_lugar == l and not Net._soy_dueno
	var p: PisoVivo = del_lugar(l)
	return p != null and not p.soy_dueno


# ¿Soy dueño del piso de este nodo? (antes: Net._soy_dueno a secas, mirando un bicho o un drop concreto)
static func dueno_del_nodo(n: Node) -> bool:
	if un_sitio():
		return Net._soy_dueno
	var p: PisoVivo = de(n)
	return p != null and p.soy_dueno


# ¿Soy dueño de ALGUN piso? (antes: Net._soy_dueno en lo que corre una vez por proceso, como difundir posiciones)
static func dueno_de_alguno() -> bool:
	if un_sitio():
		return Net._soy_dueno
	for p in _vivos:
		if p.soy_dueno:
			return true
	return false


# Donde se cuelga lo que llega por red para ese lugar (enemigos, drops). Con un piso: current_scene, lo de antes.
static func raiz_del_lugar(l: String, arbol: SceneTree) -> Node:
	if un_sitio():
		return arbol.current_scene
	return del_lugar(l)


# ------------------------------------------------------------
#  SUS GRUPOS
# ------------------------------------------------------------
# Los nodos de 'grupo' que son de este piso. Con un solo piso vivo, el grupo entero tal cual (lo mismo que antes).
func nodos(grupo: StringName) -> Array[Node]:
	var todos: Array[Node] = get_tree().get_nodes_in_group(grupo)
	if un_sitio():
		return todos
	var out: Array[Node] = []
	for n in todos:
		if is_ancestor_of(n):
			out.append(n)
	return out


func primero(grupo: StringName) -> Node:
	if un_sitio():
		return get_tree().get_first_node_in_group(grupo)
	for n in get_tree().get_nodes_in_group(grupo):
		if is_ancestor_of(n):
			return n
	return null


# UNA lista por fotograma de fisica y por piso (optimizacion 1B: los enemigos la piden varias veces por fotograma).
# 'filtro' (opcional) decide quien entra; 'clave' separa dos listas del mismo grupo con filtros distintos (si no, la
# segunda se llevaria la de la primera). Quien la use solo la RECORRE y mira is_instance_valid: al cambiar de escena
# se libera todo de golpe dentro del mismo fotograma de fisica (por eso, si algo de dentro ya no vale, se rehace).
func lista_fisica(grupo: StringName, filtro: Callable = Callable(), clave: StringName = &"") -> Array[Node2D]:
	var k: StringName = clave if clave != &"" else grupo
	var f: int = Engine.get_physics_frames()
	var hecha: Array = _listas.get(k, [])
	if not hecha.is_empty() and int(hecha[0]) == f:
		var lista: Array[Node2D] = hecha[1]
		var vale: bool = true
		for n in lista:
			if not is_instance_valid(n):
				vale = false
				break
		if vale:
			return lista
	var out: Array[Node2D] = []
	for n in nodos(grupo):
		if is_instance_valid(n) and n is Node2D and (not filtro.is_valid() or filtro.call(n)):
			out.append(n as Node2D)
	_listas[k] = [f, out]
	return out
