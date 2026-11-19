# HERRAMIENTA. No forma parte del juego.
#
#   godot --headless --fixed-fps 60 --path . res://tools/simulador_peleas.tscn -- pisos=1,6 grupos=duo escenarios=piso veces=3
#   (o el lanzador: python tools/simulador.py, que reparte el trabajo entre varios Godot a la vez y junta los numeros)
#
# EL SIMULADOR DE PELEAS (19/11/2026, memoria stats-misma-formula-todos). Peleas DE VERDAD, no formulas copiadas: la
# misma pantalla de combate en el mapa, en la ARENA DE PRUEBAS (una sala grande: nadie se engancha en esquinas), abierta
# por donde la abre la sala (tools/prueba_sala_propia.gd). Un PILOTO AUTOMATICO hace de jugador con CADA uno de los tuyos:
# anda (con las teclas de mover), elige y pulsa los botones, apunta las huellas y recita las frases.
#
# EL PERSONAJE DE REFERENCIA de cada piso (la progresion que aprobo, la de tools/tabla_formulas.gd): nivel, habilidades
# del nivel, lo bakeado de los anteriores y equipo del tier del piso con sus mejoras. CUATRO ROLES:
#   guerrero  mandoble + placas; sus 4 habilidades del arma; un Filo (la imbuicion del elemento que mejor entra al
#             enemigo principal), Manto de brasas y Vendaje de luz. 'arma=<resources/weapons>' le cambia el arma.
#   tanque    espada corta + escudo grande + placas; Provocacion, Muro, Golpe de escudo y Tajo quebrantador.
#   arquero   arco + cuero; las habilidades del arco.
#   mago      baston + tela; seis magias de todo tipo: debiles, fuertes, de area, la cura, y de elementos que le entran
#             al enemigo y que resiste (solo: Pulso menor, Brasa, Torrente, Tormenta, Voragine, Vendaje; en grupo la
#             Fortaleza en vez de la Brasa).
# GRUPOS: solo_guerrero, solo_mago, duo (tanque + mago), trio (+ guerrero), cuatro (+ arquero).
#
# ESCENARIOS (lo de enfrente):
#   uno     cada enemigo del piso suelto, CADA UNA DE SUS MUTACIONES y el jefe del piso (medir a cada uno)
#   piso    un corro como sale en el piso: su tamaño de la tabla de manada del juego segun cuantos vais
#           (Enemy.MANADA_POR_GRUPO) y cada bicho de la tabla de spawns del piso, con su 2 % de mutante
#   manada  3-5 del mismo (las areas y el reparto de golpes)
#   jefe    el jefe del piso con su sequito (un corro del piso alrededor)
#
# EL PILOTO, por rol (cada turno):
#   - TODOS: con un «¡Apartate!» encima (la huella de lo que carga un enemigo) primero se sale (el tanque no: aguanta en
#     Defender, delante de los suyos). El mago y el arquero guardan la distancia (se alejan del que tengan encima).
#   - tanque: Muro sobre el fragil (mago/arquero) si va tocado; Provocacion si hay alguien cerca de los fragiles; si no
#     su golpe que mas pega o Atacar, al enemigo que mas cerca este de los fragiles.
#   - guerrero / arquero: el Filo y el Manto al empezar (el guerrero); la habilidad que mas pega o Atacar; objetivo:
#     el que antes caiga (poca vida y cerca).
#   - mago: cura al que este por debajo del 45 %; la Fortaleza al empezar (en grupo); si no, el hechizo y el sitio que mas
#     daño esperan por turno de recitado contando A CUANTOS pilla su area (StatsMath.resolve_spell: sus resistencias),
#     solo de una frase si tiene a alguien encima o le van a dar (no le tiran el conjuro).
#   - anda hasta tenerlo a tiro; si no llega, Defender (o Pasar).
#
# SALIDA: una linea por pelea, 'R|...' (ver CABECERA). 'trozo=i/n' juega solo los casos i, i+n... (varios procesos).
extends Node

const CABECERA := "R|tanda|reglas|piso|grupo|escenario|arma|enemigo|mutacion|jefe|n_enem|t|gana|turnos_yo|turnos_el|vida_perdida|caidos|mp_gastado|dano_por_turno|dano_recibido_por_turno_suyo|segundos|acciones|fotogramas|ms_por_fotograma|pelea|ciclos|dano_por_ciclo|estados_en_enemigos|estados_en_los_tuyos|n_seguida|repetir"
# Una linea POR PERSONAJE de los tuyos en cada pelea (lo pidio: "daños de cada uno, cuanto tanquean con cada armadura, el
# dps medio, cuanto hace cada arma en su turno, si alguno se queda sin energia demasiado rapido"):
const CABECERA_P := "P|tanda|reglas|pelea|piso|grupo|escenario|n_enem|gana|rol|arma|armadura|vida_max|defensa|def_magica|mitig_fisica|mitig_magica|dano_hecho|dano_recibido|turnos|dano_por_turno|recibido_por_turno_enemigo|cayo|energia_media_al_empezar_turno|turnos_sin_energia|primer_turno_sin_energia|mp_gastado|turnos_sin_mana|primer_turno_sin_mana|pociones|acciones|nivel|tier|mejoras|fue/res/agi/des/mag/vol|ataque|velocidad|max_mp|max_energia|red_armadura|red_armadura_magica|ciclos|dano_por_ciclo|turnos_por_ciclo|recibido_por_ciclo|dano_por_elemento|habilidades_puestas"
# Y una POR ENEMIGO (crias y refuerzos incluidos):
const CABECERA_E := "E|tanda|reglas|pelea|piso|grupo|escenario|n_enem|gana|enemigo|mutacion|jefe|vida_max|ataque|defensa|def_magica|velocidad|dano_hecho|dano_recibido|turnos|dano_por_turno|muere|t|fue/res/agi/des/mag/vol|ataque_magico|red_armadura|ciclos|dano_por_ciclo|turnos_por_ciclo"
const PISOS_NIVEL := 12
# piso: [nivel, habilidad del nivel, [bakeados], tier, mejoras, piezas de armadura]  (la de tabla_formulas)
# 19/11: 750 AL FINAL DE CADA NIVEL (pisos 12, 24 y 36) y 750 lo que se bakea al subir (su indicacion: "pon 750 en todos y
# asi es mejor media"; antes 700 y 800).
const PROGRESION := {
	1: [1, 50, [], 1, 0, 2],
	2: [1, 100, [], 1, 1, 5],
	6: [1, 350, [], 1, 7, 5],
	7: [1, 400, [], 2, 0, 5],
	12: [1, 750, [], 2, 7, 5],
	13: [2, 100, [750.0], 3, 0, 5],
	18: [2, 500, [750.0], 3, 7, 5],
	24: [2, 750, [750.0], 4, 7, 5],
	25: [3, 100, [750.0, 750.0], 5, 0, 5],
	31: [3, 600, [750.0, 750.0], 6, 0, 5],
	36: [3, 750, [750.0, 750.0], 6, 7, 5],
}
# EL PERSONAJE DE REFERENCIA DE CUALQUIER PISO (19/11, lo pidio: "todos los pisos del 1 al 12, con la armadura, las armas y
# las stats que deberian llevar en ese piso"): las habilidades se interpolan en linea recta entre los pisos de PROGRESION
# (los que aprobo); el tier sube cada 6 pisos; las mejoras van de +0 a +7 dentro de cada tier (+0 +1 +3 +4 +6 +7); dos
# piezas de armadura en el piso 1 y el juego entero despues; nivel cada 12 pisos con lo bakeado de los anteriores.
func _prog(piso: int) -> Array:
	if PROGRESION.has(piso):
		return PROGRESION[piso]
	var nivel: int = 1 + (piso - 1) / PISOS_NIVEL
	var claves: Array = PROGRESION.keys()
	claves.sort()
	var a: int = claves[0]
	var b: int = claves[claves.size() - 1]
	for k in claves:
		if k <= piso and int(PROGRESION[k][0]) == nivel:
			a = k
		if k >= piso and int(PROGRESION[k][0]) == nivel and b > piso and (b < piso or k < b or int(PROGRESION[b][0]) != nivel):
			b = k
	if b < piso or int(PROGRESION[b][0]) != nivel:
		b = a
	var hab: float = float(PROGRESION[a][1])
	if b != a:
		hab = lerpf(float(PROGRESION[a][1]), float(PROGRESION[b][1]), float(piso - a) / float(b - a))
	var tier: int = int(ceil(float(piso) / 6.0))
	var dentro: int = (piso - 1) % 6   # 0..5 dentro del tier
	var mejoras: int = int(round(7.0 * float(dentro) / 5.0))
	return [nivel, int(round(hab)), PROGRESION[a][2], tier, mejoras, 2 if piso == 1 else 5]


const JEFES := {6: "res://scenes/actors/enemy/rey_slime.tres", 12: "res://scenes/actors/enemy/guardian_rango.tres"}
const TABLA_PISO := "res://resources/spawns/piso_comun.tres"
const SLOTS := ["casco", "pecho", "manos", "pantalones", "botas"]
const GRUPOS := {
	"solo_guerrero": ["guerrero"],
	"solo_mago": ["mago"],
	"duo": ["tanque", "mago"],
	"trio": ["tanque", "guerrero", "mago"],
	"cuatro": ["tanque", "guerrero", "arquero", "mago"],
}
const NOMBRES := {"guerrero": "Guerrero", "tanque": "Tanque", "arquero": "Arquero", "mago": "Mago"}
const MAGIAS_MAGO := ["pulso_menor", "brasa", "chorro_agua", "tormenta", "voragine_sombra", "vendaje_de_luz"]
const MAGIAS_MAGO_GRUPO := ["pulso_menor", "fortaleza", "chorro_agua", "tormenta", "voragine_sombra", "vendaje_de_luz"]
const FILOS := ["filo_ardiente", "filo_fulgurante", "filo_torrente", "filo_radiante", "filo_umbrio"]
const MAGIAS_GUERRERO := ["manto_brasas", "vendaje_de_luz"]
const HABS_TANQUE := ["provocacion", "muro_guardian", "golpe_escudo_grande", "tajo_quebrantador"]
const VIDA_CURA := 0.45
const VIDA_MURO := 0.55
const DIST_SEGURA := 110.0     # el mago y el arquero se alejan del que este mas cerca que esto
const TOPE_TURNOS := 200       # turnos de los tuyos (todos): mas = tablas
const TOPE_SEGUNDOS := 45.0    # reloj de verdad por pelea: mas = atascada (se apunta y se sigue)
const DIST_INICIO := 220.0
# EL MUÑECO DE DPS (19/11): cada enemigo del piso con su defensa y su esquiva de verdad, pero con vida de sobra y sin hacer
# daño (Game.volver_muneco modo 2 + dummy_dmg_out_mult 0). Se corta a los CICLOS_MUNECO: varias rotaciones enteras de
# cada arma (energia, recargas, cargas), y su daño por ciclo sin que cuente lo que tarda en morir el enemigo.
const CICLOS_MUNECO := 12.0
const VIDA_MUNECO := 9999999.0
# LA MAZMORRA SEGUIDA (19/11): peleas del piso una tras otra sin volver al pueblo: la vida, el mana y las pociones se
# arrastran (el aguante no: se repone andando entre una y otra); el que cae se levanta con 1 si el grupo gana, como en el
# juego. Se para al caer el grupo o a las SEGUIDA_MAX. La bolsa de la bajada: dos de vida por cabeza y dos de mana por mago.
const SEGUIDA_MAX := 12

