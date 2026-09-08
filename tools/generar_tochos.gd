# ============================================================
#  generar_tochos.gd  --  HERRAMIENTA, no parte del juego.
#
#  Escribe los .tres de los TOCHOS en resources/consumables/tochos/ a partir de la TABLA de aqui
#  abajo. Es un generador y no treinta ficheros escritos a mano porque el dia del pase de textos
#  vas a querer releerlos y retocarlos TODOS SEGUIDOS, no abrir treinta ficheros de cinco lineas.
#  Añadir un tocho nuevo es una linea en TOCHOS y volver a pasar esto.
#
#  Es idempotente: reescribe lo que ya hay y no borra nada. El `id` es la clave de la biblioteca
#  (Game.biblioteca) y NO se puede cambiar una vez publicado — cambiarlo le borra la entrada a
#  quien ya lo hubiera leido. El titulo y el texto si se pueden retocar cuando quieras.
#
#    godot --headless --path . res://tools/generar_tochos.tscn
#  o doble clic en herramientas/generar_tochos.bat
# ============================================================
extends Node

const DESTINO := "res://resources/consumables/tochos/"

# EL TONO, para el que venga a añadir el 31: se sostiene el respeto por algo inutil durante todo el
# libro y la ULTIMA frase lo tira abajo. Nunca un guiño a camara, nunca un chiste explicado. Es el
# registro del kebab de rata ("Nadie pregunta que lleva dentro, y todos repiten").
#
# PROVISIONALES: hoy no hay mundo escrito, asi que ninguno ata geografia, nombres propios ni
# historia. Solo se apoyan en lo que YA existe (ratas, kebab, gremio, pisos, humedad). Cuando el
# mundo este decidido, esta tabla es el sitio donde repasarlos.
#
#   id      - clave de la biblioteca. INMUTABLE una vez publicado.
#   nombre  - el titulo que ves en la bolsa.
#   texto   - lo que lees. Un parrafo, con el remate al final.
#   precio  - lo que te pagan por el sin leer. Calderilla en los de relleno.
#   excelia - 0 = relleno (el 65%). > 0 = TOMO DE SABIDURIA (el 25%): da excelia magica al leerlo.
const TOCHOS := [
	# --- RELLENO (el 65%) ---
	{"id": "humedad", "nombre": "Sobre la humedad", "precio": 30, "excelia": 0.0,
	"texto": "Un tratado sobre cómo proteger un libro de la humedad de los pisos bajos. Recomienda envolverlo en cuero curtido, guardarlo lejos del suelo y no bajarlo nunca a una mazmorra. Las últimas doce páginas están pegadas entre sí."},

	{"id": "rata_comun", "nombre": "Tratado de la rata común", "precio": 35, "excelia": 0.0,
	"texto": "Describe a la rata de mazmorra con un respeto que raya en el cariño: su tenacidad, su vista, su manera de organizarse. El autor insiste varias veces en que es un animal profundamente incomprendido. El último capítulo explica cómo despiezarla para el kebab."},

	{"id": "rata_segundo", "nombre": "Segundo tratado de la rata común", "precio": 35, "excelia": 0.0,
	"texto": "Continuación del primero, escrita años después. El autor se retracta del último capítulo y le pide disculpas al animal por escrito. Luego incluye dos recetas más."},

	{"id": "inventario_almacen", "nombre": "Inventario del almacén, tercer intento", "precio": 25, "excelia": 0.0,
	"texto": "Alguien se puso a contar las antorchas del almacén del gremio. A mitad se dio cuenta de que llevaba un rato contando las mismas dos veces. En vez de volver atrás siguió hasta el final y firmó abajo con mucha seguridad."},

	{"id": "guia_descenso", "nombre": "Guía del descenso para principiantes", "precio": 40, "excelia": 0.0,
	"texto": "Doce consejos para sobrevivir tu primer piso, explicados con paciencia y muy buena letra. Son consejos razonables. El autor firma como veterano de tres descensos."},

	{"id": "puertas", "nombre": "Las puertas de la mazmorra", "precio": 30, "excelia": 0.0,
	"texto": "Un estudio sobre por qué las puertas de ahí abajo se abren solas. Considera el aire, la inclinación del suelo, la humedad y el peso de la madera. Descarta por poco serio que las abra algo."},

	{"id": "sopa", "nombre": "Cien maneras de espesar una sopa", "precio": 25, "excelia": 0.0,
	"texto": "Recopilación de métodos para espesar una sopa aguada, cada uno con sus proporciones y sus tiempos. Noventa y siete de ellos son harina. Los otros tres también, pero explicados con más ganas."},

	{"id": "nombrar_espada", "nombre": "De cómo nombrar tu espada", "precio": 45, "excelia": 0.0,
	"texto": "Defiende que un arma sin nombre nunca llega a ser tuya del todo, y propone un método riguroso para elegirlo. El método ocupa treinta páginas. El autor no llegó a nombrar la suya."},

	{"id": "silencio", "nombre": "El silencio en los pisos hondos", "precio": 40, "excelia": 0.0,
	"texto": "Reflexión larga y sincera sobre el silencio de los pisos bajos y lo que le hace a uno por dentro. Está muy bien escrito. En el margen de la última página, otra letra ha apuntado: no es silencio, es que te están escuchando."},

	{"id": "cuentas_gremio", "nombre": "Libro de cuentas, año seco", "precio": 30, "excelia": 0.0,
	"texto": "Ingresos y gastos anotados con una pulcritud admirable, columna a columna. Cuadran hasta el último cobre. En ningún sitio pone de qué gremio."},

	{"id": "botas", "nombre": "Cuidado y conservación de la bota de cuero", "precio": 35, "excelia": 0.0,
	"texto": "Cómo engrasar, secar y remendar unas botas para que duren una vida entera. El método es bueno y está probado. Quien lo escribió murió con las botas puestas, pero no de viejo."},

	{"id": "croquis", "nombre": "Croquis del piso tercero", "precio": 30, "excelia": 0.0,
	"texto": "Un plano dibujado a mano, con las salas numeradas y las distancias anotadas a pasos. Está muy logrado hasta la mitad. La segunda mitad es la misma sala repetida once veces."},

	{"id": "setas", "nombre": "Setas comestibles de la roca", "precio": 35, "excelia": 0.0,
	"texto": "Catálogo ilustrado de las setas que crecen en la piedra húmeda, con notas de sabor y textura para cada una. La letra se va torciendo a partir de la seta número seis."},

	{"id": "cortesia", "nombre": "Manual de cortesía para el aventurero", "precio": 40, "excelia": 0.0,
	"texto": "Explica cómo saludar a un compañero de gremio, cómo repartir el botín sin ofender a nadie y cómo declinar una invitación a bajar. Dedica cuarenta páginas al reparto del botín y media al resto."},

	{"id": "goteras", "nombre": "Del agua que gotea", "precio": 25, "excelia": 0.0,
	"texto": "Trescientas observaciones sobre goteras en cuevas, ordenadas por ritmo y por sonido. Es un trabajo de una paciencia enorme. Nadie lo pidió."},

	{"id": "antorchas", "nombre": "Sobre la duración de las antorchas", "precio": 35, "excelia": 0.0,
	"texto": "Mide con reloj cuánto dura cada tipo de antorcha y lo resume en una tabla muy clara. Los números son fiables. Están tomados todos en una habitación de la superficie, con la ventana abierta."},

	{"id": "suenos", "nombre": "Los sueños del que duerme abajo", "precio": 40, "excelia": 0.0,
	"texto": "Recoge los sueños que dicen tener los que duermen en la mazmorra, con la fecha y el piso de cada uno. Se repiten muchísimo. El autor concluye que es la mala postura."},

	{"id": "escaleras", "nombre": "Tratado de las escaleras", "precio": 30, "excelia": 0.0,
	"texto": "Sobre por qué las escaleras de la mazmorra bajan siempre y nunca suben del todo igual. Es una observación interesante y está bien argumentada. Termina diciendo que seguramente sean imaginaciones suyas."},

	{"id": "versos_pozo", "nombre": "Versos del pozo", "precio": 25, "excelia": 0.0,
	"texto": "Ochenta poemas breves sobre la vida bajo tierra. Riman todos en -or. El prólogo avisa de que el autor conocía otras rimas y eligió esta."},

	{"id": "cartas", "nombre": "Cartas que no se enviaron", "precio": 45, "excelia": 0.0,
	"texto": "Un fajo de cartas escritas desde la mazmorra y nunca mandadas, cosidas después en forma de libro. Todas empiezan pidiendo perdón por tardar en escribir."},

	{"id": "piedra_tacto", "nombre": "Reconocimiento de la piedra por el tacto", "precio": 35, "excelia": 0.0,
	"texto": "Enseña a distinguir seis tipos de roca pasando la mano, sin luz. El método es real y funciona. Requiere haber tocado antes las seis con luz."},

	{"id": "precio_kebab", "nombre": "Del precio justo del kebab", "precio": 30, "excelia": 0.0,
	"texto": "Alegato larguísimo a favor de bajar el precio del kebab de rata, con números, comparativas y una carta abierta al cocinero. La carta está sin firmar. El precio sigue igual."},

	{"id": "perro", "nombre": "El perro que bajó", "precio": 45, "excelia": 0.0,
	"texto": "Historia verídica de un perro que siguió a su dueño hasta el piso cuarto y volvió solo. Está contada con mucho cariño y ocupa muy poco. No dice qué fue del dueño."},

	{"id": "indice_biblioteca", "nombre": "Índice general de la biblioteca", "precio": 30, "excelia": 0.0,
	"texto": "Lista alfabética de todos los volúmenes de la biblioteca del gremio, con su estante y su número de orden. Es de una utilidad enorme. La biblioteca ardió."},

	# --- TOMOS DE SABIDURIA (el 25%): dan excelia magica Y un CONSEJO DE VERDAD. El chiste va al
	# reves — el libro te enseña algo a pesar de si mismo, o sin darse cuenta de que lo enseña.
	#
	# LA REGLA DE LOS NUMEROS: aqui NO va ni una cifra. Ni "28 de energia", ni "un 15% de vida", ni
	# el nombre de una constante. Un consejo se da en direccion ("mas del que gastas"), no en
	# unidades: si el balance se mueve —y se va a mover— un texto con numeros se queda mintiendo y
	# nadie se acuerda de venir a corregirlo. Es la misma norma que ya siguen las fichas del juego.
	#
	# LA OTRA REGLA: el consejo tiene que ser CIERTO. Cada uno de estos seis esta contrastado contra
	# el codigo, no contra lo que uno cree recordar. Si tocas la mecanica, el tomo se corrige aqui.
	{"id": "respiracion", "nombre": "De la respiración del que combate", "precio": 180, "excelia": 18.0,
	"texto": "Cuarenta páginas quejándose de los aventureros jóvenes que encadenan habilidades hasta quedarse secos. El tono es insoportable. El consejo, en cambio, es bueno: prueba a meter un ataque básico de vez en cuando para descansar un poco, que recupera más aliento del que gastas en cubrirte."},

	{"id": "errores_propios", "nombre": "Mis errores, por un archimago", "precio": 200, "excelia": 22.0,
	"texto": "Un archimago repasa los errores más graves de su carrera, uno por capítulo y sin ahorrarse ninguno. En uno se pasó una batalla entera cubriéndose de un rival que pegaba críticos, convencido de que así no le entraba ninguno. Su consejo: cúbrete igualmente, que ayuda bastante, pero no te fíes — alguno te va a entrar."},

	{"id": "guardia", "nombre": "Tratado de la guardia", "precio": 180, "excelia": 18.0,
	"texto": "Defiende que aguantar es un oficio como otro cualquiera y que nadie lo entrena a propósito. Al final va al grano: si quieres que tu cuerpo aprenda a recomponerse solo, prueba a parar los golpes con la guardia arriba en vez de esquivarlos todos. Esquivando no se aprende nada, dice, y se queda tan ancho."},

	{"id": "estoque_rodela", "nombre": "Del estoque y la rodela", "precio": 180, "excelia": 18.0,
	"texto": "Discusión larguísima entre dos maestros de armas sobre cuál de los dos devuelve mejor un golpe. No se ponen de acuerdo en nada, pero coinciden sin querer en el consejo: prueba el estoque si lo tuyo es esquivar y la rodela si lo tuyo es bloquear, porque cada uno contesta en un momento distinto. Con la guardia baja no contesta ninguno."},

	{"id": "actas_torre", "nombre": "Actas de la torre, sesión decimosexta", "precio": 180, "excelia": 18.0,
	"texto": "Acta de una reunión de magos discutiendo durante horas si la Resistencia le sirve de algo a quien no piensa dejarse tocar ni una vez. No llegan a ningún acuerdo. Uno suelta de pasada que prueben a subirla igualmente, que además de aguantar golpes te engorda la vida, y nadie le lleva la contraria porque ya era muy tarde."},

	{"id": "boticario", "nombre": "Del despilfarro del boticario", "precio": 180, "excelia": 18.0,
	"texto": "Un boticario arruinado explica, con mucho rencor, por qué la gente gasta el triple de pociones de las que necesita. Su consejo, entre insulto e insulto: prueba a esperar un poco después de beberte una, que la cura va cayendo sola y el impaciente se bebe la siguiente encima de la anterior. Se le nota que le ha costado dinero."},
]

