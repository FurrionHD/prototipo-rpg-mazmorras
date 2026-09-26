# ============================================================
#  sellos_magicos.gd
#  EL VOCABULARIO DE LOS CIRCULOS MAGICOS (26/09/2026). Cada magia tiene SU circulo, pero nadie los dibuja a
#  mano: se montan con piezas comunes y una semilla sacada de la magia elige dentro de cada familia. Asi una
#  magia nueva sale sola y coherente con las demas. Lo que significa cada cosa (decidido con el usuario):
#    COLOR   = el elemento (TONOS: el halo saturado y el nucleo casi blanco).
#    CENTRO  = la familia del elemento, sin ser obvia (nada de dibujar un rayo para el rayo):
#              fuego triangulos hacia arriba entrelazados · agua lunas y circulos tangentes · rayo estrellas
#              agudas de puntas impares · luz estrellas de 8 y cuadrados girados · oscuridad pentagrama, luna
#              y pozo negro · sin elemento (arcano) heptagrama y hexagono.
#    BORDE   = el tipo: ataque dientes hacia fuera · refuerzo cuadrados que cruzan el anillo y doble anillo ·
#              debilitar dientes hacia dentro · cura petalos.
#    CAPAS   = las frases: 1 nucleo, 2 anillo de fuera, 3 tres satelites que orbitan, 4 la corona sobre la cabeza.
#    RAREZA  = detalle (anillos finos de mas, cuentas).
#    MEZCLAS = nucleo y satelites del primer elemento, anillo y corona del segundo (el Eclipse: morado abajo,
#              dorado fuera y arriba). El Prismatico es aparte: un elemento en cada satelite.
#  SIN RUNAS NI LETRAS: el hueco entre anillos lleva un FRISO de marcas abstractas (rombos, puntos, rayitas).
#  Una receta es un Dictionary: {"n": frases, "grupos": [grupo...]}. Cada grupo gira entero y tiene piezas en
#  sus coordenadas; CirculoMagico lo dibuja. RETOQUES deja cambiar a mano la receta de una magia concreta.
# ============================================================
extends RefCounted
class_name SellosMagicos

const E := Elementos.Elemento

# Medidas en px de mundo (el cuerpo mide ~26 de alto): el nucleo te rodea los pies.
const R_NUCLEO := 20.0
const R_ANILLO := 31.0
const R_ORBITA := 42.0
const R_SAT := 8.5
const R_CORONA := 14.0
const ALTO_CORONA := 46.0

# [halo, nucleo] por elemento. NINGUNO = arcano (violeta azulado; la oscuridad tira a magenta para no confundirse).
const TONOS := {
	E.NINGUNO: [Color(0.52, 0.5, 1.0), Color(0.88, 0.88, 1.0)],
	E.FUEGO: [Color(1.0, 0.42, 0.08), Color(1.0, 0.88, 0.55)],
	E.AGUA: [Color(0.2, 0.55, 1.0), Color(0.78, 0.93, 1.0)],
	E.RAYO: [Color(1.0, 0.9, 0.15), Color(1.0, 1.0, 0.8)],
	E.LUZ: [Color(1.0, 0.78, 0.45), Color(1.0, 0.98, 0.9)],
	E.OSCURIDAD: [Color(0.72, 0.22, 0.95), Color(0.95, 0.75, 1.0)],
}

# Retoques a mano por magia (clave = nombre del archivo sin .tres). Lo que se ponga aqui pisa lo sorteado:
#   "semilla": int  -> otra tirada de la misma familia.
const RETOQUES := {}


static func tono(elem: int) -> Array:
	return TONOS.get(elem, TONOS[E.NINGUNO])


static func clave_de(spell: SpellData) -> String:
	if spell == null:
		return ""
	if spell.resource_path != "":
		return spell.resource_path.get_file().get_basename()
	return spell.nombre


