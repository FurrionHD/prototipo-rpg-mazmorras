# ============================================================
#  jugador_sprites.gd  (class_name JugadorSprites)
#  EL REGISTRO DEL PERSONAJE: dice QUE CAPAS hay que apilar y en que orden. Nada mas.
#
#  Es el hermano de SpritesEnemigo, y existe por lo mismo: la decision de que se dibuja tiene que
#  estar en UN sitio, porque la necesitan cuatro -- el jugador del mapa, el compañero, el jugador
#  remoto del otro y la figura de combate. Cuatro copias de la misma regla acaban divergiendo, y
#  ahi la consecuencia es que cada pantalla te enseña a la misma persona con otra ropa.
#
#  NO ES EL MISMO REGISTRO QUE EL DE LOS BICHOS, y no se podia reutilizar: aquel despacha UN
#  generador por enemigo (un slime se dibuja entero con SlimeSprites), y aqui son muchos a la vez
#  sobre el mismo cuerpo. Un bicho es un dibujo; un personaje es una pila.
#
#  COMO CRECE (que es lo que hay que saber para las fases que faltan): una pieza de armadura nueva
#  es UNA linea en su tabla. El despacho va por MOLDE, y el molde sale del propio item si lo trae
#  (ArmorData.sprite_molde) o, si no, de su categoria -- exactamente como SpritesEnemigo deja que el
#  nombre gane a la familia. Hoy todo cae por categoria y no hay ni un molde propio; el dia que una
#  armadura concreta quiera su dibujo, no hay que tocar nada mas.
# ============================================================

extends RefCounted
class_name JugadorSprites

# LAS CAPAS, DE ABAJO ARRIBA. El orden de esta lista es el orden de apilado por defecto; la
# profundidad fina (que el escudo se vaya detras del cuerpo al mirar al este) NO se decide aqui sino
# fotograma a fotograma, preguntandole a PoseJugador por donde cae su punto de anclaje.
#
# 'piezas' = de cuantos trozos separados PUEDE constar la capa. No es adorno: es lo que hace que el
# validador de islas del horno sirva para algo. El cuerpo es UNA pieza siempre -- si sale en dos, se
# ha despegado algo --, pero unas botas son DOS y unos guanteletes tambien, y sin declararlo el
# validador daria un aviso por cada fotograma de cada bota del juego y acabaria ignorandose.
enum Ranura { CUERPO, PANTALONES, BOTAS, PECHO, MANOS, CARA, CASCO, MANO_DER, MANO_IZQ,
	ARMA_CADERA, ARMA_ESPALDA }

# 'tinte' = si esta capa se pinta con un color de fuera (ver MunecoJugador.tenir). Casi todas lo
# haran: una armadura de hierro y una epica son el mismo dibujo con otro tinte, y de ahi sale que
# haya ~35 atlas en vez de miles.
#
# EL CUERPO ES LA EXCEPCION Y VA EN false. La carne tiene su color y no es el que elegiste: teñida,
# la piel salia del color del personaje entero y lo que se veia no era alguien vestido de azul sino
# una estatua azul. Se hornea ya en color de piel y se deja pasar tal cual (ver la cabecera de
# cuerpo_sprites.gd). El color que elegiste no se pierde: es el de la ROPA.
# LOS 'z' SON FIJOS PARA TODO LO QUE VISTE EL EJE DEL CUERPO, y no un adorno: ver la nota larga de
# MunecoJugador._ordenar. Resumen: el ancla de estas capas esta en x=0, asi que su profundidad es
# cero -- hasta que la pose inclina el tronco y la vuelve negativa, y entonces la prenda se va DEBAJO
# del cuerpo. Solo pasaba andando y de espaldas.
#
#   1 cuerpo  ·  2 piernas  ·  3 torso  ·  2047 pelo  ·  2048 cara  ·  2049 tu foto
const Z_CUERPO := 1
const Z_PIERNAS := 2
const Z_TORSO := 3
const Z_PELO := 2047
const Z_CARA := 2048

