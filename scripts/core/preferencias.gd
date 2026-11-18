# ============================================================
#  preferencias.gd  (autoload "Preferencias")
#  LOS AJUSTES DE JUEGO (17/11, su decision): como se ESCRIBEN los numeros. Dos, en la pestaña «Juego» de Ajustes:
#
#  1. LAS CIFRAS DE LAS FICHAS (habilidades y hechizos): solo el porcentaje, solo el numero, o los dos (por defecto):
#     «un 200 % del Ataque…», «Inflige 48 de Daño Físico», «un 200 % (48) del Ataque…». Quien lo usa de verdad es
#     AbilityData.modo_cifras; aqui se guarda y se le pasa.
#  2. LOS DECIMALES: enteros, 1 decimal o por defecto (como estaba: cada sitio con los suyos, hasta 2). Vale para TODO
#     lo que es un numero de la pelea: las barras (HUD, combate, ficha del objetivo, compañeros), el registro y los
#     numeros que saltan al golpear. «1 decimal» es un TOPE, no un relleno: lo que por defecto va entero (la energia)
#     sigue entero (su decision).
#
#  3. LOS CIRCULOS DE ALCANCE (18/11, su decision): por separado los de tus personajes y los de los enemigos, cada uno
#     con cuando se ven (APAGADOS DE SERIE / solo el del turno y el apuntado / todos), su trazo (a puntos o a rayas, en
#     pixel: AroPixel), su color libre con opacidad, el grosor y las medidas del trazo. Los lee ArenaCombate al pintar
#     y CombatTactico._tick_alcances para saber de quien.
#
#  Ajustes de MAQUINA y no de partida, como los volumenes y la pantalla: viven en user://ajustes.cfg, en su seccion, y
#  se LEE ANTES DE ESCRIBIR para no llevarse por delante las de Sonido y Ventana (ver prueba_ventana_ajustes).
# ============================================================

extends Node

const RUTA_AJUSTES := "user://ajustes.cfg"
const SECCION := "juego"

enum Decimales { ENTEROS, UNO, DEFECTO }

# COMO SE LLAMAN PARA EL JUGADOR, en el orden de la lista. Los ids son los de los enums (AbilityData.ModoCifras y
# Decimales), que son lo que se guarda.
const MODOS_CIFRAS := [
	{"id": 2, "nombre": "Porcentaje y número"},   # AbilityData.ModoCifras.LOS_DOS
	{"id": 0, "nombre": "Solo porcentaje"},       # PORCENTAJE
	{"id": 1, "nombre": "Solo número"},           # NUMERO
]
const MODOS_DECIMALES := [
	{"id": Decimales.DEFECTO, "nombre": "Por defecto (hasta 2 decimales)"},
	{"id": Decimales.UNO, "nombre": "1 decimal"},
	{"id": Decimales.ENTEROS, "nombre": "Números enteros"},
]

var decimales: int = Decimales.DEFECTO

# --- LOS CIRCULOS DE ALCANCE ---
enum Alcance { APAGADO, TURNO, TODOS }
const GRUPOS_ALCANCE := ["tuyos", "enemigos"]
const MODOS_ALCANCE := [
	{"id": Alcance.APAGADO, "nombre": "Apagados"},
	{"id": Alcance.TURNO, "nombre": "Solo del turno"},   # el de quien juega y el que apuntas
	{"id": Alcance.TODOS, "nombre": "Todos"},
]
const TRAZOS_ALCANCE := [
	{"id": 1, "nombre": "A rayas"},    # AroPixel.Trazo.RAYAS
	{"id": 0, "nombre": "A puntos"},   # AroPixel.Trazo.PUNTOS
]
# Lo de serie (y lo que pone «Restablecer»): el azul y el rojo de siempre, a rayas finas de 1 px.
const ALCANCE_DEFECTO := {
	"tuyos": {"modo": Alcance.APAGADO, "trazo": 1, "color": Color(0.45, 0.75, 1.0), "opacidad": 45, "tam": 1,
		"largo": 6, "hueco": 4},
	"enemigos": {"modo": Alcance.APAGADO, "trazo": 1, "color": Color(1.0, 0.4, 0.35), "opacidad": 45, "tam": 1,
		"largo": 6, "hueco": 4},
}
# Los topes de cada mando (los usa Ajustes para sus deslizadores y _cargar para no fiarse del fichero).
const ALCANCE_TOPES := {"opacidad": [10, 100], "tam": [1, 3], "largo": [1, 16], "hueco": [1, 16]}
# El del turno y el apuntado, mas marcados que los demas: su opacidad sube esto (hasta el 100 %).
const ALCANCE_EXTRA_FUERTE := 0.35