# ------------------------------------------------------------
#  LA RECETA
# ------------------------------------------------------------
static func receta_de(spell: SpellData) -> Dictionary:
	var clave: String = clave_de(spell)
	var ret: Dictionary = RETOQUES.get(clave, {})
	var rng := RandomNumberGenerator.new()
	rng.seed = int(ret.get("semilla", hash(clave)))
	var n: int = clampi(spell.longitud(), 1, 4)
	var tipo: int = spell.tipo
	var rareza: int = spell.rareza
	var els: Array = elementos_por_capa(spell)
	var sentido: float = 1.0 if rng.randf() < 0.5 else -1.0
	var grupos: Array = []
	# 1) EL NUCLEO
	grupos.append({"etapa": 1, "clase": "nucleo", "elem": els[0], "rot0": rng.randf_range(0.0, TAU),
		"v": sentido * rng.randf_range(0.18, 0.32), "piezas": _nucleo(els[0], rng, rareza)})
	# 2) EL ANILLO DE FUERA
	if n >= 2:
		grupos.append({"etapa": 2, "clase": "anillo", "elem": els[1], "rot0": rng.randf_range(0.0, TAU),
			"v": -sentido * rng.randf_range(0.12, 0.22), "piezas": _anillo(tipo, rng, rareza)})
	# 3) LOS SATELITES y su orbita
	if n >= 3:
		grupos.append({"etapa": 3, "clase": "orbita", "elem": els[1], "rot0": 0.0, "v": 0.0,
			"piezas": [{"p": "anillo", "r": R_ORBITA, "g": 0.6, "a": 0.35}]})
		var v_orb: float = sentido * rng.randf_range(0.25, 0.4)
		var giro_sat: float = rng.randf_range(0.0, TAU)
		for i in 3:
			var el: int = els[2 + i]
			grupos.append({"etapa": 3, "clase": "sat", "i": i, "elem": el, "rot0": giro_sat,
				"v": -sentido * rng.randf_range(1.1, 1.6), "v_orb": v_orb,
				"piezas": _satelite(el, rng, rareza)})
	# 4) LA CORONA
	if n >= 4:
		grupos.append({"etapa": 4, "clase": "corona", "elem": els[5], "rot0": rng.randf_range(0.0, TAU),
			"v": sentido * 0.5, "piezas": _corona(els[5], tipo, rng)})
	return {"n": n, "grupos": grupos, "clave": clave}


# El elemento de cada capa: [nucleo, anillo, sat0, sat1, sat2, corona].
static func elementos_por_capa(spell: SpellData) -> Array:
	var lista: Array = []
	if spell.imbue_elemento_aleatorio:
		# El Prismatico: todos. Arcano en el centro, la noche fuera, un elemento en cada satelite, la luz arriba.
		return [E.NINGUNO, E.OSCURIDAD, E.FUEGO, E.AGUA, E.RAYO, E.LUZ]
	lista.append(spell.elemento)
	for e in spell.elemento_mix:
		if int(e) != spell.elemento and float(spell.elemento_mix[e]) > 0.0:
			lista.append(int(e))
	var out: Array = []
	for i in 6:
		out.append(lista[i % lista.size()])
	# Con mezcla, el anillo es el SEGUNDO elemento, los tres satelites TODOS del primero y la corona del segundo
	# (26/09, el usuario con el Eclipse: satelites de colores alternos "queda raro").
	if lista.size() > 1:
		out = [lista[0], lista[1], lista[0], lista[0], lista[0], lista[1]]
	return out