# EL ARMA ENVAINADA (espalda o cadera). NO lleva doble posicion de z: ArmaSprites decide por
# DIRECCION si se dibuja o no (ver _visible_envainada), y cuando se dibuja va SIEMPRE delante del
# cuerpo. Por debajo del pelo que cuelga (2046): de espaldas, la melena tapa la parte alta del
# mandoble, que es lo que hace de verdad.
const Z_ARMA_ESPALDA_DELANTE := 2043
const Z_ARMA_CADERA_DELANTE := 5       # justo por encima de la ropa (torso va a 3)

static var CAPAS := [
	{"ranura": Ranura.CUERPO, "clave": "cuerpo", "gen": CuerpoSprites, "piezas": 1,
		"ancla": PoseJugador.P_CADERA, "tinte": false, "z": Z_CUERPO},
]

# ============================================================
#  LOS CATALOGOS: que MODELOS hay para cada pieza que se elige
# ============================================================
# Una pieza del aspecto (ver PersonajeData.PIEZAS) tiene varios modelos, y el jugador escoge uno en
# la pantalla de creacion. Todos los modelos de una pieza comparten generador y ancla: lo unico que
# cambia es COMO se dibuja, y eso lo decide el propio generador segun el nombre del modelo.
#
# 'piezas' es POR MODELO y no por ranura, y esa es la diferencia que hace que el validador de islas
# del horno siga sirviendo: una melena es un trozo y una coleta son dos, y sin declararlo cada
# fotograma de cada peinado soltaria un aviso hasta que nadie los leyera.
#
# 'nombre' es como se llama en la pantalla de creacion, y vive AQUI y no en el menu: la lista de lo
# que se puede elegir tiene que salir del mismo sitio que la lista de lo que se sabe dibujar, o el
# dia que se añada un peinado habra que acordarse de dos sitios y el menu enseñara seis de siete.
# La opcion "no llevar nada" no esta en la tabla: es el modelo vacio, y lo pone la pantalla.
#
# 'clave' de la capa = "<pieza>_<modelo>" ("pelo_coleta"), que es tambien el nombre del atlas en
# disco. El modelo vacio ("") es "no lleva nada" y no genera capa ni atlas.
static var CATALOGO := {
	"piernas": {
		"ranura": Ranura.PANTALONES, "gen": RopaSprites, "ancla": PoseJugador.P_CADERA,
		"z": Z_PIERNAS, "titulo": "Pantalón", "sin_nada": "Sin nada",
		"modelos": {
			"pantalon": {"piezas": 1, "nombre": "Pantalón"},
			"bombacho": {"piezas": 1, "nombre": "Bombacho"},
			"faldon": {"piezas": 1, "nombre": "Faldón"},
		},
	},
	"torso": {
		"ranura": Ranura.PECHO, "gen": RopaSprites, "ancla": PoseJugador.P_TORSO,
		"z": Z_TORSO, "titulo": "Camisa", "sin_nada": "Sin nada",
		"modelos": {
			"camisa": {"piezas": 1, "nombre": "Camisa"},
			"tunica": {"piezas": 1, "nombre": "Túnica"},
			"chaleco": {"piezas": 1, "nombre": "Chaleco"},
		},
	},
	"pelo": {
		"ranura": Ranura.CASCO, "gen": PeloSprites, "ancla": PoseJugador.P_CABEZA,
		"titulo": "Pelo", "sin_nada": "Calvo",
		# EL PELO NO SE ORDENA POR PROFUNDIDAD, y no es un atajo: la cabeza esta en x=0, asi que su
		# profundidad es casi cero en las ocho direcciones y el signo lo decidiria el redondeo -- se
		# veria el pelo por detras de la propia cabeza en unas direcciones y no en otras. Es el mismo
		# motivo por el que la cara lleva z fijo (ver MunecoJugador._ordenar).
		# 2047 = justo POR DEBAJO de la cara (2048). Se probo al reves -- el flequillo cayendo sobre
		# tu foto, que es lo que hace un flequillo de verdad -- y es peor: la cara es un circulo del
		# 80% de la cabeza, asi que cualquier pelo que baje lo suficiente para leerse como flequillo
		# se come los ojos. Por debajo, el pelo ENMARCA la foto (queda el anillo de alrededor), que es
		# como lo resuelven los sprites del genero. Godot solo acepta hasta 4096 y pasarse no recorta,
		# rechaza.
		"z": Z_PELO,
		# 'cuelga' = este peinado tiene ademas una capa DETRAS del cuerpo (ver mas abajo).
		"modelos": {
			"rapado": {"piezas": 1, "nombre": "Rapado"},
			"corto": {"piezas": 1, "nombre": "Corto"},
			"bob": {"piezas": 1, "nombre": "Media melena", "cuelga": true},
			"coleta": {"piezas": 1, "nombre": "Coleta", "cuelga": true},
			"largo": {"piezas": 1, "nombre": "Largo", "cuelga": true},
			"mono": {"piezas": 1, "nombre": "Moño"},
		},
	},
	# LA CARA: los ojos y la boca, dibujados como todo lo demas (ver cara_sprites.gd). Es una pieza
	# del catalogo y no un caso aparte, asi que se elige en el creador, se hornea sola y sale en la
	# hoja comparativa igual que un peinado.
	#
	# 'piezas' son los trozos SUELTOS que tiene: dos ojos, y una boca en los estilos que la llevan.
	# Aqui son de verdad piezas separadas (una cara no es una silueta continua), asi que declararlo
	# bien es lo unico que impide que el validador de islas del horno suelte un aviso por fotograma.
	#
	# NO SE TIÑE: unos ojos no son del color de tu ropa.
	"cara": {
		"ranura": Ranura.CARA, "gen": CaraSprites, "ancla": PoseJugador.P_CABEZA,
		"z": Z_CARA, "tinte": false, "titulo": "Cara", "sin_nada": "Sin rasgos",
		"modelos": {
			# LOS TRES LLEVAN BOCA, asi que los tres son 3 trozos: dos ojos y una raya. "puntos" estaba
			# declarado con 2 porque era el unico sin boca, y eso ya no es un estilo (ver CaraSprites).
			"puntos": {"piezas": 3, "nombre": "Ojos simples"},
			"chibi": {"piezas": 3, "nombre": "Con brillo"},
			"linea": {"piezas": 3, "nombre": "Tranquilos"},
		},
	},
}