var alcance: Dictionary = {}   # grupo -> {modo, trazo, color, opacidad, tam, largo, hueco}

var _re_fmt: RegEx = null
var _re_num: RegEx = null


func _ready() -> void:
	_cargar()


# ------------------------------------------------------------
#  CAMBIAR (desde Ajustes). Se aplica al momento y se guarda.
# ------------------------------------------------------------
func fijar_modo_cifras(m: int) -> void:
	AbilityData.modo_cifras = clampi(m, 0, 2)
	_guardar()


func fijar_decimales(d: int) -> void:
	decimales = clampi(d, 0, 2)
	_guardar()


# Un valor de los circulos de un grupo ("tuyos" / "enemigos"). Se aplica al momento y se guarda.
# Mientras se arrastra un mando, guardar = false (se ve al momento sin escribir un fichero por pixel); al soltarlo, true.
func fijar_alcance(grupo: String, clave: String, valor, guardar: bool = true) -> void:
	if not alcance.has(grupo):
		return
	alcance[grupo][clave] = _sanear(clave, valor)
	if guardar:
		_guardar()


func guardar_ajustes() -> void:
	_guardar()


func restablecer_alcance(grupo: String) -> void:
	var modo: int = int(alcance.get(grupo, {}).get("modo", Alcance.APAGADO))
	alcance[grupo] = (ALCANCE_DEFECTO[grupo] as Dictionary).duplicate()
	alcance[grupo]["modo"] = modo   # restablece el aspecto; si se ven o no, lo deja como estaba
	_guardar()


# Si el aro de alguien se pinta: 'enemigo' dice su grupo y 'fuerte' si es el del turno o el apuntado.
func ve_alcance(enemigo: bool, fuerte: bool) -> bool:
	var m: int = int(alcance["enemigos" if enemigo else "tuyos"]["modo"])
	return m == Alcance.TODOS or (m == Alcance.TURNO and fuerte)


# El color con su opacidad (y el extra si es el del turno o el apuntado).
func color_alcance(enemigo: bool, fuerte: bool) -> Color:
	var a: Dictionary = alcance["enemigos" if enemigo else "tuyos"]
	var alfa: float = float(a["opacidad"]) / 100.0
	if fuerte:
		alfa = minf(1.0, alfa + ALCANCE_EXTRA_FUERTE)
	return Color(a["color"], alfa)


func _sanear(clave: String, v):
	match clave:
		"modo":
			return clampi(int(v), 0, 2)
		"trazo":
			return clampi(int(v), 0, 1)
		"color":
			return Color(v) if (v is Color) else Color.WHITE
	if ALCANCE_TOPES.has(clave):
		return clampi(int(v), int(ALCANCE_TOPES[clave][0]), int(ALCANCE_TOPES[clave][1]))
	return v


# ------------------------------------------------------------
#  LOS NUMEROS
# ------------------------------------------------------------

# Cuantos decimales le tocan a un sitio que por defecto lleva 'por_defecto'.
func dec(por_defecto: int) -> int:
	match decimales:
		Decimales.ENTEROS:
			return 0
		Decimales.UNO:
			return mini(por_defecto, 1)
	return por_defecto


