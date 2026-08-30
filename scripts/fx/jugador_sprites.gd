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
# PELO Y CASCO SON RANURAS DISTINTAS, y hubo que separarlas: el pelo vivia en 'CASCO' de cuando no
# habia cascos, y al entrar los de verdad los dos querian la misma. No es solo un nombre -- lo que
# hay debajo es que un casco NO sustituye al pelo entero (la melena sigue saliendo), asi que las dos
# capas coexisten y necesitan cada una la suya.
enum Ranura { CUERPO, PANTALONES, BOTAS, PECHO, MANOS, CARA, PELO, CASCO, MANO_DER, MANO_IZQ,
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
		# DOS PIEZAS: el pantalon recorta de si mismo el hueco de la mano cuando esta le cae por
		# delante (ver RopaSprites._hueco_brazo), y en algunas poses ese mordisco parte la cinturilla.
		# 'piezas' es el TOPE que se admite sin avisar, no una cuenta exacta.
		"modelos": {
			"pantalon": {"piezas": 2, "nombre": "Pantalón"},
			"bombacho": {"piezas": 2, "nombre": "Bombacho"},
			"faldon": {"piezas": 2, "nombre": "Faldón"},
		},
	},
	"torso": {
		"ranura": Ranura.PECHO, "gen": RopaSprites, "ancla": PoseJugador.P_TORSO,
		"z": Z_TORSO, "titulo": "Camisa", "sin_nada": "Sin nada",
		# DOS PIEZAS Y NO UNA: la prenda recorta de si misma el hueco de la cabeza (ver
		# RopaSprites.HUECO_CABEZA), y en el golpe a dos manos el brazo del fondo cruza la cabeza, asi
		# que la manga queda partida en dos. Eso es lo correcto -- un brazo por detras de la cabeza se
		# ve cortado por ella --, pero con 1 declarado el validador de islas del horno lo cantaba en
		# ocho fotogramas. El chaleco no tiene mangas y siempre es uno, y no pasa nada: 'piezas' es el
		# TOPE que se admite sin avisar, no una cuenta exacta.
		"modelos": {
			"camisa": {"piezas": 2, "nombre": "Camisa"},
			"tunica": {"piezas": 2, "nombre": "Túnica"},
			# El chaleco no tiene mangas, asi que devuelve el brazo recortandolo de si mismo
			# (RopaSprites._hueco_brazo): de perfil ese recorte lo parte en dos.
			"chaleco": {"piezas": 2, "nombre": "Chaleco"},
		},
	},
	"pelo": {
		"ranura": Ranura.PELO, "gen": PeloSprites, "ancla": PoseJugador.P_CABEZA,
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


# ============================================================
#  LOS DOS Z DEL CASCO
# ============================================================
# No hizo falta renumerar nada, y eso no es suerte: es que el casco ocupa EL SITIO QUE DEJA EL PELO.
# Con casco puesto no se pide el casquete (ver capas_de), asi que 2047 esta libre.
#
#   2046/-1 melena  ·  2047 casco abierto  ·  2048 rasgos  ·  2049 tu foto  ·  2050 casco cerrado
#
# UN CASCO ABIERTO (cuero, hierro) va por DEBAJO de la cara: se te ve, y se te ve tu foto si la
# llevas. Por encima de la melena, que es lo correcto -- el pelo sale por debajo del casco, no por
# encima.
const Z_CASCO_ABIERTO := 2047
# UN CASCO CERRADO (hierro completo, placas) va por ENCIMA DE TODO, tu foto incluida. Asi tapa la
# cara SIN que haya que apagarla: los rasgos son una capa que se podria quitar de la lista, pero la
# foto es un Sprite2D aparte que monta MunecoJugador, y alcanzarla desde aqui seria meter una
# excepcion en dos sitios. Tapandola por z, el mismo numero resuelve las dos.
const Z_CASCO_CERRADO := 2050

# LAS PIEZAS DE ARMADURA DEL CUERPO, por encima de la ropa que sustituyen (piernas 2, torso 3).
#
# GREBAS Y BOTAS COMPARTEN Z (4) y no chocan: unas cubren del muslo al tobillo y las otras del
# tobillo abajo, y donde se rozan gana la que va despues en la lista, que son las botas -- que es lo
# correcto, la bota se calza SOBRE la greba.
#
# EL PETO VA A 6 Y NO A 5, dejando el 5 al arma envainada en la cadera (Z_ARMA_CADERA_DELANTE): una
# espada colgada del cinto se ve por delante del faldar, no por detras. Con el peto en 5 se tapaban
# entre si segun el orden de la lista, que es justo lo que no se quiere que decida esto.
const Z_ARMADURA_PIERNAS := 4
const Z_ARMADURA_PECHO := 6

# ============================================================
#  LOS GUANTELETES: DOS POSICIONES, Y NINGUNA POR DEBAJO DEL CUERPO
# ============================================================
# EL SINTOMA ERA "al norte no se ven los guantes, se ve color piel". Iban SIN z, ordenados por la
# profundidad de la mano como el arma que se empuña -- y al norte la mano cae por detras del plano
# del cuerpo (MANO.y = 2,6 mirando al sur se vuelve -2,6 mirando al norte), asi que la capa entera se
# iba DEBAJO del cuerpo y lo que se veia era el brazo desnudo.
#
# Y ESE ORDEN ES CORRECTO PARA UN ARMA Y FALSO PARA UN GUANTELETE. Una espada se SOSTIENE: puede
# quedar por detras de ti y esta bien que se tape. Un guantelete se LLEVA PUESTO -- va pegado a un
# brazo que el cuerpo dibuja siempre encima de si mismo --, asi que no puede caer por debajo del
# cuerpo en ninguna direccion.
#
# Se arregla con el mecanismo que ya existe para la melena (z + z_atras, ver MunecoJugador._ordenar):
# dos posiciones fijas, y la de atras TAMBIEN por encima del cuerpo.
#   * delante (7): por encima del peto, que es donde va la mano que te queda de cara.
#   * detras (2): por encima del cuerpo pero por DEBAJO de la ropa, las grebas y el peto. Asi la mano
#     del fondo se ve donde asoma por el costado y se tapa donde el tronco la cubre, que es
#     exactamente lo que hace el brazo de carne.
const Z_ARMADURA_MANOS := 7
const Z_ARMADURA_MANOS_DETRAS := 2


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
		# EL CASQUETE DEL PELO SE APAGA CON EL CASCO PUESTO, y se apaga AQUI y no en el pintor porque
		# aqui es donde se sabe: cada capa se hornea sola y no puede ver a las demas, asi que un casco
		# NO tiene forma de recortar el pelo. Lo unico que se puede hacer es no pedirlo.
		#
		# Y solo se apaga el casquete: la capa de arriba se salta, pero la de atras (la melena, la
		# coleta) ya se ha metido unas lineas mas arriba y se queda. Eso es lo que hace que con casco
		# el pelo largo siga saliendo por detras y el rapado no enseñe nada, sin una tabla de que
		# peinado convive con que casco: lo decide el propio peinado por su flag 'cuelga'.
		if nombre == "pelo" and pj.equipped_casco != null:
			continue
		# Y LO MISMO CON LA ROPA QUE TAPA UNA PIEZA DE ARMADURA (ver ROPA_QUE_TAPA): el peto sustituye
		# a la camisa y las grebas al pantalon. Se apaga aqui por el mismo motivo que el casquete --
		# una capa no puede recortar a otra, asi que lo unico que se puede hacer es no pedirla.
		if _tapada_por_armadura(pj, nombre):
			continue
		out.append({"clave": "%s_%s" % [nombre, modelo], "ranura": cat["ranura"],
			"ancla": cat["ancla"], "tinte": bool(cat.get("tinte", true)),
			"z": int(cat["z"]), "color": p["color"], "metal": p["metal"],
			"frames": cat["gen"].frames(modelo, 1.0)})
	out.append_array(_capas_armadura(pj))
	out.append_array(_capas_arma(pj))
	return out


# LAS CAPAS DE ARMADURA que lleva puestas este personaje. Salen de equipped_casco y sus cuatro
# hermanas (ver PersonajeData), igual que el arma sale de equipped_main: es equipo, no aspecto.
#
# VA ANTES QUE EL ARMA en la lista, y no da igual: el orden de 'out' desempata entre capas que caen a
# la misma profundidad (ver MunecoJugador._ordenar), y lo que se lleva en la mano tiene que poder
# taparse a si mismo contra el cuerpo.
#
# DE LAS CINCO RANURAS SOLO SE DIBUJA LA QUE TENGA PINTOR (ArmaduraSprites.SLOTS_HECHOS). Las otras
# cuatro ya se pueden equipar y ya dan defensa desde hace tiempo -- lo que falta es el dibujo --, asi
# que llevarlas puestas sin que se vean es el estado normal y no un error: se salta y ya.
static func _capas_armadura(pj: PersonajeData) -> Array:
	var out: Array = []
	for slot in ArmaduraSprites.SLOT_NOMBRE:
		if not ArmaduraSprites.SLOTS_HECHOS.has(slot):
			continue
		var pieza = pj.get("equipped_" + slot)
		if pieza == null or not (pieza is ArmorData):
			continue
		var ti: int = clampi(int(pieza.tipo), 0, ArmaduraSprites.TIPO_NOMBRE.size() - 1)
		var tipo: String = ArmaduraSprites.TIPO_NOMBRE[ti]
		var base: String = ArmaduraSprites.clave(tipo, slot)
		# LOS GUANTELETES SON DOS CAPAS, una por mano (ver ArmaduraSprites.SLOTS_POR_MANO), y cada una
		# con SUS DOS POSICIONES de z segun por donde le caiga la mano (ver Z_ARMADURA_MANOS).
		if ArmaduraSprites.SLOTS_POR_MANO.has(slot):
			for lado in [["der", PoseJugador.P_MANO_DER, Ranura.MANO_DER],
					["izq", PoseJugador.P_MANO_IZQ, Ranura.MANO_IZQ]]:
				out.append({"clave": "%s_%s" % [base, lado[0]], "ranura": lado[2],
					"ancla": lado[1], "tinte": false,
					"z": Z_ARMADURA_MANOS, "z_atras": Z_ARMADURA_MANOS_DETRAS,
					"frames": ArmaduraSprites.frames("%s_%s" % [base, lado[0]], 1.0)})
			continue
		out.append({"clave": base, "ranura": _ranura_de(slot),
			"ancla": _ancla_de(slot), "tinte": false,
			"z": _z_de(slot, tipo),
			"frames": ArmaduraSprites.frames(base, 1.0)})
	return out


# Los tres datos que cambian por ranura. Van en funciones y no en una tabla al lado de SLOT_NOMBRE
# porque el z del casco depende ademas del TIPO (abierto o cerrado), y una tabla que solo sirve para
# cuatro de las cinco entradas miente mas de lo que ayuda.
static func _ranura_de(slot: String) -> int:
	match slot:
		"casco": return Ranura.CASCO
		"pecho": return Ranura.PECHO
		"manos": return Ranura.MANOS
		"pantalones": return Ranura.PANTALONES
		_: return Ranura.BOTAS


static func _ancla_de(slot: String) -> StringName:
	match slot:
		"casco": return PoseJugador.P_CABEZA
		"pecho": return PoseJugador.P_TORSO
		_: return PoseJugador.P_CADERA


static func _z_de(slot: String, tipo: String) -> int:
	match slot:
		"casco": return Z_CASCO_CERRADO if ArmaduraSprites.cerrado(tipo) else Z_CASCO_ABIERTO
		"pecho": return Z_ARMADURA_PECHO
		_: return Z_ARMADURA_PIERNAS


# QUE PIEZA DE ROPA APAGA CADA RANURA DE ARMADURA. La armadura SUSTITUYE a la ropa, no se pone encima:
# un peto sobre una camisa serian dos siluetas peleandose por el mismo sitio, y la de debajo no se
# veria mas que asomando a trozos por los bordes.
#
# Botas y guanteletes NO apagan nada, y no es un olvido: manos y pies se pintan en la capa del CUERPO,
# que no se puede apagar. Se dibujan encima y ya -- por eso sus radios van a ras del cuerpo.
const ROPA_QUE_TAPA := {"pecho": "torso", "pantalones": "piernas"}

# ¿Lleva puesta una pieza de armadura que sustituya a esta pieza de ropa? Mira ademas que la ranura
# tenga pintor: una armadura que todavia no se sabe dibujar NO puede apagar la ropa, o el personaje
# se quedaria desnudo por equiparse algo que no se ve.
static func _tapada_por_armadura(pj: PersonajeData, pieza_ropa: String) -> bool:
	for slot in ROPA_QUE_TAPA:
		if String(ROPA_QUE_TAPA[slot]) != pieza_ropa:
			continue
		if not ArmaduraSprites.SLOTS_HECHOS.has(slot):
			continue
		var p = pj.get("equipped_" + slot)
		if p != null and p is ArmorData:
			return true
	return false


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
	# Las capas de armadura: una por (tipo, ranura), y solo de las ranuras que ya tienen pintor.
	#
	# LA CUENTA DE TROZOS ES POR RANURA, no una para todas: un casco es una masa sola, pero unas
	# GREBAS son dos perneras y unas BOTAS son dos botas -- dos trozos y no hay nada que arreglar. El
	# peto va con dos porque el recorte del brazo puede partirlo, igual que le pasa a la camisa.
	for clave in ArmaduraSprites.todas_las_claves():
		out.append({"clave": clave, "piezas": ArmaduraSprites.trozos_de(clave),
			"gen": ArmaduraSprites, "modelo": clave})
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