# Los GRIMORIOS entran en la biblioteca igual que los tochos, pero NO se generan aqui: ya existen,
# ya tienen su texto escrito ("Un tomo que gotea aunque lleve dias cerrado...") y ese texto ES el
# que lees al estudiarlo. Lo unico que les falta es la clave de la biblioteca, y se la pone el
# parcheo de abajo derivandola del nombre del fichero: grimorio_rayo.tres -> &"grimorio_rayo".
const GRIMORIOS_DIR := "res://resources/consumables/"
const SPELLS_DIR := "res://resources/spells/"

# LA RAREZA DE CADA HECHIZO, que es lo que manda el reparto del gacha (ver Game.pesos_grimorio).
# Se escribe aqui y se vuelca al .tres: tenerlas juntas es lo unico que deja mirar la tabla entera
# de un vistazo y decidir si Tormenta esta donde tiene que estar.
#
# NO va por numero de frases. Se penso y no vale: Tormenta y los mantos recitan lo mismo y no estan
# ni de lejos al mismo nivel. El largo del recitado es largo, no poder.
#
# 'pulso_menor' figura pero NO tiene grimorio ni sale en el gacha: es la magia que presta el baston,
# y regalar el libro de algo que ya viene con el arma no tiene sentido. Se le pone rareza igual por
# si algun dia sale por otra via.
const RAREZAS := {
	# Los de una frase: lo primero que cae y lo que hace jugable a un mago.
	"descarga": Upgrades.Rareza.COMUN,
	"brasa": Upgrades.Rareza.COMUN,
	"rocio": Upgrades.Rareza.COMUN,
	# La cura de UNO. Poco comun y no comun: llega tarde a proposito, para que las pociones sigan
	# valiendo al principio.
	"vendaje_de_luz": Upgrades.Rareza.POCO_COMUN,
	"pulso_menor": Upgrades.Rareza.COMUN,
	# Ataque medio de los tres elementos, y el arcano sin elemento.
	"pulso_arcano": Upgrades.Rareza.POCO_COMUN,
	"chorro_agua": Upgrades.Rareza.POCO_COMUN,
	"bola_fuego": Upgrades.Rareza.POCO_COMUN,
	"rayo": Upgrades.Rareza.POCO_COMUN,
	# Potenciacion, debuff y los FILOS. Los filos van aqui y los mantos un escalon por encima: son
	# dos familias distintas de imbuicion y no valen lo mismo.
	"fortaleza": Upgrades.Rareza.RARO,
	"debilidad": Upgrades.Rareza.RARO,
	"filo_ardiente": Upgrades.Rareza.RARO,
	"filo_fulgurante": Upgrades.Rareza.RARO,
	"filo_torrente": Upgrades.Rareza.RARO,
	# Los MANTOS, y los dos de LUZ y OSCURIDAD, que son ataque puro de su elemento.
	"estallido_solar": Upgrades.Rareza.EPICO,
	"luz_restauradora": Upgrades.Rareza.EPICO,
	"voragine_sombra": Upgrades.Rareza.EPICO,
	"manto_brasas": Upgrades.Rareza.EPICO,
	"manto_centellas": Upgrades.Rareza.EPICO,
	"manto_marea": Upgrades.Rareza.EPICO,
	# EL TECHO. Son DOS desde que existe el Shock termico, y ese es el caso que el diseño del reparto
	# prometia: al entrar el segundo, cada uno pasa a salir la mitad sin tocar un solo numero.
	"tormenta": Upgrades.Rareza.LEGENDARIO,
	"shock_termico": Upgrades.Rareza.LEGENDARIO,
	# MITICO: la banda de encima del legendario, y de momento con un solo hechizo. Sale la mitad que
	# un legendario, o sea una de cada cien tiradas de grimorio.
	# OJO CON SUS FRASES: el recitado del Eclipse es un MEME y es PROVISIONAL. Lleva una marca
	# registrada ajena escrita tal cual, asi que NO puede salir en una version publicada -- va contra
	# la norma de no meter referencias externas en la UI, y ademas es de otro. Esta puesto porque el
	# autor lo pidio asi mientras se prueba el gacha, y hay que cambiarlo en el pase de textos.
	"eclipse": Upgrades.Rareza.MITICO,
}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DESTINO)
	var script: Script = load("res://scripts/items/consumable_data.gd")
	var ids := {}
	var n_relleno := 0
	var n_sabio := 0
	for t in TOCHOS:
		var id: String = str(t["id"])
		if ids.has(id):
			printerr("[tochos] ID REPETIDO: %s. Dos tochos con la misma clave se pisan la entrada de la biblioteca." % id)
			get_tree().quit(1)
			return
		ids[id] = true

		var c: ConsumableData = ConsumableData.new()
		c.set_script(script)
		c.nombre = str(t["nombre"])
		c.descripcion = str(t["texto"])
		c.tomo_id = StringName(id)
		c.excelia_magia = float(t["excelia"])
		c.valor_base = int(t["precio"])
		# Un tocho no cura, no da maná y no tiquea nada: los campos de poción se dejan a cero, igual
		# que hacen el grimorio y el cebo.
		c.cura_total = 0.0
		c.turnos = 0
		c.segundos = 0.0

		var ruta: String = "%s%s.tres" % [DESTINO, id]
		var err: int = ResourceSaver.save(c, ruta)
		if err != OK:
			printerr("[tochos] no se pudo escribir %s (error %d)" % [ruta, err])
			get_tree().quit(1)
			return
		if c.es_tomo_sabio():
			n_sabio += 1
		else:
			n_relleno += 1

	print("[tochos] %d escritos en %s (%d de relleno, %d de sabiduría)." % [
		TOCHOS.size(), DESTINO, n_relleno, n_sabio])
	_barrer_huerfanos(ids)
	if not _marcar_grimorios():
		get_tree().quit(1)
		return
	if not _poner_rarezas():
		get_tree().quit(1)
		return
	if not _cuadrar_grimorios():
		get_tree().quit(1)
		return
	if not _escribir_manifiesto():
		get_tree().quit(1)
		return
	get_tree().quit(0)