# LO QUE CUELGA DEL PELO VA EN SU PROPIA CAPA, Y ESA SI SE ORDENA POR PROFUNDIDAD.
#
# El casquete tiene que ir por encima de todo a la fuerza (cuelga de la cabeza, que esta en x=0, y
# ordenarlo por profundidad lo dejaria al azar del redondeo). Pero UNA MELENA NO ES UN CASQUETE: cae
# casi en el plano central del cuerpo, asi que con el mismo z se pintaba sobre el pecho MIRASES HACIA
# DONDE MIRASES. De ahi salian las dos quejas a la vez -- "el pelo largo se ve igual delante que
# detras" y "la camisa solo se ve de frente" --, que eran el mismo fallo.
#
# Esta capa se ancla a la NUCA (PoseJugador.P_NUCA) y de ahi sale la regla sola: de frente la nuca
# queda al fondo -> se pinta DEBAJO del cuerpo; de espaldas queda delante -> se pinta ENCIMA. Sin un
# caso por direccion.
#
# LOS DOS Z SON FIJOS Y NO SALEN DE LA FORMULA de MunecoJugador._ordenar (prof x 4 x 16): la nuca
# esta a diez unidades del eje, asi que esa formula daria z de +-600 -- y estas capas van en z
# ABSOLUTO, o sea que un -600 se cuela por debajo del suelo del piso (z_index -1).
const Z_CUELGA_DELANTE := 2046   # justo por debajo del casquete (2047) y de la cara (2048)
const Z_CUELGA_DETRAS := -1      # entre el suelo del piso y el cuerpo (que va a 0)


