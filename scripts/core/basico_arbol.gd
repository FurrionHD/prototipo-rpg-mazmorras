# ============================================================
#  basico_arbol.gd
#  EL ARBOL DEL BASICO (23/11, memoria rangos-magias-y-habilidades): lo que mejora el ataque basico de cada TIPO de arma.
#
#  NO es un arbol de nodos como el de las habilidades (Mejoras / nodo_mejora.gd): el basico no tiene ficha. Son dos cosas:
#    1) LA LINEA: tres pasos por nivel, en los pisos 4, 8 y 12 de cada nivel (local), con oro y sin dominio. El del piso 12
#       pide haber subido ya al nivel siguiente. Lo que da:
#         piso 4  daño  (100 % -> 115 %)
#         piso 8  energia que repone el basico (+10 %) y daño (115 % -> 120 %)
#         piso 12 daño (-> 140 %, que es el x1,4 del nivel siguiente), energia +5 % y UN PUNTO DE FACULTAD
#       Cada nivel compone el x1,4 (el presupuesto de las mejoras): el nivel 2 va 140 -> 161 -> 168 -> 196 %.
#       EL BASTON no sube daño: piso 4 +0,5 puntos de mana al acertar, piso 8 energia, piso 12 la MARCA.
#    2) LAS FACULTADES: con cada punto, una NUEVA (rango 1) o +1 RANGO a una que ya tengas (tope 5). El PRIMER punto
#       elige entre las dos EXCLUSIVAS de su arma (la otra se cierra para siempre); las COMUNES van con cualquiera.
#  Lo que se mejora es del BASICO y nada mas: nunca toca las habilidades.
#
#  Los numeros son los que aprobo el jefe arma por arma (23/11). Los "+X % de daño" de las facultades MULTIPLICAN el
#  daño final del basico (su regla); lo que suma al % es solo la linea.
#
#  Lo que lleva cada personaje: PersonajeData.basico_arbol {tipo_arma: {"pasos": n, "fac": {id: rango}}}.
#  Sin class_name (ver nodo_mejora.gd): se usa por preload.
# ============================================================
extends RefCounted

const PISOS := [4, 8, 12]          # los pisos LOCALES de cada nivel donde se compra un paso de la linea
const PISOS_NIVEL := 12
const RANGO_MAX := 5
const DANO_NIVEL := 1.4            # el presupuesto por nivel (memoria: REGLA DE LAS MEJORAS)
const DANO_PASO := [1.0, 1.15, 1.2]   # dentro del nivel, tras 0, 1 y 2 pasos (el 3º es ya el x1,4 del siguiente)
const ENERGIA_PISO_8 := 0.10
const ENERGIA_PISO_12 := 0.05
const MANA_PISO_4 := 0.005         # baston: +0,5 puntos del mana maximo al acertar el basico
const MARCA_BASTON := 0.05         # +5 % al siguiente hechizo por marca, hasta 3 (MARCA_TOPE)
const MARCA_VARITA := 0.025        # con varita, la mitad
const MARCA_TOPE := 3
# Lo que cuesta cada paso, en oro, por nivel (PROVISIONAL: "una buena cantidad"; se ajusta aqui).
const ORO_PASO := 400
const ORO_NIVEL_MULT := 2.5

# Claves de la lista de facultades por arma (WeaponData.Tipo); los escudos y la varita llevan solo su linea.
const T := WeaponData.Tipo

