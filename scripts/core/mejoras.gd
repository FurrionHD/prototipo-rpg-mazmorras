# ============================================================
#  mejoras.gd
#  LOS ARBOLES DE LAS HABILIDADES Y LAS MAGIAS (22/11, memoria rangos-magias-y-habilidades): montar una habilidad con
#  los nodos que ha cogido un personaje, y lo que pide coger cada nodo.
#
#  LA HABILIDAD MONTADA ES UNA COPIA de su ficha con los cambios de sus nodos, y se llama como la ficha mas los nodos:
#      res://resources/spells/venablo_de_tormenta.tres#punta_larga+atraviesa
#  Por que asi y no tocando cada sitio que lee la ficha:
#    - Todo lo que reconoce una habilidad por su RUTA (la red, las recargas, los efectos, los sonidos) sigue sirviendo:
#      la sala monta tu personaje con tus mismos nodos y saca el MISMO nombre, y get_file().get_basename() de ese nombre
#      sigue dando "venablo_de_tormenta" (lo que buscan los sellos, los sonidos y los grimorios).
#    - IdsRed ya deja pasar en texto una ruta que no esta en su tabla ("un recurso hecho en runtime").
#    - Se separa con '#' y no con '::' porque '::' es como Godot nombra los sub-recursos de un .tres.
#  Solo se monta para el COMBATE (Game.crear_player_combatant): lo que se guarda y se equipa sigue siendo la ficha.
#
#  Sin class_name (ver nodo_mejora.gd): se usa por preload.
# ============================================================
extends RefCounted

const SEP := "#"
const SEP_NODOS := "+"

# EL PRESUPUESTO DE CADA NIVEL (23/11 y 24/11, el jefe; memoria empezar-habilidades-24-11): cada nivel de personaje da
# x1,4 de daño Y de coste, medido SIEMPRE desde el NOMINAL (base x 1,4^(nivel-1)), no desde lo que lleve de verdad. Un
# nodo dice solo QUE PARTE de ese +40 % se lleva (["presupuesto", 0.75] = 30 de 40; puede pasar de 1 si lo paga con
# otra cosa) y aqui sale el numero: 1,4^(nivel-2) x (1 + 0,4 x parte). Lo que una rama deja sin subir es un PRESTAMO:
# el nodo del nivel siguiente vuelve a partir del nominal. Por eso es "set" y no "mult": el ultimo nodo manda, y uno
# que junta dos ramas da lo mismo llegues por donde llegues. Lo que cambia la FORMA de la rama (mas o menos tajos) va
# aparte, con "mult".
const PASO_NIVEL := 1.4
# Los campos que fijan los nodos y se HORNEAN al final del montaje (ver _hornear). En la ficha valen 1.
const POTENCIA := "potencia"
const POTENCIA_COSTE := "potencia_coste"


# Lo que vale ["presupuesto", parte] en un nodo de ese nivel.
static func presupuesto(nivel: int, parte: float) -> float:
	return pow(PASO_NIVEL, float(maxi(nivel, 2) - 2)) * (1.0 + (PASO_NIVEL - 1.0) * parte)


# La ruta de la FICHA de una habilidad, montada o no.
static func ruta_base(r) -> String:
	var ruta: String = (r as Resource).resource_path if r is Resource else String(r) if r != null else ""
	var i: int = ruta.find(SEP)
	return ruta if i < 0 else ruta.substr(0, i)


static func es_montada(r) -> bool:
	var ruta: String = (r as Resource).resource_path if r is Resource else String(r) if r != null else ""
	return ruta.contains(SEP)


# Los nodos de una ficha, por su id.
static func nodo(base: Resource, id: StringName) -> Resource:
	if base == null or not ("arbol" in base):
		return null
	for n in base.arbol:
		if n != null and StringName(n.id) == id:
			return n
	return null


# LA HABILIDAD CON ESOS NODOS. Sin nodos (o sin arbol) devuelve la ficha tal cual. Los nodos se aplican en el orden
# del arbol, no en el que lleguen, para que dos maquinas saquen la misma copia y el mismo nombre.
static func montar(base: Resource, ids: Array) -> Resource:
	if base == null or ids.is_empty() or not ("arbol" in base) or (base.arbol as Array).is_empty():
		return base
	var buenos: Array = []
	for n in base.arbol:
		if n != null and ids.has(String(n.id)) or n != null and ids.has(StringName(n.id)):
			buenos.append(n)
	if buenos.is_empty():
		return base
	var nombres: Array = buenos.map(func(n): return String(n.id))
	var ruta: String = String(base.resource_path) + SEP + SEP_NODOS.join(PackedStringArray(nombres))
	# La misma copia mientras viva (la pelea, las recargas que se arrastran): asi se compara por referencia igual.
	if ResourceLoader.has_cached(ruta):
		return ResourceLoader.get_cached_ref(ruta)
	var copia: Resource = montar_sin_nombre(base, buenos)
	copia.resource_path = ruta
	copia.set_meta(&"ruta_base", String(base.resource_path))
	copia.set_meta(&"nodos", nombres)
	return copia