var sala = null
var _tanda := "sin_nombre"
var _reglas := "hoy"
var _pisos: Array = []
var _grupos: Array = ["solo_guerrero", "solo_mago"]
var _escenarios: Array = ["uno"]
var _veces := 1
var _solo := ""
var _arma := "mandobles"
# TODAS LAS ARMAS (19/11, lo pidio: "pruebalas todas"): 'armas=daga,estoque,...' o 'armas=todas'. Cada una va en el hueco
# del GUERRERO (las de distancia, con el perfil del arquero: sus stats, cuero y guardar la distancia); los demas roles no
# cambian. Es una dimension mas de los casos.
const ARMAS_TODAS := ["daga", "espada_corta", "espada_larga", "estoque", "hacha_grande", "mandobles", "martillo_grande",
	"maza_peq", "punos", "arco", "ballesta",
	# DOBLE ARMA Y ESCUDOS (19/11): 'principal+mano_secundaria' (un arma de resources/weapons o un escudo de resources/shields)
	"daga+daga", "espada_corta+espada_corta", "maza_peq+maza_peq", "espada_corta+escudo_pequeno",
	"espada_larga+escudo_normal", "maza_peq+escudo_normal"]
# EL PERFIL DE CADA ARMA (19/11, lo pidio: "perfil de stats por arma"): como la llevaria quien la elige. Todos con el MISMO
# presupuesto (tres stats al 100 % y dos a la mitad), para que ninguno gane por tener mas puntos. Las cuerpo a cuerpo
# escalan su daño con la Fuerza (escala_destreza 0); lo que distingue a las ligeras es el critico (Destreza) y la esquiva
# (Agilidad). Y su armadura: pesada -> placas, media -> hierro, agil y distancia -> cuero.
const PERFILES := {
	"pesado": [{"fuerza": 1.0, "resistencia": 1.0, "destreza": 1.0, "agilidad": 0.5, "voluntad": 0.5}, "placas"],
	"medio": [{"fuerza": 1.0, "resistencia": 1.0, "agilidad": 1.0, "destreza": 0.5, "voluntad": 0.5}, "hierro"],
	"agil": [{"fuerza": 1.0, "agilidad": 1.0, "destreza": 1.0, "resistencia": 0.5, "voluntad": 0.5}, "cuero"],
	"distancia": [{"destreza": 1.0, "agilidad": 1.0, "fuerza": 1.0, "resistencia": 0.5, "voluntad": 0.5}, "cuero"],
}
const PERFIL_DE_ARMA := {"hacha_grande": "pesado", "mandobles": "pesado", "martillo_grande": "pesado",
	"espada_corta": "medio", "espada_larga": "medio", "maza_peq": "medio", "punos": "medio",
	"daga": "agil", "estoque": "agil", "arco": "distancia", "ballesta": "distancia"}
const ARMAS_DISTANCIA := ["arco", "ballesta"]
var _armas: Array = []
# TODAS LAS ARMADURAS (19/11, lo pidio: "todas las armas con todos los tipos de armadura, una daga y un broquel, hacha con
# cuero"): 'armaduras=todas' o una lista; el hueco del guerrero lleva esa en vez de la de su perfil. Cada equipo se apunta
# como 'arma@armadura'.
const ARMADURAS_TODAS := ["tela", "cuero", "hierro", "placas"]
var _armaduras: Array = []
# LOS SETS DE HABILIDADES (19/11, lo pidio: "solo tenemos 4 huecos y hay armas con 6, y con escudo se juntan"): 'sets=todos'
# prueba CADA combinacion de 4 de las que puede llevar ese equipo (las del arma, las de la otra mano y las del escudo). Se
# apunta como 'arma@armadura#hab1;hab2;hab3;hab4'. Sin esto, las 4 primeras (el autorrelleno del juego).
var _sets_todos := false


# TODAS LAS COMBINACIONES LEGALES de manos: las de una mano solas, dobles (si se puede) y con escudo pequeño (broquel),
# normal y grande; las de dos manos solas; arco y ballesta.
static func equipos_todos() -> Array:
	var out: Array = []
	for w in ["daga", "espada_corta", "espada_larga", "estoque", "maza_peq", "punos"]:
		out.append(w)
		var wd: WeaponData = load("res://resources/weapons/%s.tres" % w)
		if wd.puede_dual:
			out.append("%s+%s" % [w, w])
		for e in ["escudo_pequeno", "escudo_normal", "escudo_grande"]:
			out.append("%s+%s" % [w, e])
	for w in ["hacha_grande", "mandobles", "martillo_grande", "arco", "ballesta"]:
		out.append(w)
	return out
var _trozo := 0
var _trozos := 1
var _escala_tiempo := 8.0
var _sin_mutantes := false
var _sin_jefes := false
var _ver := false
# REPETIR UNA PELEA (19/11): cada pelea saca en su linea R lo que hay que pasarle a 'repetir=' para volver a jugarla igual
# (mismo piso, grupo, escenario, arma, enemigo, mutacion, SEMILLA y escala). Igual de verdad solo a la MISMA escala (el
# azar y la barra van por fotogramas): para verla, grabarla con --write-movie y mirarla despacio.
#   godot --fixed-fps 60 --path . res://tools/simulador_peleas.tscn --write-movie pelea.avi -- repetir=6,trio,piso,mandobles,-,-,123456,8
var _semilla_fija := -1
var _solo_mut := ""


func _ver_progresion() -> void:
	for p in range(1, 37):
		print("[prog] piso %2d: %s" % [p, str(_prog(p))])


func _ready() -> void:
	call_deferred("_empezar")


func _empezar() -> void:
	reparent(get_tree().root)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hueco := Node.new()
	get_tree().root.add_child(hueco)
	get_tree().current_scene = hueco
	_hueco = hueco
	OS.set_environment("PRUEBA_SIN_MUTANTES", "1")   # los mutantes los pone el simulador, no salen solos
	_leer_args()
	if OS.get_cmdline_user_args().has("progresion"):
		_ver_progresion()
		get_tree().quit(0)
		return
	await _correr()
	print("[sim] FIN")
	get_tree().quit(0)


func _leer_args() -> void:
	_pisos = range(1, 13)   # del 1 al 12 (los de despues, pidiendolos: pisos=13,18,25...)
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = String(a).split("=", true, 1)
		if kv.size() != 2:
			continue
		match kv[0]:
			"pisos": _pisos = Array(kv[1].split(",")).map(func(x): return int(x))
			"clases": _grupos = Array(kv[1].split(",")).map(func(x): return "solo_" + x)   # lo de antes
			"grupos": _grupos = Array(kv[1].split(","))
			"escenarios": _escenarios = Array(kv[1].split(","))
			"veces": _veces = maxi(1, int(kv[1]))
			"solo": _solo = kv[1]
			"arma": _arma = kv[1]
			"escala_des":
				# PROBAR SIN TOCAR EL JUEGO (19/11, su idea: "que las dagas escalen con destreza, y el estoque tambien o
				# hibrido"): 'escala_des=daga:1,estoque:0.5' cambia la escala_destreza de esas armas SOLO en esta simulacion.
				for par in kv[1].split(","):
					var ab: PackedStringArray = par.split(":")
					var w: WeaponData = load("res://resources/weapons/%s.tres" % ab[0])
					if w != null and ab.size() == 2:
						w.escala_destreza = float(ab[1])
						print("[sim] %s: escala_destreza %.2f (solo en esta simulacion)" % [ab[0], w.escala_destreza])
			"armas": _armas = equipos_todos() if kv[1] == "todas" else (ARMAS_TODAS.duplicate() if kv[1] == "basicas" else Array(kv[1].split(",")))
			"sets": _sets_todos = kv[1] == "todos"
			"armaduras": _armaduras = ARMADURAS_TODAS.duplicate() if kv[1] == "todas" else Array(kv[1].split(","))
			"tanda": _tanda = kv[1]
			"reglas": _reglas = kv[1]
			"escala": _escala_tiempo = maxf(1.0, float(kv[1]))
			"sin_mutantes": _sin_mutantes = kv[1] == "1"
			"sin_jefes": _sin_jefes = kv[1] == "1"
			"ver": _ver = kv[1] == "1"
			"repetir":
				var r: PackedStringArray = kv[1].split(",")
				if r.size() >= 8:
					_pisos = [int(r[0])]
					_grupos = [r[1]]
					_escenarios = [r[2]]
					_armas = [r[3]] if r[3] != "-" else []
					_solo = r[4] if r[4] != "-" else ""
					_solo_mut = r[5] if r[5] != "-" else ""
					_semilla_fija = int(r[6])
					_escala_tiempo = float(r[7])
					_veces = 1
					_ver = true
			"pociones":
				var pz: PackedStringArray = kv[1].split(",")
				_pociones_vida = int(pz[0])
				_pociones_mana = int(pz[1]) if pz.size() > 1 else 0
			"trozo":
				var t: PackedStringArray = kv[1].split("/")
				_trozo = int(t[0])
				_trozos = maxi(1, int(t[1]))


# ------------------------------------------------------------
#  LOS PERSONAJES DE REFERENCIA
# ------------------------------------------------------------
# Cuanto de la habilidad del nivel va a cada stat, por rol (1 = toda, 0.5 = la mitad...).
const REPARTO := {
	"guerrero": {"fuerza": 1.0, "resistencia": 1.0, "agilidad": 1.0, "destreza": 0.5, "voluntad": 0.5},
	"tanque": {"fuerza": 1.0, "resistencia": 1.0, "agilidad": 0.5, "destreza": 0.5, "voluntad": 0.5},
	"arquero": {"fuerza": 1.0, "resistencia": 0.5, "agilidad": 1.0, "destreza": 1.0, "voluntad": 0.5},
	"mago": {"magia": 1.0, "resistencia": 0.5, "agilidad": 0.5, "voluntad": 0.5, "fuerza": 0.25},
}

