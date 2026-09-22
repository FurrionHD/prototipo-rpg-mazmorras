# ============================================================
#  guardia_pueblo.gd  (class_name GuardiaPueblo)
#  UN GUARDIA DEL PUEBLO. No decide nada: cada fotograma le pregunta a GuardiasPlan donde esta a esta
#  hora (CicloDia.segundo) y lo pinta con el mismo muñeco que el jugador (MunecoJugador).
#
#  DOS FICHAS DE MENTIRA, como el maestro de la Meditacion (GachaRitual.maestro): de PAISANO (ropa de
#  calle, su pelo) y ARMADO (hierro completo, espada larga y escudo normal, lo que pidio el usuario). No
#  estan en la plantilla, no tienen stats ni se guardan: son bolsas de aspecto (el equipo, T3 prístino
#  al +15: ver TIER_EQUIPO). El aspecto de cada uno
#  sale de su numero, asi que es el mismo en todos los PC.
#
#  SOLO CHOCA EL QUE ESTA DE GUARDIA (decision del usuario): un cuerpo estatico con la huella de los pies
#  que se enciende en el puesto. Los que van andando se atraviesan, para que no se atasquen contigo.
# ============================================================
extends Node2D
class_name GuardiaPueblo

const ARMADURA := "res://resources/armor/hierro_completo_%s.tres"
const ESPADA := "res://resources/weapons/espada_larga.tres"
const ESCUDO := "res://resources/shields/escudo_normal.tres"
# EL COLOR DEL EQUIPO: tier 3 prístino al +15 (lo pidio el usuario, "lo mas claro posible"). En la
# paleta eso es ACERO ESPEJO, casi blanco, con el destello metalico a tope (ver PaletaEquipo: el T3
# aclara al mejorar y el brillo sube con las mejoras). La rareza no cambia el dibujo; va apuntada por si
# algun dia lo hace. Con el hierro T2 +0 de antes se veian casi negros.
const TIER_EQUIPO := 3
const MEJORAS_EQUIPO := 15
const RAREZA_EQUIPO := "pristino"

var indice: int = 0

var _muneco: MunecoJugador = null
var _pj_paisano: PersonajeData = null
var _pj_armado: PersonajeData = null
var _armado: bool = false
# Que version lleva montada el muñeco: -1 ninguna, 0 paisano, 1 armado. Aparte de _armado porque un
# guardia que nace escondido en su casa no monta nada hasta que sale; con un simple "ha cambiado" se
# quedaba sin dibujo si al salir iba igual que como se le supuso al nacer.
var _montado: int = -1
var _choque: CollisionShape2D = null


static func crear(i: int) -> GuardiaPueblo:
	var g := GuardiaPueblo.new()
	g.indice = i
	g.name = "Guardia_%d" % i
	return g


func _ready() -> void:
	# Para que las piezas estrechas del pueblo (braseros, farolas, verjas) se ordenen tambien contra el.
	add_to_group(PiezaPueblo.GRUPO_NPC)
	z_as_relative = false
	z_index = 0
	_pj_paisano = paisano(indice)
	_pj_armado = armado(indice)
	_muneco = MunecoJugador.new()
	add_child(_muneco)
	_muneco.z_index = Game.Z_PERSONAJES
	var cuerpo := StaticBody2D.new()
	cuerpo.name = "Choque"
	add_child(cuerpo)
	_choque = CollisionShape2D.new()
	var forma := RectangleShape2D.new()
	forma.size = PoseJugador.HUELLA
	_choque.shape = forma
	_choque.position = Vector2(0.0, PoseJugador.HUELLA_Y)
	_choque.disabled = true
	cuerpo.add_child(_choque)
	_actualizar()


func _process(_delta: float) -> void:
	_actualizar()


