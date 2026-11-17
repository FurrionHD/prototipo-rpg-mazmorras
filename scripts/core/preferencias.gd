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


func _guardar() -> void:
	# LEER ANTES DE ESCRIBIR: en este fichero estan tambien los volumenes y la pantalla.
	var cfg := ConfigFile.new()
	cfg.load(RUTA_AJUSTES)
	cfg.set_value(SECCION, "cifras", AbilityData.modo_cifras)
	cfg.set_value(SECCION, "decimales", decimales)
	var err: int = cfg.save(RUTA_AJUSTES)
	if err != OK:
		push_warning("[preferencias] no se pudo guardar %s (error %d)" % [RUTA_AJUSTES, err])