func _personaje(piso: int, rol: String, en_grupo: bool, arma_g: String = "") -> PersonajeData:
	var arma_guerrero: String = arma_g if arma_g != "" else _arma
	var set_forzado: Array = []
	if arma_guerrero.contains("#"):
		set_forzado = Array(arma_guerrero.get_slice("#", 1).split(";"))
		arma_guerrero = arma_guerrero.get_slice("#", 0)
	var armadura_forzada: String = ""
	if arma_guerrero.contains("@"):
		armadura_forzada = arma_guerrero.get_slice("@", 1)
		arma_guerrero = arma_guerrero.get_slice("@", 0)
	var partes_arma: PackedStringArray = arma_guerrero.split("+")
	var principal: String = partes_arma[0]
	var secundaria: String = partes_arma[1] if partes_arma.size() > 1 else ""
	# El hueco del guerrero con un arma de distancia juega de arquero (stats, cuero, distancia), con ESA arma.
	if rol == "guerrero" and principal in ARMAS_DISTANCIA:
		rol = "arquero"
	var pr: Array = _prog(piso)
	var rep: Dictionary = REPARTO[rol]
	var perfil: String = ""
	if rol in ["guerrero", "arquero"] and PERFIL_DE_ARMA.has(principal):
		perfil = PERFIL_DE_ARMA[principal]
		rep = PERFILES[perfil][0]
	var p := PersonajeData.new()
	p.nombre = NOMBRES[rol]
	p.set_meta("rol", rol)
	var hp: float = p.base_hp
	var at: float = p.base_attack
	var de: float = p.base_defense
	var sp: float = p.base_speed
	var mg: float = p.base_magic
	var mf: float = p.base_magia_factor
	for s in pr[2]:
		var a := Abilities.new()
		for k in rep:
			a.set(k, int(float(s) * float(rep[k])))
		if rep.has("magia"):
			mf = mf * StatsMath.magia_factor(float(a.magia)) * 1.1
		else:
			at = at * StatsMath.fuerza_factor(float(a.fuerza)) * 1.1
		hp = StatsMath.max_hp_jugador(a, hp) * 1.1
		de = StatsMath.defense_jugador(a, de) * 1.1
		sp = StatsMath.speed_jugador(a, sp) * 1.1
		mg = StatsMath.magic_jugador(a, mg) * 1.1
	p.base_attack = at; p.base_hp = hp; p.base_defense = de; p.base_speed = sp; p.base_magic = mg; p.base_magia_factor = mf
	var h: int = int(pr[1])
	for k in rep:
		p.set(k, int(float(h) * float(rep[k])))
	var armas := {"guerrero": principal, "tanque": "espada_corta", "arquero": principal if principal in ARMAS_DISTANCIA else "arco",
		"mago": "baston"}
	var armadura := {"guerrero": "placas", "tanque": "placas", "arquero": "cuero", "mago": "tela"}
	p.equipped_main = load("res://resources/weapons/%s.tres" % armas[rol])
	var mejora = Upgrades.POTENCIA if rol == "mago" else Upgrades.AGUDEZA
	p.equip_meta["main"] = {"tier": int(pr[3]), "rareza": 0, "mejoras": {mejora: int(pr[4])}, "durabilidad": 1.0, "banda": 0}
	if rol == "tanque":
		p.equipped_off = load("res://resources/shields/escudo_grande.tres")
		p.equip_meta["off"] = {"tier": int(pr[3]), "rareza": 0, "mejoras": {}, "durabilidad": 1.0, "banda": 0}
	elif rol == "guerrero" and secundaria != "":
		var ruta_off: String = "res://resources/shields/%s.tres" % secundaria
		if not ResourceLoader.exists(ruta_off):
			ruta_off = "res://resources/weapons/%s.tres" % secundaria
		p.equipped_off = load(ruta_off)
		var meta_off: Dictionary = {} if p.equipped_off is ShieldData else {Upgrades.AGUDEZA: int(pr[4])}
		p.equip_meta["off"] = {"tier": int(pr[3]), "rareza": 0, "mejoras": meta_off, "durabilidad": 1.0, "banda": 0}
	if perfil != "":
		armadura[rol] = PERFILES[perfil][1]
	if armadura_forzada != "" and rol in ["guerrero", "arquero"]:
		armadura[rol] = armadura_forzada
	for i in int(pr[5]):
		var s: String = SLOTS[(i + 1) % 5] if int(pr[5]) < 5 else SLOTS[i]
		p.set("equipped_" + s, load("res://resources/armor/%s_%s.tres" % [armadura[rol], s]))
		p.equip_meta[s] = {"tier": int(pr[3]), "rareza": 0, "mejoras": {Upgrades.DUREZA: int(pr[4])}, "durabilidad": 1.0, "banda": 0}
	# Las habilidades del arma: todas sabidas; las cuatro primeras puestas (el tanque, las suyas).
	p.habilidades_aprendidas = Game.pool_habilidades(p).duplicate()
	if rol == "tanque":
		var set_t: Array = []
		for n in HABS_TANQUE:
			set_t.append(load("res://resources/abilities/%s.tres" % n))
		p.loadout_habilidades[Game.clave_loadout(p)] = set_t
	elif not set_forzado.is_empty() and rol in ["guerrero", "arquero"]:
		var set_g: Array = []
		for n in set_forzado:
			set_g.append(load("res://resources/abilities/%s.tres" % n))
		while set_g.size() < Game.MAX_HABILIDADES:
			set_g.append(null)
		p.loadout_habilidades[Game.clave_loadout(p)] = set_g
	var magias: Array = []
	match rol:
		"mago": magias = MAGIAS_MAGO_GRUPO if en_grupo else MAGIAS_MAGO
		"guerrero": magias = MAGIAS_GUERRERO + FILOS
	var hz: Array = []
	for m in magias:
		hz.append(load("res://resources/spells/%s.tres" % m))
	p.hechizos_aprendidos = hz.duplicate()
	p.equipped_spells = hz.slice(0, Game.MAX_HECHIZOS) if rol == "mago" else []
	return p


# El guerrero lleva UN filo: el del elemento que mejor le entre al enemigo principal (y el manto y la cura).
func _poner_magias_guerrero(p: PersonajeData, ed: EnemyData, mutacion: StringName) -> void:
	var mejor: SpellData = null
	var mejor_m: float = -INF
	var e: Combatant = ed.crear_combatant(0.5, mutacion != &"", false, mutacion)
	for f in FILOS:
		var s: SpellData = load("res://resources/spells/%s.tres" % f)
		var m: float = Elementos.mult_recibido(s.elemento, e)
		if m > mejor_m:
			mejor_m = m
			mejor = s
	var hz: Array = [mejor]
	for m in MAGIAS_GUERRERO:
		hz.append(load("res://resources/spells/%s.tres" % m))
	p.equipped_spells = hz


# A punto para otra pelea: vida, mana y aguante llenos, sin estados ni recargas.
func _reponer(p: PersonajeData) -> void:
	p.current_hp = -1.0
	p.current_mp = -1.0
	var maxi_: float = 100.0 + Game.stat_consolidado("resistencia", p) * 0.075 + Game.stat_consolidado("agilidad", p) * 0.025
	p.set_meta("aguante", [maxi_, maxi_])
	p.remove_meta("sin_fuelle")
	p.estados = []


# LA BOLSA DE CADA PELEA (lo pidio: "limitadas"): una pocion de vida por cabeza y una de mana si va mago, del tamaño del
# piso (menor hasta el 6, media despues). 'pociones=v,m' cambia cuantas (0,0 = sin pociones).
var _pociones_vida := -1
var _pociones_mana := -1

func _llenar_bolsa(piso: int, jefe: bool) -> void:
	Game.consumables.clear()
	var tam: String = "menor" if piso <= 6 else "media"
	var magos: int = Game.party.filter(func(p): return String(p.get_meta("rol", "")) == "mago").size()
	# CONTRA UN JEFE se baja mejor servido (lo pidio: "2 de mana y 2 de vida"): dos de vida por cabeza y dos de mana por mago.
	var por: int = 2 if jefe else 1
	var v: int = _pociones_vida if _pociones_vida >= 0 else Game.party.size() * por
	var m: int = _pociones_mana if _pociones_mana >= 0 else magos * por
	if v > 0:
		Game.add_consumable(load("res://resources/consumables/pocion_%s.tres" % tam), v)
	if m > 0:
		Game.add_consumable(load("res://resources/consumables/pocion_mana_%s.tres" % tam), m)


# ------------------------------------------------------------
#  LOS CASOS: [piso, grupo, escenario, enemigo (EnemyData o null), mutacion, mutante, jefe]
# ------------------------------------------------------------
func _enemigos_de(piso: int) -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at("res://resources/spawns"):
		if not f.ends_with(".tres"):
			continue
		for en in load("res://resources/spawns/" + f).entradas:
			var p1: int = int(en.piso_max) if int(en.piso_max) > 0 else int(en.piso_min) + 3
			if int(en.piso_min) <= piso and piso <= p1 and en.enemy_data != null and not out.has(en.enemy_data):
				out.append(en.enemy_data)
	return out


func _pasa_solo(ed: EnemyData) -> bool:
	if _semilla_fija >= 0 and _solo != "" and ed != null:
		return ed.resource_path.get_file().get_basename() == _solo
	return _solo == "" or ed == null or Array(_solo.split(",")).any(func(q): return String(ed.resource_path.get_file().get_basename()).contains(q))


func _casos() -> Array:
	var base: Array = _casos_base()
	if _solo_mut != "":
		base = base.filter(func(c): return String(c[4]) == _solo_mut or (_solo_mut == "mutante" and c[5] and c[4] == &""))
	var armas: Array = _armas if not _armas.is_empty() else [_arma]
	if not _armaduras.is_empty():
		var con: Array = []
		for a in armas:
			for ar in _armaduras:
				con.append("%s@%s" % [a, ar])
		armas = con
	if _sets_todos:
		var con_sets: Array = []
		var vistos: Dictionary = {}
		for a in armas:
			var pj: PersonajeData = _personaje(1, "guerrero", false, a)
			var pool: Array = Game.pool_habilidades(pj)
			var nombres: Array = pool.map(func(ab): return ab.resource_path.get_file().get_basename())
			for combo in _combinaciones(nombres, mini(4, nombres.size())):
				var clave: String = "%s#%s" % [a, ";".join(combo)]
				if not vistos.has(clave):
					vistos[clave] = true
					con_sets.append(clave)
		armas = con_sets
		print("[sim] sets de habilidades: %d equipos con sus sets" % armas.size())
	var out: Array = []
	for c in base:
		if (GRUPOS[c[1]] as Array).has("guerrero"):
			for a in armas:
				out.append(c + [a])
		else:
			out.append(c + [""])
	return out


# Todas las combinaciones de 'k' elementos de 'lista' (en su orden).
static func _combinaciones(lista: Array, k: int) -> Array:
	if k <= 0:
		return [[]]
	if lista.size() < k:
		return []
	var out: Array = []
	for i in lista.size() - k + 1:
		for resto in _combinaciones(lista.slice(i + 1), k - 1):
			out.append([lista[i]] + resto)
	return out


func _casos_base() -> Array:
	var out: Array = []
	for piso in _pisos:
		if piso < 1:
			continue
		for grupo in _grupos:
			if not GRUPOS.has(grupo):
				continue
			for esc in _escenarios:
				match esc:
					"uno":
						for ed in _enemigos_de(piso):
							if not _pasa_solo(ed):
								continue
							out.append([piso, grupo, esc, ed, &"", false, false])
							if not _sin_mutantes:
								var muts: Array = (ed.mutaciones as Array).filter(func(m): return m != null)
								if muts.is_empty():
									out.append([piso, grupo, esc, ed, &"", true, false])
								for m in muts:
									out.append([piso, grupo, esc, ed, m.id, true, false])
						if JEFES.has(piso) and not _sin_jefes and _pasa_solo(load(JEFES[piso])):
							out.append([piso, grupo, esc, load(JEFES[piso]), &"", false, true])
					"piso", "seguida":
						out.append([piso, grupo, esc, null, &"", false, false])
					"manada":
						for ed in _enemigos_de(piso):
							if _pasa_solo(ed):
								out.append([piso, grupo, esc, ed, &"", false, false])
					"jefe":
						if JEFES.has(piso) and not _sin_jefes:
							out.append([piso, grupo, esc, load(JEFES[piso]), &"", false, true])
					"muneco":
						for ed in _enemigos_de(piso):
							if _pasa_solo(ed):
								out.append([piso, grupo, esc, ed, &"", false, false])
	return out


# El corro de esta pelea: [[EnemyData, mutacion, mutante, jefe], ...]
func _corro(caso: Array, n_grupo: int) -> Array:
	var piso: int = caso[0]
	match String(caso[2]):
		"uno", "muneco":
			return [[caso[3], caso[4], caso[5], caso[6]]]
		"manada":
			var n: int = 3 + randi() % 3
			var out: Array = []
			for _i in n:
				out.append([caso[3], &"", false, false])
			return out
		"piso", "seguida":
			return _corro_del_piso(piso, _tirar_manada(n_grupo))
		"jefe":
			return [[caso[3], &"", false, true]] + _corro_del_piso(piso, maxi(1, _tirar_manada(n_grupo) - 1))
	return []


# El tamaño del corro como lo tira el juego (Enemy.MANADA_POR_GRUPO, segun cuantos vais).
func _tirar_manada(n_grupo: int) -> int:
	var tabla: Array = load("res://scripts/actors/enemy/enemy.gd").MANADA_POR_GRUPO[clampi(n_grupo, 1, 4)]
	var total: int = 0
	for fila in tabla:
		total += int(fila[1])
	var r: int = randi() % maxi(1, total)
	for fila in tabla:
		r -= int(fila[1])
		if r < 0:
			return int(fila[0])
	return int(tabla[0][0])


func _corro_del_piso(piso: int, n: int) -> Array:
	var tabla = load(TABLA_PISO)
	var out: Array = []
	for _i in n:
		var ed: EnemyData = tabla.elegir(piso)
		if ed == null:
			continue
		var mut: bool = false
		var id: StringName = &""
		if not _sin_mutantes and randf() < EnemyData.MUTANTE_PROB:
			mut = true
			var de1: Array = (ed.mutaciones as Array).filter(func(m): return m != null and m.grado == 1)
			if not de1.is_empty():
				id = de1[randi() % de1.size()].id
		out.append([ed, id, mut, false])
	return out


