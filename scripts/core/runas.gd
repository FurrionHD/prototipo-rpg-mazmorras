# ============================================================
#  runas.gd  (class_name Runas)
#  LAS RUNAS DE LOS MUTANTES (08/10/2026, fase 5 del plan de mecanicas). Una pieza (arma, varita, escudo o armadura)
#  puede llevar UN set (RunaSetData) y hasta MAX_SUBS sub-stats. Todo vive en su meta (item_meta / equip_meta, el mismo
#  dict): meta["runas"] = {"set": id, "subs": [{"s": clave, "v": valor}, ...]}. La partida guarda la meta entera; por
#  la red viaja en Game.serializar_equipo.
#
#  REGLAS (decididas por el usuario el 08/10):
#   - la pieza empieza en 0 sub-stats y cada runa le pone UNA, hasta 4 (al estilo WuWa);
#   - una misma sub-stat puede salir hasta 2 veces; los elementos son libres (fuego y agua juntos, vale);
#   - el valor sale CONTINUO dentro de su rango y SESGADO HACIA LO BAJO (el tope sale poco);
#   - un arma a DOS MANOS lleva los valores x2 (ocupa las dos ranuras);
#   - las armas MAGICAS (baston, varita) tienen su propia lista: Daño magico en vez de Ataque, y el critico magico;
#   - el ESCUDO lleva sub-stats de armadura pero cuenta como pieza de ARMA para los sets (es la secundaria);
#   - critico, penetracion, evasion, resist. a criticos y resist. a un elemento son FIJOS; la velocidad sube en curva
#     con el tier; lo demas escala con el TIER DE LA PIEZA.
# ============================================================
extends RefCounted
class_name Runas

const MAX_SUBS := 4
const MAX_IGUALES := 2
# Sesgo hacia lo bajo: valor = min + (max - min) x azar^SESGO.
const SESGO := 1.5
# Lo que escala con el tier: +50 % por tier por encima del 1 (T2 x1,5, T3 x2). PROVISIONAL.
const ESCALA_TIER := 0.5
# La velocidad: tier_mult^VEL_CURVA (T2 x1,6, T3 x2,6): en curva porque en T3 las stats suben mucho mas.
const VEL_CURVA := 0.6
# Probabilidad de que caiga la runa de un enemigo, por grado de mutacion (0 = normal).
const DROP_RUNA := [0.005, 0.30, 0.70]

enum Lista { ARMA_FISICA, ARMA_MAGICA, ARMADURA }

const ELEMENTOS := ["fuego", "agua", "rayo", "luz", "oscuridad"]
const ELEM_ID := {"fuego": 1, "agua": 2, "rayo": 3, "luz": 4, "oscuridad": 5}   # Elementos.Elemento

# clave -> nombre, rango T1 [min, max], escala ("fijo" | "tier" | "vel"), y peso de aparicion por lista
# [ARMA_FISICA, ARMA_MAGICA, ARMADURA] (0 = no sale ahi). Los de elemento se generan abajo (_subs).
const _BASE := {
	"ataque_pct": ["Ataque", 0.03, 0.06, "tier", [100, 0, 0]],
	"dano_magico_pct": ["Daño mágico", 0.03, 0.06, "tier", [0, 100, 0]],
	"crit": ["Probabilidad de crítico", 0.03, 0.06, "fijo", [50, 0, 0]],
	"crit_dmg": ["Daño crítico", 0.06, 0.12, "tier", [50, 0, 0]],
	"crit_mag": ["Probabilidad de crítico mágico", 0.03, 0.06, "fijo", [0, 50, 0]],
	"crit_dmg_mag": ["Daño crítico mágico", 0.06, 0.12, "tier", [0, 50, 0]],
	"dano_hab": ["Daño de habilidades", 0.04, 0.08, "tier", [60, 60, 0]],
	"eficacia": ["Eficacia", 0.04, 0.08, "tier", [60, 60, 0]],
	"penetracion": ["Ignora Defensa", 0.08, 0.12, "fijo", [50, 0, 0]],
	"dano_jefes": ["Daño a mutantes y jefes", 0.05, 0.10, "tier", [40, 40, 0]],
	"velocidad": ["Velocidad", 0.10, 0.20, "vel", [30, 30, 30]],
	"dano_todos": ["Daño de todos los elementos", 0.04, 0.08, "tier", [5, 5, 0]],
	"final_fis": ["Daño final físico", 0.02, 0.04, "tier", [3, 0, 0]],
	"final_mag": ["Daño final mágico", 0.02, 0.04, "tier", [0, 3, 0]],
	"vida_pct": ["Vida", 0.03, 0.06, "tier", [0, 0, 100]],
	"defensa_pct": ["Defensa", 0.03, 0.06, "tier", [0, 0, 100]],
	"mdef_pct": ["Defensa mágica", 0.03, 0.06, "tier", [0, 0, 100]],
	"resist_estados": ["Resistencia a estados", 0.04, 0.08, "tier", [0, 0, 70]],
	"resist_crit": ["Resistencia a críticos", 0.02, 0.04, "fijo", [0, 0, 50]],
	"cura_recibida": ["Curación recibida", 0.04, 0.08, "tier", [0, 0, 50]],
	"menos_dot": ["Menos daño con el tiempo", 0.04, 0.08, "tier", [0, 0, 50]],
	"evasion": ["Esquiva", 0.01, 0.03, "fijo", [0, 0, 40]],
}
# Daño de UN elemento (arma) y resistencia a UN elemento (armadura): el peso de 60 repartido entre los cinco.
const PESO_ELEM_DANO := 12
const PESO_ELEM_RES := 12