func _actualizar() -> void:
	var e: Dictionary = GuardiasPlan.estado(indice, CicloDia.segundo())
	visible = bool(e["visible"])
	position = e["pos"]
	if _choque.disabled == bool(e["solido"]):
		_choque.set_deferred("disabled", not bool(e["solido"]))
	if not visible:
		return
	_armado = bool(e["armado"])
	if _montado != int(_armado):
		_montado = int(_armado)
		var pj: PersonajeData = _pj_armado if _armado else _pj_paisano
		_muneco.montar(pj)
		_muneco.tenir(pj.color, 0.0)
	_muneco.animar(PoseJugador.animacion(e["mira"], 1, bool(e["moviendose"]), false, _armado))


# ============================================================
#  EL ASPECTO
# ============================================================
const PELOS := ["rapado", "corto", "corto", "bob"]
const COLORES_PELO := [Color(0.16, 0.11, 0.08), Color(0.36, 0.22, 0.12), Color(0.55, 0.38, 0.20),
	Color(0.12, 0.12, 0.13), Color(0.70, 0.56, 0.34), Color(0.45, 0.45, 0.46)]
const TORSOS := ["camisa", "tunica", "chaleco"]
const PIERNAS := ["pantalon", "bombacho"]
const COLORES_ROPA := [Color(0.42, 0.34, 0.24), Color(0.30, 0.36, 0.46), Color(0.46, 0.30, 0.26),
	Color(0.34, 0.40, 0.28), Color(0.52, 0.48, 0.40), Color(0.28, 0.26, 0.30)]
const CARAS := ["puntos", "linea"]
const BOCAS := ["recta", "sonrisa"]
const OJOS := [Color(0.28, 0.20, 0.12), Color(0.22, 0.36, 0.52), Color(0.26, 0.40, 0.24)]


# El guardia 'i' vestido de calle. Todo sale de su numero: igual en todos los PC.
static func paisano(i: int) -> PersonajeData:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * (i + 1)
	var pj := PersonajeData.new()
	pj.nombre = "Guardia"
	var ropa: Color = COLORES_ROPA[rng.randi_range(0, COLORES_ROPA.size() - 1)]
	pj.color = ropa
	pj.aspecto = PersonajeData.aspecto_nuevo(ropa)
	pj.poner_pieza("pelo", PELOS[rng.randi_range(0, PELOS.size() - 1)], COLORES_PELO[rng.randi_range(0, COLORES_PELO.size() - 1)])
	pj.poner_pieza("torso", TORSOS[rng.randi_range(0, TORSOS.size() - 1)], ropa)
	pj.poner_pieza("piernas", PIERNAS[rng.randi_range(0, PIERNAS.size() - 1)],
		COLORES_ROPA[rng.randi_range(0, COLORES_ROPA.size() - 1)].darkened(0.2))
	pj.poner_pieza("cara", CARAS[rng.randi_range(0, CARAS.size() - 1)], OJOS[rng.randi_range(0, OJOS.size() - 1)])
	pj.poner_pieza("boca", BOCAS[rng.randi_range(0, BOCAS.size() - 1)], Color(0.45, 0.22, 0.20))
	return pj


# El mismo guardia con el equipo puesto. El tier va en equip_meta, que es de donde JugadorSprites saca
# la paleta (ver _tier_de); no se pasa por Game.meta_de, que CREA entradas en el baul del jugador.
static func armado(i: int) -> PersonajeData:
	var pj: PersonajeData = paisano(i)
	for slot in ["casco", "pecho", "manos", "pantalones", "botas"]:
		var pieza: Resource = load(ARMADURA % slot)
		if pieza != null:
			pj.set("equipped_" + slot, pieza)
			pj.equip_meta[slot] = _meta_equipo()
	pj.equipped_main = load(ESPADA)
	pj.equip_meta["main"] = _meta_equipo()
	pj.equipped_off = load(ESCUDO)
	pj.equip_meta["off"] = _meta_equipo()
	return pj


# La meta de cada pieza. JugadorSprites suma los valores de 'mejoras' para sacar el +N, asi que da igual
# en que stat vayan: aqui van todas en una.
static func _meta_equipo() -> Dictionary:
	return {"tier": TIER_EQUIPO, "rareza": RAREZA_EQUIPO, "mejoras": {"guardia": MEJORAS_EQUIPO}}