# Los SpriteFrames de todas las capas que le tocan a ESTE personaje, ya en orden de apilado, con su
# color y su acabado. Devuelve [{clave, frames, ancla, color, metal, ...}] para que el compositor no
# tenga que saber ni de generadores ni de catalogos.
#
# 'pj' puede ser null (el jugador remoto antes de que llegue su ficha): sale el cuerpo desnudo, que
# es mejor que no dibujar a nadie.
static func capas_de(pj: PersonajeData) -> Array:
	var out: Array = []
	for c in CAPAS:
		var g = c["gen"]
		out.append({"clave": c["clave"], "ranura": c["ranura"], "ancla": c["ancla"],
			"tinte": bool(c.get("tinte", true)), "z": 0, "frames": g.frames(1.0)})
	if pj == null:
		return out
	for nombre in PersonajeData.PIEZAS:
		var cat: Dictionary = CATALOGO.get(nombre, {})
		if cat.is_empty():
			continue
		var p: Dictionary = pj.pieza(nombre)
		var modelo: String = String(p["modelo"])
		# Un modelo que no existe se trata como "no lleva nada" y NO como un error que revienta: por
		# aqui pasan partidas viejas y personajes que llegan por red desde otro build.
		if modelo == "" or not (cat["modelos"] as Dictionary).has(modelo):
			continue
		# LOS RASGOS SOLO SI NO HAY FOTO: con imagen propia, tu imagen ES tu cara, y unos ojos
		# dibujados asomarian por debajo de ella.
		if nombre == "cara" and not pj.imagen.is_empty():
			continue
		# LA QUE CUELGA VA PRIMERO EN LA LISTA: el orden de 'out' desempata entre capas a la misma
		# profundidad, y ademas asi el atlas de detras se monta antes que el de delante.
		if bool((cat["modelos"][modelo] as Dictionary).get("cuelga", false)):
			out.append({"clave": "%s_%s_atras" % [nombre, modelo], "ranura": cat["ranura"],
				"ancla": PoseJugador.P_NUCA, "tinte": true,
				"z": Z_CUELGA_DELANTE, "z_atras": Z_CUELGA_DETRAS,
				"color": p["color"], "metal": p["metal"],
				"frames": cat["gen"].frames(modelo + PeloSprites.SUFIJO_ATRAS, 1.0)})
		out.append({"clave": "%s_%s" % [nombre, modelo], "ranura": cat["ranura"],
			"ancla": cat["ancla"], "tinte": bool(cat.get("tinte", true)),
			"z": int(cat["z"]), "color": p["color"], "metal": p["metal"],
			"frames": cat["gen"].frames(modelo, 1.0)})
	out.append_array(_capas_arma(pj))
	return out


# LAS CAPAS DEL ARMA que lleva este personaje. Salen de equipped_main / equipped_off (ver
# PersonajeData), no del catalogo: el arma es equipo, no aspecto. Se montan SIEMPRE las dos
# versiones (en mano y envainada) porque envainar en el juego solo cambia el nombre de la
# animacion, no la lista de capas -- si dependiera de la lista, el muñeco se reconstruiria cada vez
# que te acercas a un enemigo.
static func _capas_arma(pj: PersonajeData) -> Array:
	var out: Array = []
	_arma_de(out, pj.equipped_main, 0)
	_arma_de(out, pj.equipped_off, 1)
	return out