static var _cache_subs: Dictionary = {}


# El catalogo entero: {clave: {nombre, min, max, escala, pesos}}.
static func subs() -> Dictionary:
	if not _cache_subs.is_empty():
		return _cache_subs
	for k in _BASE:
		var b: Array = _BASE[k]
		_cache_subs[k] = {"nombre": b[0], "min": b[1], "max": b[2], "escala": b[3], "pesos": b[4]}
	for e in ELEMENTOS:
		_cache_subs["dano_" + e] = {"nombre": "Daño de %s" % e.capitalize(), "min": 0.05, "max": 0.10, "escala": "tier",
			"pesos": [PESO_ELEM_DANO, PESO_ELEM_DANO, 0]}
		_cache_subs["res_" + e] = {"nombre": "Resistencia a %s" % e.capitalize(), "min": 0.03, "max": 0.06, "escala": "fijo",
			"pesos": [0, 0, PESO_ELEM_RES]}
	return _cache_subs


static func nombre_sub(clave: String) -> String:
	return str(subs().get(clave, {}).get("nombre", clave))

# EL NOMBRE DE LAS FICHAS: cabe en la columna de etiquetas (200 desde el 06/11, medido) para que el valor quede ALINEADO con los
# de encima (lo pidio el usuario: "todo en la misma linea"). Desde el pase de textos van COMPLETOS (sin "Resist.",
# "crít.", que el jefe pidio nombres enteros y una columna mas ancha).
const _CORTOS := {
	"crit": "Probabilidad de crítico", "crit_mag": "Probabilidad de crítico mágico", "crit_dmg_mag": "Daño crítico mágico",
	"dano_hab": "Daño de habilidades", "dano_jefes": "Daño a mutantes y jefes", "dano_todos": "Daño elemental",
	"resist_estados": "Resistencia a estados", "resist_crit": "Resistencia a críticos", "menos_dot": "Menos daño con el tiempo",
	"cura_recibida": "Curación recibida",
}

static func nombre_corto(clave: String) -> String:
	if _CORTOS.has(clave):
		return _CORTOS[clave]
	return nombre_sub(clave)


# ------------------------------------------------------------
#  QUE PIEZA ES
# ------------------------------------------------------------
static func admite_runas(item: Resource) -> bool:
	return item is WeaponData or item is WandData or item is ShieldData or item is ArmorData

static func es_magica(item: Resource) -> bool:
	return item is WandData or (item is WeaponData and int((item as WeaponData).tipo) == WeaponData.Tipo.BASTON)

static func lista_de(item: Resource) -> int:
	if item is ArmorData or item is ShieldData:
		return Lista.ARMADURA
	return Lista.ARMA_MAGICA if es_magica(item) else Lista.ARMA_FISICA

# El tipo de SET que admite: armas, varitas y escudos los de arma; armaduras los de armadura.
static func tipo_set_de(item: Resource) -> int:
	return RunaSetData.Tipo.ARMADURA if item is ArmorData else RunaSetData.Tipo.ARMA

static func dos_manos(item: Resource) -> bool:
	return item is WeaponData and bool((item as WeaponData).dos_manos)