# LA COPIA CON ESOS NODOS (ya en el orden del arbol), sin nombre ni cache: la usa montar y la ficha del nodo para
# enseñar el "antes -> despues" sin dejar copias colgadas en la cache de recursos.
static func montar_sin_nombre(base: Resource, nodos: Array) -> Resource:
	var copia: Resource = base.duplicate(false)
	for n in nodos:
		_aplicar(copia, n)
	_hornear(copia)
	return copia


# LA POTENCIA del ultimo nodo al daño, y la del coste a la energia (o al mana). Se dejan a 1 para que no se apliquen dos
# veces si alguien vuelve a montar la copia.
static func _hornear(copia: Resource) -> void:
	if POTENCIA in copia:
		var p: float = float(copia.get(POTENCIA))
		if not is_equal_approx(p, 1.0):
			for c in ["dano_mult", "dano_base"]:
				if c in copia:
					copia.set(c, float(copia.get(c)) * p)
			# la fuerza del veneno, SOLO en las que impregnan el arma (el Filo): las demas no tienen veneno que subir
			if "imbue_fuerza" in copia and int(copia.get("imbue_estado")) >= 0 and float(copia.get("dano_mult")) <= 0.0:
				copia.set("imbue_fuerza", float(copia.get("imbue_fuerza")) * p)
			copia.set(POTENCIA, 1.0)
	if POTENCIA_COSTE in copia:
		var k: float = float(copia.get(POTENCIA_COSTE))
		if not is_equal_approx(k, 1.0):
			for c in ["coste_energia", "coste_energia_dual"]:
				if c in copia and float(copia.get(c)) > 0.0:
					copia.set(c, roundf(float(copia.get(c)) * k))
			if "coste_mana" in copia:
				copia.set("coste_mana", maxi(1, roundi(float(copia.get("coste_mana")) * k)))
			copia.set(POTENCIA_COSTE, 1.0)


static func _aplicar(copia: Resource, n: Resource) -> void:
	for campo in (n.cambios as Dictionary):
		var c: String = String(campo)
		if not (c in copia):
			push_warning("[mejoras] el nodo '%s' de %s cambia '%s', que la ficha no tiene" % [n.id, copia.resource_path, c])
			continue
		var par = n.cambios[campo]
		if not (par is Array) or (par as Array).size() != 2:
			push_warning("[mejoras] el nodo '%s' cambia '%s' con %s (va [operacion, valor])" % [n.id, c, str(par)])
			continue
		var op: String = String(par[0])
		var v = par[1]
		var ahora = copia.get(c)
		match op:
			"mult": copia.set(c, ahora * v)
			"add":
				if ahora is Array:
					copia.set(c, (ahora as Array) + (v as Array))   # una lista NUEVA: la de la ficha no se toca
				else:
					copia.set(c, ahora + v)
			"set": copia.set(c, v)
			"presupuesto": copia.set(c, presupuesto(int(n.nivel_min), float(v)))
			_: push_warning("[mejoras] el nodo '%s' usa la operacion '%s' (mult, add, set o presupuesto)" % [n.id, op])


# DE UNA RUTA (lo que llega por la red, lo que se guardo de una recarga): la ficha, o la habilidad montada.
static func cargar(ruta: String) -> Resource:
	if ruta.is_empty():
		return null
	if ResourceLoader.has_cached(ruta):
		return ResourceLoader.get_cached_ref(ruta)
	var i: int = ruta.find(SEP)
	if i < 0:
		return load(ruta) if ResourceLoader.exists(ruta) else null
	var base_r: String = ruta.substr(0, i)
	if not ResourceLoader.exists(base_r):
		return null
	return montar(load(base_r), Array(ruta.substr(i + 1).split(SEP_NODOS, false)))


# LA QUE LLEVA A LA PELEA un personaje: con sus nodos, o la ficha tal cual si la lleva SIN MEJORAS (el interruptor que
# pidio el jefe: la de sin mejorar sigue existiendo y se puede llevar).
static func para_combate(p, r: Resource) -> Resource:
	if r == null or p == null:
		return r
	var base: String = String(r.resource_path)
	if bool((p.sin_mejoras as Dictionary).get(base, false)):
		return r
	return montar(r, (p.nodos_elegidos as Dictionary).get(base, []))