# 'lado': 0 = mano/cadera derecha (principal), 1 = izquierda (secundaria).
static func _arma_de(out: Array, item, lado: int) -> void:
	if item == null:
		return
	if item is ShieldData:
		_escudo_de(out, item as ShieldData)
		return
	var tn := ""
	var dos_manos := false
	if item is WeaponData:
		if int(item.tipo) == WeaponData.Tipo.PUNOS:
			return
		tn = ArmaSprites.TIPO_NOMBRE[int(item.tipo)]
		dos_manos = bool(item.dos_manos)
	elif item is WandData:
		tn = "varita"
	else:
		return   # otro Resource desconocido: no hay nada que dibujar

	var suf_mano := "der" if lado == 0 else "izq"
	var ancla_mano: StringName = PoseJugador.P_EMPUNADURA_DER if lado == 0 else PoseJugador.P_EMPUNADURA_IZQ
	var ancla_cadera: StringName = PoseJugador.P_CADERA_DER if lado == 0 else PoseJugador.P_CADERA_IZQ

	if tn == "varita":
		# La varita solo cuelga de la cadera: no se desenvaina en el mapa.
		out.append({"clave": "arma_varita_cadera_izq", "ranura": Ranura.ARMA_CADERA,
			"ancla": PoseJugador.P_CADERA_IZQ, "tinte": false,
			"z": Z_ARMA_CADERA_DELANTE,
			"frames": ArmaSprites.frames("arma_varita_cadera_izq", 1.0)})
		return

	if dos_manos:
		out.append({"clave": "arma_%s_mano_der" % tn, "ranura": Ranura.MANO_DER,
			"ancla": PoseJugador.P_EMPUNADURA_DER, "tinte": false,
			"frames": ArmaSprites.frames("arma_%s_mano_der" % tn, 1.0)})
		out.append({"clave": "arma_%s_espalda" % tn, "ranura": Ranura.ARMA_ESPALDA,
			"ancla": PoseJugador.P_ESPALDA, "tinte": false,
			"z": Z_ARMA_ESPALDA_DELANTE,
			"frames": ArmaSprites.frames("arma_%s_espalda" % tn, 1.0)})
		return

	out.append({"clave": "arma_%s_mano_%s" % [tn, suf_mano],
		"ranura": Ranura.MANO_DER if lado == 0 else Ranura.MANO_IZQ,
		"ancla": ancla_mano, "tinte": false,
		"frames": ArmaSprites.frames("arma_%s_mano_%s" % [tn, suf_mano], 1.0)})
	out.append({"clave": "arma_%s_cadera_%s" % [tn, suf_mano], "ranura": Ranura.ARMA_CADERA,
		"ancla": ancla_cadera, "tinte": false,
		"z": Z_ARMA_CADERA_DELANTE,
		"frames": ArmaSprites.frames("arma_%s_cadera_%s" % [tn, suf_mano], 1.0)})


# LAS CAPAS DEL ESCUDO. Solo dos, y ninguna con 'lado' -- un escudo siempre va en la mano
# secundaria (equipped_off), nunca en la principal. Envainado comparte P_ESPALDA con las armas a
# dos manos: nunca chocan, porque equipped_off tiene que ser null si el arma principal es a dos
# manos (ver Game._secundaria_valida) -- por eso reutiliza Z_ARMA_ESPALDA_DELANTE tal cual.
static func _escudo_de(out: Array, sh: ShieldData) -> void:
	var tn: String = EscudoSprites.TAMANO_NOMBRE[clampi(int(sh.tamano), 0,
		EscudoSprites.TAMANO_NOMBRE.size() - 1)]
	out.append({"clave": "escudo_%s_mano_izq" % tn, "ranura": Ranura.MANO_IZQ,
		"ancla": PoseJugador.P_EMPUNADURA_IZQ, "tinte": false,
		"frames": EscudoSprites.frames("escudo_%s_mano_izq" % tn, 1.0)})
	out.append({"clave": "escudo_%s_espalda" % tn, "ranura": Ranura.ARMA_ESPALDA,
		"ancla": PoseJugador.P_ESPALDA, "tinte": false,
		"z": Z_ARMA_ESPALDA_DELANTE,
		"frames": EscudoSprites.frames("escudo_%s_espalda" % tn, 1.0)})