# ------------------------------------------------------------
#  LOS SETS
# ------------------------------------------------------------
const RUTAS_SETS := ["res://resources/runas/set_slime.tres", "res://resources/runas/set_profundo.tres",
	"res://resources/runas/set_rey.tres", "res://resources/runas/set_fuego.tres",
	"res://resources/runas/set_venenoso.tres", "res://resources/runas/set_abisal.tres",
	"res://resources/runas/set_rata.tres", "res://resources/runas/set_rey_rata.tres", "res://resources/runas/set_jabali.tres",
	"res://resources/runas/set_trent.tres", "res://resources/runas/set_arana.tres",
	"res://resources/runas/set_escarabajo.tres", "res://resources/runas/set_ciempies.tres",
	"res://resources/runas/set_segadora.tres"]
static var _sets: Array = []

static func sets() -> Array:
	if _sets.is_empty():
		for r in RUTAS_SETS:
			var s: RunaSetData = load(r)
			if s != null:
				_sets.append(s)
	return _sets

static func set_por_id(id: StringName) -> RunaSetData:
	for s in sets():
		if (s as RunaSetData).id == id:
			return s
	return null


# ------------------------------------------------------------
#  LA META DE UNA PIEZA
# ------------------------------------------------------------
static func runas_de(item: Resource) -> Dictionary:
	if item == null:
		return {}
	# Solo LEER: meta_de fabrica una meta por defecto si no la hay, y las fichas preguntan tambien por copias de
	# escaparate (tienda, vitrinas) que no deben dejar meta colgando.
	return Game.meta_si_hay(item).get("runas", {})

static func set_de(item: Resource) -> RunaSetData:
	var r: Dictionary = runas_de(item)
	return set_por_id(StringName(str(r.get("set", "")))) if not r.is_empty() else null

static func subs_de(item: Resource) -> Array:
	return runas_de(item).get("subs", [])


# ------------------------------------------------------------
#  TIRADAS
# ------------------------------------------------------------
# El valor de 'clave' para una pieza de 'tier' (x2 si es a dos manos), sesgado hacia lo bajo.
static func tirar_valor(clave: String, tier: int, dos_m: bool = false, azar: float = -1.0) -> float:
	var d: Dictionary = subs().get(clave, {})
	if d.is_empty():
		return 0.0
	var r: float = randf() if azar < 0.0 else azar
	var v: float = float(d["min"]) + (float(d["max"]) - float(d["min"])) * pow(r, SESGO)
	match str(d["escala"]):
		"tier":
			v *= 1.0 + ESCALA_TIER * float(maxi(tier, 1) - 1)
		"vel":
			v *= pow(Game.tier_mult(tier), VEL_CURVA)
	return v * (2.0 if dos_m else 1.0)

# Elige una sub-stat al azar por los pesos de la lista de la pieza, sin pasar de MAX_IGUALES. 'excluir' = una clave
# que no puede salir (la que se esta cambiando).
static func elegir_sub(item: Resource, excluir: String = "") -> String:
	var lista: int = lista_de(item)
	var cuenta: Dictionary = {}
	for s in subs_de(item):
		cuenta[s["s"]] = int(cuenta.get(s["s"], 0)) + 1
	if excluir != "":
		cuenta[excluir] = int(cuenta.get(excluir, 0)) - 1   # la que se va deja su sitio libre...
	var total: float = 0.0
	var cand: Array = []
	for k in subs():
		if k == excluir:
			continue   # ...pero no puede volver a salir ella misma
		var p: float = float(subs()[k]["pesos"][lista])
		if p <= 0.0 or int(cuenta.get(k, 0)) >= MAX_IGUALES:
			continue
		cand.append([k, p])
		total += p
	if cand.is_empty():
		return ""
	var r: float = randf() * total
	for c in cand:
		r -= float(c[1])
		if r <= 0.0:
			return str(c[0])
	return str(cand[-1][0])


# ------------------------------------------------------------
#  LO QUE CUESTA Y SI LO TIENES (del baul del hogar, como la herreria)
# ------------------------------------------------------------
static func puede_activar(item: Resource, s: RunaSetData) -> bool:
	return admite_runas(item) and s != null and int(s.tipo) == tipo_set_de(item) and runas_de(item).is_empty() \
		and Game.unidades_material_en_hogar(s.material) >= s.coste_material \
		and Game.nucleos_en_hogar(s.nucleo) >= s.coste_nucleo

static func runas_en_hogar(s: RunaSetData) -> int:
	return Game.nucleos_en_hogar(s.runa) if s != null and s.runa != null else 0