func _correr() -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.party = [Game.lider()]
	Game.lider_idx = 0
	sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	var casos: Array = _casos()
	var mios: Array = []
	for i in casos.size():
		if i % _trozos == _trozo:
			mios.append(casos[i])
	print("[sim] %d casos (de %d) x %d veces" % [mios.size(), casos.size(), _veces])
	print(CABECERA)
	print(CABECERA_P)
	print(CABECERA_E)
	print("S|tanda|reglas|piso|grupo|arma|peleas_ganadas|como_acaba|pociones_que_quedan|vida_al_acabar")
	var montado: String = ""
	var arrancada := false
	for caso in mios:
		var clave: String = "%d|%s|%s" % [caso[0], caso[1], caso[7]]
		if clave != montado:
			# Otro piso u otro grupo: los personajes nuevos y la arena otra vez (el jugador trae a sus compañeros al entrar).
			var roles: Array = GRUPOS[caso[1]]
			var pjs: Array = []
			for r in roles:
				pjs.append(_personaje(caso[0], r, roles.size() > 1, caso[7]))
			Game.party.assign(pjs)
			Game.lider_idx = 0
			Game.arena_piso_juego = caso[0]
			var ok: bool = await sala.remontar(Game.PISO_ARENA) if arrancada \
				else await sala.arrancar("simulador_peleas_%d" % _trozo, Game.PISO_ARENA, 424242, false)
			arrancada = true
			if not ok:
				print("[sim] MAL: no se monta la arena del piso %d" % caso[0])
				return
			montado = clave
		for _v in _veces:
			if String(caso[2]) == "seguida":
				await _seguida(caso)
				continue
			var r: String = await _pelea(caso)
			print(r)
			for l in _lineas_extra:
				print(l)
			_lineas_extra.clear()


# ------------------------------------------------------------
#  UNA PELEA
# ------------------------------------------------------------
var _cb: Node = null
var _turnos: Dictionary = {}
var _acciones: Dictionary = {}
var _plan: Dictionary = {}
var _quieto: int = 0
var _pasos: int = 0
var _mejor_dist: float = INF
var _pos_antes: Vector2 = Vector2.ZERO
var _usado: Dictionary = {}   # Combatant -> {"manto": true, "buff": true}
var _apuntes := 0
var _hist: Dictionary = {}
var _rehacer_arena := false
var _hueco: Node = null
# LA MEDICION de cada pelea
var _n_pelea := 0
var _lineas_extra: Array = []
var _actor: Combatant = null              # el del turno (a quien se le apunta el daño que entra en el bando de enfrente)
var _accion_de: Dictionary = {}           # Combatant -> lo ultimo que eligio (el daño de su turno va a esa accion)
var _hecho: Dictionary = {}               # Combatant -> daño hecho
var _recibido: Dictionary = {}            # Combatant -> daño recibido (la vida que le quitaron, ya con todo)
var _por_accion: Dictionary = {}          # Combatant -> {accion: [usos, daño]}
var _fuera: Dictionary = {"aliados": 0.0, "enemigos": 0.0}   # daño sin dueño claro (contraataques, DoT): por bando
var _recursos: Dictionary = {}            # Combatant -> energia y mana turno a turno
var _pociones: Dictionary = {}            # Combatant -> pociones que bebio o dio
var _por_estado: Dictionary = {"aliados": {}, "enemigos": {}}   # bando que lo HACE -> {estado: daño} (los DoT)
var _elem_de: Dictionary = {}             # Combatant -> elemento de lo que eligio
var _por_elem: Dictionary = {}            # Combatant -> {elemento: daño}


func _rol(c: Combatant) -> String:
	var pj: PersonajeData = Game.pj_de_combatant(c)
	return String(pj.get_meta("rol", "guerrero")) if pj != null else "guerrero"


func _linea_error(caso: Array, que: String) -> String:
	return "R|%s|%s|%d|%s|%s|%s|%s|-|0|0|0|%s" % [_tanda, _reglas, caso[0], caso[1], caso[2], caso[7] if caso[7] != "" else "-",
		caso[3].enemy_name if caso[3] != null else "-", que]


# Una bajada entera: peleas hasta caer (o SEGUIDA_MAX). Cada pelea sale como las demas (escenario "seguida", con su numero
# en 'n_seguida'), y al final una linea S con cuantas aguanto y como acabo.
func _seguida(caso: Array) -> void:
	for p in Game.party:
		_reponer(p)
	Game.ability_cooldowns_persist.clear()
	_llenar_bolsa(caso[0], true)   # la bolsa de la bajada (dos y dos)
	var ganadas: int = 0
	var final: String = "TOPE"
	for k in SEGUIDA_MAX:
		_n_seguida = k + 1
		var r: String = await _pelea(caso, false)
		print(r)
		for l in _lineas_extra:
			print(l)
		_lineas_extra.clear()
		var cols: PackedStringArray = r.split("|")   # [12] = gana (ver CABECERA)
		if cols.size() > 12 and cols[12] == "GANA":
			ganadas += 1
		else:
			final = cols[12] if cols.size() > 12 else "ERROR"
			break
	var vida: Array = []
	for p in Game.party:
		vida.append("%s:%.0f" % [String(p.get_meta("rol", "?")), maxf(0.0, p.current_hp)])
	print("S|%s|%s|%d|%s|%s|%d|%s|%d|%s" % [_tanda, _reglas, caso[0], caso[1], caso[7] if caso[7] != "" else "-", ganadas, final,
		Game.consumibles_total(), ",".join(vida)])
	_n_seguida = 0


var _n_seguida := 0
var _semilla := 0