# EL MANIFIESTO de todos los libros, para que la Biblioteca pueda pintar TAMBIEN los que aun no
# tienes (en negro, como el libro del Pescador con los peces que te faltan).
#
# Hace falta una lista escrita y no un escaneo de la carpeta porque DirAccess sobre res:// no es de
# fiar en el .exe — es exactamente el motivo por el que existe Game._MANIFIESTO_PLANTILLAS. Y se
# GENERA en vez de mantenerse a mano justamente para que no se quede corta: una lista a mano se
# olvida el dia que añades un tocho, y entonces la coleccion dice "29 de 29" para siempre.
func _escribir_manifiesto() -> bool:
	var tochos: Array = []
	for t in TOCHOS:
		tochos.append("%s%s.tres" % [DESTINO, str(t["id"])])
	tochos.sort()
	var grimorios: Array = []
	var d := DirAccess.open(GRIMORIOS_DIR)
	if d == null:
		return false
	for f in d.get_files():
		if f.begins_with("grimorio_") and f.ends_with(".tres"):
			grimorios.append(GRIMORIOS_DIR + f)
	grimorios.sort()

	var txt := "# ============================================================\n"
	txt += "#  libros.gd  --  GENERADO por tools/generar_tochos.gd. NO EDITAR A MANO.\n"
	txt += "#\n"
	txt += "#  La lista de TODOS los libros que existen, para que la Biblioteca pueda enseñar los que\n"
	txt += "#  te faltan y no solo los que tienes. Va escrita y no escaneada porque DirAccess sobre\n"
	txt += "#  res:// no es de fiar en el .exe (mismo motivo que Game._MANIFIESTO_PLANTILLAS).\n"
	txt += "#\n"
	txt += "#  Para cambiarla: toca la tabla de tools/generar_tochos.gd y vuelve a pasar\n"
	txt += "#  herramientas/generar_tochos.bat.\n"
	txt += "# ============================================================\n\n"
	# TODOS los hechizos que existen. No es solo para la biblioteca: lo usa el panel de DEBUG para
	# poder equipar cualquiera sin que nadie tenga que apuntarlo a mano. Antes eso era una lista
	# clavada en Game._dev_spells, y el primer hechizo nuevo que se creo (el Shock termico) no se
	# podia ni probar porque no estaba en ella.
	var hechizos: Array = []
	for id in RAREZAS:
		hechizos.append("%s%s.tres" % [SPELLS_DIR, id])
	hechizos.sort()

	txt += "class_name Libros\n\n"
	txt += "# Todos los hechizos del juego. La fuente es la tabla RAREZAS de tools/generar_tochos.gd,\n"
	txt += "# que ya falla si un .tres de la carpeta no esta apuntado: por ahi no se puede quedar corta.\n"
	txt += "const HECHIZOS: Array[String] = [\n"
	for r in hechizos:
		txt += "\t\"%s\",\n" % r
	txt += "]\n\nconst TOCHOS: Array[String] = [\n"
	for r in tochos:
		txt += "\t\"%s\",\n" % r
	txt += "]\n\nconst GRIMORIOS: Array[String] = [\n"
	for r in grimorios:
		txt += "\t\"%s\",\n" % r
	txt += "]\n\n\n"
	txt += "# Los 46 de golpe, que es lo que recorre la Biblioteca.\n"
	txt += "static func todos() -> Array[String]:\n"
	txt += "\tvar out: Array[String] = []\n"
	txt += "\tout.append_array(GRIMORIOS)\n"
	txt += "\tout.append_array(TOCHOS)\n"
	txt += "\treturn out\n"

	var f2 := FileAccess.open("res://scripts/core/libros.gd", FileAccess.WRITE)
	if f2 == null:
		printerr("[manifiesto] no puedo escribir scripts/core/libros.gd")
		return false
	f2.store_string(txt)
	f2.close()
	print("[manifiesto] scripts/core/libros.gd: %d grimorios + %d tochos = %d libros." % [
		grimorios.size(), tochos.size(), grimorios.size() + tochos.size()])
	return true


