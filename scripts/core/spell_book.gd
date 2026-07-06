# ============================================================
#  spell_book.gd
#  Repositorio de FRASES de encantamiento + utilidades para el test de recitado.
#
#  Los hechizos (SpellData) recitan frases de este repositorio. En combate, cada
#  turno se muestra un test tipo examen (a/b/c/d): la frase correcta del hechizo
#  mezclada con DISTRACTORES sacados de aqui (frases de OTROS conjuros). Aciertas
#  -> avanzas; fallas -> backfire.
#
#  Es una clase estatica (como StatsMath / Upgrades): solo datos y helpers.
# ============================================================

extends RefCounted
class_name SpellBook

# Repositorio de frases de encantamiento (estilo latino-fantastico). Las frases
# de los .tres de hechizos DEBEN salir de aqui (verbatim) para que nunca aparezcan
# como su propio distractor. Ampliable libremente.
const REPOSITORIO: Array[String] = [
	# Fuego (chispa / bola_fuego)
	"Ignis, arde en mi mano",
	"Que la llama primigenia despierte",
	"Ceniza y brasa, obedeced",
	# Tormenta / rayo (tormenta)
	"Fulgor, desciende del cielo",
	"Truenos, romped el silencio",
	"El viento aullara conmigo",
	# Hielo
	"Aqua, congela el aliento",
	"Escarcha, sella su avance",
	"Hielo eterno, alza tu muro",
	# Sombra
	"Umbra, devora la luz",
	"Sombras, tejed vuestro manto",
	# Tierra
	"Terra, alza tu ira",
	"Piedra viva, escudame",
	# Luz / sanacion
	"Lumen, cierra esta herida",
	"Luz sagrada, restaurame",
	# Genericas (relleno / despiste)
	"Por el pacto de los ancianos",
	"Que se cumpla mi voluntad",
	"Silencio, criatura del abismo",
	"Vientos del norte, acudid",
	"Sangre y raiz, respondedme",
	"El vacio escucha mi llamada",
	"Sello roto, poder liberado",
]


# Devuelve n_opciones frases BARAJADAS para el test: 1 correcta + (n-1)
# distractores tomados de REPOSITORIO union extra_pool, excluyendo la correcta.
# extra_pool = frases de otros hechizos equipados (por si no estuvieran ya en el
# repositorio). Si no hay suficientes distractores, devuelve las que haya.
static func opciones_test(correcta: String, extra_pool: Array = [], n_opciones: int = 4) -> Array:
	# Conjunto de candidatos unicos, sin la correcta.
	var candidatos: Array[String] = []
	for f in REPOSITORIO:
		if f != correcta and not candidatos.has(f):
			candidatos.append(f)
	for f in extra_pool:
		if f != correcta and not candidatos.has(f):
			candidatos.append(f)

	candidatos.shuffle()
	var distractores := candidatos.slice(0, maxi(0, n_opciones - 1))

	var opciones: Array = distractores.duplicate()
	opciones.append(correcta)
	opciones.shuffle()
	return opciones