# ------------------------------------------------------------
#  LAS PIEZAS (en coordenadas del grupo; 'g' = grosor relativo, 'a' = alfa relativo)
# ------------------------------------------------------------
static func _nucleo(el: int, rng: RandomNumberGenerator, rareza: int) -> Array:
	var r := R_NUCLEO
	var ps: Array = [{"p": "anillo", "r": r, "g": 1.2}]
	if rareza >= 2:
		ps.append({"p": "anillo", "r": r - 2.2, "g": 0.55, "a": 0.7})
	var arriba: float = -PI * 0.5
	match el:
		E.FUEGO:
			match rng.randi_range(0, 2):
				0:
					ps.append({"p": "estrella", "r": r - 1.0, "n": 3, "k": 1, "rot": arriba})
					ps.append({"p": "estrella", "r": (r - 1.0) * 0.5, "n": 3, "k": 1, "rot": arriba, "g": 0.8})
					ps.append({"p": "estrella", "r": (r - 1.0) * 0.5, "n": 3, "k": 1, "rot": arriba + PI, "g": 0.6, "a": 0.7})
				1:
					ps.append({"p": "estrella", "r": r - 1.0, "n": 6, "k": 2, "rot": arriba})
					ps.append({"p": "estrella", "r": r * 0.42, "n": 3, "k": 1, "rot": arriba, "g": 0.8})
					ps.append({"p": "anillo", "r": r * 0.5, "g": 0.6})
				_:
					ps.append({"p": "estrella", "r": r - 1.0, "n": 9, "k": 3, "rot": arriba})
					ps.append({"p": "anillo", "r": r * 0.52, "g": 0.7})
					ps.append({"p": "estrella", "r": r * 0.5, "n": 3, "k": 1, "rot": arriba, "g": 0.7})
		E.AGUA:
			var nl: int = [3, 4, 6][rng.randi_range(0, 2)]
			ps.append({"p": "anillo", "r": r * 0.55, "g": 0.8})
			ps.append({"p": "lunas", "r": r * 0.55, "n": nl, "rr": r * 0.3, "rot": rng.randf_range(0.0, TAU)})
			if rng.randf() < 0.6:
				ps.append({"p": "estrella", "r": r * 0.5, "n": 3, "k": 1, "rot": -arriba, "g": 0.7})
			else:
				ps.append({"p": "cuentas", "r": r * 0.78, "n": nl * 2, "rr": 1.4, "g": 0.6})
		E.RAYO:
			var nk: Array = [[7, 3], [9, 4], [7, 2], [11, 4]][rng.randi_range(0, 3)]
			ps.append({"p": "estrella", "r": r - 1.0, "n": nk[0], "k": nk[1], "rot": arriba})
			ps.append({"p": "anillo", "r": r * 0.3, "g": 0.8})
			ps.append({"p": "dientes", "r": r * 0.3, "n": nk[0], "h": 2.5, "dir": 1.0, "g": 0.6})
		E.LUZ:
			if rng.randf() < 0.5:
				ps.append({"p": "estrella", "r": r - 1.0, "n": 8, "k": 3, "rot": arriba})
			else:
				ps.append({"p": "estrella", "r": r - 1.0, "n": 8, "k": 2, "rot": arriba})
				ps.append({"p": "estrella", "r": (r - 1.0) * 0.7, "n": 8, "k": 3, "rot": arriba + PI / 8.0, "g": 0.6})
			ps.append({"p": "marcas", "r0": r * 0.36, "r1": r * 0.48, "n": 16, "g": 0.6})
			ps.append({"p": "anillo", "r": r * 0.3, "g": 0.8})
		E.OSCURIDAD:
			ps.append({"p": "pozo", "r": r * 0.5})
			ps.append({"p": "estrella", "r": r - 1.0, "n": 5, "k": 2, "rot": arriba + (PI if rng.randf() < 0.5 else 0.0)})
			ps.append({"p": "anillo", "r": r * 0.5, "g": 0.9})
			ps.append({"p": "lunas", "r": 0.0, "n": 1, "rr": r * 0.3, "rot": rng.randf_range(0.0, TAU), "g": 0.8})
		_:
			var k7: int = 2 if rng.randf() < 0.5 else 3
			ps.append({"p": "estrella", "r": r - 1.0, "n": 7, "k": k7, "rot": arriba})
			ps.append({"p": "estrella", "r": r * 0.45, "n": 6, "k": 1, "rot": arriba, "g": 0.7})
			ps.append({"p": "anillo", "r": r * 0.25, "g": 0.6})
	return ps