func _pelea(caso: Array, reponer: bool = true) -> String:
	var piso: int = caso[0]
	_semilla = _semilla_fija if _semilla_fija >= 0 else randi() % 2000000000
	seed(_semilla)
	var corro: Array = _corro(caso, Game.party.size())
	if corro.is_empty():
		return _linea_error(caso, "ERROR_SIN_ENEMIGOS")
	for p in Game.party:
		if reponer:
			_reponer(p)
		else:
			# EN LA SEGUIDA solo vuelve el aguante (se repone andando); la vida y el mana, como salio de la anterior
			var maxi_: float = 100.0 + Game.stat_consolidado("resistencia", p) * 0.075 + Game.stat_consolidado("agilidad", p) * 0.025
			p.set_meta("aguante", [maxi_, maxi_])
			p.remove_meta("sin_fuelle")
		if String(p.get_meta("rol", "")) == "guerrero":
			_poner_magias_guerrero(p, corro[0][0], corro[0][1])
	if reponer:
		Game.ability_cooldowns_persist.clear()
		_llenar_bolsa(piso, corro.any(func(c): return c[3]))
	var suelo: Node = sala.piso.primero(&"dungeon_floor")
	if suelo != null and suelo.has_method("limpiar_arena"):
		suelo.limpiar_arena()
	await _esperar(2)
	# SIEMPRE EN EL CENTRO DE LA SALA (19/11): pelea tras pelea el jugador acababa pegado al borde o al porton, y el enemigo
	# nacia donde no habia camino entre los dos (120 turnos mirandose: "no llega a nadie y se queda a la espera").
	var centro: Vector2 = suelo.gen.centro_px((suelo.gen.salas[0] as Rect2i).get_center())
	sala.jugador.recolocar(centro - Vector2(DIST_INICIO * 0.5, 0))
	await _esperar(2)
	var nodos: Array = []
	var t: float = randf()
	for i in corro.size():
		var c: Array = corro[i]
		var y: float = (float(i) - float(corro.size() - 1) * 0.5) * 55.0
		var es_muneco: bool = String(caso[2]) == "muneco"
		var nodo = suelo.crear_enemigo(c[0], centro + Vector2(DIST_INICIO * 0.5 + (0.0 if i % 2 == 0 else 40.0), y), 90.0,
			t if i == 0 else randf(), 1 if c[2] else 0, c[3], {"modo": 2, "hp": VIDA_MUNECO} if es_muneco else {}, c[1])
		if nodo != null:
			nodos.append(nodo)
			nodo.set_meta("t_sim", nodo.get("current_t") if nodo.get("current_t") != null else -1.0)
	if nodos.is_empty():
		return _linea_error(caso, "ERROR_NO_NACE")
	await _esperar(3)
	var t0: int = Time.get_ticks_msec()
	_cb = await sala.pelear(nodos, false)
	if _cb == null:
		return _linea_error(caso, "ERROR_NO_ABRE")
	_cb._aplicar_velocidad(4.0)
	_turnos.clear()
	_acciones.clear()
	_plan = {}
	_usado.clear()
	_n_pelea += 1
	_lineas_extra.clear()
	_actor = null
	_accion_de.clear()
	_hecho.clear()
	_recibido.clear()
	_por_accion.clear()
	_fuera = {"aliados": 0.0, "enemigos": 0.0}
	_recursos.clear()
	_pociones.clear()
	_por_estado = {"aliados": {}, "enemigos": {}}
	_elem_de.clear()
	_por_elem.clear()
	var aliados: Array = _cb._aliados.duplicate()
	if _ver:
		for a in aliados:
			print("   [entra] %s vida %.1f/%.1f mana %.1f/%.1f energia %.1f/%.1f" % [a.nombre, a.current_hp, a.max_hp, a.current_mp,
				a.max_mp, a.current_energy, a.max_energy])
	_cb.turno_empieza.connect(_al_empezar_turno.bind(aliados))
	Combatant.al_recibir = _al_recibir.bind(aliados)
	var mitig: Dictionary = {}
	for a in aliados:
		mitig[a] = _mitigacion(a, _cb._enemies)
	var stats_e: Dictionary = {}
	for i in mini(nodos.size(), _cb._enemies.size()):
		_cb._enemies[i].set_meta("t", float(nodos[i].get_meta("t_sim", -1.0)))
	for e in _cb._enemies:
		stats_e[e] = [e.max_hp, e.atk(), e.def_value(), e.mdef_value(), e.spd()]
	# EL MUÑECO NO ACTUA NUNCA (19/11, lo pidio: "que no actue, que se quede para recibir daño y ya"): su barra casi no se
	# llena (ni anda, ni pega, ni carga, ni se cura) y, por si acaso, lo que hiciera no quita nada.
	if String(caso[2]) == "muneco":
		for e in _cb._enemies:
			e.dummy_speed_override = 0.0001
			e.dummy_dmg_out_mult = 0.0
			_cb._gauge[e] = 0.0
	Engine.time_scale = _escala_tiempo
	var vida0: Dictionary = {}
	var mp0: float = 0.0
	for a in aliados:
		vida0[a] = a.current_hp
		mp0 += a.current_mp
	_hist.clear()
	var resultado := "?"
	var fotos: int = 0
	while true:
		await get_tree().process_frame
		fotos += 1
		if _ver and is_instance_valid(_cb):
			var k: String = "st%d fase%d" % [int(_cb._state), int(_cb.turno_mapa._fase)]
			_hist[k] = int(_hist.get(k, 0)) + 1
			_hist["~nodos"] = int(_hist.get("~nodos", 0)) + int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
			_hist["~ms_proceso"] = float(_hist.get("~ms_proceso", 0.0)) + Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			_hist["~ms_fisica"] = float(_hist.get("~ms_fisica", 0.0)) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			var efx: int = 0
			for n in get_tree().root.find_children("*", "EfectoPixel", true, false):
				efx += 1
			_hist["~efectos_pixel"] = int(_hist.get("~efectos_pixel", 0)) + efx
		if not is_instance_valid(_cb):
			resultado = "CERRADA"
			break
		if int(_cb._state) == 3:
			resultado = "GANA" if not _cb._aliados_vivos().is_empty() else "PIERDE"
			break
		if String(caso[2]) == "muneco" and float(_cb.reloj_barra) / float(_cb.RELOJ_POR_CICLO) >= CICLOS_MUNECO:
			resultado = "MUNECO"
			break
		var mios: int = 0
		for a in aliados:
			mios += int(_turnos.get(a, 0))
		if mios >= TOPE_TURNOS:
			resultado = "TABLAS"
			_volcar_atasco()
			break
		if (Time.get_ticks_msec() - t0) / 1000.0 > TOPE_SEGUNDOS:
			resultado = "ATASCADA"
			_volcar_atasco()
			break
		_pilotar()
	_soltar_teclas()
	Engine.time_scale = 1.0
	Combatant.al_recibir = Callable()
	var seg: float = (Time.get_ticks_msec() - t0) / 1000.0
	# Lo que les quitaste: a todos los de su bando que llegaron a estar (crias y refuerzos incluidos).
	var quitado: float = 0.0
	var enems: Array = _cb._enemies if is_instance_valid(_cb) else []
	for e in enems:
		quitado += maxf(0.0, e.max_hp - maxf(0.0, e.current_hp))
	var mis_turnos: int = 0
	var sus_turnos: int = 0
	for c in _turnos:
		if aliados.has(c):
			mis_turnos += int(_turnos[c])
		else:
			sus_turnos += int(_turnos[c])
	# LO QUE LE QUEDA va a su ficha (la mazmorra seguida lo arrastra): el que cae se levanta con 1 si el grupo gana.
	for a in aliados:
		var pj_a: PersonajeData = Game.pj_de_combatant(a)
		if pj_a != null:
			pj_a.current_hp = maxf(1.0, a.current_hp) if resultado == "GANA" else maxf(0.0, a.current_hp)
			pj_a.current_mp = maxf(0.0, a.current_mp)
	var perdida: float = 0.0
	var perdida_abs: float = 0.0
	var caidos: int = 0
	var mp1: float = 0.0
	for a in aliados:
		var l: float = float(vida0[a]) - maxf(0.0, a.current_hp)
		perdida += l / maxf(1.0, a.max_hp)
		perdida_abs += l
		mp1 += a.current_mp
		if not a.is_alive():
			caidos += 1
	perdida /= maxf(1.0, float(aliados.size()))
	var acc: Array = []
	for k in _acciones:
		acc.append("%s:%d" % [k, _acciones[k]])
	var e0: Array = corro[0]
	var mut_txt: String = "-"
	for c in corro:
		if c[2]:
			mut_txt = String(c[1]) if c[1] != &"" else "mutante"
	var linea: String = "R|%s|%s|%d|%s|%s|%s|%s|%s|%d|%d|%.2f|%s|%d|%d|%.3f|%d|%.1f|%.2f|%.2f|%.1f|%s|%d|%.1f" % [_tanda, _reglas,
		piso, caso[1], caso[2], caso[7] if caso[7] != "" else "-", (e0[0] as EnemyData).enemy_name if String(caso[2]) != "piso" else _nombres_corro(corro),
		mut_txt, 1 if corro.any(func(c): return c[3]) else 0, enems.size(), t, resultado, mis_turnos, sus_turnos, perdida,
		caidos, mp0 - mp1, quitado / maxf(1.0, float(mis_turnos)), perdida_abs / maxf(1.0, float(sus_turnos)), seg,
		",".join(acc), fotos, seg * 1000.0 / maxf(1.0, float(fotos))]
	var pelea_id: String = "%d-%d" % [_trozo, _n_pelea]
	# LOS CICLOS (19/11, su definicion, como los 100 de accion de HSR): 1 ciclo = lo que tarda alguien con velocidad 5 (la
	# base del jugador) en actuar dos veces. Solo corre cuando corre la barra (no mientras decides).
	var ciclos: float = maxf(0.01, float(_cb.reloj_barra) / float(_cb.RELOJ_POR_CICLO)) if is_instance_valid(_cb) else 0.01
	var ed0: EnemyData = corro[0][0]
	var repetir: String = "%d,%s,%s,%s,%s,%s,%d,%s" % [piso, caso[1], caso[2], caso[7] if caso[7] != "" else "-",
		ed0.resource_path.get_file().get_basename() if String(caso[2]) in ["uno", "manada", "muneco", "jefe"] else "-",
		(String(caso[4]) if caso[4] != &"" else ("mutante" if caso[5] else "-")) if String(caso[2]) == "uno" else "-",
		_semilla, str(_escala_tiempo)]
	linea += "|%s|%.2f|%.2f|%s|%s|%d|%s" % [pelea_id, ciclos, quitado / ciclos, _txt_reparto(_por_estado["aliados"]),
		_txt_reparto(_por_estado["enemigos"]), _n_seguida, repetir]
	var comun: String = "%s|%s|%s|%d|%s|%s|%d|%s" % [_tanda, _reglas, pelea_id, piso, caso[1], caso[2], enems.size(), resultado]
	for a in aliados:
		var pj: PersonajeData = Game.pj_de_combatant(a)
		var rec: Dictionary = _recursos.get(a, {})
		var n_t: int = int(_turnos.get(a, 0))
		var acc_a: Array = []
		var pa: Dictionary = _por_accion.get(a, {})
		for k in pa:
			acc_a.append("%s:%d:%.1f" % [k, int(pa[k][0]), float(pa[k][1])])
		var arma_a: String = pj.equipped_main.resource_path.get_file().get_basename() if pj != null and pj.equipped_main != null else "-"
		if pj != null and pj.equipped_off != null:
			arma_a += "+" + pj.equipped_off.resource_path.get_file().get_basename()
		_lineas_extra.append("P|%s|%s|%s|%s|%.1f|%.2f|%.2f|%.3f|%.3f|%.1f|%.1f|%d|%.2f|%.2f|%d|%.3f|%d|%d|%.1f|%d|%d|%d|%s" % [comun,
			_rol(a), arma_a, _armadura_de(pj), a.max_hp, a.def_value(), a.mdef_value(), float(mitig[a][0]), float(mitig[a][1]),
			float(_hecho.get(a, 0.0)), float(_recibido.get(a, 0.0)), n_t, float(_hecho.get(a, 0.0)) / maxf(1.0, float(n_t)),
			float(_recibido.get(a, 0.0)) / maxf(1.0, float(sus_turnos)), 0 if a.is_alive() else 1,
			float(rec.get("en_suma", 0.0)) / maxf(1.0, float(rec.get("n", 0))), int(rec.get("sin_en", 0)),
			int(rec.get("primer_en", -1)), _mp_gastado(a, rec), int(rec.get("sin_mp", 0)),
			int(rec.get("primer_mp", -1)), int(_pociones.get(a, 0)), ",".join(acc_a)]
			+ "|%d|%d|%d|%s|%.2f|%.2f|%.1f|%.1f|%.3f|%.3f" % [int(_prog(piso)[0]), int(_prog(piso)[3]),
			int(_prog(piso)[4]), _habs(a), a.atk(), a.spd(), a.max_mp, a.max_energy, a.armor_reduction, a.armor_reduction_magica]
			+ "|%.2f|%.2f|%.2f|%.2f|%s" % [ciclos, float(_hecho.get(a, 0.0)) / ciclos, float(n_t) / ciclos,
			float(_recibido.get(a, 0.0)) / ciclos, _txt_reparto(_por_elem.get(a, {}))]
			+ "|" + ";".join(Game.habilidades_equipadas(pj).map(func(ab): return ab.nombre)) if pj != null else "")
	for e in enems:
		var st: Array = stats_e.get(e, [e.max_hp, e.atk(), e.def_value(), e.mdef_value(), e.spd()])
		var n_e: int = int(_turnos.get(e, 0))
		var mut_e: String = String(e.get("mutacion")) if e.get("mutacion") != null else ""
		_lineas_extra.append("E|%s|%s|%s|%d|%.1f|%.2f|%.2f|%.2f|%.2f|%.1f|%.1f|%d|%.2f|%d" % [comun, e.nombre,
			mut_e if mut_e != "" else "-", 1 if e.get("es_boss") else 0,
			float(st[0]), float(st[1]), float(st[2]), float(st[3]), float(st[4]), float(_hecho.get(e, 0.0)),
			float(_recibido.get(e, 0.0)), n_e, float(_hecho.get(e, 0.0)) / maxf(1.0, float(n_e)), 0 if e.is_alive() else 1]
			+ "|%.2f|%s|%.2f|%.3f" % [float(e.get_meta("t", -1.0)), _habs(e), e.atk_magico() if e.abilities_eff().magia > 0 else 0.0,
			e.armor_reduction] + "|%.2f|%.2f|%.2f" % [ciclos, float(_hecho.get(e, 0.0)) / ciclos, float(n_e) / ciclos])
	if _ver:
		print("   [fotogramas] ", _hist)
		if is_instance_valid(_cb):
			for l in _cb._log_lines:
				print("   LOG ", l)
	await _cerrar()
	return linea


# EL TURNO DE ALGUIEN: a el se le apunta el daño que entre ahora en el bando de enfrente; y, si es de los tuyos, como
# llega de energia y de mana (¿puede pagar su habilidad de daño mas barata? ¿y su hechizo mas barato?).
func _al_empezar_turno(c: Combatant, aliados: Array) -> void:
	_turnos[c] = int(_turnos.get(c, 0)) + 1
	_actor = c
	if not aliados.has(c):
		return
	var r: Dictionary = _recursos.get(c, {"en_suma": 0.0, "n": 0, "sin_en": 0, "primer_en": -1, "sin_mp": 0, "primer_mp": -1,
		"mp_baja": 0.0, "mp_ant": c.current_mp})
	var n: int = int(_turnos[c])
	r["en_suma"] = float(r["en_suma"]) + c.current_energy / maxf(1.0, c.max_energy)
	r["n"] = int(r["n"]) + 1
	var barata: float = INF
	for ab in c.abilities_combate:
		if ab != null and ab.dano_mult > 0.0 and not ab.es_preparacion():
			barata = minf(barata, ab.coste(c.ability_manos(ab)))
	if barata < INF and c.current_energy < barata:
		r["sin_en"] = int(r["sin_en"]) + 1
		if int(r["primer_en"]) < 0:
			r["primer_en"] = n
	var barato: float = INF
	for sp in c.spells:
		if sp.tipo == SpellData.TipoEfecto.ATAQUE and sp.dano_base > 0.0:
			barato = minf(barato, sp.coste_mana)
	if barato < INF and c.current_mp < barato:
		r["sin_mp"] = int(r["sin_mp"]) + 1
		if int(r["primer_mp"]) < 0:
			r["primer_mp"] = n
	# el mana gastado: lo que baja entre turno y turno (lo que sube, pociones y recargas, no resta)
	var baja: float = float(r["mp_ant"]) - c.current_mp
	if baja > 0.0:
		r["mp_baja"] = float(r["mp_baja"]) + baja
	r["mp_ant"] = c.current_mp
	_recursos[c] = r


func _mp_gastado(a: Combatant, rec: Dictionary) -> float:
	return float(rec.get("mp_baja", 0.0)) + maxf(0.0, float(rec.get("mp_ant", a.current_mp)) - a.current_mp)