# UNA FACULTAD: id, nombre, 'excl' (true = de las dos del primer punto), 'v' sus 5 valores por rango, 'enf' turnos de
# enfriamiento (0 = sin), 'p' parametros fijos, 'pide' lo que hace falta llevar ("escudo", "dual") y 'txt' la frase
# (con {v} = el valor del rango, en %, y los {p.x} de sus parametros).
const FACULTADES := {
	T.DAGA: [
		{"id": "sangrado", "nombre": "Sangrado", "excl": true, "v": [0.10, 0.15, 0.20, 0.25, 0.30], "enf": 0,
			"txt": "El básico tiene un {v} de probabilidad de causar sangrado."},
		{"id": "doble", "nombre": "Básico doble", "excl": true, "v": [0.20, 0.25, 0.30, 0.35, 0.40], "enf": 0,
			"p": {"dano": 0.5}, "pide": "dual",
			"txt": "Con dos dagas, el básico tiene un {v} de probabilidad de pegar también con la otra, al {p.dano} de daño."},
		{"id": "abrir_herida", "nombre": "Abrir la herida", "v": [0.25, 0.35, 0.45, 0.55, 0.65], "enf": 2,
			"txt": "Si el objetivo ya sangra, el básico tiene un {v} de probabilidad de renovar todas sus cargas."},
		{"id": "ensanamiento", "nombre": "Ensañamiento", "v": [0.15, 0.20, 0.25, 0.30, 0.35], "enf": 0,
			"txt": "El básico hace un {v} más de daño a un enemigo con un estado que hace daño (sangrado, veneno, quemadura)."},
	],
	T.ESTOQUE: [
		{"id": "respuesta", "nombre": "Respuesta", "excl": true, "v": [0.20, 0.25, 0.30, 0.35, 0.40], "enf": 0,
			"txt": "Tras un básico que acierta, un {v} de probabilidad de quedar en respuesta: al próximo golpe que te den, contraatacas una vez con un básico."},
		{"id": "estocada_limpia", "nombre": "Estocada limpia", "excl": true, "v": [0.05, 0.07, 0.09, 0.11, 0.13], "enf": 0,
			"txt": "El básico ignora un {v} de la defensa del objetivo."},
		{"id": "filo_certero", "nombre": "Filo certero", "v": [0.10, 0.14, 0.18, 0.22, 0.26], "enf": 0,
			"txt": "Los críticos del básico hacen un {v} más de daño."},
		{"id": "pies_ligeros", "nombre": "Pies ligeros", "v": [0.10, 0.15, 0.20, 0.25, 0.30], "enf": 2,
			"txt": "Tras un básico que acierta, un {v} de probabilidad de ganar Presteza 1 turno."},
	],
	T.ESPADA_CORTA: [
		{"id": "exponer", "nombre": "Exponer", "excl": true, "v": [0.10, 0.15, 0.20, 0.25, 0.30], "enf": 2,
			"txt": "El básico tiene un {v} de probabilidad de dejar Expuesto al objetivo."},
		{"id": "doble", "nombre": "Básico doble", "excl": true, "v": [0.20, 0.25, 0.30, 0.35, 0.40], "enf": 0,
			"p": {"dano": 0.5}, "pide": "dual",
			"txt": "Con dos espadas cortas, el básico tiene un {v} de probabilidad de pegar también con la otra, al {p.dano} de daño."},
		{"id": "castigar_guardia", "nombre": "Castigar la guardia", "v": [0.15, 0.20, 0.25, 0.30, 0.35], "enf": 0,
			"txt": "El básico hace un {v} más de daño a un enemigo Expuesto."},
		{"id": "buen_ritmo", "nombre": "Buen ritmo", "v": [0.10, 0.15, 0.20, 0.25, 0.30], "enf": 2,
			"txt": "Tras un básico que acierta, un {v} de probabilidad de quitar 1 turno de recarga a una habilidad de espada corta."},
	],
	T.ESPADA_LARGA: [
		{"id": "escudazo", "nombre": "Escudazo de seguida", "excl": true, "v": [0.20, 0.25, 0.30, 0.35, 0.40], "enf": 0,
			"pide": "escudo",
			"txt": "Con escudo, tras un básico que acierta, un {v} de probabilidad de rematar con un golpe de escudo que pega con tu defensa y puede aturdir."},
		{"id": "desarmar", "nombre": "Desarmar", "excl": true, "v": [0.10, 0.15, 0.20, 0.25, 0.30], "enf": 2,
			"txt": "El básico tiene un {v} de probabilidad de dejar Débil al objetivo."},
		{"id": "firmeza", "nombre": "Firmeza", "v": [0.10, 0.15, 0.20, 0.25, 0.30], "enf": 2, "p": {"menos": 0.30},
			"txt": "Tras un básico que acierta, un {v} de probabilidad de que el próximo golpe que recibas te haga un {p.menos} menos."},
		{"id": "dar_ejemplo", "nombre": "Dar ejemplo", "v": [0.15, 0.20, 0.25, 0.30, 0.35], "enf": 2,
			"p": {"energia": [0.10, 0.12, 0.14, 0.16, 0.18]},
			"txt": "Tras un básico que acierta, un {v} de probabilidad de que tus compañeros cercanos recuperen un {p.energia} de su energía máxima."},
	],
	T.MANDOBLE: [
		{"id": "barrido", "nombre": "Barrido", "excl": true, "v": [0.20, 0.25, 0.30, 0.35, 0.40], "enf": 0, "p": {"angulo": 90.0},
			"txt": "El básico barre en un cono hacia el objetivo: los demás enemigos dentro reciben un {v} del daño."},
		{"id": "verdugo", "nombre": "Verdugo", "excl": true, "v": [0.20, 0.25, 0.30, 0.35, 0.40], "enf": 0,
			"p": {"vida": 0.30, "miedo": [0.25, 0.30, 0.35, 0.40, 0.45], "radio": 50.0},
			"txt": "El básico hace un {v} más de daño a enemigos por debajo del {p.vida} de vida. Si al matar le sobra al menos la mitad del golpe, un {p.miedo} de probabilidad de asustar 1 turno a los enemigos cercanos."},
		{"id": "descoser", "nombre": "Descoser", "v": [0.20, 0.25, 0.30, 0.35, 0.40], "enf": 1,
			"txt": "Si el objetivo ya sangra, el básico tiene un {v} de probabilidad de añadirle una carga de sangrado."},
		{"id": "impulso", "nombre": "Impulso", "v": [0.50, 0.60, 0.70, 0.80, 0.90], "enf": 0,
			"txt": "Si el básico mata, recuperas un {v} de la energía que repone un básico."},
	],
	T.HACHA_GRANDE: [
		{"id": "rompearmadura", "nombre": "Rompearmadura", "excl": true, "v": [0.04, 0.05, 0.06, 0.07, 0.08], "enf": 0,
			"p": {"cargas": 3, "turnos": 3},
			"txt": "Cada básico que acierta le quita al objetivo un {v} de su defensa, hasta {p.cargas} veces, durante {p.turnos} turnos."},
		{"id": "furia", "nombre": "Furia", "excl": true, "v": [0.20, 0.25, 0.30, 0.35, 0.40], "enf": 0, "p": {"vida": 0.50},
			"txt": "Con menos del {p.vida} de tu vida, el básico hace un {v} más de daño."},
		{"id": "sed", "nombre": "Sed", "v": [0.03, 0.04, 0.05, 0.06, 0.07], "enf": 0,
			"p": {"tope": [0.02, 0.025, 0.03, 0.035, 0.04]},
			"txt": "El básico te cura un {v} del daño que hace, hasta un {p.tope} de tu vida máxima por turno."},
		{"id": "herida_no_cierra", "nombre": "Herida que no cierra", "v": [0.15, 0.20, 0.25, 0.30, 0.35], "enf": 1,
			"txt": "El básico tiene un {v} de probabilidad de causar Herida profunda (las curas le sirven menos)."},
	],
	T.MAZA_PEQ: [
		{"id": "cerrojo", "nombre": "Cerrojo", "excl": true, "v": [0.05, 0.0625, 0.075, 0.0875, 0.10], "enf": 0,
			"pide": "escudo",
			"txt": "Con escudo, si el básico aturde o retrasa quedas cubierto hasta tu turno: bloqueas como al defender con {v} más de bloqueo y un {v} más de defensa del escudo."},
		{"id": "martilleo", "nombre": "Martilleo", "excl": true, "v": [0.08, 0.10, 0.12, 0.14, 0.16], "enf": 0, "p": {"cargas": 3},
			"txt": "Cada básico seguido al mismo objetivo hace un {v} más de daño, hasta {p.cargas} veces. Al cambiar de objetivo pierdes la mitad."},
		{"id": "machacar", "nombre": "Machacar", "v": [0.15, 0.20, 0.25, 0.30, 0.35], "enf": 0,
			"txt": "El básico hace un {v} más de daño a un enemigo Aturdido o Lento."},
		{"id": "arenga", "nombre": "Arenga", "v": [0.10, 0.15, 0.20, 0.25, 0.30], "enf": 2,
			"txt": "Tras un básico que acierta, un {v} de probabilidad de dar Fortaleza 1 turno a tus compañeros cercanos."},
	],
	T.MARTILLO_GRANDE: [
		{"id": "sacudida", "nombre": "Sacudida", "excl": true, "v": [0.30, 0.35, 0.40, 0.45, 0.50], "enf": 0, "p": {"radio": 40.0},
			"txt": "Si el básico aturde o retrasa, la onda llega a los enemigos cercanos: cada uno tiene un {v} de probabilidad de quedar retrasado."},
		{"id": "impacto", "nombre": "Impacto", "excl": true, "v": [0.25, 0.30, 0.35, 0.40, 0.45], "enf": 0,
			"txt": "El golpe del básico que aturde o retrasa hace un {v} más de daño."},
		{"id": "romper_ritmo", "nombre": "Romper el ritmo", "v": [0.40, 0.50, 0.60, 0.70, 0.80], "enf": 0,
			"txt": "Si el básico aturde o retrasa, recuperas un {v} de la energía que repone un básico."},
		{"id": "arrastre", "nombre": "Arrastre", "v": [0.10, 0.15, 0.20, 0.25, 0.30], "enf": 0,
			"txt": "El retraso que causa el básico empuja un {v} más atrás en la barra."},
	],
	T.ARCO: [
		{"id": "atravesar", "nombre": "Atravesar", "excl": true, "v": [0.30, 0.35, 0.40, 0.45, 0.50], "enf": 0,
			"txt": "La flecha del básico sigue de largo: el primer enemigo detrás en línea recibe un {v} del daño."},
		{"id": "tiro_lejano", "nombre": "Tiro lejano", "excl": true, "v": [0.20, 0.25, 0.30, 0.35, 0.40], "enf": 0,
			"txt": "Cuanto más lejos está el objetivo, más daño hace el básico: hasta un {v} más a su alcance máximo."},
		{"id": "clavar", "nombre": "Clavar", "v": [0.10, 0.15, 0.20, 0.25, 0.30], "enf": 2,
			"txt": "El básico tiene un {v} de probabilidad de dejar Enraizado al objetivo."},
		{"id": "sangre_fria", "nombre": "Sangre fría", "v": [0.15, 0.20, 0.25, 0.30, 0.35], "enf": 0,
			"txt": "Si ningún enemigo te ha golpeado desde tu último turno, el básico hace un {v} más de daño."},
	],
	T.BALLESTA: [
		{"id": "carga_mixta", "nombre": "Carga mixta", "excl": true, "v": [0.20, 0.25, 0.30, 0.35, 0.40], "enf": 0, "p": {"cada": 3},
			"txt": "Cargar admite dos tipos de virote: cada básico suma un {v} del daño extra del segundo, que se gasta 1 de cada {p.cada} disparos."},
		{"id": "plantado", "nombre": "Plantado", "excl": true, "v": [0.20, 0.25, 0.30, 0.35, 0.40], "enf": 0,
			"txt": "Si no te has movido en tu turno, el básico hace un {v} más de daño."},
		{"id": "retrasar", "nombre": "Retrasar", "v": [0.10, 0.15, 0.20, 0.25, 0.30], "enf": 2,
			"txt": "El básico tiene un {v} de probabilidad de retrasar al objetivo en la barra."},
		{"id": "matagigantes", "nombre": "Matagigantes", "v": [0.15, 0.20, 0.25, 0.30, 0.35], "enf": 0,
			"txt": "El básico hace un {v} más de daño a jefes, mutantes y enemigos grandes."},
	],
	T.BASTON: [
		{"id": "eco_arcano", "nombre": "Eco arcano", "excl": true, "v": [0.05, 0.075, 0.10, 0.125, 0.15], "enf": 2,
			"txt": "Tras un básico que acierta, tu siguiente hechizo cuesta un {v} menos de maná."},
		{"id": "chispa", "nombre": "Chispa", "excl": true, "v": [0.15, 0.20, 0.25, 0.30, 0.35], "enf": 0, "p": {"magia": 0.50},
			"txt": "El básico tiene un {v} de probabilidad de soltar una chispa mágica que hace un {p.magia} de tu Magia."},
		{"id": "concentracion", "nombre": "Concentración", "v": [0.10, 0.15, 0.20, 0.25, 0.30], "enf": 2,
			"txt": "Tras un básico que acierta, un {v} de probabilidad de ganar una carga de Foco arcano."},
		{"id": "escabullirse", "nombre": "Escabullirse", "v": [0.15, 0.20, 0.25, 0.30, 0.35], "enf": 2,
			"txt": "Tras un básico que acierta, un {v} de probabilidad de quedar con el Velo umbrío 1 turno."},
	],
}