# QUE HECHIZOS LLEVAN GRIMORIO. Es lo que define el pool del gacha, asi que se cuadra aqui y no a
# mano: un hechizo sin libro no puede salir nunca, y uno con libro de mas ensucia el reparto.
#
# 'pulso_menor' NO lleva: viene de serie con el baston y la varita (ver WeaponData.hechizo_base), y
# regalar el libro de algo que ya te presta el arma no tiene sentido. Ojo al efecto de quitarlo:
# pulso_menor deja de poderse APRENDER para siempre — si sueltas el arma, lo pierdes. Es lo buscado.
const SIN_GRIMORIO := ["pulso_menor"]

# El texto de un grimorio nuevo. Mismo patron que los 16 que ya habia: como es el libro al tacto, y
# la formula "Estudialo y aprenderas X" al final.
const TEXTOS_GRIMORIO := {
	"tormenta": "Un volumen que hay que sujetar con las dos manos y que nunca se deja abrir del todo por la misma pagina. Las tapas estan alabeadas, como si dentro hiciera su propio tiempo. Estudialo y aprenderas Tormenta.",
	"vendaje_de_luz": "Un cuadernillo de tapas blandas con una cruz cosida en el lomo. Se le nota el uso: alguien lo ha abierto muchas veces y siempre por la misma pagina. Estudialo y aprenderas Vendaje de luz.",
	"luz_restauradora": "Un tomo claro que no coge polvo. Da igual donde lo dejes y cuanto tiempo pase. Estudialo y aprenderas Luz restauradora.",
	"estallido_solar": "Un tomo de tapas palidas que cuesta mirar de frente si le da la luz de una vela. Las paginas estan gastadas justo por el centro, como si alguien hubiera leido siempre el mismo parrafo. Estudialo y aprenderas Estallido solar.",
	"voragine_sombra": "Un tomo que pesa mas de lo que deberia por su tamaño, y que si lo dejas en una mesa acaba en el borde. Nadie recuerda haberlo movido. Estudialo y aprenderas Voragine de sombra.",
	"eclipse": "Dos tomos cosidos en uno, uno claro y otro oscuro, y no hay forma de saber donde acaba el primero. La costura esta hecha por dentro. Estudialo y aprenderas Eclipse.",
	"shock_termico": "Un tomo que quema por una tapa y hiela por la otra, y que en el medio esta a temperatura de sala. Nadie ha conseguido dejarlo apoyado del lado frio mas de un rato. Estudialo y aprenderas Shock termico fulminante.",
}