# TODAS las capas que existen, para el horno. No es lo mismo que 'capas_de': aquella son las de UN
# personaje (las que lleva puestas) y esta son todas las que hay que hornear, lleve alguien lo que
# lleve. Confundirlas significa que solo se hornea el traje del ultimo que se creo.
#
# NO GENERA LOS DIBUJOS: devuelve la RECETA de cada capa y quien la quiera llama a 'generar_capa'.
# Cada capa son 41 animaciones de imagenes, y devolverlas ya montadas obligaria a tener las trece en
# memoria a la vez para hornearlas de una en una.
static func todas_las_capas() -> Array:
	var out: Array = []
	for c in CAPAS:
		out.append({"clave": c["clave"], "piezas": int(c["piezas"]), "gen": c["gen"], "modelo": ""})
	for nombre in CATALOGO:
		var cat: Dictionary = CATALOGO[nombre]
		for modelo in (cat["modelos"] as Dictionary):
			out.append({"clave": "%s_%s" % [nombre, modelo],
				"piezas": int((cat["modelos"][modelo] as Dictionary)["piezas"]),
				"gen": cat["gen"], "modelo": String(modelo)})
			# Y su capa de detras, si la tiene: es un atlas mas, con su propia cuenta de trozos.
			if bool((cat["modelos"][modelo] as Dictionary).get("cuelga", false)):
				out.append({"clave": "%s_%s_atras" % [nombre, modelo], "piezas": 1,
					"gen": cat["gen"], "modelo": String(modelo) + PeloSprites.SUFIJO_ATRAS})
	# Las capas de arma: una por (arma, sitio, mano). El horno las dibuja como cualquier otra.
	# 2 piezas: la guarda / cabeza puede quedar como isla propia en algunos angulos (hoja + guarda).
	for clave in ArmaSprites.todas_las_claves():
		out.append({"clave": clave, "piezas": 2, "gen": ArmaSprites, "modelo": clave})
	# Las capas del escudo: 2 piezas (el aro puede quedar como isla propia del cuerpo en algunos
	# angulos, igual que la guarda de un arma).
	for clave in EscudoSprites.todas_las_claves():
		out.append({"clave": clave, "piezas": 2, "gen": EscudoSprites, "modelo": clave})
	return out


# Dibuja una capa de las de arriba. 'generar' y no 'frames' a proposito: quien llama a esto (el
# horno, el visor) quiere el dibujo de AHORA, no el horneado viejo que hay en disco.
static func generar_capa(receta: Dictionary, esc: float = 1.0) -> SpriteFrames:
	var g = receta["gen"]
	if String(receta.get("modelo", "")) == "":
		return g.generar(esc)
	return g.generar(String(receta["modelo"]), esc)


# Que animacion toca. Delega en PoseJugador, que es donde vive la regla: aqui solo se reexporta para
# que quien use este registro no tenga que conocer dos clases.
static func animacion(mirada: Vector2, modo: int, moviendose: bool, golpeando: bool = false,
		desenvainado: bool = false, golpe_variante: int = 0) -> String:
	return PoseJugador.animacion(mirada, modo, moviendose, golpeando, desenvainado, golpe_variante)


static func cadaver(mirada: Vector2) -> String:
	return PoseJugador.cadaver(mirada)


# La caja de colision del personaje, en unidades de mundo. Se queda en los 32x32 de siempre A
# PROPOSITO: el sprite se dibuja alrededor y es mas alto que ancho, pero cambiar la colision movería
# como estorba el personaje en un pasillo, que es cosa de juego y no de dibujo. Si algun dia se
# toca, que sea por una decision de juego y no de refilon al meter arte.
static func tam_cuerpo() -> Vector2:
	return Vector2(32.0, 32.0)