# LAS LINEAS SIN FACULTADES de la varita y los escudos: en el piso 12 de cada nivel, lo suyo (claves de abajo).
#   varita: la marca a la mitad.  escudos (por ShieldData.Tamano): su verbo, nunca el bloqueo (techo del 80 %).
const ESCUDO_POR_NIVEL := {
	0: {"campo": "contra_prob", "suma": 0.03},       # pequeño: +3 puntos de contraataque al bloquear
	1: {"campo": "resist_estados", "suma": 0.02},    # normal: +2 puntos de resistencia a estados
	2: {"campo": "defend_defense", "mult": 0.05},    # grande: +5 % a la defensa del escudo al defender
}


# ---------------------------------------------------------------- la linea

# Nivel y paso (0, 1, 2 = pisos 4, 8, 12) del paso 'k' (contando desde 0).
static func nivel_de_paso(k: int) -> int:
	return 1 + k / 3

static func piso_de_paso(k: int) -> int:
	return PISOS_NIVEL * (nivel_de_paso(k) - 1) + int(PISOS[k % 3])


# El multiplicador del daño del basico con 'pasos' comprados. 0 pasos = 1.
static func mult_dano(pasos: int) -> float:
	return pow(DANO_NIVEL, pasos / 3) * float(DANO_PASO[pasos % 3])