func _cuadrar_grimorios() -> bool:
	var d := DirAccess.open(SPELLS_DIR)
	if d == null:
		return false
	var creados := 0
	var borrados := 0
	for f in d.get_files():
		if not f.ends_with(".tres"):
			continue
		var id: String = f.get_basename()
		var ruta_g: String = "%sgrimorio_%s.tres" % [GRIMORIOS_DIR, id]
		var existe: bool = ResourceLoader.exists(ruta_g)
		if SIN_GRIMORIO.has(id):
			if existe:
				print("[grimorios] %s viene con el arma: se borra su libro." % id)
				DirAccess.remove_absolute(ruta_g)
				borrados += 1
			continue
		if existe:
			continue
		# Falta el libro de un hechizo que si deberia tenerlo.
		if not TEXTOS_GRIMORIO.has(id):
			printerr("[grimorios] falta el libro de '%s' y no hay texto para el. Escribelo en TEXTOS_GRIMORIO." % id)
			return false
		var s: SpellData = load(SPELLS_DIR + f) as SpellData
		if s == null:
			continue
		var c: ConsumableData = ConsumableData.new()
		c.set_script(load("res://scripts/items/consumable_data.gd"))
		c.nombre = "Grimorio: %s" % s.nombre
		c.descripcion = str(TEXTOS_GRIMORIO[id])
		c.spell = s
		c.tomo_id = StringName("grimorio_" + id)
		c.cura_total = 0.0
		c.turnos = 1
		c.segundos = 1.0
		# PROVISIONAL, como todo precio de aqui: se pone en el orden de magnitud de los que ya hay
		# (1700-2920) y se cuadra con la curva entera, no a ojo.
		c.valor_base = 4200
		var err: int = ResourceSaver.save(c, ruta_g)
		if err != OK:
			printerr("[grimorios] no se pudo crear %s (error %d)" % [ruta_g, err])
			return false
		print("[grimorios] creado el libro de %s." % id)
		creados += 1
	print("[grimorios] cuadrados: %d creados, %d borrados." % [creados, borrados])
	return true