# ¿PUEDE COGER este nodo? "" si puede; si no, por que (para la pantalla). 'nivel' y 'oro' son los del personaje.
static func motivo_no(p, base: Resource, id: StringName, nivel: int, oro: int) -> String:
	var n: Resource = nodo(base, id)
	if n == null:
		return "no existe"
	var ruta: String = String(base.resource_path)
	var cogidos: Array = (p.nodos_elegidos as Dictionary).get(ruta, [])
	if cogidos.has(String(id)):
		return "ya lo tienes"
	for x in n.excluye:
		if cogidos.has(String(x)):
			return "cierra otra rama"
	if not (n.padres as Array).is_empty() and not (n.padres as Array).any(func(pa): return cogidos.has(String(pa))):
		return "te falta el anterior"
	if nivel < int(n.nivel_min):
		return "pide nivel %d" % int(n.nivel_min)
	if int((p.dominio as Dictionary).get(ruta, 0)) < int(n.dominio):
		return "pide dominio %d" % int(n.dominio)
	if oro < int(n.oro):
		return "pide %d de oro" % int(n.oro)
	return ""


# ------------------------------------------------------------
#  EL DOMINIO POR TRAMOS (24/11, el jefe: "como las profesiones del WoW")
# ------------------------------------------------------------
# Cada vez que se usa en una pelea, TIRA por +1 a SU ficha (montada o no, cuenta para la ficha). La prob depende de tu
# dominio frente al PISO donde la usas, para que no se pueda subir spameando en el piso 1. Cada piso tiene su TRAMO de 25
# (piso p: de 25(p-1) a 25p):
#   por DEBAJO del tramo            100 %         NARANJA  (el piso te queda grande: sube siempre)
#   DENTRO del tramo                 70 -> 40 %   AMARILLO (bajando seguido de su principio a su final)
#   en el tramo del piso SIGUIENTE   20 -> 10 %   VERDE    (ya casi no te enseña nada)
#   mas arriba                        0 %         GRIS     (aqui ya no aprendes: baja mas hondo)
# Los nodos piden 300 por nivel por encima del 1 (tools/arboles_habilidades.py): el nivel 2, 300 = acabar el piso 12.
# Habilidades Y magias (combat_magia tambien lo llama).
const DOMINIO_TRAMO := 25
enum Ritmo { NARANJA, AMARILLO, VERDE, GRIS }
const COLOR_RITMO := {
	Ritmo.NARANJA: Color(1.0, 0.55, 0.2),
	Ritmo.AMARILLO: Color(1.0, 0.85, 0.3),
	Ritmo.VERDE: Color(0.45, 0.85, 0.4),
	Ritmo.GRIS: Color(0.55, 0.55, 0.6),
}


static func ritmo_dominio(dominio: int, piso: int) -> int:
	var ini: int = DOMINIO_TRAMO * (maxi(1, piso) - 1)
	if dominio < ini:
		return Ritmo.NARANJA
	if dominio < ini + DOMINIO_TRAMO:
		return Ritmo.AMARILLO
	if dominio < ini + DOMINIO_TRAMO * 2:
		return Ritmo.VERDE
	return Ritmo.GRIS


# La prob de que este uso le sume +1 (0..1).
static func prob_dominio(dominio: int, piso: int) -> float:
	var ini: int = DOMINIO_TRAMO * (maxi(1, piso) - 1)
	var dentro: float = float(dominio - ini) / float(DOMINIO_TRAMO)   # 0 al empezar el tramo, 1 al acabarlo
	match ritmo_dominio(dominio, piso):
		Ritmo.NARANJA:
			return 1.0
		Ritmo.AMARILLO:
			return lerpf(0.7, 0.4, dentro)
		Ritmo.VERDE:
			return lerpf(0.2, 0.1, dentro - 1.0)
	return 0.0


# EL PISO DONDE SE PELEA: el de la mazmorra (en la arena de pruebas, el que simula).
static func piso_de_ahora() -> int:
	return maxi(1, int(Game.current_floor))


# Un uso: tira y, si sale, +1. 'piso' < 1 = el de ahora; 'tirada' (0..1) solo para las pruebas (< 0 = al azar).
# Devuelve si ha subido.
static func sumar_dominio(p, r, piso: int = -1, tirada: float = -1.0) -> bool:
	if p == null or r == null:
		return false
	var ruta: String = ruta_base(r)
	if ruta.is_empty():
		return false
	var d: int = int((p.dominio as Dictionary).get(ruta, 0))
	var prob: float = prob_dominio(d, piso if piso >= 1 else piso_de_ahora())
	if (tirada if tirada >= 0.0 else randf()) >= prob:
		return false
	p.dominio[ruta] = d + 1
	return true


# LO SIGUIENTE QUE PIDE dominio en su arbol (el mas bajo de los nodos aun sin coger que pida mas de lo que llevas); 0 = nada.
static func dominio_siguiente(p, base: Resource) -> int:
	if base == null or base.get("arbol") == null:
		return 0
	var ruta: String = String(base.resource_path)
	var d: int = int((p.dominio as Dictionary).get(ruta, 0))
	var cogidos: Array = (p.nodos_elegidos as Dictionary).get(ruta, [])
	var mejor: int = 0
	for n in base.arbol:
		if n == null or cogidos.has(String(n.id)) or int(n.dominio) <= d:
			continue
		if mejor == 0 or int(n.dominio) < mejor:
			mejor = int(n.dominio)
	return mejor