# Lo que se multiplica la energia que repone el basico. Piso 8 +10 %, piso 12 +5 %, cada nivel.
static func mult_energia(pasos: int) -> float:
	var completos: int = pasos / 3
	var e: float = 1.0 + (ENERGIA_PISO_8 + ENERGIA_PISO_12) * completos
	if pasos % 3 >= 2:
		e += ENERGIA_PISO_8
	return e


# Los pasos de piso 4 que lleva (el baston: +0,5 puntos de mana cada uno).
static func pasos_piso(pasos: int, cual: int) -> int:
	return pasos / 3 + (1 if pasos % 3 > cual else 0)


# Los PUNTOS DE FACULTAD: uno por cada paso del piso 12.
static func puntos(pasos: int) -> int:
	return pasos / 3


# ¿PUEDE COMPRAR el paso siguiente? "" si si; si no, por que. 'piso_max' = el piso mas hondo al que ha llegado.
static func motivo_no_paso(pasos: int, nivel: int, piso_max: int, oro: int) -> String:
	var piso: int = piso_de_paso(pasos)
	if piso_max < piso:
		return "pide llegar al piso %d" % piso
	# El del piso 12 pide haber subido al nivel siguiente (el primer punto llega al subir a nivel 2).
	if pasos % 3 == 2 and nivel < nivel_de_paso(pasos) + 1:
		return "pide nivel %d" % (nivel_de_paso(pasos) + 1)
	if oro < oro_paso(pasos):
		return "pide %d de oro" % oro_paso(pasos)
	return ""