# Vuelca RAREZAS a los .tres de los hechizos. Avisa —y falla— si la tabla y la carpeta no dicen lo
# mismo en los dos sentidos: un hechizo sin rareza saldria como comun sin que nadie lo decidiera, y
# una entrada que sobra suele ser un fichero renombrado que dejo la tabla apuntando al vacio.
func _poner_rarezas() -> bool:
	var d := DirAccess.open(SPELLS_DIR)
	if d == null:
		printerr("[rarezas] no puedo abrir %s" % SPELLS_DIR)
		return false
	var vistos := {}
	var n := 0
	for f in d.get_files():
		if not f.ends_with(".tres"):
			continue
		var id: String = f.get_basename()
		vistos[id] = true
		if not RAREZAS.has(id):
			printerr("[rarezas] '%s' no esta en la tabla: saldria comun sin que nadie lo decida." % id)
			return false
		var s: SpellData = load(SPELLS_DIR + f) as SpellData
		if s == null:
			continue
		if int(s.rareza) == int(RAREZAS[id]):
			continue
		s.rareza = int(RAREZAS[id])
		var err: int = ResourceSaver.save(s, SPELLS_DIR + f)
		if err != OK:
			printerr("[rarezas] no se pudo escribir %s (error %d)" % [f, err])
			return false
		n += 1
	var sobran: Array = []
	for id in RAREZAS:
		if not vistos.has(id):
			sobran.append(id)
	if not sobran.is_empty():
		printerr("[rarezas] la tabla nombra hechizos que no existen: %s" % ", ".join(sobran))
		return false
	# El reparto que sale de la tabla, para poder juzgarla sin abrir el visor.
	var cuenta := {}
	for id in RAREZAS:
		var r: int = int(RAREZAS[id])
		cuenta[r] = int(cuenta.get(r, 0)) + 1
	print("[rarezas] %d hechizos actualizados. Por banda: %s" % [n, cuenta])
	return true


