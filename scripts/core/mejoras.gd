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
			for c in ["dano_mult", "dano_base", "imbue_fuerza"]:
				if c in copia:
					copia.set(c, float(copia.get(c)) * p)
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


# El dominio de una habilidad: cada vez que se usa en una pelea, +1 a SU ficha (montada o no, cuenta para la ficha).
static func sumar_dominio(p, r, n: int = 1) -> void:
	if p == null or r == null:
		return
	var ruta: String = ruta_base(r)
	if ruta.is_empty():
		return
	p.dominio[ruta] = int((p.dominio as Dictionary).get(ruta, 0)) + n