# ------------------------------------------------------------
#  LAS ACCIONES DEL TALLER. Devuelven "" si salio bien o el motivo si no.
# ------------------------------------------------------------
static func activar(item: Resource, s: RunaSetData) -> String:
	if not puede_activar(item, s):
		return "Te falta material o la pieza ya tiene un set."
	Game._consumir_unidades(s.material, s.coste_material)
	Game._consumir_nucleos(s.nucleo, s.coste_nucleo)
	Game.meta_de(item)["runas"] = {"set": String(s.id), "subs": []}
	return ""

static func _gastar_runa(item: Resource) -> String:
	var s: RunaSetData = set_de(item)
	if s == null:
		return "La pieza no tiene set."
	if runas_en_hogar(s) < 1:
		return "No te quedan runas de ese set."
	Game._consumir_nucleos(s.runa, 1)
	return ""

static func subir(item: Resource) -> String:
	if subs_de(item).size() >= MAX_SUBS:
		return "Ya tiene %d atributos secundarios." % MAX_SUBS
	var clave: String = elegir_sub(item)
	if clave == "":
		return "No queda ningún atributo secundario posible."
	var err: String = _gastar_runa(item)
	if err != "":
		return err
	subs_de(item).append({"s": clave, "v": tirar_valor(clave, _tier(item), dos_manos(item))})
	return ""

static func cambiar(item: Resource, i: int) -> String:
	var lista: Array = subs_de(item)
	if i < 0 or i >= lista.size():
		return "Elige un atributo secundario."
	var clave: String = elegir_sub(item, str(lista[i]["s"]))
	if clave == "":
		return "No hay otro atributo secundario posible."
	var err: String = _gastar_runa(item)
	if err != "":
		return err
	lista[i] = {"s": clave, "v": tirar_valor(clave, _tier(item), dos_manos(item))}
	return ""

static func retirar(item: Resource, i: int) -> String:
	var lista: Array = subs_de(item)
	if i < 0 or i >= lista.size():
		return "Elige un atributo secundario."
	var err: String = _gastar_runa(item)
	if err != "":
		return err
	var clave: String = str(lista[i]["s"])
	lista[i] = {"s": clave, "v": tirar_valor(clave, _tier(item), dos_manos(item))}
	return ""

# Deja la pieza limpia. Las runas gastadas NO se devuelven (decision del plan).
static func desencantar(item: Resource) -> String:
	if runas_de(item).is_empty():
		return "La pieza no tiene runas."
	Game.meta_de(item).erase("runas")
	return ""

static func _tier(item: Resource) -> int:
	return int(Game.meta_de(item).get("tier", 1))


# ------------------------------------------------------------
#  TEXTOS (generados de los datos, sin numeros a mano)
# ------------------------------------------------------------
static func valor_txt(clave: String, v: float) -> String:
	if clave == "velocidad":
		return "+" + ("%.2f" % v).replace(".", ",")
	return "+%s %%" % num_txt(v * 100.0)

# UN NUMERO PARA LEER (06/11, pase de textos): con coma y sin el ",0" que sobra ("12 %", no "12.0 %").
static func num_txt(x: float) -> String:
	if absf(x - roundf(x)) < 0.05:
		return str(roundi(x))
	return ("%.1f" % x).replace(".", ",")

# Un % de un parametro (0.25 -> "25 %").
static func _pct(p: Dictionary, k: String, def: float) -> String:
	return "%s %%" % num_txt(float(p.get(k, def)) * 100.0)

# DISTANCIAS SIN PX (06/11, decision del jefe: en palabras, sin frases forzadas). Un cuerpo de personaje son ~24 px.
# 'de_el' = la frase va del portador ("pegados a él") y no del objetivo ("pegado al objetivo").
static func cerca_txt(px: float, de_el: bool) -> String:
	if px <= 45.0:
		return "pegados a él" if de_el else "pegado al objetivo"
	if px <= 90.0:
		return "cerca de él" if de_el else "cerca del objetivo"
	return "a media distancia de él" if de_el else "a media distancia del objetivo"

static func tramo_txt(px: float) -> String:
	return "un tramo corto" if px <= 60.0 else "un buen tramo"

static func _turnos(n: int) -> String:
	return "%d turno%s" % [n, "" if n == 1 else "s"]

static func sub_txt(s: Dictionary) -> String:
	return "%s %s" % [nombre_sub(str(s["s"])), valor_txt(str(s["s"]), float(s["v"]))]