static func _anillo(tipo: int, rng: RandomNumberGenerator, rareza: int) -> Array:
	var r0 := R_NUCLEO + 1.5
	var r1 := R_ANILLO
	var ps: Array = [{"p": "anillo", "r": r1, "g": 1.1}]
	# EL FRISO: marcas abstractas entre el nucleo y el anillo (lo que en sus referencias son letras).
	# Barajado con la semilla (shuffle() usa el azar global: saldria distinto en cada maquina).
	var estilos: Array = ["rombo", "punto", "raya", "tri"]
	var patron: Array = []
	for i in rng.randi_range(2, 3):
		patron.append(estilos.pop_at(rng.randi_range(0, estilos.size() - 1)))
	var nf: int = [16, 20, 24][rng.randi_range(0, 2)]
	ps.append({"p": "friso", "r0": r0 + 1.0, "r1": r1 - 1.5, "n": nf, "estilos": patron, "g": 0.6})
	match tipo:
		SpellData.TipoEfecto.ATAQUE:
			ps.append({"p": "dientes", "r": r1, "n": [18, 24, 30][rng.randi_range(0, 2)], "h": 3.5, "dir": 1.0, "g": 0.9})
		SpellData.TipoEfecto.DEBUFF:
			ps.append({"p": "anillo", "r": r1 + 2.5, "g": 0.6})
			ps.append({"p": "dientes", "r": r1 + 2.5, "n": 16, "h": -3.0, "dir": -1.0, "g": 0.8})
		SpellData.TipoEfecto.CURACION:
			ps.append({"p": "petalos", "r": r1, "n": [8, 10, 12][rng.randi_range(0, 2)], "h": 5.0, "g": 0.9})
		_:
			# Refuerzo: cuadrados inscritos que cruzan el friso, y un segundo anillo (el escudo).
			var nc: int = 1 if rng.randf() < 0.5 else 2
			ps.append({"p": "estrella", "r": r1, "n": 4 * nc, "k": nc, "rot": rng.randf_range(0.0, PI), "g": 0.8})
			ps.append({"p": "anillo", "r": r1 + 2.2, "g": 0.6})
	if rareza >= 3:
		ps.append({"p": "cuentas", "r": r1 + (6.0 if tipo == SpellData.TipoEfecto.ATAQUE else 4.5),
			"n": 6 if rng.randf() < 0.5 else 8, "rr": 1.3, "g": 0.6})
	return ps


static func _satelite(el: int, rng: RandomNumberGenerator, rareza: int) -> Array:
	var r := R_SAT
	var ps: Array = [{"p": "anillo", "r": r, "g": 0.9}, {"p": "anillo", "r": r * 0.72, "g": 0.5, "a": 0.8}]
	var arriba: float = -PI * 0.5
	match el:
		E.FUEGO:
			ps.append({"p": "estrella", "r": r * 0.72, "n": 3, "k": 1, "rot": arriba, "g": 0.7})
		E.AGUA:
			ps.append({"p": "lunas", "r": 0.0, "n": 1, "rr": r * 0.42, "rot": rng.randf_range(0.0, TAU), "g": 0.7})
		E.RAYO:
			ps.append({"p": "estrella", "r": r * 0.72, "n": 5, "k": 2, "rot": arriba, "g": 0.6})
			ps.append({"p": "dientes", "r": r, "n": 7, "h": 2.0, "dir": 1.0, "g": 0.5})
		E.LUZ:
			ps.append({"p": "estrella", "r": r * 0.72, "n": 8, "k": 3, "rot": arriba, "g": 0.55})
		E.OSCURIDAD:
			ps.append({"p": "pozo", "r": r * 0.55})
			ps.append({"p": "lunas", "r": 0.0, "n": 1, "rr": r * 0.45, "rot": rng.randf_range(0.0, TAU), "g": 0.7})
		_:
			ps.append({"p": "estrella", "r": r * 0.72, "n": 6, "k": 2, "rot": arriba, "g": 0.6})
	if rareza >= 4:
		ps.append({"p": "cuentas", "r": r + 2.0, "n": 4, "rr": 0.9, "g": 0.5})
	return ps


static func _corona(el: int, tipo: int, rng: RandomNumberGenerator) -> Array:
	var r := R_CORONA
	var ps: Array = [{"p": "anillo", "r": r, "g": 1.0}, {"p": "anillo", "r": r * 0.62, "g": 0.6}]
	var nk: Array = [[8, 3], [7, 3], [5, 2], [6, 2]][rng.randi_range(0, 3)]
	if el == E.FUEGO:
		nk = [6, 2]
	elif el == E.LUZ:
		nk = [8, 3]
	elif el == E.OSCURIDAD:
		nk = [5, 2]
	ps.append({"p": "estrella", "r": r * 0.95, "n": nk[0], "k": nk[1], "rot": -PI * 0.5, "g": 0.7})
	if tipo == SpellData.TipoEfecto.ATAQUE:
		ps.append({"p": "dientes", "r": r, "n": 16, "h": 3.0, "dir": 1.0, "g": 0.8})
	else:
		ps.append({"p": "petalos", "r": r, "n": 8, "h": 3.5, "g": 0.8})
	return ps