# CADA DAÑO QUE ENTRA (Combatant.al_recibir): al que lo recibe, y al que tiene el turno si es del otro bando (a su accion).
# El DoT y lo que entra fuera de turno (contraataques, espinas) va a la cuenta de su bando, sin dueño.
func _al_recibir(v: Combatant, dano: float, es_dot: bool, aliados: Array) -> void:
	if dano <= 0.0:
		return
	_recibido[v] = float(_recibido.get(v, 0.0)) + dano
	var v_aliado: bool = aliados.has(v)
	if es_dot or _actor == null or aliados.has(_actor) == v_aliado:
		var bando: String = "enemigos" if v_aliado else "aliados"
		_fuera[bando] = float(_fuera[bando]) + dano
		if es_dot:
			# repartido entre los estados que ardian, en proporcion (Combatant.ultimo_dot)
			var des: Dictionary = v.ultimo_dot
			var tot: float = 0.0
			for k in des:
				tot += float(des[k])
			for k in des:
				var parte: float = dano * float(des[k]) / maxf(tot, 0.0001)
				_por_estado[bando][k] = float(_por_estado[bando].get(k, 0.0)) + parte
			if des.is_empty():
				_por_estado[bando]["?"] = float(_por_estado[bando].get("?", 0.0)) + dano
		return
	_hecho[_actor] = float(_hecho.get(_actor, 0.0)) + dano
	if aliados.has(_actor):
		var el: String = _elem_de.get(_actor, "fisico")
		if not _por_elem.has(_actor):
			_por_elem[_actor] = {}
		_por_elem[_actor][el] = float(_por_elem[_actor].get(el, 0.0)) + dano
		var k: String = _accion_de.get(_actor, "?")
		if not _por_accion.has(_actor):
			_por_accion[_actor] = {}
		if not _por_accion[_actor].has(k):
			_por_accion[_actor][k] = [0, 0.0]
		_por_accion[_actor][k][1] = float(_por_accion[_actor][k][1]) + dano


# Lo que elige cada uno (y cuantas veces): el daño de su turno se le apunta a esto.
func _eligio(yo: Combatant, que: String) -> void:
	_accion_de[yo] = que
	# EL ELEMENTO de lo que hace: el del hechizo; el de los golpes, fisico (o "fisico+fuego" con un Filo puesto).
	var el: String = "fisico"
	for sp in yo.spells:
		if sp.nombre == que:
			el = Elementos.nombre(sp.elemento).to_lower() if sp.elemento > 0 else "neutro"
	if el == "fisico" and yo.imbue_elemento > 0 and (yo.imbue_usos > 0 or yo.imbue_pct > 0.0):
		el = "fisico+" + Elementos.nombre(yo.imbue_elemento).to_lower()
	_elem_de[yo] = el
	if not _por_accion.has(yo):
		_por_accion[yo] = {}
	if not _por_accion[yo].has(que):
		_por_accion[yo][que] = [0, 0.0]
	_por_accion[yo][que][0] = int(_por_accion[yo][que][0]) + 1


# CUANTO LE QUITA SU DEFENSA Y SU ARMADURA a lo que le tiran ESTOS enemigos (la media): fisico y magico (0 = sin magia).
func _mitigacion(a: Combatant, enemigos: Array) -> Array:
	var f: float = 0.0
	var nf: int = 0
	var m: float = 0.0
	var nm: int = 0
	for e in enemigos:
		var at: float = e.atk()
		if at > 0.0:
			f += 1.0 - StatsMath.damage(at, a.def_value()) * (1.0 - clampf(a.armor_reduction, 0.0, StatsMath.ARMOR_REDUCTION_MAX)) / at
			nf += 1
		if e.abilities_eff().magia > 0:
			var am: float = e.atk_magico()
			if am > 0.0:
				m += 1.0 - StatsMath.damage(am, a.mdef_value()) * (1.0 - clampf(a.armor_reduction_magica, 0.0, StatsMath.ARMOR_REDUCTION_MAX)) / am
				nm += 1
	return [f / maxf(1.0, float(nf)), m / float(nm) if nm > 0 else 0.0]


# Sus habilidades de verdad en esta pelea (con bonos): Fuerza/Resistencia/Agilidad/Destreza/Magia/Voluntad.
func _habs(c: Combatant) -> String:
	var a: Abilities = c.abilities_eff()
	return "%d/%d/%d/%d/%d/%d" % [a.fuerza, a.resistencia, a.agilidad, a.destreza, a.magia, a.voluntad]


func _armadura_de(pj: PersonajeData) -> String:
	if pj == null or pj.equipped_pecho == null:
		return "-"
	var n: String = pj.equipped_pecho.resource_path.get_file().get_basename()
	return n.split("_")[0] + ("+escudo" if pj.equipped_off is ShieldData else "")


# {cosa: daño} -> "cosa:daño,cosa:daño" (de mas a menos)
func _txt_reparto(d: Dictionary) -> String:
	var ks: Array = d.keys()
	ks.sort_custom(func(a, b): return float(d[a]) > float(d[b]))
	var out: Array = []
	for k in ks:
		out.append("%s:%.1f" % [String(k).replace(",", " ").replace(":", " ").replace("|", " "), float(d[k])])
	return ",".join(out)


func _nombres_corro(corro: Array) -> String:
	var n: Array = []
	for c in corro:
		n.append((c[0] as EnemyData).enemy_name)
	n.sort()
	return "+".join(n)


# Donde se ha quedado: para arreglar el piloto (o encontrar un fallo del juego).
func _volcar_atasco() -> void:
	_rehacer_arena = true
	var tm = _cb.turno_mapa
	var cajas: Array = []
	for k in ["_actions_box", "_spell_box", "_ability_box", "_cast_box", "_objeto_box"]:
		var c = _cb.get(k)
		if c != null and _visible(c):
			cajas.append(k)
	var yo: Combatant = _cb._player
	if yo != null and _cb._aliados.has(yo):
		print("   [atasco] %s pies %s inicio %s radio %.0f eje %s" % [yo.nombre, str(tm.pies_de(yo).round()),
			str(tm._inicio.round()), float(tm._radio), str(Input.get_vector("move_left", "move_right", "move_up", "move_down"))])
	print("   [atasco] estado %d jugador %s plan %s cajas %s apuntando %s fase %d quien %s andando %s" % [int(_cb._state),
		_cb._player.nombre if _cb._player != null else "-", str(_plan), str(cajas), str(tm.esta_apuntando()), int(tm._fase),
		tm._quien.nombre if tm._quien != null else "-", str(tm._andando)])
	for e in _cb._enemies:
		print("   [atasco]   %s vida %.1f/%.1f elegible %s pies %s" % [e.nombre, e.current_hp, e.max_hp, str(not e.no_elegible()),
			str(tm.pies_de(e).round()) if tm.cuerpo_de(e) != null else "-"])
	var ls: Array = _cb._log_lines
	for i in range(maxi(0, ls.size() - 6), ls.size()):
		print("   [atasco]   LOG ", ls[i])


func _cerrar() -> void:
	if is_instance_valid(_cb):
		if int(_cb._state) != 3:
			_cb._state = _cb.State.FINISHED
		_cb._on_continue_pressed()
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000 and sala.peleando():
		await get_tree().process_frame
	await _esperar(3)
	# Lo que quede en la arena (un enemigo de una pelea cortada, crias, cadaveres) fuera: no se puede colar en la siguiente.
	if sala.piso != null and is_instance_valid(sala.piso):
		for g in [&"enemy", &"corpse"]:
			for n in sala.piso.nodos(g):
				if is_instance_valid(n):
					n.remove_from_group(String(g))
					n.queue_free()
	await _esperar(2)
	# Si han caido, la arena puede haberles sacado: se vuelve a montar (y al grupo dentro). Tambien tras una pelea atascada
	# o en tablas: que lo que se quedara roto no se arrastre a las siguientes.
	# EL PUEBLO FUERA (19/11): al perder, el juego te manda al pueblo (Net.pisos.viajar_al_pueblo) y se cargaba ENTERO de fondo
	# (~1500 nodos: casas, humo, antorchas, sonidos) y se quedaba vivo el resto de la tanda, procesandose en cada fotograma.
	var habia_pueblo := false
	for h in get_tree().root.get_children():
		if h.scene_file_path == "res://scenes/levels/town.tscn":
			habia_pueblo = true
			# ANTES de quitarlo: hay quien lee la escena actual (la puerta de la arena al montarse). El viaje al pueblo CAMBIA DE
			# ESCENA y se lleva por delante nuestro nodo vacio: si ya no esta, uno nuevo.
			if not is_instance_valid(_hueco):
				_hueco = Node.new()
				get_tree().root.add_child(_hueco)
			get_tree().current_scene = _hueco
			h.queue_free()
	if habia_pueblo:
		await _esperar(2)
		_rehacer_arena = true
	if _ver:
		# QUE SE QUEDA COLGADO tras cada pelea (por clase y nombre de script), lo mas numeroso
		var cuenta: Dictionary = {}
		for n in get_tree().root.find_children("*", "", true, false):
			var sc = n.get_script()
			var k: String = n.get_class() + (":" + sc.resource_path.get_file() if sc != null else "")
			cuenta[k] = int(cuenta.get(k, 0)) + 1
		var ks: Array = cuenta.keys()
		ks.sort_custom(func(a, b): return cuenta[a] > cuenta[b])
		for h in get_tree().root.get_children():
			print("   [raiz] %s (%s) escena=%s hijos=%d" % [h.name, h.get_class(), h.scene_file_path, h.find_children("*", "", true, false).size()])
		print("   [nodos tras la pelea] total %d: %s" % [get_tree().root.find_children("*", "", true, false).size(),
			", ".join(ks.slice(0, 12).map(func(k): return "%s=%d" % [k, cuenta[k]]))])
	if _rehacer_arena or not Game.es_arena() or not is_instance_valid(sala.jugador):
		_rehacer_arena = false
		await sala.remontar(Game.PISO_ARENA)


func _esperar(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _apuntar_accion(que: String) -> void:
	_acciones[que] = int(_acciones.get(que, 0)) + 1


# ------------------------------------------------------------
#  EL PILOTO
# ------------------------------------------------------------
func _vivos_elegibles() -> Array:
	return _cb._enemies.filter(func(e): return e.is_alive() and not e.no_elegible())


func _fragiles(yo: Combatant) -> Array:
	return _cb._aliados_vivos().filter(func(a): return a != yo and _rol(a) in ["mago", "arquero"])


func _mas_cerca(de: Vector2, lista: Array) -> Combatant:
	var tm = _cb.turno_mapa
	var mejor: Combatant = null
	var d: float = INF
	for e in lista:
		var dd: float = tm.pies_de(e).distance_to(de)
		if dd < d:
			d = dd
			mejor = e
	return mejor


# A QUIEN, segun el rol: el tanque al que mas cerca este de los fragiles; los demas, el que antes caiga (poca vida y
# cerca); nadie elegible (en las sombras...): el primero vivo, para tener hacia donde mirar.
func _objetivo(yo: Combatant, rol: String) -> Combatant:
	var tm = _cb.turno_mapa
	var lista: Array = _vivos_elegibles()
	if lista.is_empty():
		for e in _cb._enemies:
			if e.is_alive():
				return e
		return null
	if rol == "tanque":
		var fr: Array = _fragiles(yo)
		if not fr.is_empty():
			var mejor: Combatant = null
			var d: float = INF
			for e in lista:
				for f in fr:
					var dd: float = tm.pies_de(e).distance_to(tm.pies_de(f))
					if dd < d:
						d = dd
						mejor = e
			return mejor
		return _mas_cerca(tm.pies_de(yo), lista)
	var mejor2: Combatant = null
	var p_min: float = INF
	for e in lista:
		var p: float = e.current_hp / maxf(1.0, e.max_hp) * 100.0 + tm.pies_de(e).distance_to(tm.pies_de(yo)) * 0.25
		if p < p_min:
			p_min = p
			mejor2 = e
	return mejor2


func _soltar_teclas() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)


# Como un mando: la direccion con su fuerza (largo de 'dir', hasta 1).
# (Los move_* tienen zona muerta 0,5: Input.get_vector da 0 por debajo y estira lo de encima a 0..1.)
func _andar_hacia(dir: Vector2) -> void:
	_soltar_teclas()
	var f: float = clampf(dir.length(), 0.0, 1.0)
	if f <= 0.0:
		return
	dir = dir.normalized() * (0.51 + 0.49 * f)
	if dir.x > 0.0: Input.action_press("move_right", minf(1.0, dir.x))
	if dir.x < 0.0: Input.action_press("move_left", minf(1.0, -dir.x))
	if dir.y > 0.0: Input.action_press("move_down", minf(1.0, dir.y))
	if dir.y < 0.0: Input.action_press("move_up", minf(1.0, -dir.y))


