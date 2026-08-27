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
enum Ranura { CUERPO, PANTALONES, BOTAS, PECHO, MANOS, CARA, CASCO, MANO_DER, MANO_IZQ }

# 'tinte' = si esta capa se pinta con un color de fuera (ver MunecoJugador.tenir). Casi todas lo
# haran: una armadura de hierro y una epica son el mismo dibujo con otro tinte, y de ahi sale que
# haya ~35 atlas en vez de miles.
#
# EL CUERPO ES LA EXCEPCION Y VA EN false. La carne tiene su color y no es el que elegiste: teñida,
# la piel salia del color del personaje entero y lo que se veia no era alguien vestido de azul sino
# una estatua azul. Se hornea ya en color de piel y se deja pasar tal cual (ver la cabecera de
# cuerpo_sprites.gd). El color que elegiste no se pierde: es el de la ROPA.
static var CAPAS := [
	{"ranura": Ranura.CUERPO, "clave": "cuerpo", "gen": CuerpoSprites, "piezas": 1,
		"ancla": PoseJugador.P_CADERA, "tinte": false},
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
		"z": 0, "titulo": "Pantalón", "sin_nada": "Sin nada",
		"modelos": {
			"pantalon": {"piezas": 1, "nombre": "Pantalón"},
			"bombacho": {"piezas": 1, "nombre": "Bombacho"},
			"faldon": {"piezas": 1, "nombre": "Faldón"},
		},
	},
	"torso": {
		"ranura": Ranura.PECHO, "gen": RopaSprites, "ancla": PoseJugador.P_TORSO,
		"z": 0, "titulo": "Camisa", "sin_nada": "Sin nada",
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
		"z": 2047,
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
		# LA QUE CUELGA VA PRIMERO EN LA LISTA: el orden de 'out' desempata entre capas a la misma
		# profundidad, y ademas asi el atlas de detras se monta antes que el de delante.
		if bool((cat["modelos"][modelo] as Dictionary).get("cuelga", false)):
			out.append({"clave": "%s_%s_atras" % [nombre, modelo], "ranura": cat["ranura"],
				"ancla": PoseJugador.P_NUCA, "tinte": true,
				"z": Z_CUELGA_DELANTE, "z_atras": Z_CUELGA_DETRAS,
				"color": p["color"], "metal": p["metal"],
				"frames": cat["gen"].frames(modelo + PeloSprites.SUFIJO_ATRAS, 1.0)})
		out.append({"clave": "%s_%s" % [nombre, modelo], "ranura": cat["ranura"],
			"ancla": cat["ancla"], "tinte": true, "z": int(cat.get("z", 0)),
			"color": p["color"], "metal": p["metal"],
			"frames": cat["gen"].frames(modelo, 1.0)})
	return out


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
static func animacion(mirada: Vector2, modo: int, moviendose: bool, golpeando: bool = false) -> String:
	return PoseJugador.animacion(mirada, modo, moviendose, golpeando)


static func cadaver(mirada: Vector2) -> String:
	return PoseJugador.cadaver(mirada)


# La caja de colision del personaje, en unidades de mundo. Se queda en los 32x32 de siempre A
# PROPOSITO: el sprite se dibuja alrededor y es mas alto que ancho, pero cambiar la colision movería
# como estorba el personaje en un pasillo, que es cosa de juego y no de dibujo. Si algun dia se
# toca, que sea por una decision de juego y no de refilon al meter arte.
static func tam_cuerpo() -> Vector2:
	return Vector2(32.0, 32.0)