# DE CUANTO A CUANTO puede salir 'clave' en esta pieza (su tier y si es a dos manos): "3 – 6 %". Lo enseña el
# Taller junto a cada sub-stat, para saber si merece la pena re-tirarla.
static func rango_txt(clave: String, item: Resource) -> String:
	var lo: float = tirar_valor(clave, _tier(item), dos_manos(item), 0.0)
	var hi: float = tirar_valor(clave, _tier(item), dos_manos(item), 1.0)
	if clave == "velocidad":
		return ("%.2f – %.2f" % [lo, hi]).replace(".", ",")
	return "%s – %s %%" % [num_txt(lo * 100.0), num_txt(hi * 100.0)]

static func bonus_txt(b: Dictionary) -> String:
	var partes: PackedStringArray = []
	for k in b:
		partes.append("%s %s" % [nombre_sub(str(k)), valor_txt(str(k), float(b[k]))])
	return ", ".join(partes)

# Lo que hace el efecto especial de un set, con sus numeros.
# (06/11, pase de textos al estilo de las fichas de Honkai: Star Rail) Se habla del PORTADOR; cada % dice DE QUE es; lo
# que solo mejora algo que ya existe lo dice ("que ya pueden causar..."); y los limites van en su propia frase.
# Contrastado contra el codigo, no de memoria (ver docs/guia_textos.md).
static func efecto_txt(s: RunaSetData) -> String:
	var p: Dictionary = s.params
	match s.efecto:
		&"masa":
			return "La primera vez en cada combate que el portador recibe un golpe que le inflige un %s o más de su vida máxima, ese golpe le inflige un %s menos de daño (el daño con el tiempo no cuenta). Además, los enemigos que atacan al portador cuerpo a cuerpo tienen un %s de probabilidad base de quedar Pegajosos." % [
				_pct(p, "umbral", 0.2), _pct(p, "reduce", 0.4), _pct(p, "pegajoso", 0.25)]
		&"marea":
			return "Al empezar el combate, el portador obtiene un escudo de agua que absorbe daño equivalente al %s de su vida máxima (no absorbe el daño con el tiempo). Mientras el escudo dure, el portador no puede quedar Lento ni sufrir Congelación. Cuando el escudo se rompe, el enemigo que lo rompió queda Mojado." % [
				_pct(p, "escudo", 0.15)]
		&"corona":
			return "Los aliados que están cuerpo a cuerpo con el portador reciben un %s menos de daño. Cuando un aliado baja del %s de su vida máxima, el portador provoca a todos los enemigos durante %s. Este efecto solo se puede activar 1 vez por combate." % [
				_pct(p, "aliados", 0.1), _pct(p, "umbral", 0.3), _turnos(int(p.get("turnos", 1)))]
		&"ignicion":
			return "Los ataques y habilidades del portador que ya pueden causar Quemadura suman un %s a su probabilidad base de causarla. El daño de las Quemaduras que causa el portador aumenta en un %s." % [
				_pct(p, "prob", 0.10), _pct(p, "dano", 0.25)]
		&"alcantarilla":
			return "Los ataques y habilidades del portador que ya pueden causar Sangrado suman un %s a su probabilidad base de causarlo. Además, los Sangrados que causa el portador infligen en cada turno un daño adicional equivalente al %s del daño del golpe que los causó." % [
				_pct(p, "prob", 0.10), _pct(p, "dano", 0.05)]
		&"hilo_conductor":
			return "Cada golpe del portador tiene un %s de probabilidad de rebotar a otro enemigo que esté %s. El rebote inflige como Daño de Rayo un %s del daño de ese golpe y tiene un 100 %% de probabilidad base de dejar Electrizado al enemigo alcanzado. Si el objetivo ya está Electrizado, el rebote se produce siempre." % [
				_pct(p, "prob", 0.25), cerca_txt(float(p.get("radio", 60.0)), false), _pct(p, "dano", 0.4)]
		&"musgo_viejo":
			return "Los ataques en área (círculos, conos y ataques a varios objetivos) infligen al portador un %s menos de daño. Este efecto no funciona mientras el portador está Quemado." % [
				_pct(p, "reduce", 0.2)]
		&"dos_mentes":
			return "La primera vez que el portador fuera a quedar Aturdido, no queda Aturdido. Este efecto se puede volver a activar tras %s del portador." % [
				_turnos(int(p.get("turnos", 4)))]
		&"campo_magnetico":
			return "Cada %s del portador, la barra de turno de los enemigos que estén %s retrocede un %s." % [
				_turnos(int(p.get("cada", 3))), cerca_txt(float(p.get("radio", 40.0)), true), _pct(p, "barra", 0.25)]
		&"ambar":
			return "Al empezar el combate, el portador obtiene una capa de ámbar que absorbe daño equivalente al %s de su vida máxima. Si se rompe, vuelve a aparecer completa tras %s del portador." % [
				_pct(p, "capa", 0.08), _turnos(int(p.get("turnos", 3)))]
		&"sangre_real":
			return "El daño que inflige el portador aumenta en un %s por cada acumulación de Sangrado que tengan los enemigos del combate (se suman las de todos), hasta un máximo de un %s." % [
				_pct(p, "por_carga", 0.02), _pct(p, "max", 0.16)]
		&"miasma":
			return "El daño que inflige el portador a un enemigo aumenta en un %s por cada acumulación de Veneno que tenga ese enemigo, hasta un máximo de %d acumulaciones. Además, los Venenos que causa el portador duran %s más." % [
				_pct(p, "por_carga", 0.04), int(p.get("max", 5)), _turnos(int(p.get("turnos", 1)))]
		&"filo_aire":
			return "Los ataques con arma del portador se alargan con un corte de viento: los conos y los círculos llegan un %s más lejos, las líneas son un %s más largas y los ataques a un solo objetivo siguen %s por detrás de él. Los enemigos a los que solo alcanza el corte reciben como Daño de Viento un %s del daño que esa habilidad o ataque les habría infligido. Se activa 1 vez por habilidad. No funciona con la magia." % [
				_pct(p, "mas", 0.3), _pct(p, "linea", 0.4), tramo_txt(float(p.get("detras", 50.0))), _pct(p, "dano", 0.3)]
		&"cielo":
			return "El Daño de Luz y el Daño de Oscuridad del portador aumentan en un %s. Cuando el portador asesta un golpe crítico, tiene un %s de probabilidad base de causar Ceguera al objetivo." % [
				_pct(p, "dano", 0.20), _pct(p, "ciego", 0.20)]
	return ""