# Un formato de barra («%.2f / %.2f», «MP  %.1f/%.1f») con los decimales del ajuste: cada %.Nf pasa a %.{dec(N)}f.
func fmt(formato: String) -> String:
	if decimales == Decimales.DEFECTO:
		return formato
	if _re_fmt == null:
		_re_fmt = RegEx.create_from_string("%\\.(\\d)f")
	var out: String = ""
	var desde: int = 0
	for m in _re_fmt.search_all(formato):
		out += formato.substr(desde, m.get_start() - desde) + "%%.%df" % dec(int(m.get_string(1)))
		desde = m.get_end()
	return out + formato.substr(desde)


# El texto de una barra, ya con coma decimal: barra("%.2f / %.2f", 198.84, 199.9) -> «198,84 / 199,90».
func barra(formato: String, v: float, maximo: float) -> String:
	return (fmt(formato) % [v, maximo]).replace(".", ",")


# Un numero suelto con 'por_defecto' decimales como mucho y sin los ceros que sobran (el del registro: 4.10 -> «4,1»).
func num(x: float, por_defecto: int = 2) -> String:
	var s: String = ("%%.%df" % dec(por_defecto)) % x
	if s.contains("."):
		s = s.rstrip("0").rstrip(".")
	if s == "-0":
		s = "0"
	return s.replace(".", ",")


# Un numero con sus decimales FIJOS (el que salta al golpear: «134,42», «134,4», «134»).
func fijo(x: float, por_defecto: int = 2) -> String:
	return (("%%.%df" % dec(por_defecto)) % x).replace(".", ",")


# UNA FRASE YA ESCRITA (el registro de combate) con los decimales del ajuste: «34,62» -> «34,6» o «35». El registro
# viaja escrito por la red (lo escribe quien resuelve la accion, con 2 decimales siempre), asi que cada maquina lo
# recorta AL PINTARLO con lo suyo. Solo toca numeros con coma pegada («34,62»): una lista lleva espacio tras la coma.
func en_texto(t: String) -> String:
	if decimales == Decimales.DEFECTO or not t.contains(","):
		return t
	if _re_num == null:
		_re_num = RegEx.create_from_string("(?<!\\d,)(?<!\\d)(\\d+),(\\d+)(?!,?\\d)")
	var out: String = ""
	var desde: int = 0
	for m in _re_num.search_all(t):
		out += t.substr(desde, m.get_start() - desde) + num(float(m.get_string(1) + "." + m.get_string(2)), 2)
		desde = m.get_end()
	return out + t.substr(desde)


# ------------------------------------------------------------
#  DISCO
# ------------------------------------------------------------
func _cargar() -> void:
	var cfg := ConfigFile.new()
	var err: int = cfg.load(RUTA_AJUSTES)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("[preferencias] no se pudo leer %s (error %d): por defecto" % [RUTA_AJUSTES, err])
	AbilityData.modo_cifras = clampi(int(cfg.get_value(SECCION, "cifras", AbilityData.ModoCifras.LOS_DOS)), 0, 2)
	decimales = clampi(int(cfg.get_value(SECCION, "decimales", Decimales.DEFECTO)), 0, 2)
	for g in GRUPOS_ALCANCE:
		var d: Dictionary = (ALCANCE_DEFECTO[g] as Dictionary).duplicate()
		var leido = cfg.get_value(SECCION, "alcance_" + g, {})
		if leido is Dictionary:
			for k in d:
				if leido.has(k):
					d[k] = _sanear(k, leido[k])
		alcance[g] = d


func _guardar() -> void:
	# LEER ANTES DE ESCRIBIR: en este fichero estan tambien los volumenes y la pantalla.
	var cfg := ConfigFile.new()
	cfg.load(RUTA_AJUSTES)
	cfg.set_value(SECCION, "cifras", AbilityData.modo_cifras)
	cfg.set_value(SECCION, "decimales", decimales)
	for g in alcance:
		cfg.set_value(SECCION, "alcance_" + g, alcance[g])
	var err: int = cfg.save(RUTA_AJUSTES)
	if err != OK:
		push_warning("[preferencias] no se pudo guardar %s (error %d)" % [RUTA_AJUSTES, err])