func _pilotar() -> void:
	if int(_cb._state) != 1:   # WAITING_PLAYER
		_soltar_teclas()
		return
	var yo: Combatant = _cb._player
	if yo == null or not _cb._aliados.has(yo):
		return
	var tm = _cb.turno_mapa
	var turno_id: int = int(_turnos.get(yo, 0))
	var nuevo: bool = _plan.get("quien") != yo or _plan.get("turno", -2) != turno_id or _plan.get("hecho", false)
	var obj: Combatant = _plan.get("obj") if not nuevo and _plan.get("obj") != null and (_plan["obj"] as Combatant).is_alive() \
		else _objetivo(yo, _rol(yo))
	if obj == null:
		return
	_cb._target_idx = _cb._enemies.find(obj)
	# 1) RECITANDO: la frase que toca (y al final, Lanzar hacia donde este ahora su objetivo)
	var cast: Control = _cb._cast_box
	if cast != null and _visible(cast):
		_soltar_teclas()
		if tm.recolocando():
			var k: Dictionary = _cb._casteos.get(yo, {})
			var sp_r = k.get("spell")
			var hacia: Vector2 = tm.pies_de(obj)
			if sp_r is SpellData and (sp_r as SpellData).forma_a_aliados:
				hacia = tm.pies_de(yo)
			tm.arrastrar_recolocar(hacia)
		var sp = _cb._cast_spell
		var idx: int = int(_cb._cast_index)
		var botones: Array = _botones(cast)
		if sp != null and idx < sp.frases.size():
			for b in botones:
				if b.text.ends_with(sp.frases[idx]):
					b.pressed.emit()
					return
		for b in botones:
			if not b.text.begins_with("◄"):
				b.pressed.emit()
				return
		return
	# 2) APUNTANDO una huella: al objetivo del plan (o al aliado, si es para los suyos)
	if tm.esta_apuntando():
		_soltar_teclas()
		var ab: AbilityData = tm._apuntando
		var al: Combatant = _plan.get("aliado") if _plan.get("aliado") != null else yo
		var punto: Vector2 = tm.pies_de(al) if ab.forma_a_aliados else tm.pies_de(_plan.get("obj", obj) if _plan.get("obj") != null else obj)
		tm.raton_simulado = punto
		tm._andando = false
		tm._refrescar_apunte(punto)
		tm._confirmar_apunte()
		_apuntes += 1
		if tm.esta_apuntando() and _apuntes > 20:
			tm._cancelar_apunte()
			_plan = {"que": "defender", "quien": yo, "turno": turno_id}
		return
	_apuntes = 0
	# 3) UN SUBMENU ABIERTO: el boton de lo planeado (o el aliado al que va)
	for caja in ["_spell_box", "_ability_box", "_objeto_box"]:
		var c: Control = _cb.get(caja)
		if c != null and _visible(c):
			_soltar_teclas()
			var nombre: String = _plan.get("nombre", "")
			var al2: Combatant = _plan.get("aliado") if _plan.get("aliado") != null else yo
			for b in _botones(c):
				if nombre != "" and b.text.begins_with(nombre):
					b.pressed.emit()
					_apuntar_accion("%s %s" % [_rol(yo), nombre])
					_eligio(yo, nombre)
					if _plan.get("que", "") == "objeto":
						_pociones[yo] = int(_pociones.get(yo, 0)) + 1
					var marca: String = _plan.get("marca", "")
					if marca != "":
						if not _usado.has(yo):
							_usado[yo] = {}
						_usado[yo][marca] = true
					_plan["hecho"] = true
					return
				if b.text == al2.nombre or b.text.begins_with(al2.nombre + " "):
					b.pressed.emit()   # el aliado al que va
					return
			# no esta (sin mana, en recarga...): atras y a Atacar
			for b in _botones(c):
				if b.text.begins_with("◄") or b.text.to_lower().contains("volver"):
					b.pressed.emit()
					break
			_plan = {"que": "atacar", "quien": yo, "turno": turno_id, "obj": obj}
			return
	# 4) EL MENU DE ACCIONES: plan del turno, andar y actuar
	var acciones_box: Control = _cb._actions_box
	if acciones_box == null or not _visible(acciones_box):
		return
	if nuevo:
		_plan = _decidir(yo, obj, _rol(yo))
		_plan["quien"] = yo
		_plan["turno"] = turno_id
		if not _plan.has("obj"):
			_plan["obj"] = obj
		obj = _plan["obj"]
		_cb._target_idx = _cb._enemies.find(obj)
		_pasos = 0
		_quieto = 0
		_mejor_dist = INF
		_pos_antes = tm.pies_de(yo)
		# ¿ME CAE ENCIMA LO QUE ESTA CARGANDO? (el «¡Apartate!»): fuera de su huella. El tanque no: aguanta delante.
		var sitio = _sitio_a_salvo(yo)
		if sitio != null:
			if _rol(yo) == "tanque" and _cb._action_buttons.get(3) != null and not _cb._action_buttons[3].disabled:
				_plan = {"que": "defender", "quien": yo, "turno": turno_id, "obj": obj}
				_apuntar_accion("tanque aguanta")
			else:
				_plan["huir_a"] = sitio
				_apuntar_accion("%s se aparta" % _rol(yo))
		# EL MAGO Y EL ARQUERO GUARDAN LA DISTANCIA: si tienen a alguien encima, un paso atras antes de nada.
		elif _rol(yo) in ["mago", "arquero"] and not _plan.has("huir_a"):
			var atras = _sitio_lejos(yo)
			if atras != null:
				_plan["huir_a"] = atras
				_apuntar_accion("%s se aleja" % _rol(yo))
		if _ver:
			var ver_plan: Dictionary = _plan.duplicate()
			ver_plan.erase("quien")
			for k in ["obj", "aliado"]:
				if ver_plan.get(k) != null:
					ver_plan[k] = (ver_plan[k] as Combatant).nombre
			print("   [piloto] %s turno %d plan %s | dist %.0f llega %s radio %.0f pies %s" % [yo.nombre, turno_id, str(ver_plan),
				tm.pies_de(yo).distance_to(tm.pies_de(obj)), str(tm.llega(yo, obj)), float(tm._radio), str(tm.pies_de(yo).round())])
	if _plan.has("huir_a"):
		var p0: Vector2 = tm.pies_de(yo)
		var meta: Vector2 = _plan["huir_a"]
		if p0.distance_to(meta) > 2.0 and _quieto < 6 and _pasos < 120:
			_quieto = _quieto + 1 if p0.distance_to(_pos_antes) < 0.5 else 0
			_pos_antes = p0
			_pasos += 1
			# frenando al llegar (el paso de un fotograma, a esta velocidad, son decenas de px)
			var paso: float = maxf(1.0, tm.VEL_PASEO * get_process_delta_time() * float(_cb._vel_pelea))
			_andar_hacia((meta - p0).normalized() * clampf(p0.distance_to(meta) / paso, 0.05, 1.0))
			return
		_plan.erase("huir_a")
		_quieto = 0
		_pasos = 0
		_mejor_dist = INF
	# ¿a tiro? (de su objetivo, o del aliado si va a uno de los suyos)
	var hacia_quien: Combatant = _plan.get("aliado") if _plan.get("aliado") != null and _plan.get("que", "") != "objeto" else obj
	var a_tiro: bool
	var rango: float = float(_plan.get("rango", -1.0))
	if rango >= 0.0:
		a_tiro = tm.pies_de(yo).distance_to(tm.pies_de(hacia_quien)) <= rango
	else:
		a_tiro = tm.llega(yo, obj)
	if not a_tiro and _plan.get("que", "") != "defender":
		var p: Vector2 = tm.pies_de(yo)
		# Se para en cuanto deja de ACERCARSE (el circulo se acabo, o resbala contra algo).
		var dist: float = p.distance_to(tm.pies_de(hacia_quien))
		if dist > _mejor_dist - 0.5:
			_quieto += 1
		else:
			_quieto = 0
			_mejor_dist = dist
		_pasos += 1
		if _quieto < 6 and _pasos < 240:
			_andar_hacia((tm.pies_de(hacia_quien) - p).normalized())
			return
		# SE HA ATASCADO CONTRA SU CUERPO sin llegar (19/11: el muñeco del piso 1, cualquiera que no se mueva): RODEARLE, a un
		# hueco libre de su alrededor mas cerca que donde esta. Una vez por turno.
		if not _plan.get("rodeado", false):
			_plan["rodeado"] = true
			var de: Vector2 = tm.pies_de(hacia_quien)
			var ahora: float = p.distance_to(de)
			var rodeo = _buscar_sitio(yo, func(q): return q.distance_to(de) < ahora - 8.0 and q.distance_to(de) > 12.0,
				func(q): return q.distance_to(de))
			if rodeo != null:
				_plan["huir_a"] = rodeo
				_quieto = 0
				_pasos = 0
				_mejor_dist = INF
				_apuntar_accion("%s rodea" % _rol(yo))
				return
		# no llega (se acabo el circulo): defender
		_plan = {"que": "defender", "quien": yo, "turno": turno_id, "obj": obj}
	_soltar_teclas()
	if tm._andando:
		return   # parandose: un fotograma
	var ids := {"atacar": 0, "habilidad": 1, "magia": 2, "defender": 3, "objeto": 4}
	var que: String = _plan.get("que", "atacar")
	var b: BaseButton = _cb._action_buttons.get(ids.get(que, 0))
	if b == null or b.disabled or not b.visible:
		if que != "atacar":
			b = _cb._action_buttons.get(0)
			que = "atacar"
		if b == null or b.disabled:
			b = _cb._action_buttons.get(3)
			que = "defender"
		if b == null or b.disabled:
			# EL SUELO DEL MENU: Pasar (el sexto boton, si no esta en el borde de la arena, donde seria Huir)
			b = _cb._action_buttons.get(5)
			que = "pasar"
			if b == null or b.disabled or b.text != "Pasar":
				_apuntar_accion("%s pasar" % _rol(yo))
				_eligio(yo, "pasar")
				_plan["hecho"] = true
				_cb._accion_esperar()
				return
	if b != null and not b.disabled:
		if que in ["atacar", "defender", "pasar"]:
			_apuntar_accion("%s %s" % [_rol(yo), que])
			_eligio(yo, que)
			_plan["hecho"] = true
		b.pressed.emit()


# Las huellas de lo que estan cargando los enemigos (fijas en el suelo); si me pilla alguna, el sitio mas cerca dentro de
# mi circulo de este turno que no pille ninguna (null = no hace falta, o no lo hay).
func _sitio_a_salvo(yo: Combatant):
	var tm = _cb.turno_mapa
	var formas: Array = []
	for e in _cb._enemies:
		if not e.is_alive():
			continue
		var d: Array = tm._cargas.get(e, [])
		if d.size() >= 3 and d[2] != null:
			formas.append(d[2])
	if formas.is_empty() or not tm._en_peligro(yo, tm.pies_de(yo), formas):
		return null
	return _buscar_sitio(yo, func(p): return not tm._en_peligro(yo, p, formas, true), func(p): return p.distance_to(tm.pies_de(yo)))


# EL QUE GUARDA LA DISTANCIA: si el enemigo mas cerca esta a menos de DIST_SEGURA, el sitio de su circulo que mas le
# aleje de el (null = no hace falta).
func _sitio_lejos(yo: Combatant):
	var tm = _cb.turno_mapa
	var cerca: Combatant = _mas_cerca(tm.pies_de(yo), _cb._enemies.filter(func(e): return e.is_alive()))
	if cerca == null or tm.pies_de(cerca).distance_to(tm.pies_de(yo)) >= DIST_SEGURA:
		return null
	var de: Vector2 = tm.pies_de(cerca)
	return _buscar_sitio(yo, func(p): return p.distance_to(de) > tm.pies_de(yo).distance_to(de) + 20.0,
		func(p): return -p.distance_to(de))