static func descripcion_set(s: RunaSetData) -> String:
	if s.tipo == RunaSetData.Tipo.ARMA:
		return "2 piezas: %s" % efecto_txt(s) if s.bonus_2p.is_empty() \
			else "2 piezas: %s. %s" % [bonus_txt(s.bonus_2p), efecto_txt(s)]
	return "2 piezas: %s.\n5 piezas: %s" % [bonus_txt(s.bonus_2p), efecto_txt(s)]

# Las filas que enseñan las fichas de una pieza (vacio si no lleva runas).
static func filas(item: Resource) -> Array:
	var out: Array = []
	var s: RunaSetData = set_de(item)
	if s == null:
		return out
	out.append(["Set de runas", s.nombre])
	for sub in subs_de(item):
		out.append(["  " + nombre_sub(str(sub["s"])), valor_txt(str(sub["s"]), float(sub["v"]))])
	return out


# ------------------------------------------------------------
#  EN EL COMBATE: suma lo que lleva puesto y se lo pone al combatiente. Lo llama Game._aplicar_loadout (y la vida,
#  crear_player_combatant via aplicar_vida). Un solo sitio.
# ------------------------------------------------------------
const SLOTS_ARMA := ["equipped_main", "equipped_off"]
const SLOTS_ARMADURA := ["equipped_casco", "equipped_pecho", "equipped_manos", "equipped_pantalones", "equipped_botas"]

const _SLOTS_TODOS := ["equipped_main", "equipped_off",   # SLOTS_ARMA + SLOTS_ARMADURA, sin juntarlas en cada llamada
	"equipped_casco", "equipped_pecho", "equipped_manos", "equipped_pantalones", "equipped_botas"]

