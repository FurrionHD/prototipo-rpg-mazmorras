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
	# Fuego (brasa / bola_fuego=Andanada ignea / filo_ardiente / manto_brasas)
	"Ignis, arde en mi mano",
	"Que la llama primigenia despierte",
	"Ceniza y brasa, obedeced",
	"Alzo la mano y el cielo se prende",
	"Caed, brasas, sin clemencia",
	"Que la brasa cubra mi filo",
	"Arde con cada tajo",
	"Fuego interior, despierta",
	"Que mi piel sea ascua",
	"Soy la hoguera, y la hoguera no arde",
	# Rayo (descarga / rayo / tormenta / filo_fulgurante / manto_centellas)
	"Centella, salta ya",
	"Relampago, parte el aire",
	"Que el cielo descargue su furia",
	"Fulgor, desciende del cielo",
	"Truenos, romped el silencio",
	"El viento aullara conmigo",
	"Que el rayo duerma en mi acero",
	"Chispa, salta al golpear",
	"Tormenta, hazme tu cauce",
	"Que el trueno lata en mi pecho",
	"Soy la centella, y no me alcanzan",
	# Agua (rocio / chorro_agua=Torrente / filo_torrente / manto_marea). OJO: el AGUA y el HIELO son
	# elementos DISTINTOS: el agua apaga el fuego, pero el hielo se derrite con el.
	"Gota, hiere al caer",
	"Que la corriente me responda",
	"Rompete contra mi enemigo",
	"Que el rio rompa su cauce",
	"Arrasa cuanto se te ponga delante",
	"Que el rio abrace mi acero",
	"Torrente, muerde por mi",
	"Aguas profundas, cubridme",
	"Que la marea sea mi piel",
	"Soy el mar, y el mar no arde",
	# Hielo (elemento FUTURO: aun no existe en Elementos)
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
	# Potenciacion propia (buff: Fortaleza)
	"Vigor, colma mis musculos",
	"Furia ancestral, empuname",
	# Debilitamiento (debuff: Debil)
	"Languidez, quiebra su fuerza",
	"Flaqueza, muerde sus huesos",
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


# ¿A cuantas columnas se pueden pintar estas opciones en 'ancho' px? Las frases van en rejilla (como
# los hechizos y las habilidades), pero una frase RECORTADA es peor que fea: si no puedes leer la
# opcion no puedes elegirla, y equivocarse cuesta un backfire. Asi que si a dos columnas no cabe la
# mas larga, se pintan a una.
#
# Vive aqui, con el resto del examen, porque lo preguntan las DOS pantallas que lo pintan: la de
# combate (combat._pintar_test) y la del mapa (casteo_mapa._mostrar_frase).
static func columnas_para_frases(opciones: Array, ancho: float, fuente: Font, tam: int,
		columnas: int = 2, margen: float = 24.0) -> int:
	if fuente == null or columnas <= 1:
		return 1
	var mas_larga: float = 0.0
	for o in opciones:
		# El "a)  " de delante cuenta: es parte del boton.
		var t: String = "a)  %s" % String(o)
		mas_larga = maxf(mas_larga, fuente.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x)
	var por_columna: float = (ancho - 10.0 * float(columnas - 1)) / float(columnas)
	return columnas if por_columna >= mas_larga + margen else 1