static func oro_paso(pasos: int) -> int:
	return int(round(ORO_PASO * pow(ORO_NIVEL_MULT, float(pasos / 3))))


# ---------------------------------------------------------------- las facultades

static func facultades(tipo: int) -> Array:
	return FACULTADES.get(tipo, [])


static func facultad(tipo: int, id: String) -> Dictionary:
	for f in facultades(tipo):
		if String(f["id"]) == id:
			return f
	return {}


# Los puntos GASTADOS (la suma de los rangos).
static func gastados(fac: Dictionary) -> int:
	var n: int = 0
	for k in fac:
		n += int(fac[k])
	return n


# ¿PUEDE poner un punto en 'id'? "" si si. 'datos' = {"pasos": n, "fac": {id: rango}}.
static func motivo_no_facultad(tipo: int, datos: Dictionary, id: String) -> String:
	var f: Dictionary = facultad(tipo, id)
	if f.is_empty():
		return "no existe"
	var fac: Dictionary = datos.get("fac", {})
	var tiene_excl: String = exclusiva_elegida(tipo, fac)
	# Lo que ya no tiene vuelta va primero (la ficha lo enseña aunque no queden puntos).
	if bool(f.get("excl", false)) and tiene_excl != "" and tiene_excl != id:
		return "cerrada: elegiste %s" % String(facultad(tipo, tiene_excl).get("nombre", tiene_excl))
	if gastados(fac) >= puntos(int(datos.get("pasos", 0))):
		return "no te quedan puntos"
	if int(fac.get(id, 0)) >= RANGO_MAX:
		return "ya está al máximo"
	# El PRIMER punto va a una de las dos exclusivas; la otra queda cerrada para siempre.
	if fac.is_empty() and not bool(f.get("excl", false)):
		return "el primer punto va a una de las dos primeras"
	if bool(f.get("excl", false)) and tiene_excl != "" and tiene_excl != id:
		return "cerrada: elegiste %s" % String(facultad(tipo, tiene_excl).get("nombre", tiene_excl))
	return ""