# Borra los .tres de la carpeta que YA NO ESTAN en la tabla. Hace falta porque renombrar un id deja
# el fichero viejo en disco, y ese fichero se sigue cargando: la primera vez que paso esto la
# carpeta tenia 33 tochos y tres tomos de sabiduria fantasma que nadie habia escrito.
#
# Solo barre DESTINO, que es una carpeta 100% generada: aqui no vive nada escrito a mano.
func _barrer_huerfanos(vivos: Dictionary) -> void:
	var d := DirAccess.open(DESTINO)
	if d == null:
		return
	var fuera: Array = []
	for f in d.get_files():
		if not f.ends_with(".tres"):
			continue
		if not vivos.has(f.get_basename()):
			fuera.append(f)
	for f in fuera:
		# Se dice EN VOZ ALTA lo que se tira: un borrado callado en una herramienta es como se
		# pierde un texto que alguien habia escrito a mano en el sitio equivocado.
		print("[tochos] sobra y se borra: %s" % f)
		DirAccess.remove_absolute(DESTINO + f)
	if fuera.is_empty():
		print("[tochos] no sobraba ninguno.")


# Le pone su clave de biblioteca a cada grimorio que no la tenga. NO les toca el texto: el que ya
# tienen ("Un tomo que gotea aunque lleve dias cerrado...") es exactamente el que se lee al
# estudiarlo, y reescribirlo desde aqui seria tirar a la basura los que ya estaban escritos.
#
# La clave sale del NOMBRE DEL FICHERO y no del titulo: el titulo se puede retocar en el pase de
# textos, y una clave que cambia le borra la entrada a quien ya lo hubiera leido.
func _marcar_grimorios() -> bool:
	var d := DirAccess.open(GRIMORIOS_DIR)
	if d == null:
		printerr("[tochos] no puedo abrir %s" % GRIMORIOS_DIR)
		return false
	var n := 0
	var ya := 0
	for f in d.get_files():
		if not f.begins_with("grimorio_") or not f.ends_with(".tres"):
			continue
		var ruta: String = GRIMORIOS_DIR + f
		var c: ConsumableData = load(ruta) as ConsumableData
		if c == null:
			continue
		var id := StringName(f.get_basename())
		if c.tomo_id == id:
			ya += 1
			continue
		c.tomo_id = id
		var err: int = ResourceSaver.save(c, ruta)
		if err != OK:
			printerr("[tochos] no se pudo marcar %s (error %d)" % [ruta, err])
			return false
		n += 1
	print("[tochos] grimorios en la biblioteca: %d marcados, %d ya lo estaban." % [n, ya])
	return true