# {clave: suma} de las sub-stats de todo lo puesto + los bonus de 2 piezas de los sets activos.
# EN UNA PASADA (optimizacion 1B, 16/10): la vida maxima lo pregunta por cada personaje en cada fotograma (las barras),
# y antes recorria el equipo dos veces (subs y luego sets_activos) leyendo la meta de cada pieza tres veces. Mismo
# resultado que sumar subs_de de cada pieza + bonus_2p de cada set con 2 piezas o mas.
static func totales(p: PersonajeData) -> Dictionary:
	var t: Dictionary = {}
	var cuenta: Dictionary = {}   # RunaSetData -> piezas (dos manos cuenta 2), como sets_activos
	for r in _SLOTS_TODOS:
		var it: Resource = p.get(r)
		if it == null or not admite_runas(it):
			continue
		var ru: Dictionary = runas_de(it)
		if ru.is_empty():
			continue   # sin runas: ni subs ni set
		for s in ru.get("subs", []):
			t[s["s"]] = float(t.get(s["s"], 0.0)) + float(s["v"])
		var sd: RunaSetData = set_por_id(StringName(str(ru.get("set", ""))))
		if sd != null:
			cuenta[sd] = int(cuenta.get(sd, 0)) + (2 if dos_manos(it) else 1)
	for sd in cuenta:
		if int(cuenta[sd]) >= 2:
			for k in (sd as RunaSetData).bonus_2p:
				t[k] = float(t.get(k, 0.0)) + float((sd as RunaSetData).bonus_2p[k])
	return t

# [[RunaSetData, piezas]] de los sets que lleva (arma: principal + secundaria, dos manos cuenta 2).
static func sets_activos(p: PersonajeData) -> Array:
	var cuenta: Dictionary = {}
	for r in SLOTS_ARMA + SLOTS_ARMADURA:
		var it: Resource = p.get(r)
		if it == null or not admite_runas(it):
			continue
		var s: RunaSetData = set_de(it)
		if s == null:
			continue
		cuenta[s] = int(cuenta.get(s, 0)) + (2 if dos_manos(it) else 1)
	var out: Array = []
	for s in cuenta:
		out.append([s, cuenta[s]])
	return out

# Cuantas piezas del set 's' lleva 'p' (un arma a dos manos cuenta 2). 0 si ninguna.
static func piezas_de_set(p: PersonajeData, s: RunaSetData) -> int:
	if p == null or s == null:
		return 0
	for e in sets_activos(p):
		if e[0] == s:
			return int(e[1])
	return 0


# El efecto especial de un set, si llega a sus piezas: devuelve sus params o {} si no.
static func efecto_activo(p: PersonajeData, efecto: StringName) -> Dictionary:
	for s in sets_activos(p):
		var sd: RunaSetData = s[0]
		if sd.efecto == efecto and int(s[1]) >= sd.piezas_efecto():
			var d: Dictionary = sd.params.duplicate()
			d["_ok"] = true
			return d
	return {}