static func exclusiva_elegida(tipo: int, fac: Dictionary) -> String:
	for f in facultades(tipo):
		if bool(f.get("excl", false)) and int(fac.get(String(f["id"]), 0)) > 0:
			return String(f["id"])
	return ""


# EL VALOR de la facultad 'id' al rango que tiene (0 si no la tiene), y el de uno de sus parametros por rango.
static func valor(tipo: int, fac: Dictionary, id: String) -> float:
	var r: int = int(fac.get(id, 0))
	if r <= 0:
		return 0.0
	var f: Dictionary = facultad(tipo, id)
	return float((f.get("v", []) as Array)[clampi(r, 1, RANGO_MAX) - 1]) if not f.is_empty() else 0.0


static func param(tipo: int, fac: Dictionary, id: String, clave: String) -> float:
	var f: Dictionary = facultad(tipo, id)
	var p = (f.get("p", {}) as Dictionary).get(clave)
	if p is Array:
		var r: int = clampi(int(fac.get(id, 1)), 1, RANGO_MAX)
		return float(p[r - 1])
	return float(p) if p != null else 0.0


# ---------------------------------------------------------------- el arbol como se ve (23/11, el dibujo del jefe)
# UNA COLUMNA POR PUNTO: la columna 0 (el punto del nivel 2) son las dos EXCLUSIVAS; las columnas 1 y 2 (niveles 3 y 4)
# son las dos COMUNES (coger la misma dos veces le sube el rango); la 3 (nivel 5) es tu PRINCIPAL otra vez, a rango 2. Coger un nodo ES el paso del piso 12 de ese nivel (su daño, su energia y el punto): se paga en el nodo.
# Lo elegido en cada columna va en datos["elec"] (lista de ids, una por columna).
const COLUMNAS := 4

# LA ULTIMA COLUMNA (el nivel 5) vuelve a la PRINCIPAL (23/11, el jefe): un solo nodo, la que elegiste en la primera, que
# sube a rango 2. Sin principal elegida todavia, las dos (y solo valdra la que elijas).
static func opciones_columna(tipo: int, col: int, elec: Array = []) -> Array:
	var principal_otra_vez: bool = col == COLUMNAS - 1
	if principal_otra_vez and not elec.is_empty():
		return [String(elec[0])]
	var out: Array = []
	for f in facultades(tipo):
		if bool(f.get("excl", false)) == (col == 0 or principal_otra_vez):
			out.append(String(f["id"]))
	return out