# El mejor punto (menor 'coste') de mi circulo que cumpla 'vale', donde se pueda estar.
func _buscar_sitio(yo: Combatant, vale: Callable, coste: Callable):
	var tm = _cb.turno_mapa
	var cuerpo: Node2D = tm.cuerpo_de(yo)
	if cuerpo == null:
		return null
	var pies: Vector2 = tm.pies_de(yo)
	var radio: float = float(tm._radio)
	var mejor = null
	var mejor_c: float = INF
	for k in 24:
		var dir := Vector2.RIGHT.rotated(TAU * float(k) / 24.0)
		var dist: float = 20.0
		while dist <= radio:
			var p: Vector2 = pies + dir * dist
			var en_cuerpo: Vector2 = cuerpo.global_position + (p - pies)
			if tm._inicio.distance_to(en_cuerpo) <= radio and vale.call(p) and tm._puede_estar(en_cuerpo, cuerpo):
				var c: float = coste.call(p)
				if c < mejor_c:
					mejor_c = c
					mejor = p
			dist += 15.0
	return mejor


func _habilidad_lista(yo: Combatant, ab: AbilityData) -> bool:
	return ab != null and not ab.es_preparacion() and ab.cargar_municion <= 0 and not ab.untar \
		and yo.ability_cd_left(ab) <= 0 and yo.has_energy(ab.coste(yo.ability_manos(ab)))


func _habilidad_por_nombre(yo: Combatant, archivo: String) -> AbilityData:
	for ab in yo.abilities_combate:
		if ab != null and ab.resource_path.get_file().get_basename() == archivo:
			return ab
	return null


# La de mas daño que pueda pagar (si pega mas que el ataque normal), o null.
func _mejor_golpe(yo: Combatant, oculto: bool) -> AbilityData:
	var tm = _cb.turno_mapa
	var mejor: AbilityData = null
	var mejor_v: float = 1.05
	for ab in yo.abilities_combate:
		if not _habilidad_lista(yo, ab) or ab.dano_mult <= 0.0 or ab.objetivo_aliado == AbilityData.Objetivo.ALIADO:
			continue
		if oculto and (not tm.usa_huella(ab) or ab.forma_a_aliados):
			continue
		var v: float = ab.dano_mult * float(ab.num_golpes(yo.ability_manos(ab), 1))
		if v > mejor_v:
			mejor_v = v
			mejor = ab
	return mejor


func _plan_golpe(yo: Combatant, obj: Combatant) -> Dictionary:
	var oculto: bool = obj.no_elegible()
	var ab: AbilityData = _mejor_golpe(yo, oculto)
	if ab != null:
		var r: float = -1.0
		if oculto:
			r = maxf(30.0, (ab.forma_rango if ab.forma_rango > 0.0 else ab.forma_radio) * 0.8)
		return {"que": "habilidad", "nombre": ab.nombre, "rango": r}
	if oculto:
		return {"que": "defender"}
	return {"que": "atacar", "rango": -1.0}


# Lo que hace este turno: {"que": atacar|habilidad|magia|defender, "nombre": boton, "rango": px o -1 (alcance del arma),
# "obj": a quien, "aliado": a cual de los suyos (curas, muro), "marca": lo que solo se hace una vez por pelea}.
func _decidir(yo: Combatant, obj: Combatant, rol: String) -> Dictionary:
	var tm = _cb.turno_mapa
	# EL MAGO CURA CON SU MAGIA si puede (la pocion es para cuando no hay otra)
	if rol == "mago":
		var cura0 = _plan_cura(yo, false)
		if cura0 != null:
			return cura0
	var pocion = _plan_pocion(yo, rol)
	if pocion != null:
		return pocion
	match rol:
		"tanque":
			var fr: Array = _fragiles(yo)
			# MURO sobre el fragil tocado
			var muro: AbilityData = _habilidad_por_nombre(yo, "muro_guardian")
			if muro != null and _habilidad_lista(yo, muro):
				for f in fr:
					if f.current_hp / maxf(1.0, f.max_hp) < VIDA_MURO:
						return {"que": "habilidad", "nombre": muro.nombre, "rango": muro.forma_rango * 0.9, "aliado": f}
			# PROVOCACION si alguien anda cerca de los fragiles (o, solo, si hay varios)
			var prov: AbilityData = _habilidad_por_nombre(yo, "provocacion")
			if prov != null and _habilidad_lista(yo, prov):
				var amenaza: bool = false
				for e in _vivos_elegibles():
					for f in fr:
						if tm.pies_de(e).distance_to(tm.pies_de(f)) < 160.0:
							amenaza = true
				if amenaza or (fr.is_empty() and _vivos_elegibles().size() >= 2):
					return {"que": "habilidad", "nombre": prov.nombre, "rango": prov.forma_radio * 0.7}
			return _plan_golpe(yo, obj)
		"guerrero", "arquero":
			var cura = _plan_cura(yo, true)
			if cura != null:
				return cura
			if not _usado.get(yo, {}).has("filo"):
				for s in yo.spells:
					if s.es_imbuicion() and yo.imbue_usos <= 0 and yo.imbue_pct <= 0.0 and s.coste_mana <= yo.current_mp:
						return {"que": "magia", "nombre": s.nombre, "rango": 99999.0, "aliado": yo, "marca": "filo"}
			if not _usado.get(yo, {}).has("manto"):
				for s in yo.spells:
					if not s.es_imbuicion() and s.tipo == SpellData.TipoEfecto.BUFF and s.coste_mana <= yo.current_mp:
						return {"que": "magia", "nombre": s.nombre, "rango": 99999.0, "aliado": yo, "marca": "manto"}
			return _plan_golpe(yo, obj)
		"mago":
			var cura2 = _plan_cura(yo, false)
			if cura2 != null:
				return cura2
			if _cb._aliados_vivos().size() > 1 and not _usado.get(yo, {}).has("buff"):
				for s in yo.spells:
					if s.tipo == SpellData.TipoEfecto.BUFF and s.forma_a_aliados and s.coste_mana <= yo.current_mp:
						return {"que": "magia", "nombre": s.nombre, "rango": 99999.0, "aliado": yo, "marca": "buff"}
			var m = _plan_hechizo(yo)
			if m != null:
				return m
			return {"que": "atacar", "rango": -1.0}
	return _plan_golpe(yo, obj)


# LAS POCIONES, como las usaria un jugador: la de vida a alguien de los suyos que este por debajo del 25 % (el mas tocado),
# no por cuatro rasguños; la de mana, el mago que ya no puede pagar ni su hechizo mas barato. Y nunca con la pelea casi
# ganada (lo que les queda a ellos cabe en un par de golpes tuyos).
const VIDA_POCION := 0.25

func _plan_pocion(yo: Combatant, rol: String):
	if Game.consumibles_total() <= 0:
		return null
	var b: BaseButton = _cb._action_buttons.get(4)
	if b == null or b.disabled:
		return null
	var les_queda: float = 0.0
	for e in _cb._enemies:
		if e.is_alive():
			les_queda += e.current_hp
	if les_queda <= yo.atk() * 2.0:
		return null
	var vida: ConsumableData = null
	var mana: ConsumableData = null
	for c in Game.consumables:
		if int(Game.consumables[c]) <= 0:
			continue
		if c.da_mana():
			mana = c
		elif c.cura_total > 0.0 or c.cura_pct > 0.0:
			vida = c
	if vida != null:
		var peor: Combatant = null
		var v_min: float = VIDA_POCION
		for a in _cb._aliados_vivos():
			var v: float = a.current_hp / maxf(1.0, a.max_hp)
			if v < v_min:
				v_min = v
				peor = a
		if peor != null:
			return {"que": "objeto", "nombre": vida.nombre, "aliado": peor, "rango": 99999.0}
	if mana != null and rol == "mago":
		var barato: float = INF
		for s in yo.spells:
			if s.tipo == SpellData.TipoEfecto.ATAQUE:
				barato = minf(barato, s.coste_mana)
		if yo.current_mp < barato:
			return {"que": "objeto", "nombre": mana.nombre, "aliado": yo, "rango": 99999.0}
	return null


# CURAR: al de los suyos que este por debajo de VIDA_CURA (el mas tocado). 'solo_yo' = el guerrero solo se cura a si mismo.
func _plan_cura(yo: Combatant, solo_yo: bool):
	var cura: SpellData = null
	for s in yo.spells:
		if s.tipo == SpellData.TipoEfecto.CURACION and s.coste_mana <= yo.current_mp:
			cura = s
	if cura == null:
		return null
	var peor: Combatant = null
	var v_min: float = VIDA_CURA
	for a in ([yo] if solo_yo else _cb._aliados_vivos()):
		var v: float = a.current_hp / maxf(1.0, a.max_hp)
		if v < v_min:
			v_min = v
			peor = a
	if peor == null:
		return null
	return {"que": "magia", "nombre": cura.nombre, "rango": 99999.0, "aliado": peor}


# EL MAGO: el hechizo y el sitio que mas daño esperan por turno de recitado (contando a cuantos pilla el area), entre los
# que puede pagar. Con alguien encima o algo cargado contra el, solo los de una frase (no le tiran el conjuro).
func _plan_hechizo(yo: Combatant):
	var tm = _cb.turno_mapa
	var lista: Array = _vivos_elegibles()
	var ocultos: bool = lista.is_empty()
	if ocultos:
		lista = _cb._enemies.filter(func(e): return e.is_alive())
	if lista.is_empty():
		return null
	var cerca: Combatant = _mas_cerca(tm.pies_de(yo), lista)
	var apurado: bool = _sitio_a_salvo(yo) != null or (cerca != null and tm.pies_de(cerca).distance_to(tm.pies_de(yo)) < DIST_SEGURA)
	var mejor = null
	var mejor_d: float = 0.0
	for s in yo.spells:
		if s.tipo != SpellData.TipoEfecto.ATAQUE or s.coste_mana > yo.current_mp or s.dano_base <= 0.0:
			continue
		if apurado and s.frases.size() > 1:
			continue
		if ocultos and not tm.usa_huella_hechizo(s):
			continue
		for e in lista:
			var d: float = 0.0
			for _i in 6:
				d += float(StatsMath.resolve_spell(yo, e, s, s.elemento, 1.0).damage)
			d /= 6.0
			# EL AREA: a cuantos mas pilla alrededor (el salpicon pega menos que el golpe principal)
			if s.salpica() or s.forma_radio > 0.0:
				var r: float = maxf(s.forma_radio, 40.0)
				var mas: int = 0
				for o in lista:
					if o != e and tm.pies_de(o).distance_to(tm.pies_de(e)) <= r:
						mas += 1
				d *= 1.0 + 0.6 * float(mas)
			d /= float(maxi(1, s.frases.size()))
			if d > mejor_d:
				mejor_d = d
				mejor = {"que": "magia", "nombre": s.nombre, "obj": e,
					"rango": s.forma_rango * 0.85 if s.forma_rango > 0.0 else 99999.0}
	return mejor


# Visible dentro de la pantalla de combate (la capa de la sala no se pinta: nadie la mira).
func _visible(c: CanvasItem) -> bool:
	var n: Node = c
	while n != null and n != _cb:
		if n is CanvasItem and not (n as CanvasItem).visible:
			return false
		n = n.get_parent()
	return true


func _botones(nodo: Node) -> Array:
	var out: Array = []
	for h in nodo.get_children():
		if h is BaseButton and not (h as BaseButton).disabled and (h as Control).visible:
			out.append(h)
		out.append_array(_botones(h))
	return out