static func aplicar(c: Combatant, p: PersonajeData) -> void:
	if c == null or p == null:
		return
	var t: Dictionary = totales(p)
	# --- ARMA ---
	var atk: float = float(t.get("ataque_pct", 0.0))
	var hs: Array = []
	for h in c.hands:
		var h2: Dictionary = (h as Dictionary).duplicate()
		h2["ataque_arma"] = float(h2["ataque_arma"]) * (1.0 + atk)
		h2["crit_bonus"] = float(h2["crit_bonus"]) + float(t.get("crit", 0.0))
		h2["crit_dmg"] = float(h2.get("crit_dmg", 0.0)) + float(t.get("crit_dmg", 0.0))
		h2["penetracion"] = float(h2.get("penetracion", 0.0)) + float(t.get("penetracion", 0.0))
		hs.append(h2)
	if not hs.is_empty():
		c.set_hands(hs)   # (el jugador siempre tiene mano: sin arma, los puños)
	c.magic_amp *= 1.0 + float(t.get("dano_magico_pct", 0.0))
	c.crit_magico += float(t.get("crit_mag", 0.0))
	c.crit_dmg_magico += float(t.get("crit_dmg_mag", 0.0))
	c.eficacia += float(t.get("eficacia", 0.0))
	c.runa_dano_hab = float(t.get("dano_hab", 0.0))
	c.runa_dano_jefes = float(t.get("dano_jefes", 0.0))
	c.runa_final_fis = float(t.get("final_fis", 0.0))
	c.runa_final_mag = float(t.get("final_mag", 0.0))
	var de: Dictionary = {}
	var re: Dictionary = {}
	for e in ELEMENTOS:
		var d: float = float(t.get("dano_" + e, 0.0)) + float(t.get("dano_todos", 0.0))
		if d > 0.0:
			de[ELEM_ID[e]] = d
		var r: float = float(t.get("res_" + e, 0.0))
		if r > 0.0:
			re[ELEM_ID[e]] = r
	# --- ARMADURA ---
	# En campos PROPIOS y no multiplicando base_defense & co.: _aplicar_loadout se repite en mitad de la pelea y se
	# acumularian. Los lee el combatiente al calcular (def_value, mdef_value, _spd_base).
	c.runa_def_pct = float(t.get("defensa_pct", 0.0))
	c.runa_mdef_pct = float(t.get("mdef_pct", 0.0))
	c.status_resist += float(t.get("resist_estados", 0.0))
	c.crit_resist += float(t.get("resist_crit", 0.0))
	c.evasion_penal -= float(t.get("evasion", 0.0))
	c.runa_cura_recibida = float(t.get("cura_recibida", 0.0))
	c.runa_menos_dot = float(t.get("menos_dot", 0.0))
	c.runa_vel = float(t.get("velocidad", 0.0))
	# --- LOS SETS (efectos especiales) ---
	var cielo: Dictionary = efecto_activo(p, &"cielo")
	if not cielo.is_empty():
		for e in [ELEM_ID["luz"], ELEM_ID["oscuridad"]]:
			de[e] = float(de.get(e, 0.0)) + float(cielo.get("dano", 0.2))
		c.runa_crit_ciego = float(cielo.get("ciego", 0.2))
	c.runa_dano_elem = de
	c.runa_resist_elem = re
	var ign: Dictionary = efecto_activo(p, &"ignicion")
	c.runa_ignicion_prob = float(ign.get("prob", 0.0))
	c.runa_ignicion_dano = float(ign.get("dano", 0.0))
	var alc: Dictionary = efecto_activo(p, &"alcantarilla")
	c.runa_alcantarilla_prob = float(alc.get("prob", 0.0))
	c.runa_alcantarilla_dano = float(alc.get("dano", 0.0))
	var filo: Dictionary = efecto_activo(p, &"filo_aire")
	c.runa_filo_dano = float(filo.get("dano", 0.0))
	c.runa_filo_mas = float(filo.get("mas", 0.0))
	c.runa_filo_linea = float(filo.get("linea", 0.0))
	c.runa_filo_detras = float(filo.get("detras", 0.0))
	var hilo: Dictionary = efecto_activo(p, &"hilo_conductor")
	c.runa_hilo_prob = float(hilo.get("prob", 0.0))
	c.runa_hilo_dano = float(hilo.get("dano", 0.0))
	c.runa_hilo_radio = float(hilo.get("radio", 0.0))
	c.runa_musgo_reduce = float(efecto_activo(p, &"musgo_viejo").get("reduce", 0.0))
	var amb: Dictionary = efecto_activo(p, &"ambar")
	c.runa_ambar = float(amb.get("capa", 0.0))
	c.runa_ambar_turnos = int(amb.get("turnos", 3))
	c.runa_mentes_turnos = int(efecto_activo(p, &"dos_mentes").get("turnos", 0))
	var cam: Dictionary = efecto_activo(p, &"campo_magnetico")
	c.runa_campo_cada = int(cam.get("cada", 0))
	c.runa_campo_radio = float(cam.get("radio", 0.0))
	c.runa_campo_barra = float(cam.get("barra", 0.0))
	var sr: Dictionary = efecto_activo(p, &"sangre_real")
	c.runa_sangre_real_carga = float(sr.get("por_carga", 0.0))
	c.runa_sangre_real_max = float(sr.get("max", 0.0))
	var mia: Dictionary = efecto_activo(p, &"miasma")
	c.runa_miasma_carga = float(mia.get("por_carga", 0.0))
	c.runa_miasma_max = int(mia.get("max", 0))
	c.runa_miasma_turnos = int(mia.get("turnos", 0))
	var masa: Dictionary = efecto_activo(p, &"masa")
	c.runa_gordo_umbral = float(masa.get("umbral", 0.0))
	c.runa_gordo_reduce = float(masa.get("reduce", 0.0))
	c.runa_pegajoso = float(masa.get("pegajoso", 0.0))
	var marea: Dictionary = efecto_activo(p, &"marea")
	c.runa_marea = float(marea.get("escudo", 0.0))
	var corona: Dictionary = efecto_activo(p, &"corona")
	c.runa_corona_aliados = float(corona.get("aliados", 0.0))
	c.runa_corona_umbral = float(corona.get("umbral", 0.0))
	c.runa_corona_turnos = int(corona.get("turnos", 0))


# La VIDA va aparte: crear_player_combatant la congela al crear el combatiente (antes del loadout).
static func vida_mult(p: PersonajeData) -> float:
	return 1.0 + float(totales(p).get("vida_pct", 0.0)) if p != null else 1.0