# ¿PUEDE coger 'id' en la columna 'col'? "" si si. Pide: que sea la columna que toca, los pisos 4 y 8 de ese nivel ya
# comprados, lo que pide el paso del piso 12 (nivel y piso) y el oro.
static func motivo_no_nodo(tipo: int, datos: Dictionary, col: int, id: String, nivel: int, piso_max: int, oro: int) -> String:
	var elec: Array = datos.get("elec", [])
	if col < elec.size():
		return "ya elegiste en este nivel"
	if col > elec.size():
		return "antes, el nivel anterior"
	if not opciones_columna(tipo, col, elec).has(id):
		return "no existe"
	var pasos: int = int(datos.get("pasos", 0))
	var paso_12: int = col * 3 + 2
	if pasos < paso_12:
		return "antes, los pisos 4 y 8 de este nivel"
	return motivo_no_paso(paso_12, nivel, piso_max, oro)


# Lo que queda al coger 'id' en la siguiente columna (sin cobrar: eso lo hace Game).
static func con_nodo(datos: Dictionary, id: String) -> Dictionary:
	var d: Dictionary = datos.duplicate(true)
	var elec: Array = d.get("elec", [])
	elec.append(id)
	d["elec"] = elec
	var fac: Dictionary = d.get("fac", {})
	fac[id] = mini(int(fac.get(id, 0)) + 1, RANGO_MAX)
	d["fac"] = fac
	d["pasos"] = int(d.get("pasos", 0)) + 1
	return d


# ---------------------------------------------------------------- lo que viaja a la pelea

# LO QUE LLEVA UNA MANO a la pelea (va en el Dictionary de la mano: Combatant._apply_hand lo deja en arbol_mano()).
#   {"tipo", "dano" (mult de la linea), "energia" (mult), "mana_extra" (baston), "marca" (baston/varita), "fac" {id: valor},
#    "rangos" {id: rango}}
static func de_mano(datos: Dictionary, tipo: int) -> Dictionary:
	var pasos: int = int(datos.get("pasos", 0))
	var fac: Dictionary = datos.get("fac", {})
	var out := {"tipo": tipo, "dano": 1.0, "energia": mult_energia(pasos), "mana_extra": 0.0, "marca": 0.0,
		"fac": {}, "rangos": fac.duplicate()}
	if tipo == T.BASTON:
		out["mana_extra"] = MANA_PISO_4 * pasos_piso(pasos, 0)
		out["marca"] = MARCA_BASTON if pasos_piso(pasos, 2) > 0 else 0.0
	else:
		out["dano"] = mult_dano(pasos)
	for id in fac:
		out["fac"][String(id)] = valor(tipo, fac, String(id))
	return out


# LA FRASE de una facultad a su rango (o al 1 si no la tiene), con sus numeros sacados del dato.
static func frase(tipo: int, id: String, rango: int) -> String:
	var f: Dictionary = facultad(tipo, id)
	if f.is_empty():
		return ""
	var r: int = clampi(maxi(rango, 1), 1, RANGO_MAX)
	var fac := {id: r}
	var s: String = String(f.get("txt", ""))
	var v: float = valor(tipo, fac, id)
	s = s.replace("{v}", _pct(v))
	for k in (f.get("p", {}) as Dictionary):
		var x: float = param(tipo, fac, id, String(k))
		var txt: String = _pct(x) if x < 1.0 else ("%d" % int(x) if is_equal_approx(x, round(x)) else "%.1f" % x)
		s = s.replace("{p.%s}" % k, txt)
	return s


static func _pct(x: float) -> String:
	var p: float = x * 100.0
	return ("%d %%" % int(round(p))) if is_equal_approx(p, round(p)) else ("%s %%" % String.num(p, 2).replace(".", ","))
