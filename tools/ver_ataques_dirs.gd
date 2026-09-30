# HOJAS DE LOS ATAQUES DEL MAPA, ENTEROS Y EN CINCO DIRECCIONES (lo pidio el usuario el 24/09, al estilo
# de ver_suelo_roto: suelo de losetas, tu en azul y enemigos en rojo). Una hoja por habilidad: una fila
# por direccion (N, NE, E, SE, S) y en cada fila la HUELLA al apuntar y cinco momentos de su efecto.
# La forma sale de la FICHA (de_habilidad_mapa, con el alcance de su arma), asi que es la de verdad.
# CON VENTANA.
#   ATAQUES_SALIDA=/carpeta ATAQUES_LISTA=tajo_del_verdugo godot --path . res://tools/ver_ataques_dirs.tscn
extends Node2D

# El combate tactico no tiene class_name: sus constantes (el salto de los enemigos) se leen de su script.
const _TACTICO := preload("res://scripts/ui/combat_tactico.gd")
const LADO := 420            # px de pantalla de cada viñeta
const HABILIDADES := [
	["martillo", "golpe_sismico"], ["martillo", "martillo_de_guerra"], ["martillo", "rompecorazas"],
	["martillo", "onda_expansiva"], ["martillo", "temblor"],
	["mandoble", "molinete"], ["mandoble", "segar"], ["mandoble", "tajo_devastador"],
	["mandoble", "tajo_del_verdugo"], ["mandoble", "grito_de_guerra"],
	["hacha", "hachazo_brutal"], ["hacha", "carniceria"], ["hacha", "desgarro"], ["hacha", "hendedura"],
	["hacha", "sed_de_sangre"],
	["daga", "rafaga"], ["daga", "punalada"], ["daga", "filo_emponzonado"], ["daga", "desaparecer"],
	["daga", "oportunista"],
	["estoque", "estocada_penetrante"], ["estoque", "fintas"], ["estoque", "punzada_al_nervio"],
	["estoque", "paso_ligero"], ["estoque", "danza_de_acero"], ["estoque", "en_guardia"],
	["espada", "basico"], ["espada", "tajo_quebrantador"], ["espada", "doble_tajo"], ["espada", "cambio_de_ritmo"],
	["espada", "senalar_el_hueco"], ["espada", "corte_de_tendones"],
	["larga", "basico"], ["larga", "tajo_pesado"], ["larga", "tajo_desarmante"], ["larga", "estocada_marcial"],
	["larga", "guardia_rota"],
	["escudo", "golpe_escudo_pequeno"], ["escudo", "golpe_escudo_normal"], ["escudo", "golpe_escudo_grande"],
	["escudo", "embestida"],
	["larga", "voto_de_guardia"], ["larga", "voz_de_mando"],
	["escudo", "provocacion"], ["escudo", "cobertura"], ["escudo", "escolta"], ["escudo", "muro_guardian"],
	["escudo", "guardia_de_carne"], ["escudo", "postura_rodela"],
	# LA MAZA PEQUEÑA (25/09). "maza2" = con DOS mazas: sale como <habilidad>_dual.png.
	["maza", "basico"], ["maza", "golpe_demoledor"], ["maza2", "golpe_demoledor"], ["maza", "rompepiernas"],
	["maza2", "rompepiernas"], ["maza", "culatazo"], ["maza2", "culatazo"], ["maza", "aplastamiento"],
	["maza", "grito_de_aliento"], ["maza2", "grito_de_aliento"], ["maza", "muro_de_aliados"],
	# EL BASTON Y LA VARITA (26/09). "canalizar" = el Foco arcano del baston; "canalizar_varita", el de la varita.
	["baston", "basico"], ["baston", "bastonazo"], ["baston", "sello_arcano"], ["baston", "viento_limpio"],
	["baston", "velo_umbrio"], ["baston", "canalizar"],
	["varita", "canalizar_varita"], ["varita", "purificar"], ["varita", "chispa_vinculada"], ["varita", "egida_menor"],
	# LAS MAGIAS (26/09): la huella de cada hechizo, sacada de su ficha (CombatTactico.huella_hechizo).
	["magia", "brasa"], ["magia", "descarga"], ["magia", "rocio"], ["magia", "pulso_menor"],
	["magia", "vendaje_de_luz"], ["magia", "bola_fuego"], ["magia", "chorro_agua"], ["magia", "rayo"], ["magia", "pulso_arcano"],
	["magia", "debilidad"], ["magia", "fortaleza"], ["magia", "filo_ardiente"], ["magia", "filo_fulgurante"], ["magia", "filo_umbrio"], ["magia", "filo_torrente"], ["magia", "filo_radiante"], ["magia", "mar_de_brasas"], ["magia", "venablo_de_tormenta"],
	["magia", "estallido_solar"], ["magia", "voragine_sombra"], ["magia", "luz_restauradora"], ["magia", "shock_termico"], ["magia", "tormenta"], ["magia", "manto_brasas"], ["magia", "manto_marea"], ["magia", "manto_centellas"],
	["magia", "manto_aureo"], ["magia", "manto_umbrio"],
	["magia", "manto_prismatico"], ["magia", "eclipse"],
]
const ALCANCE := {"martillo": 32.25, "mandoble": 34.5, "hacha": 32.25, "daga": 15.0, "estoque": 32.25,
	"espada": 18.75, "larga": 23.25, "escudo": 23.25, "maza": 18.75, "maza2": 18.75,
	"baston": 21.0, "varita": 21.0, "magia": 21.0}
# LA ESPADA CORTA (EspadaAire), como la daga: golpe a golpe sobre cada cuerpo. "basico" no tiene ficha: el
# tajo de siempre sobre el de delante.
const MOMENTOS_ESPADA := {
	"basico": [-0.04, -0.01, 0.02, 0.08, 0.16],
	"tajo_quebrantador": [0.03, 0.07, 0.11, 0.18, 0.35],
	"doble_tajo": [-0.06, -0.01, 0.12, 0.2, 0.34],
	"cambio_de_ritmo": [0.04, 0.1, 0.16, 0.24, 0.4],
	"senalar_el_hueco": [-0.02, 0.03, 0.12, 0.4, 0.8],
	"corte_de_tendones": [0.03, 0.07, 0.11, 0.18, 0.35],
	# LA ESPADA LARGA y el ESCUDO (25/09), por el mismo camino (EspadaAire, EstoqueAire, EscudoAire).
	"tajo_pesado": [-0.03, 0.02, 0.07, 0.14, 0.45],
	"tajo_desarmante": [0.03, 0.07, 0.12, 0.2, 0.4],
	"estocada_marcial": [-0.03, 0.0, 0.03, 0.08, 0.2],
	"guardia_rota": [0.04, 0.1, 0.2, 0.26, 0.4],
	"golpe_escudo_pequeno": [-0.03, 0.02, 0.07, 0.13, 0.3],
	"golpe_escudo_normal": [-0.03, 0.02, 0.07, 0.13, 0.3],
	"golpe_escudo_grande": [-0.03, 0.02, 0.07, 0.13, 0.3],
	"embestida": [0.04, 0.1, 0.16, 0.22, 0.4],
	# Las de apoyo (ApoyoAire): los de la huella son de los TUYOS (figuras verdes).
	"voto_de_guardia": [0.03, 0.1, 0.2, 0.45, 0.8],
	"voz_de_mando": [0.02, 0.08, 0.16, 0.26, 0.4],
	"provocacion": [-0.02, 0.04, 0.1, 0.18, 0.3],
	"cobertura": [0.03, 0.1, 0.2, 0.35, 0.6],
	"escolta": [0.05, 0.12, 0.2, 0.3, 0.5],
	"muro_guardian": [0.06, 0.14, 0.22, 0.45, 0.8],
	"guardia_de_carne": [0.03, 0.1, 0.22, 0.35, 0.5],
	"postura_rodela": [0.03, 0.1, 0.18, 0.3, 0.5],
}
# LA MAZA (MazaAire): el suelo por SueloRoto y lo de cada cuerpo golpe a golpe. '_dual' = con dos mazas.
const MOMENTOS_MAZA := {
	"basico": [-0.04, -0.01, 0.02, 0.08, 0.18],
	"golpe_demoledor": [-0.03, 0.02, 0.08, 0.18, 0.45],
	"rompepiernas": [0.03, 0.07, 0.11, 0.18, 0.35],
	"rompepiernas_dual": [-0.06, -0.01, 0.12, 0.2, 0.34],
	"culatazo": [-0.03, 0.0, 0.03, 0.1, 0.2],
	"culatazo_dual": [-0.02, 0.02, 0.1, 0.14, 0.25],
	"aplastamiento": [-0.04, 0.02, 0.1, 0.22, 0.4],
	"grito_de_aliento": [0.02, 0.08, 0.16, 0.26, 0.4],
	"muro_de_aliados": [0.03, 0.1, 0.2, 0.4, 0.7],
}
# EL BASTON Y LA VARITA (BastonAire): el suelo por SueloRoto y lo de cada cuerpo cuando le llega.
const MOMENTOS_BASTON := {
	"basico": [-0.05, -0.02, 0.02, 0.08, 0.18],
	"bastonazo": [0.04, 0.1, 0.16, 0.24, 0.45],
	"sello_arcano": [0.08, 0.2, 0.36, 0.45, 0.6],
	"viento_limpio": [0.06, 0.14, 0.24, 0.36, 0.55],
	"velo_umbrio": [0.06, 0.14, 0.24, 0.36, 0.6],
	"canalizar": [0.06, 0.16, 0.28, 0.36, 0.55],
	"canalizar_varita": [0.06, 0.16, 0.28, 0.36, 0.55],
	"purificar": [0.03, 0.1, 0.22, 0.4, 0.65],
	"chispa_vinculada": [0.06, 0.16, 0.3, 0.42, 0.7],
	"egida_menor": [0.03, 0.08, 0.16, 0.35, 0.65],
}
# LAS MAGIAS (MagiaAire): el efecto por el suelo y, en la Descarga, los arcos de la cadena.
const MOMENTOS_MAGIA := {
	"brasa": [0.1, 0.22, 0.36, 0.55, 0.85],
	"descarga": [0.1, 0.2, 0.3, 0.4, 0.55],
	"rocio": [0.12, 0.3, 0.6, 1.0, 1.9],
	"pulso_menor": [0.05, 0.12, 0.2, 0.28, 0.45],
	"vendaje_de_luz": [0.02, 0.12, 0.3, 0.5, 0.75],
	"bola_fuego": [0.12, 0.26, 0.4, 0.62, 1.1],
	"chorro_agua": [0.12, 0.28, 0.45, 0.7, 1.4],
	"rayo": [0.04, 0.1, 0.2, 0.35, 0.6],
	"pulso_arcano": [0.08, 0.18, 0.3, 0.42, 0.6],
	"debilidad": [0.15, 0.32, 0.45, 0.7, 1.1],
	"fortaleza": [0.12, 0.26, 0.38, 0.6, 0.95],
	"filo_ardiente": [0.12, 0.38, 0.62, 0.85, 1.2],
	"filo_fulgurante": [0.12, 0.38, 0.62, 0.85, 1.2],
	"filo_umbrio": [0.12, 0.38, 0.62, 0.85, 1.2],
	"filo_torrente": [0.12, 0.38, 0.62, 0.85, 1.2],
	"filo_radiante": [0.12, 0.38, 0.62, 0.85, 1.2],
	"mar_de_brasas": [0.2, 0.55, 1.05, 1.65, 2.2],
	"venablo_de_tormenta": [0.08, 0.16, 0.24, 0.34, 0.5],
	"estallido_solar": [0.08, 0.25, 0.5, 0.82, 0.97, 1.12, 1.5],
	"voragine_sombra": [0.2, 0.36, 0.55, 0.72, 0.95, 1.4, 1.75],
	"shock_termico": [0.1, 0.25, 0.4, 0.5, 0.62, 0.8, 1.2, 1.45, 1.6, 1.75, 1.95],
	"tormenta": [0.1, 0.3, 0.5, 0.75, 0.95, 1.25, 1.6, 2.1, 2.4, 2.65],
	"luz_restauradora": [0.1, 0.25, 0.4, 0.55, 0.7, 0.9, 1.2],
	"manto_brasas": [0.12, 0.38, 0.62, 0.8, 0.95, 1.2, 1.5],
	"manto_marea": [0.12, 0.38, 0.62, 0.8, 0.95, 1.2, 1.5],
	"manto_centellas": [0.12, 0.38, 0.62, 0.8, 0.95, 1.2, 1.5],
	"manto_aureo": [0.12, 0.38, 0.62, 0.8, 0.95, 1.2, 1.5],
	"manto_umbrio": [0.12, 0.38, 0.62, 0.8, 0.95, 1.2, 1.5],
	"manto_prismatico": [0.1, 0.25, 0.45, 0.65, 0.85, 1.05, 1.3, 1.55],
	"eclipse": [0.15, 0.3, 0.4, 0.5, 0.62, 0.74, 0.8, 0.95, 1.1, 1.4, 1.95],
}
# EL ESTOQUE (EstoqueAire), como la daga: golpe a golpe sobre cada cuerpo.
const MOMENTOS_ESTOQUE := {
	"estocada_penetrante": [-0.03, 0.0, 0.03, 0.08, 0.2],
	"fintas": [-0.1, -0.05, 0.0, 0.07, 0.14],
	"punzada_al_nervio": [-0.03, 0.0, 0.05, 0.1, 0.2],
	"paso_ligero": [0.05, 0.12, 0.2, 0.24, 0.38],
	"danza_de_acero": [0.06, 0.16, 0.26, 0.36, 0.55],
	# Tres de la postura al activarla y dos de la esquiva en guardia (el golpe llega a los 0.6).
	"en_guardia": [0.05, 0.12, 0.2, 0.63, 0.72],
}
# LA DAGA (DagaAire) pinta golpe a golpe sobre cada cuerpo: sus momentos van por habilidad.
const MOMENTOS_DAGA := {
	"rafaga": [-0.02, 0.03, 0.09, 0.16, 0.3],
	"punalada": [-0.04, 0.0, 0.03, 0.07, 0.16],
	"filo_emponzonado": [0.08, 0.25, 0.45, 0.7, 1.2],
	"desaparecer": [0.05, 0.2, 0.3, 0.45, 1.6],
	"oportunista": [0.04, 0.09, 0.15, 0.2, 0.3],
}
const PISA := 6.0
const DIRS := [["N", Vector2(0, -1)], ["NE", Vector2(1, -1)], ["E", Vector2(1, 0)],
	["SE", Vector2(1, 1)], ["S", Vector2(0, 1)]]
# Los cinco momentos de cada efecto (segundos desde el golpe), por SueloRoto.Tipo.
const MOMENTOS := {
	0: [0.18, 0.45, 0.95, 1.55, 2.0],
	1: [0.18, 0.45, 0.95, 1.55, 2.0],
	2: [0.04, 0.1, 0.25, 0.55, 0.95],
	3: [0.07, 0.14, 0.2, 0.25, 0.4],
	4: [0.08, 0.17, 0.27, 0.36, 0.8],
	5: [0.06, 0.13, 0.2, 0.3, 0.45],
	6: [0.07, 0.14, 0.27, 0.34, 0.5],
	7: [0.08, 0.18, 0.3, 0.45, 0.7],
	# El hacha (HachaAire): en su reloj, que en la Carniceria, el Desgarro y la Hendedura arranca antes del golpe.
	9: [0.05, 0.11, 0.17, 0.25, 0.6],
	10: [0.06, 0.1, 0.29, 0.5, 0.9],
	11: [0.04, 0.08, 0.12, 0.17, 0.3],
	12: [0.04, 0.08, 0.14, 0.24, 0.6],
	13: [0.05, 0.15, 0.3, 0.45, 0.65],
}
const COLOR_HUELLA := Color(1.0, 0.72, 0.25)
# LA CARPETA de cada arma dentro de ATAQUES_SALIDA (25/09, lo pidio el: una por arma).
const CARPETA := {"espada": "espada_corta", "larga": "espada_larga", "maza2": "maza"}
const APOYO_ALIADOS := ["voto_de_guardia", "voz_de_mando", "cobertura", "escolta", "muro_guardian",
	"grito_de_aliento", "muro_de_aliados", "viento_limpio", "purificar", "chispa_vinculada", "egida_menor"]
const VERDE := Color(0.35, 0.8, 0.45)
const ROJO := Color(0.8, 0.35, 0.35)

var _cam: Camera2D
var _enemigos: Array = []    # donde estan los pies de cada figura roja
var _huella: Node2D
var _forma_huella = null
var _forma_huella2 = null   # la segunda huella de la misma habilidad (el pisoton de la Carga acorazada)
var _color_huella: Color = COLOR_HUELLA   # rojo en las de los enemigos
var _rotulo: Label
var _yo_fig: ColorRect = null
var _figs: Array = []        # las figuras de alrededor (rojas; verdes en las de apoyo)


func _ready() -> void:
	_cam = Camera2D.new()
	add_child(_cam)
	_cam.make_current()
	_huella = Node2D.new()
	_huella.z_index = 1
	add_child(_huella)
	_huella.draw.connect(func():
		if _forma_huella != null:
			CombatFormas.dibujar(_forma_huella, _huella, _color_huella)
		if _forma_huella2 != null:
			CombatFormas.dibujar(_forma_huella2, _huella, _color_huella))
	var capa := CanvasLayer.new()
	add_child(capa)
	_rotulo = Label.new()
	_rotulo.add_theme_font_size_override("font_size", 17)
	_rotulo.add_theme_color_override("font_outline_color", Color.BLACK)
	_rotulo.add_theme_constant_override("outline_size", 6)
	capa.add_child(_rotulo)
	call_deferred("_correr")


func _draw() -> void:
	# Un suelo de losetas oscuro, como el de la mazmorra (el de ver_suelo_roto).
	var r: int = 400
	for x in range(-r, r, 16):
		for y in range(-r, r, 16):
			var v: float = 0.17 + 0.015 * float((x / 16 + y / 16) % 2)
			draw_rect(Rect2(x, y, 16, 16), Color(v, v + 0.02, v + 0.035))
			draw_rect(Rect2(x, y, 16, 16), Color(0.11, 0.12, 0.14), false, 1.0)


func _figura(p: Vector2, col: Color) -> ColorRect:
	var fig := ColorRect.new()
	fig.color = col
	fig.size = Vector2(14, 26)
	fig.position = p - Vector2(7, 26)
	fig.z_index = 1024
	fig.z_as_relative = false
	add_child(fig)
	return fig


func _correr() -> void:
	var salida: String = OS.get_environment("ATAQUES_SALIDA")
	if salida == "":
		salida = "user://ataques"
	DirAccess.make_dir_recursive_absolute(salida)
	var yo := Vector2.ZERO
	_yo_fig = _figura(yo, Color(0.35, 0.6, 1.0))
	# Enemigos alrededor: un anillo cerca y unos cuantos mas lejos, para ver hasta donde llega cada uno.
	# ATAQUES_ANILLO=34 -> el anillo de cerca mas pegado (la daga no llega a 62).
	var anillo: float = float(OS.get_environment("ATAQUES_ANILLO")) if OS.get_environment("ATAQUES_ANILLO") != "" else 62.0
	for i in 8:
		var a: float = TAU * float(i) / 8.0 + 0.2
		_figs.append(_figura(Vector2(cos(a), sin(a)) * anillo, ROJO))
		_enemigos.append(Vector2(cos(a), sin(a)) * anillo)
	for i in 5:
		var a2: float = TAU * float(i) / 5.0 + 0.9
		_figs.append(_figura(Vector2(cos(a2), sin(a2)) * 118.0, ROJO))
		_enemigos.append(Vector2(cos(a2), sin(a2)) * 118.0)
	var pedidas: String = OS.get_environment("ATAQUES_LISTA")
	# ATAQUES_ENEMIGOS=1 -> las hojas de los ENEMIGOS (28/09, los slimes): enemigos/slimes/<slime>/<habilidad>.png.
	if OS.get_environment("ATAQUES_ENEMIGOS") != "" and OS.get_environment("ATAQUES_BESTIA") != "":
		await _hojas_bestias(salida, pedidas, OS.get_environment("ATAQUES_BESTIA"))
		get_tree().quit(0)
		return
	if OS.get_environment("ATAQUES_ENEMIGOS") != "":
		await _hojas_slimes(salida, pedidas)
		get_tree().quit(0)
		return
	# ATAQUES_ECLIPSE=1 -> la version B del Eclipse (corona de esquirlas); sin nada, la A (corona de llamas).
	if OS.get_environment("ATAQUES_ECLIPSE") != "":
		MagiaMayor.eclipse_variante = int(OS.get_environment("ATAQUES_ECLIPSE"))
	for h in HABILIDADES:
		var arma: String = h[0]
		var nom: String = h[1]
		if pedidas != "" and not (nom in pedidas.split(",")):
			continue
		var ab: AbilityData
		var hechizo: SpellData = null
		if arma == "magia":
			hechizo = load("res://resources/spells/%s.tres" % nom)
			ab = AbilityData.new()
			ab.nombre = hechizo.nombre
			ab.forma = hechizo.forma
			ab.forma_apunte = hechizo.forma_apunte
			ab.forma_radio = hechizo.forma_radio
			ab.forma_apertura = hechizo.forma_apertura
			ab.forma_rango = hechizo.forma_rango
			ab.forma_ancho = hechizo.forma_ancho
			ab.forma_solo_primero = hechizo.forma_solo_primero
		elif nom == "basico":
			ab = AbilityData.new()
			ab.nombre = "Tajo (basico)"
			ab.forma = CombatFormas.Tipo.CIRCULO
			ab.forma_apunte = CombatFormas.Apunte.DELANTE
			ab.forma_radio = 10.0
		else:
			ab = load("res://resources/abilities/%s.tres" % nom)
		var dual: bool = arma == "maza2"
		var tiempos: Array = MOMENTOS_BASTON.get(nom, []) if arma in ["baston", "varita"] 			else MOMENTOS_DAGA.get(nom, []) if arma == "daga" \
			else (MOMENTOS_MAZA.get(nom + ("_dual" if dual else ""), MOMENTOS_MAZA.get(nom, [])) if arma.begins_with("maza") \
			else (MOMENTOS_ESTOQUE.get(nom, []) if arma == "estoque" \
			else (MOMENTOS_ESPADA.get(nom, []) if arma in ["espada", "larga", "escudo"] \
			else MOMENTOS.get(ab.suelo_roto, []))))
		if arma == "magia":
			tiempos = MOMENTOS_MAGIA.get(nom, [])
		var cols: int = 1 + tiempos.size()
		# El zoom de toda la hoja: que quepa la forma mas larga de esta habilidad, en cualquier direccion.
		var f0 = CombatFormas.de_habilidad_mapa(ab, yo, PISA, ALCANCE[arma], yo + Vector2(70, 0))
		var medida: float = maxf(maxf(f0.radio, f0.largo), 40.0)
		if int(ab.forma_apunte) == CombatFormas.Apunte.DELANTE and int(ab.forma) == CombatFormas.Tipo.CIRCULO:
			medida += PISA + ALCANCE[arma]
		# Un circulo LIBRE (las magias) cae a 70 px de ti: que quepa entero.
		if int(ab.forma_apunte) == CombatFormas.Apunte.LIBRE and int(ab.forma) == CombatFormas.Tipo.CIRCULO:
			medida = maxf(medida, f0.radio + 70.0 * 0.65)
		# ATAQUES_ACERCA=3 -> tres veces mas cerca (para mirar un efecto de cerca).
		var acerca: float = maxf(float(OS.get_environment("ATAQUES_ACERCA")), 1.0) if OS.get_environment("ATAQUES_ACERCA") != "" else 1.0
		var zoom: float = float(LADO) / (2.0 * (medida + 30.0)) * acerca
		_cam.zoom = Vector2(zoom, zoom)
		var hoja := Image.create(LADO * cols, LADO * DIRS.size(), false, Image.FORMAT_RGBA8)
		for fila in DIRS.size():
			var dir_n: String = DIRS[fila][0]
			var hacia: Vector2 = yo + (DIRS[fila][1] as Vector2).normalized() * 70.0
			# El Oportunista se pone ENCIMA de un enemigo: el mas cercano a esa direccion.
			if nom in ["oportunista", "purificar", "chispa_vinculada", "egida_menor"]:
				var mejor: float = INF
				for p in _enemigos:
					var dd: float = absf(angle_difference((p - yo).angle(), (DIRS[fila][1] as Vector2).angle())) \
						+ (p - yo).length() * 0.002
					if dd < mejor:
						mejor = dd
						hacia = p + Vector2(0, -13)
			var f = CombatFormas.de_habilidad_mapa(ab, yo, PISA, ALCANCE[arma], hacia)
			if hechizo != null:
				f.cunas = hechizo.forma_cunas
				# De donde sale lo que se lanza a un circulo (ver CombatTactico.forma_hechizo).
				if f.tipo == CombatFormas.Tipo.CIRCULO:
					f.ancho = yo.distance_to(f.centro)
			# La camara, un poco hacia donde va el ataque (salvo los que caen a tu alrededor).
			var hacia_cam: float = 0.0 if int(ab.forma_apunte) == CombatFormas.Apunte.ALREDEDOR else 0.35
			_cam.global_position = yo + (DIRS[fila][1] as Vector2).normalized() * medida * hacia_cam / acerca
			# 1) Apuntando: la huella.
			_forma_huella = f if int(ab.forma) >= 0 and nom != "basico" else null
			_huella.queue_redraw()
			await _viñeta(hoja, 0, fila, "%s · %s · apuntando" % [ab.nombre, dir_n])
			_forma_huella = null
			_huella.queue_redraw()
			if tiempos.is_empty():
				continue
			if arma == "daga":
				await _efecto_daga(ab, nom, f, fila, hoja, tiempos, dir_n, yo)
				continue
			if arma == "estoque":
				await _efecto_estoque(ab, nom, f, fila, hoja, tiempos, dir_n, yo)
				continue
			if arma in ["espada", "larga", "escudo"]:
				await _efecto_espada(ab, nom, f, fila, hoja, tiempos, dir_n, yo)
				continue
			if arma in ["baston", "varita"]:
				await _efecto_baston(ab, nom, f, fila, hoja, tiempos, dir_n, yo, DIRS[fila][1])
				continue
			if hechizo != null:
				await _efecto_magia(hechizo, f, fila, hoja, tiempos, dir_n, yo)
				continue
			if arma.begins_with("maza"):
				await _efecto_maza(ab, nom, dual, f, fila, hoja, tiempos, dir_n, yo)
				continue
			# 2) El efecto, en sus cinco momentos.
			var f_suelo = f
			if ab.suelo_roto == SueloRoto.Tipo.ESTELA:
				f_suelo = CombatFormas.cono(yo, f.centro - yo, EstelaGolpe.RADIO, 0.0)
			var s: Node2D = SueloRoto.lanzar(self, f_suelo, ab.suelo_roto, 1234 + fila, ab.forma_nucleo)
			s.set_process(false)
			# LA SANGRE DEL HACHA: sale en el juego cuando el golpe entra (CombatTactico._on_impacto); aqui se
			# simula sobre cada figura que pilla la huella, a su instante (retraso del efecto).
			var sangres: Array = []   # {n: SangreMapa, t0, hecho}
			if ab.suelo_roto >= SueloRoto.Tipo.HACHAZO and ab.suelo_roto != SueloRoto.Tipo.MIRADA:
				BarridoAire.ritmo = 1.0
				var antes: float = HachaAire._antes(ab.suelo_roto - SueloRoto.Tipo.HACHAZO)
				for p in _enemigos:
					if not f.toca(Rect2(p - Vector2(7, 26), Vector2(14, 26))):
						continue
					var radial: Vector2 = (p - yo).normalized()
					var dir_g: Vector2 = radial.rotated(PI * 0.5) * 0.85 + radial * 0.45
					var fuerza: float = 1.0
					match ab.suelo_roto:
						SueloRoto.Tipo.HACHAZO: fuerza = 1.4
						SueloRoto.Tipo.DESGARRO: dir_g = -radial
						SueloRoto.Tipo.HENDEDURA: dir_g = radial
					SangreMapa.salpicar(self, p - Vector2(0, 13), p, dir_g, fuerza, 77 + fila)
					var n: Node2D = get_child(get_child_count() - 1)
					n.set_process(false)
					sangres.append({"n": n, "t0": antes + SueloRoto.retraso(f_suelo, p, ab.suelo_roto), "hecho": 0.0})
			for col in tiempos.size():
				s.set("_t", float(tiempos[col]))
				for sg in sangres:
					var quiere: float = float(tiempos[col]) - float(sg["t0"])
					while float(sg["hecho"]) + 0.01 <= quiere:
						(sg["n"] as Node2D).call("_process", 0.01)
						sg["hecho"] = float(sg["hecho"]) + 0.01
					(sg["n"] as Node2D).visible = quiere >= 0.0
				for hijo in ["_geiser", "_aire", "_atras", "_delante"]:
					if s.get(hijo) != null:
						(s.get(hijo) as Node2D).queue_redraw()
				s.queue_redraw()
				await _viñeta(hoja, col + 1, fila, "%s · %s · %.2f s" % [ab.nombre, dir_n, float(tiempos[col])])
			s.queue_free()
			for sg in sangres:
				if is_instance_valid(sg["n"]):
					(sg["n"] as Node).queue_free()
			await get_tree().process_frame
		var carpeta: String = "%s/%s" % [salida, CARPETA.get(arma, arma)]
		DirAccess.make_dir_recursive_absolute(carpeta)
		var ruta: String = "%s/%s%s.png" % [carpeta, nom, "_dual" if arma == "maza2" else ""]
		hoja.save_png(ruta)
		print("[hoja] ", ruta)
	get_tree().quit(0)


# LA DAGA: cada golpe sobre las figuras que pilla su huella, en su instante (como en el juego, donde los
# pinta CombatTactico._on_dibujo_mapa golpe a golpe).
func _efecto_daga(ab: AbilityData, nom: String, f, fila: int, hoja: Image, tiempos: Array, dir_n: String,
		yo: Vector2) -> void:
	BarridoAire.ritmo = 1.0
	var mano: Vector2 = yo + Vector2(0.0, -DagaAire.ALTO_TORSO)
	var cajas: Array = []
	if int(ab.forma) >= 0:
		for p in _enemigos:
			var r := Rect2(p - Vector2(7, 26), Vector2(14, 26))
			if f.toca(r):
				cajas.append(r)
	var cu: Vector2 = f.centro_util()
	cajas.sort_custom(func(a, b): return a.get_center().distance_squared_to(cu) < b.get_center().distance_squared_to(cu))
	var piezas: Array = []   # {n, t0}
	var salta_a: Vector2 = Vector2.INF
	var semilla: int = 900 + fila * 13
	match nom:
		"rafaga":
			var g: int = 3 + mini(4, int(floor(1.15 * float(maxi(cajas.size(), 1) - 1))))
			for i in g:
				if cajas.is_empty():
					break
				piezas.append({"n": DagaAire.golpe(self, DagaAire.Modo.RAFAGA, mano, cajas[i % cajas.size()],
					false, i == 2, i, semilla + i, 0.0, 1.0), "t0": 0.075 * float(i)})
		"punalada":
			for i in mini(cajas.size(), 2):
				piezas.append({"n": DagaAire.golpe(self, DagaAire.Modo.PUNALADA, mano, cajas[i], false, i == 0, 0,
					semilla + i, 0.0, 1.0), "t0": 0.0})
		"desaparecer":
			piezas.append({"n": SueloRoto.lanzar(self, f, SueloRoto.Tipo.HUMO, semilla), "t0": 0.0})
			for i in cajas.size():
				piezas.append({"n": DagaAire.golpe(self, DagaAire.Modo.TAJO, mano, cajas[i], false, false, i,
					semilla + i, 0.0, 1.0), "t0": DagaAire.T_HUMO_ABRE + 0.075 * float(i)})
		"oportunista":
			if not cajas.is_empty():
				var r0: Rect2 = cajas[0]
				var pies_v := Vector2(r0.get_center().x, r0.end.y - 2.0)
				salta_a = pies_v + (pies_v - yo).normalized() * (8.0 + 3.0 + 2.0)
				piezas.append({"n": DagaAire.sombra(self, yo, salta_a, semilla, 1.0), "t0": 0.0})
				piezas.append({"n": DagaAire.golpe(self, DagaAire.Modo.PUNALADA, salta_a + Vector2(0.0, -DagaAire.ALTO_TORSO),
					r0, false, true, 0, semilla, 0.0, 1.0), "t0": 0.2})
		"filo_emponzonado":
			piezas.append({"n": DagaAire.ponzona(self, null, semilla, 0.0, 1.0, mano + Vector2(6.0, 0.0)), "t0": 0.0})
	for pz in piezas:
		(pz["n"] as Node).set_process(false)
	for col in tiempos.size():
		var t: float = float(tiempos[col])
		for pz in piezas:
			var n: Node2D = pz["n"]
			n.set("_t", t - float(pz["t0"]))
			n.queue_redraw()
			var su = n.get("_suelo")
			if su is Node2D:
				(su as Node2D).queue_redraw()
		if salta_a != Vector2.INF:
			_yo_fig.position = (salta_a if t >= 0.08 else yo) - Vector2(7, 26)
		await _viñeta(hoja, col + 1, fila, "%s · %s · %.2f s" % [ab.nombre, dir_n, t])
	for pz in piezas:
		(pz["n"] as Node).queue_free()
	_yo_fig.position = yo - Vector2(7, 26)
	await get_tree().process_frame


# EL ESTOQUE: como la daga, y el Paso ligero y la Danza MUEVEN la figura azul (con su rastro).
func _efecto_estoque(ab: AbilityData, nom: String, f, fila: int, hoja: Image, tiempos: Array, dir_n: String,
		yo: Vector2) -> void:
	var semilla: int = 700 + fila * 13
	var alto := Vector2(0.0, -EstoqueAire.ALTO_TORSO)
	var cajas: Array = []
	for p in _enemigos:
		var r := Rect2(p - Vector2(7, 26), Vector2(14, 26))
		if f.toca(r):
			cajas.append(r)
	cajas.sort_custom(func(a, b): return a.get_center().distance_squared_to(yo) < b.get_center().distance_squared_to(yo))
	var piezas: Array = []   # {n, t0}
	var camino: Array = []   # [de, a, dur] si la figura se mueve
	var esquiva: EstoqueAire = null
	match nom:
		"en_guardia":
			# La hoja mira hacia la fila; la esquiva, de un golpe que viene de ahi.
			var hacia: Vector2 = (DIRS[fila][1] as Vector2).normalized()
			var mano: Vector2 = yo + Vector2(5.0, -EstoqueAire.ALTO_TORSO)
			piezas.append({"n": EstoqueAire.postura(self, EstoqueAire.Modo.GUARDIA, null, yo, hacia, semilla, 0.0, 1.0,
				mano), "t0": 0.0})
			esquiva = EstoqueAire.postura(self, EstoqueAire.Modo.ESQUIVA, _yo_fig, yo, hacia, semilla, 0.0, 1.0, mano,
				true, Rect2(yo - Vector2(7, 26), Vector2(14, 26)))
			piezas.append({"n": esquiva, "t0": 0.6})
		"estocada_penetrante":
			for i in cajas.size():
				piezas.append({"n": EstoqueAire.golpe(self, EstoqueAire.Modo.PENETRANTE, yo + alto, cajas[i], false,
					i == 0, 0, semilla + i, 0.0, 1.0), "t0": 0.0})
		"fintas":
			var g: int = 2 + int(floor(0.7 * float(maxi(cajas.size(), 1) - 1)))
			for i in g:
				if cajas.is_empty():
					break
				piezas.append({"n": EstoqueAire.golpe(self, EstoqueAire.Modo.FINTA if i == 0 else EstoqueAire.Modo.PUNZADA,
					yo + alto, cajas[i % cajas.size()],
					false, i == 1, i, semilla + i, 0.0, 1.0), "t0": 0.075 * float(i)})
		"punzada_al_nervio":
			if not cajas.is_empty():
				piezas.append({"n": EstoqueAire.golpe(self, EstoqueAire.Modo.NERVIO, yo + alto, cajas[0], false, false, 0,
					semilla, 0.0, 1.0), "t0": 0.0})
		"paso_ligero":
			# Nadie a tiro al empezar (el anillo esta lejos): das el paso y le pegas al que quede a tiro.
			var dest: Vector2 = f.centro
			for p in _enemigos:
				if dest.distance_to(p) < 22.0:
					dest = p + (dest - p).normalized() * 22.0
			camino = [yo, dest, 0.16]
			piezas.append({"n": EstoqueAire.rastro(self, yo, dest, 0.16, semilla), "t0": 0.0})
			var mejor: Rect2 = Rect2()
			var d_mejor: float = INF
			for p in _enemigos:
				var r2 := Rect2(p - Vector2(7, 26), Vector2(14, 26))
				var cerca := Vector2(clampf(dest.x, r2.position.x, r2.end.x), clampf(dest.y, r2.position.y, r2.end.y))
				var hueco: float = dest.distance_to(cerca) - PISA
				if hueco <= ALCANCE["estoque"] and hueco < d_mejor:
					d_mejor = hueco
					mejor = r2
			if mejor.has_area():
				piezas.append({"n": EstoqueAire.golpe(self, EstoqueAire.Modo.PUNZADA, dest + alto, mejor, false, false, 0,
					semilla, 0.0, 1.0), "t0": 0.2})
		"danza_de_acero":
			# Cruzas la linea entera (sin acabar encima de nadie) y cada estocada cae al pasar a su lado.
			var fin: Vector2 = f.origen + f.dir * f.largo
			for p in _enemigos:
				if fin.distance_to(p) < 22.0:
					fin = p - f.dir * 22.0
			var dur: float = yo.distance_to(fin) / EstoqueAire.V_DANZA
			camino = [yo, fin, dur]
			piezas.append({"n": EstoqueAire.rastro(self, yo, fin, dur, semilla), "t0": 0.0})
			var g2: int = 3 + int(floor(0.7 * float(maxi(cajas.size(), 1) - 1)))
			for i in g2:
				if cajas.is_empty():
					break
				var r3: Rect2 = cajas[mini(i * cajas.size() / g2, cajas.size() - 1)]
				var cerca3 := Vector2(clampf(yo.x, r3.position.x, r3.end.x), clampf(yo.y, r3.position.y, r3.end.y))
				var t0: float = yo.distance_to(cerca3) / EstoqueAire.V_DANZA + 0.05 * float(i % 2)
				var ahi: Vector2 = yo.lerp(fin, clampf(t0 / maxf(dur, 0.01), 0.0, 1.0))
				piezas.append({"n": EstoqueAire.golpe(self, EstoqueAire.Modo.DANZA, ahi + alto - f.dir * 12.0, r3, false,
					i == 0, i, semilla + i, 0.0, 1.0), "t0": t0})
	for pz in piezas:
		if pz["n"] != null:
			(pz["n"] as Node).set_process(false)
	for col in tiempos.size():
		var t: float = float(tiempos[col])
		for pz in piezas:
			var n: Node2D = pz["n"]
			if n == null:
				continue
			n.set("_t", t - float(pz["t0"]))
			n.queue_redraw()
			var su = n.get("_suelo")
			if su is Node2D:
				(su as Node2D).queue_redraw()
		if not camino.is_empty():
			var u: float = clampf(t / float(camino[2]), 0.0, 1.0)
			_yo_fig.position = (camino[0] as Vector2).lerp(camino[1], u) - Vector2(7, 26)
		# La esquiva mueve la figura (en el juego lo hace su _process, aqui parado).
		if esquiva != null:
			_yo_fig.position = esquiva._base_muneco + esquiva._a * esquiva._lado * esquiva._cuanto_fuera(t - 0.6)
		await _viñeta(hoja, col + 1, fila, "%s · %s · %.2f s" % [ab.nombre, dir_n, t])
	for pz in piezas:
		if pz["n"] != null:
			(pz["n"] as Node).queue_free()
	_yo_fig.position = yo - Vector2(7, 26)
	await get_tree().process_frame


# LA ESPADA CORTA: cada golpe sobre las figuras que pilla su huella; Cambio de ritmo MUEVE la figura azul
# (avance, al compas de la Danza) y cada tajo cae al pasar.
func _efecto_espada(ab: AbilityData, nom: String, f, fila: int, hoja: Image, tiempos: Array, dir_n: String,
		yo: Vector2) -> void:
	BarridoAire.ritmo = 1.0
	var semilla: int = 500 + fila * 13
	var alto := Vector2(0.0, -EspadaAire.ALTO_TORSO)
	var cajas: Array = []
	for p in _enemigos:
		var r := Rect2(p - Vector2(7, 26), Vector2(14, 26))
		if f.toca(r):
			cajas.append(r)
	cajas.sort_custom(func(a, b): return a.get_center().distance_squared_to(yo) < b.get_center().distance_squared_to(yo))
	var piezas: Array = []   # {n, t0}
	var camino: Array = []
	var hacia_fila: Vector2 = f.dir
	match nom:
		"basico":
			# El basico no tiene huella: le pega al que tengas mas a mano hacia donde miras.
			var mejor: Rect2 = Rect2()
			var d_mejor: float = INF
			for p in _enemigos:
				var dd: float = absf(angle_difference((p - yo).angle(), hacia_fila.angle())) * 60.0 + (p - yo).length()
				if dd < d_mejor:
					d_mejor = dd
					mejor = Rect2(p - Vector2(7, 26), Vector2(14, 26))
			if mejor.has_area():
				piezas.append({"n": EspadaAire.golpe(self, EspadaAire.Modo.TAJO, yo + alto, mejor, false, false, 0,
					semilla, 0.0, 1.0), "t0": 0.0})
		"tajo_quebrantador", "corte_de_tendones", "doble_tajo":
			# El barrido (por el camino del suelo, como el juego) y, en cada cuerpo, lo suyo a su instante.
			var s_b: Node2D = SueloRoto.lanzar(self, f, ab.suelo_roto, semilla)
			# El Doble tajo acaba su primer barrido EN el golpe: arranca T_BARRE antes.
			piezas.append({"n": s_b, "t0": -EspadaAire.T_BARRE if nom == "doble_tajo" else 0.0})
			var m: int = EspadaAire.Modo.QUEBRANTADOR if nom == "tajo_quebrantador" \
				else (EspadaAire.Modo.TENDONES if nom == "corte_de_tendones" else EspadaAire.Modo.DOBLE)
			var golpes_b: int = 2 if nom == "doble_tajo" else 1
			for i in cajas.size():
				var pies_i: Vector2 = Vector2((cajas[i] as Rect2).get_center().x, (cajas[i] as Rect2).end.y)
				var llega: float = SueloRoto.retraso(f, pies_i, ab.suelo_roto)
				for g in golpes_b:
					var t_g: float = llega + EspadaAire.T_ENTRE * float(g)
					piezas.append({"n": EspadaAire.golpe(self, m, yo + alto, cajas[i], false, i == 0, g,
						semilla + i * 7 + g, 0.0, 1.0), "t0": t_g})
					SangreMapa.salpicar(self, (cajas[i] as Rect2).get_center(), pies_i,
						(pies_i - yo).normalized().rotated(PI * 0.5) * 0.85 + (pies_i - yo).normalized() * 0.45,
						0.6, 77 + i + g)
					var n_s: Node2D = get_child(get_child_count() - 1)
					piezas.append({"n": n_s, "t0": t_g, "sangre": true})
		"tajo_pesado", "tajo_desarmante", "guardia_rota":
			# El barrido o la raja (camino del suelo) y, en cada cuerpo, su corte cuando le llega. El Tajo pesado cae
			# T_CAE antes del golpe. La Guardia rota ademas mete el ESCUDAZO por su linea, un golpe despues.
			var s_l: Node2D = SueloRoto.lanzar(self, f, ab.suelo_roto, semilla)
			piezas.append({"n": s_l, "t0": -EspadaAire.T_CAE if nom == "tajo_pesado" else 0.0})
			var m_l: int = EspadaAire.Modo.PESADO_C if nom == "tajo_pesado" \
				else (EspadaAire.Modo.DESARME if nom == "tajo_desarmante" else EspadaAire.Modo.QUEBRANTADOR)
			for i in cajas.size():
				var pies_l: Vector2 = Vector2((cajas[i] as Rect2).get_center().x, (cajas[i] as Rect2).end.y)
				var llega_l: float = SueloRoto.retraso(f, pies_l, ab.suelo_roto)
				piezas.append({"n": EspadaAire.golpe(self, m_l, yo + alto, cajas[i], false, i == 0, 0,
					semilla + i * 7, 0.0, 1.0), "t0": llega_l})
				SangreMapa.salpicar(self, (cajas[i] as Rect2).get_center(), pies_l,
					(pies_l - yo).normalized() if nom == "tajo_pesado"
					else (pies_l - yo).normalized().rotated(PI * 0.5) * 0.85 + (pies_l - yo).normalized() * 0.45,
					0.6, 77 + i)
				piezas.append({"n": get_child(get_child_count() - 1), "t0": llega_l, "sangre": true})
			if nom == "guardia_rota":
				var linea_e = CombatFormas.linea(yo, f.dir, ab.forma_escudo_largo, ShieldData.ANCHO_ESCUDAZO[1])
				for p in _enemigos:
					var r_e := Rect2(p - Vector2(7, 26), Vector2(14, 26))
					if linea_e.toca(r_e):
						var t_e: float = SueloRoto.retraso(f, Vector2(r_e.get_center().x, r_e.end.y), ab.suelo_roto) \
							+ EspadaAire.T_ENTRE
						piezas.append({"n": EscudoAire.golpe(self, EscudoAire.Modo.ESCUDAZO, yo + alto, r_e, false, false, 1,
							semilla + 99, 0.0, 1.0, true), "t0": t_e})
		"estocada_marcial":
			for i in cajas.size():
				piezas.append({"n": EstoqueAire.golpe(self, EstoqueAire.Modo.PENETRANTE, yo + alto, cajas[i], false,
					i == 0, 0, semilla + i, 0.0, 1.0), "t0": 0.0})
		"golpe_escudo_pequeno", "golpe_escudo_normal", "golpe_escudo_grande":
			# UN escudazo: la onda (con la chapa delante de ti) y el impacto en cada uno cuando le llega.
			piezas.append({"n": SueloRoto.lanzar(self, f, ab.suelo_roto, semilla), "t0": 0.0})
			for i in cajas.size():
				var llega_z: float = SueloRoto.retraso_caja(f, cajas[i], ab.suelo_roto)
				piezas.append({"n": EscudoAire.golpe(self, EscudoAire.Modo.ESCUDAZO, yo + alto, cajas[i], false,
					i == 0, 0, semilla + i, 0.0, 1.0), "t0": llega_z})
		"embestida":
			# La carga: corres por la linea hasta pegarte al primero (o al final) con el rastro, y el choque al llegar.
			var fin_c: Vector2 = f.origen + f.dir * f.largo
			var primero: Rect2 = cajas[0] if not cajas.is_empty() else Rect2()
			if primero.has_area():
				fin_c = Vector2(primero.get_center().x, primero.end.y) - f.dir * 22.0   # CombatTactico.SEPARACION
			var dur_c: float = 0.16
			camino = [yo, fin_c, dur_c]
			piezas.append({"n": EstoqueAire.rastro(self, yo, fin_c, dur_c, semilla), "t0": 0.0})
			if primero.has_area():
				piezas.append({"n": EscudoAire.golpe(self, EscudoAire.Modo.EMBESTIDA, fin_c + alto, primero, false,
					false, 0, semilla, 0.0, 1.0), "t0": dur_c})
		"voto_de_guardia", "voz_de_mando", "provocacion", "cobertura":
			piezas.append({"n": SueloRoto.lanzar(self, f, ab.suelo_roto, semilla), "t0": 0.0})
			var m_ap: int = ApoyoAire.Modo.PRESTEZA if nom == "voz_de_mando" \
				else (ApoyoAire.Modo.AMPARO_C if nom == "cobertura" else -1)
			if m_ap >= 0:
				for i in cajas.size():
					piezas.append({"n": ApoyoAire.cuerpo(self, m_ap, yo + alto, cajas[i], semilla + i, 0.0, 1.0), "t0": 0.03})
		"escolta", "muro_guardian":
			# A uno de los tuyos: el mas cercano a esa direccion.
			var mejor_a: Rect2 = Rect2()
			var d_a: float = INF
			for p in _enemigos:
				var dd: float = absf(angle_difference((p - yo).angle(), hacia_fila.angle())) * 60.0 + (p - yo).length()
				if dd < d_a:
					d_a = dd
					mejor_a = Rect2(p - Vector2(7, 26), Vector2(14, 26))
			if mejor_a.has_area():
				var m_u: int = ApoyoAire.Modo.ESCOLTA if nom == "escolta" else ApoyoAire.Modo.MURO
				# El Muro: "su enemigo" hacia fuera del corro.
				var fuera: Vector2 = (mejor_a.get_center() - yo) if nom == "muro_guardian" else Vector2.ZERO
				piezas.append({"n": ApoyoAire.cuerpo(self, m_u, yo + alto, mejor_a, semilla, 0.0, 1.0, fuera), "t0": 0.0})
				# El Muro MUEVE tu figura: te deslizas junto a el (con el rastro), del lado de "su enemigo".
				if nom == "muro_guardian":
					var pies_a := Vector2(mejor_a.get_center().x, mejor_a.end.y)
					var sitio_m: Vector2 = pies_a + fuera.normalized() * ApoyoAire.MURO_SITIO
					camino = [yo, sitio_m, ApoyoAire.T_MURO_LLEGA]
					piezas.append({"n": EstoqueAire.rastro(self, yo, sitio_m, ApoyoAire.T_MURO_LLEGA, semilla), "t0": 0.0})
		"guardia_de_carne", "postura_rodela":
			var yo_caja := Rect2(yo - Vector2(7, 26), Vector2(14, 26))
			var m_s: int = ApoyoAire.Modo.CARNE if nom == "guardia_de_carne" else ApoyoAire.Modo.RODELA
			piezas.append({"n": ApoyoAire.cuerpo(self, m_s, yo + alto, yo_caja, semilla, 0.0, 1.0, hacia_fila), "t0": 0.0})
		"senalar_el_hueco":
			if not cajas.is_empty():
				for g in 2:
					piezas.append({"n": EspadaAire.golpe(self, EspadaAire.Modo.SENALAR, yo + alto, cajas[0], false, false, g,
						semilla + g, 0.0, 1.0), "t0": 0.09 * float(g)})
		"cambio_de_ritmo":
			var fin: Vector2 = f.origen + f.dir * f.largo
			for p in _enemigos:
				if fin.distance_to(p) < 22.0:
					fin = p - f.dir * 22.0
			var dur: float = yo.distance_to(fin) / EstoqueAire.V_DANZA
			camino = [yo, fin, dur]
			piezas.append({"n": EstoqueAire.rastro(self, yo, fin, dur, semilla), "t0": 0.0})
			for i in cajas.size():
				var r3: Rect2 = cajas[i]
				var cerca3 := Vector2(clampf(yo.x, r3.position.x, r3.end.x), clampf(yo.y, r3.position.y, r3.end.y))
				var t0: float = yo.distance_to(cerca3) / EstoqueAire.V_DANZA
				var ahi: Vector2 = yo.lerp(fin, clampf(t0 / maxf(dur, 0.01), 0.0, 1.0))
				piezas.append({"n": EspadaAire.golpe(self, EspadaAire.Modo.RITMO, ahi + alto - f.dir * 12.0, r3, false,
					i == 0, i, semilla + i, 0.0, 1.0), "t0": t0})
	for pz in piezas:
		if pz["n"] != null:
			(pz["n"] as Node).set_process(false)
	for fg in _figs:
		(fg as ColorRect).color = VERDE if nom in APOYO_ALIADOS else ROJO
	for col in tiempos.size():
		var t: float = float(tiempos[col])
		# La Guardia de carne: tu, mas grande y rojizo (en el juego, el muñeco mientras dure).
		if nom == "guardia_de_carne":
			_yo_fig.color = Color(0.35, 0.6, 1.0).lerp(Color(0.9, 0.45, 0.5), 0.6) if t > 0.0 else Color(0.35, 0.6, 1.0)
			_yo_fig.scale = Vector2.ONE * (1.12 if t > 0.0 else 1.0)
		for pz in piezas:
			var n: Node2D = pz["n"]
			if n == null:
				continue
			if bool(pz.get("sangre", false)):
				var quiere: float = t - float(pz["t0"])
				var hecho: float = float(pz.get("hecho", 0.0))
				while hecho + 0.01 <= quiere:
					n.call("_process", 0.01)
					hecho += 0.01
				pz["hecho"] = hecho
				n.visible = quiere >= 0.0
				continue
			n.set("_t", t - float(pz["t0"]))
			n.queue_redraw()
			for hijo in ["_suelo", "_atras", "_delante"]:
				var su = n.get(hijo)
				if su is Node2D:
					(su as Node2D).queue_redraw()
		if not camino.is_empty():
			var u: float = clampf(t / float(camino[2]), 0.0, 1.0)
			_yo_fig.position = (camino[0] as Vector2).lerp(camino[1], u) - Vector2(7, 26)
		await _viñeta(hoja, col + 1, fila, "%s · %s · %.2f s" % [ab.nombre, dir_n, t])
	for pz in piezas:
		if pz["n"] != null:
			(pz["n"] as Node).queue_free()
	_yo_fig.position = yo - Vector2(7, 26)
	_yo_fig.color = Color(0.35, 0.6, 1.0)
	_yo_fig.scale = Vector2.ONE
	for fg in _figs:
		(fg as ColorRect).color = ROJO
	await get_tree().process_frame


# LA MAZA: el suelo (por SueloRoto, con su variante de dos mazas) y lo de cada cuerpo cuando le llega. El Muro de
# aliados MUEVE las figuras verdes: su paso hacia ti.
func _efecto_maza(ab: AbilityData, nom: String, dual: bool, f, fila: int, hoja: Image, tiempos: Array, dir_n: String,
		yo: Vector2) -> void:
	BarridoAire.ritmo = 1.0
	var semilla: int = 300 + fila * 13
	var alto := Vector2(0.0, -MazaAire.ALTO_TORSO)
	var cajas: Array = []     # [Rect2, indice de su figura]
	for i in _enemigos.size():
		var r := Rect2((_enemigos[i] as Vector2) - Vector2(7, 26), Vector2(14, 26))
		if f.toca(r):
			cajas.append([r, i])
	cajas.sort_custom(func(a, b): return (a[0] as Rect2).get_center().distance_squared_to(yo) \
		< (b[0] as Rect2).get_center().distance_squared_to(yo))
	var piezas: Array = []    # {n, t0}
	var pasos: Array = []     # {fig, de, a}: las figuras que se arriman (Muro)
	var tipo: int = SueloRoto.con_manos(ab.suelo_roto, 2 if dual else 1)
	match nom:
		"basico":
			var mejor: Rect2 = Rect2()
			var d_mejor: float = INF
			for p in _enemigos:
				var dd: float = absf(angle_difference((p - yo).angle(), f.dir.angle())) * 60.0 + (p - yo).length()
				if dd < d_mejor:
					d_mejor = dd
					mejor = Rect2(p - Vector2(7, 26), Vector2(14, 26))
			piezas.append({"n": MazaAire.golpe(self, MazaAire.Modo.PORRAZO, yo + alto, mejor, false, false, 0,
				semilla, 0.0, 1.0), "t0": 0.0})
		"golpe_demoledor", "aplastamiento":
			# UN solo mazazo al suelo: nada en cada cuerpo (como el Golpe sismico).
			piezas.append({"n": SueloRoto.lanzar(self, f, tipo, semilla, ab.forma_nucleo), "t0": 0.0})
			if nom == "aplastamiento":
				var linea_e = CombatFormas.linea(yo, f.dir, ab.forma_escudo_largo, ShieldData.ANCHO_ESCUDAZO[1])
				for p in _enemigos:
					var r_e := Rect2(p - Vector2(7, 26), Vector2(14, 26))
					if linea_e.toca(r_e):
						piezas.append({"n": EscudoAire.golpe(self, EscudoAire.Modo.ESCUDAZO, yo + alto, r_e, false, false, 1,
							semilla + 99, 0.0, 1.0, true), "t0": SueloRoto.retraso(f, _pies_caja(r_e), tipo) + BarridoAire.T_ENTRE})
		"rompepiernas":
			# Con dos mazas la ida ACABA en el primer golpe (como el Doble tajo): arranca T_BARRE antes.
			piezas.append({"n": SueloRoto.lanzar(self, f, tipo, semilla), "t0": -MazaAire.T_BARRE if dual else 0.0})
			for i in cajas.size():
				var r1: Rect2 = cajas[i][0]
				for g in (2 if dual else 1):
					var t_g: float = (0.0 if dual else SueloRoto.retraso(f, _pies_caja(r1), tipo)) + MazaAire.T_ENTRE * float(g)
					piezas.append({"n": MazaAire.golpe(self, MazaAire.Modo.ROMPE_C, yo + alto, r1, false, i == 0, g,
						semilla + i * 7 + g, 0.0, 1.0), "t0": t_g})
		"culatazo":
			if not cajas.is_empty():
				for g in (2 if dual else 1):
					piezas.append({"n": MazaAire.golpe(self, MazaAire.Modo.CULATAZO, yo + alto, cajas[0][0], false, g == 1, g,
						semilla + g, 0.0, 1.0), "t0": 0.1 * float(g)})
		"grito_de_aliento", "muro_de_aliados":
			piezas.append({"n": SueloRoto.lanzar(self, f, tipo, semilla), "t0": 0.0})
			var m_a: int = MazaAire.Modo.ALIENTO_C if nom == "grito_de_aliento" else MazaAire.Modo.MURO_C
			for i in cajas.size():
				var r2: Rect2 = cajas[i][0]
				piezas.append({"n": MazaAire.golpe(self, m_a, yo + alto, r2, false, false, 0, semilla + i, 0.0, 1.0),
					"t0": 0.03})
				if nom == "muro_de_aliados":
					var de: Vector2 = _enemigos[int(cajas[i][1])]
					var largo: float = minf(ab.junta_aliados, de.distance_to(yo) - 24.0)
					if largo > 2.0:
						pasos.append({"fig": _figs[int(cajas[i][1])], "de": de, "a": de + (yo - de).normalized() * largo})
	for pz in piezas:
		if pz["n"] != null:
			(pz["n"] as Node).set_process(false)
	for fg in _figs:
		(fg as ColorRect).color = VERDE if nom in APOYO_ALIADOS else ROJO
	for col in tiempos.size():
		var t: float = float(tiempos[col])
		for pz in piezas:
			var n: Node2D = pz["n"]
			if n == null:
				continue
			n.set("_t", t - float(pz["t0"]))
			n.queue_redraw()
			for hijo in ["_suelo", "_atras", "_delante"]:
				var su = n.get(hijo)
				if su is Node2D:
					(su as Node2D).queue_redraw()
		for ps in pasos:
			var u: float = clampf(t / 0.16, 0.0, 1.0)
			(ps["fig"] as ColorRect).position = (ps["de"] as Vector2).lerp(ps["a"], u) - Vector2(7, 26)
		await _viñeta(hoja, col + 1, fila, "%s%s · %s · %.2f s" % [ab.nombre, " (dos mazas)" if dual else "", dir_n, t])
	for pz in piezas:
		if pz["n"] != null:
			(pz["n"] as Node).queue_free()
	for ps in pasos:
		(ps["fig"] as ColorRect).position = (ps["de"] as Vector2) - Vector2(7, 26)
	for fg in _figs:
		(fg as ColorRect).color = ROJO
	await get_tree().process_frame


# EL BASTON Y LA VARITA: el suelo (por SueloRoto) y lo de cada cuerpo cuando le llega. El Bastonazo EMPUJA las
# figuras que pilla (su tiron en negativo); lo que te echas encima (Velo, Foco) va sobre tu figura; las de un aliado,
# al mas cercano a esa direccion.
func _efecto_baston(ab: AbilityData, nom: String, f, fila: int, hoja: Image, tiempos: Array, dir_n: String,
		yo: Vector2, hacia_fila: Vector2) -> void:
	BarridoAire.ritmo = 1.0
	var semilla: int = 500 + fila * 13
	var alto := Vector2(0.0, -BastonAire.ALTO_TORSO)
	var cajas: Array = []     # [Rect2, indice de su figura]
	if int(ab.forma) >= 0:
		for i in _enemigos.size():
			var r := Rect2((_enemigos[i] as Vector2) - Vector2(7, 26), Vector2(14, 26))
			if f.toca(r):
				cajas.append([r, i])
	cajas.sort_custom(func(a, b): return (a[0] as Rect2).get_center().distance_squared_to(f.centro_util()) 		< (b[0] as Rect2).get_center().distance_squared_to(f.centro_util()))
	var yo_caja := Rect2(yo - Vector2(7, 26), Vector2(14, 26))
	var piezas: Array = []    # {n, t0}
	var pasos: Array = []     # {fig, de, a, t0}: las figuras que se apartan (Bastonazo)
	match nom:
		"basico":
			var mejor: Rect2 = Rect2()
			var d_mejor: float = INF
			for p in _enemigos:
				var dd: float = absf(angle_difference((p - yo).angle(), f.dir.angle())) * 60.0 + (p - yo).length()
				if dd < d_mejor:
					d_mejor = dd
					mejor = Rect2(p - Vector2(7, 26), Vector2(14, 26))
			piezas.append({"n": BastonAire.golpe(self, BastonAire.Modo.GOLPE, yo + alto, mejor, false, false, 0,
				semilla, 0.0, 1.0), "t0": 0.0})
		"bastonazo":
			piezas.append({"n": SueloRoto.lanzar(self, f, ab.suelo_roto, semilla), "t0": 0.0})
			for i in cajas.size():
				var r1: Rect2 = cajas[i][0]
				var t1: float = SueloRoto.retraso(f, _pies_caja(r1), ab.suelo_roto)
				piezas.append({"n": BastonAire.golpe(self, BastonAire.Modo.BASTONAZO_C, yo + alto, r1, false, i == 0, 0,
					semilla + i, 0.0, 1.0), "t0": t1})
				var de: Vector2 = _enemigos[int(cajas[i][1])]
				pasos.append({"fig": _figs[int(cajas[i][1])], "de": de, "a": de + (de - yo).normalized() * -ab.tiron, "t0": t1})
		"sello_arcano":
			# Se cierra en el suelo y alcanza a todos a la vez: nada en cada cuerpo.
			piezas.append({"n": SueloRoto.lanzar(self, f, ab.suelo_roto, semilla), "t0": 0.0})
		"viento_limpio":
			piezas.append({"n": SueloRoto.lanzar(self, f, ab.suelo_roto, semilla), "t0": 0.0})
			for i in cajas.size():
				var r2: Rect2 = cajas[i][0]
				piezas.append({"n": BastonAire.golpe(self, BastonAire.Modo.VIENTO_C, yo + alto, r2, false, false, 0,
					semilla + i, 0.0, 1.0), "t0": SueloRoto.retraso(f, _pies_caja(r2), ab.suelo_roto)})
		"velo_umbrio", "canalizar", "canalizar_varita":
			var m_s: int = BastonAire.Modo.VELO if nom == "velo_umbrio" else BastonAire.Modo.FOCO
			piezas.append({"n": BastonAire.golpe(self, m_s, yo + alto, yo_caja, false, false, 0, semilla, 0.0, 1.0,
				Vector2.ZERO, 0.7 if nom == "canalizar_varita" else 1.0), "t0": 0.0})
		"purificar", "chispa_vinculada", "egida_menor":
			if not cajas.is_empty():
				var m_v: int = {"purificar": BastonAire.Modo.PURIFICAR, "chispa_vinculada": BastonAire.Modo.CHISPA,
					"egida_menor": BastonAire.Modo.EGIDA}[nom]
				# La Egida, hacia fuera del corro (su "enemigo mas cercano").
				var r3: Rect2 = cajas[0][0]
				var mano: Vector2 = yo + alto + (hacia_fila as Vector2).normalized().orthogonal() * 5.0
				piezas.append({"n": BastonAire.golpe(self, m_v, mano, r3, false, false, 0, semilla, 0.0, 1.0,
					r3.get_center() - yo), "t0": 0.0})
	for pz in piezas:
		if pz["n"] != null:
			(pz["n"] as Node).set_process(false)
	for fg in _figs:
		(fg as ColorRect).color = VERDE if nom in APOYO_ALIADOS else ROJO
	for col in tiempos.size():
		var t: float = float(tiempos[col])
		# El Velo: tu figura medio transparente en cuanto la sombra te ha tapado (el Sigilo, en el juego).
		if nom == "velo_umbrio":
			_yo_fig.color = Color(0.35, 0.6, 1.0, 0.45 if t > BastonAire.T_CAE_VELO else 1.0)
		for pz in piezas:
			var n: Node2D = pz["n"]
			if n == null:
				continue
			n.set("_t", t - float(pz["t0"]))
			n.queue_redraw()
			for hijo in ["_suelo", "_atras", "_delante"]:
				var su = n.get(hijo)
				if su is Node2D:
					(su as Node2D).queue_redraw()
		for ps in pasos:
			var u: float = clampf((t - float(ps["t0"])) / 0.12, 0.0, 1.0)
			(ps["fig"] as ColorRect).position = (ps["de"] as Vector2).lerp(ps["a"], u) - Vector2(7, 26)
		await _viñeta(hoja, col + 1, fila, "%s · %s · %.2f s" % [ab.nombre, dir_n, t])
	for pz in piezas:
		if pz["n"] != null:
			(pz["n"] as Node).queue_free()
	for ps in pasos:
		(ps["fig"] as ColorRect).position = (ps["de"] as Vector2) - Vector2(7, 26)
	for fg in _figs:
		(fg as ColorRect).color = ROJO
	_yo_fig.color = Color(0.35, 0.6, 1.0)
	await get_tree().process_frame


func _pies_caja(r: Rect2) -> Vector2:
	return Vector2(r.get_center().x, r.end.y)


func _viñeta(hoja: Image, col: int, fila: int, texto: String) -> void:
	var tam: Vector2 = get_viewport().get_visible_rect().size
	_rotulo.text = texto
	_rotulo.position = tam * 0.5 - Vector2(LADO, LADO) * 0.5 + Vector2(8, 4)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var cen: Vector2i = img.get_size() / 2
	hoja.blit_rect(img, Rect2i(cen - Vector2i(LADO, LADO) / 2, Vector2i(LADO, LADO)),
		Vector2i(col * LADO, fila * LADO))


# LAS MAGIAS: el efecto por el suelo con la forma que le da la pelea (los proyectiles, hasta el primero que pillan)
# y los ARCOS de la cadena de la Descarga, cada uno en su instante (como en el juego, uno tras otro).
func _efecto_magia(sp: SpellData, f, fila: int, hoja: Image, tiempos: Array, dir_n: String, yo: Vector2) -> void:
	BarridoAire.ritmo = 1.0
	var pillados: Array = []
	for p in _enemigos:
		var caja := Rect2(p - Vector2(7, 26), Vector2(14, 26))
		if f.toca(caja):
			pillados.append(caja)
	pillados.sort_custom(func(x, y): return (x as Rect2).get_center().distance_squared_to(yo) < (y as Rect2).get_center().distance_squared_to(yo))
	if sp.forma_solo_primero and pillados.size() > 1:
		pillados = pillados.slice(0, 1)
	var tipo: int = sp.suelo_mapa
	var f_ef = f
	# LAS SIN GOLPE: la maldicion en cada figura del circulo, la fortaleza en las de alrededor (y en ti) y el filo
	# de ti a la figura mas cercana a la huella.
	var sueltos: Array = []   # {n, t0}
	if sp.tipo == SpellData.TipoEfecto.DEBUFF:
		# La MIASMA por el suelo y, a cada uno, su maldicion cuando le llega.
		if sp.suelo_mapa >= 0:
			BarridoAire.ritmo = 1.0
			sueltos.append({"n": SueloRoto.lanzar(self, f, sp.suelo_mapa, 4321 + fila), "t0": 0.0})
		for cj in pillados:
			var llega: float = SueloRoto.retraso_caja(f, cj, sp.suelo_mapa) if sp.suelo_mapa >= 0 else 0.0
			sueltos.append({"n": MagiaAire.sobre_cuerpo(self, MagiaAire.Modo.MALDICION, cj, Color.WHITE, 9, 0.0, 1.0), "t0": llega})
	elif sp.forma_a_aliados and int(sp.forma_apunte) == CombatFormas.Apunte.ALREDEDOR:
		var cajas_f: Array = [Rect2(yo - Vector2(7, 26), Vector2(14, 26))]
		for p in _enemigos:
			var cjf := Rect2(p - Vector2(7, 26), Vector2(14, 26))
			if f.toca(cjf):
				cajas_f.append(cjf)
		if sp.suelo_mapa >= 0:
			BarridoAire.ritmo = 1.0
			sueltos.append({"n": SueloRoto.lanzar(self, f, sp.suelo_mapa, 4321 + fila), "t0": 0.0})
		for cj2 in cajas_f:
			var llega2: float = SueloRoto.retraso_caja(f, cj2, sp.suelo_mapa) if sp.suelo_mapa >= 0 else 0.0
			# La cura de grupo: su columna de luz en cada uno; el resto (la Fortaleza), su aura.
			if sp.tipo == SpellData.TipoEfecto.CURACION:
				sueltos.append({"n": MagiaMayor.columna_luz(self, cj2, 9, 0.0, 1.0), "t0": llega2})
			elif sp.imbue_prisma:
				# El prismatico: su chorro de petalos del pecho del mago a cada uno (sale tras la carga).
				sueltos.append({"n": MagiaMayor.petalos_prisma(self, yo + Vector2(0, -13), cj2, 9, 0.6, 1.0), "t0": MagiaMayor.T_CARGA_PRISMA + 0.6})
			else:
				sueltos.append({"n": MagiaAire.sobre_cuerpo(self, MagiaAire.Modo.FORTALECER, cj2, Color.WHITE, 9, 0.0, 1.0), "t0": llega2})
	elif sp.imbue_tipo > 0:
		var caja_i: Rect2 = Rect2()
		var d_i: float = INF
		for p in _enemigos:
			var cji := Rect2(p - Vector2(7, 26), Vector2(14, 26))
			if cji.get_center().distance_to(f.centro) < d_i:
				d_i = cji.get_center().distance_to(f.centro)
				caja_i = cji
		var col_i: Color = Elementos.color(sp.elemento) if Elementos.tiene_color(sp.elemento) else MagiaAire.ARCANO
		sueltos.append({"n": MagiaAire.filo(self, yo + Vector2(0, -13), caja_i, col_i, 9, 0.6, 1.0, sp.elemento,
			sp.imbue_tipo == 2), "t0": 0.6})
	if not sueltos.is_empty():
		for su in sueltos:
			(su["n"] as Node).set_process(false)
		for col in tiempos.size():
			for su in sueltos:
				(su["n"] as Node2D).set("_t", float(tiempos[col]) - float(su["t0"]))
				for hijo in ["_suelo", "_delante", "_brillo"]:
					var hn = (su["n"] as Node2D).get(hijo)
					if hn is Node2D:
						(hn as Node2D).queue_redraw()
			await _viñeta(hoja, col + 1, fila, "%s · %s · %.2f s" % [sp.nombre, dir_n, float(tiempos[col])])
		for su in sueltos:
			(su["n"] as Node).queue_free()
		await get_tree().process_frame
		return
	# EL VENDAJE: la luz sobre la figura que tenga la huella encima (en el juego, uno de los tuyos).
	if sp.forma_a_aliados:
		var caja_c: Rect2 = Rect2()
		var d_c: float = INF
		for p in _enemigos:
			var cj := Rect2(p - Vector2(7, 26), Vector2(14, 26))
			var dd: float = cj.get_center().distance_to(f.centro)
			if dd < d_c:
				d_c = dd
				caja_c = cj
		var cu := MagiaAire.cura(self, caja_c, 55 + fila, 0.0, 1.0)
		cu.set_process(false)
		for col in tiempos.size():
			cu.set("_t", float(tiempos[col]))
			for hijo in ["_suelo", "_brillo"]:
				(cu.get(hijo) as Node2D).queue_redraw()
			await _viñeta(hoja, col + 1, fila, "%s · %s · %.2f s" % [sp.nombre, dir_n, float(tiempos[col])])
		cu.queue_free()
		await get_tree().process_frame
		return
	var proyectil: bool = tipo in [SueloRoto.Tipo.MAGIA_ORBE, SueloRoto.Tipo.MAGIA_BOLA, SueloRoto.Tipo.MAGIA_HELICE,
		SueloRoto.Tipo.MAGIA_JABALINA]
	if proyectil:
		var dir: Vector2 = f.dir if f.tipo == CombatFormas.Tipo.LINEA else (f.centro - yo)
		var largo: float = f.largo if f.tipo == CombatFormas.Tipo.LINEA else yo.distance_to(f.centro)
		if not pillados.is_empty():
			var c0: Rect2 = pillados[0]
			if f.tipo != CombatFormas.Tipo.LINEA:
				dir = Vector2(c0.get_center().x, c0.end.y) - yo
			var cerca := Vector2(clampf(yo.x, c0.position.x, c0.end.x), clampf(yo.y, c0.position.y, c0.end.y))
			largo = maxf((cerca - yo).dot(dir.normalized()), 4.0)
		else:
			tipo = {SueloRoto.Tipo.MAGIA_ORBE: SueloRoto.Tipo.MAGIA_ORBE_FALLA, SueloRoto.Tipo.MAGIA_BOLA: SueloRoto.Tipo.MAGIA_BOLA_FALLA,
				SueloRoto.Tipo.MAGIA_HELICE: SueloRoto.Tipo.MAGIA_HELICE_FALLA,
				SueloRoto.Tipo.MAGIA_JABALINA: SueloRoto.Tipo.MAGIA_JABALINA_FALLA}[tipo]
		f_ef = CombatFormas.linea(yo, dir, largo, 8.0)
	if tipo == SueloRoto.Tipo.MAGIA_RAYO:
		f_ef = CombatFormas.circulo(Vector2(pillados[0].get_center().x, pillados[0].end.y) if not pillados.is_empty() else f.centro, 8.0)
	var s: Node2D = SueloRoto.lanzar(self, f_ef, tipo, 1234 + fila)
	s.set_process(false)
	# LA CADENA: del primero al mas cercano que no haya recibido (60 px), hasta 3 saltos.
	var arcos: Array = []   # {n, t0}
	# LA TORMENTA: sus rayos de muestra, uno a cada figura de dentro, escalonados como sus golpes.
	var rayos_t: Array = []   # {n, t0}
	if tipo == SueloRoto.Tipo.MAGIA_TORMENTA and not pillados.is_empty():
		var t_r0: float = MagiaMayor.retraso(MagiaMayor.Modo.TORMENTA, f_ef, f_ef.centro)
		for i in pillados.size() * 2:
			var rt := MagiaMayor.rayo_tormenta(self, pillados[i % pillados.size()], 90 + i, 0.0, 1.0)
			rt.set_process(false)
			rayos_t.append({"n": rt, "t0": t_r0 + 0.14 * float(i)})
	if sp.forma_cadena > 0.0 and not pillados.is_empty():
		var t_llega: float = MagiaAire.retraso(tipo - SueloRoto.Tipo.MAGIA_ALIENTO, f_ef, Vector2(pillados[0].get_center().x, pillados[0].end.y))
		var ya: Array = [pillados[0]]
		var desde: Rect2 = pillados[0]
		for i in sp.rebotes:
			var mejor: Rect2 = Rect2()
			var d_m: float = INF
			for p in _enemigos:
				var caja2 := Rect2(p - Vector2(7, 26), Vector2(14, 26))
				if ya.has(caja2):
					continue
				var d: float = caja2.get_center().distance_to(desde.get_center()) - 14.0
				if d <= sp.forma_cadena and d < d_m:
					d_m = d
					mejor = caja2
			if not mejor.has_area():
				break
			var a := MagiaAire.arco(self, desde.get_center(), mejor.get_center(), MagiaAire.RAYO, 77 + i, 0.0, 1.0)
			a.set_process(false)
			arcos.append({"n": a, "t0": t_llega + 0.075 * float(i + 1)})
			ya.append(mejor)
			desde = mejor
	for col in tiempos.size():
		var t: float = float(tiempos[col])
		s.set("_t", t)
		for hijo in ["_suelo", "_delante", "_brillo", "_lluvia"]:
			if s.get(hijo) != null:
				(s.get(hijo) as Node2D).queue_redraw()
		for ar in arcos:
			(ar["n"] as Node2D).set("_t", t - float(ar["t0"]))
			((ar["n"] as Node2D).get("_brillo") as Node2D).queue_redraw()
		for rt2 in rayos_t:
			(rt2["n"] as Node2D).set("_t", t - float(rt2["t0"]))
			for hijo2 in ["_suelo", "_brillo"]:
				((rt2["n"] as Node2D).get(hijo2) as Node2D).queue_redraw()
		await _viñeta(hoja, col + 1, fila, "%s · %s · %.2f s" % [sp.nombre, dir_n, t])
	s.queue_free()
	for ar in arcos:
		(ar["n"] as Node).queue_free()
	for rt3 in rayos_t:
		(rt3["n"] as Node).queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------
#  LOS ENEMIGOS (28/09): los SLIMES
# ------------------------------------------------------------
# El slime de verdad en el centro (su dibujo, mirando a cada direccion) y los tuyos en AZUL alrededor. Cada
# habilidad con su forma de la ficha (el alcance de los enemigos, 15) y su efecto del mapa (SlimeAire), del color
# de ESE slime. Una carpeta por slime: la misma habilidad sale en cada uno que la tiene, con su color.
const SLIMES := [["comun", "slime"], ["venenoso", "slime_veneno"], ["fuego", "slime_fuego"],
	["abisal", "slime_abisal"], ["profundo", "slime_profundo"], ["rey", "rey_slime"]]
const ALCANCE_ENEMIGO := 15.0
const AZUL := Color(0.35, 0.6, 1.0)
# Los momentos de cada efecto (segundos desde el golpe; los negativos, lo que viaja antes de llegar).
const MOMENTOS_SLIME := {
	"basico": [-0.02, 0.03, 0.1, 0.2, 0.4],
	"slime_placaje_viscoso": [0.04, 0.1, 0.2, 0.3, 0.6],
	"slime_placaje_corrosivo": [0.04, 0.1, 0.2, 0.3, 0.6],
	"slime_doble_embate": [0.05, 0.12, 0.25, 0.32, 0.5],
	"slime_reventon": [0.02, 0.08, 0.16, 0.35, 1.2],
	"slime_rociada_corrosiva": [0.05, 0.12, 0.22, 0.35, 0.9],
	"slime_escupitajo_toxico": [-0.18, -0.08, 0.02, 0.15, 0.5],
	"slime_llamarada": [0.1, 0.22, 0.36, 0.55, 0.85],
	"slime_salpicadura_ardiente": [0.05, 0.12, 0.22, 0.4, 0.9],
	"slime_combustion": [0.03, 0.1, 0.2, 0.4, 0.9],
	"slime_ignicion": [0.05, 0.2, 0.4, 0.7, 1.1],
	"slime_presion_abismo": [0.12, 0.28, 0.45, 0.7, 1.4],
	"slime_tromba_abisal": [-0.08, 0.02, 0.15, 0.35, 0.6],
	"rey_slime_aplastamiento": [0.03, 0.1, 0.22, 0.45, 1.2],
	"rey_slime_escision": [-0.12, 0.02, 0.2, 0.4, 0.62],
	"rey_slime_marea": [0.1, 0.3, 0.5, 0.75, 1.3],
}

func _hojas_slimes(salida: String, pedidas: String) -> void:
	BarridoAire.ritmo = 1.0
	var yo := Vector2.ZERO
	_yo_fig.visible = false
	_color_huella = Color(1.0, 0.3, 0.25)
	for fg in _figs:
		(fg as ColorRect).color = AZUL
	var solo: String = OS.get_environment("ATAQUES_SLIME")   # ATAQUES_SLIME=rey -> solo ese
	for sl in SLIMES:
		if solo != "" and sl[0] != solo:
			continue
		var ed: EnemyData = load("res://scenes/actors/enemy/%s.tres" % sl[1])
		var col: Color = ed.color_visual(0.5)
		# SU DIBUJO: un cuerpo con su sprite, con los pies (su centro en el suelo) en el centro de la hoja.
		var cuerpo := Node2D.new()
		cuerpo.z_index = 1000
		cuerpo.z_as_relative = false
		add_child(cuerpo)
		var spr := AnimatedSprite2D.new()
		spr.sprite_frames = SpritesEnemigo.frames_de(ed, 0.5)
		spr.scale = Vector2.ONE * SpritesEnemigo.escala_de(ed)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		cuerpo.add_child(spr)
		spr.play(&"idle_0")
		spr.pause()
		var rd: Rect2 = load("res://scripts/ui/combat_tactico.gd").rect_dibujo(cuerpo)
		spr.position = yo - Vector2(rd.get_center().x, rd.position.y + rd.size.y * ed.centro_suelo_real())
		var pisa: float = maxf(rd.size.x * 0.33, 4.0)
		var bulto: Rect2 = Rect2(rd.position + spr.position, rd.size)
		var habs: Array = ["basico"]
		for h in ed.habilidades:
			habs.append((h as AbilityData).resource_path.get_file().get_basename())
		for nom in habs:
			if pedidas != "" and not (String(nom) in pedidas.split(",")):
				continue
			var ab: AbilityData
			if nom == "basico":
				ab = AbilityData.new()
				ab.nombre = "Basico"
				ab.forma = CombatFormas.Tipo.CIRCULO
				ab.forma_apunte = CombatFormas.Apunte.DELANTE
				ab.forma_radio = 8.0
			else:
				ab = load("res://resources/abilities/%s.tres" % nom)
			if int(ab.forma) < 0 and nom != "slime_ignicion":
				continue   # sin huella (el Brote): no hay nada que enseñar aqui
			var tiempos: Array = MOMENTOS_SLIME.get(nom, [0.05, 0.15, 0.3, 0.5, 0.9])
			var f0 = CombatFormas.de_habilidad_mapa(ab, yo, pisa, ALCANCE_ENEMIGO, yo + Vector2(70, 0)) if int(ab.forma) >= 0 else null
			var medida: float = 70.0 if f0 == null else maxf(maxf(f0.radio, f0.largo), 40.0)
			if f0 != null and int(ab.forma_apunte) == CombatFormas.Apunte.LIBRE:
				medida = maxf(medida, f0.radio + 70.0 * 0.7)
			medida = maxf(medida, 90.0)
			var zoom: float = float(LADO) / (2.0 * (medida + 30.0))
			_cam.zoom = Vector2(zoom, zoom)
			var hoja := Image.create(LADO * (1 + tiempos.size()), LADO * DIRS.size(), false, Image.FORMAT_RGBA8)
			for fila in DIRS.size():
				var dvec: Vector2 = (DIRS[fila][1] as Vector2).normalized()
				var dir_n: String = DIRS[fila][0]
				var hacia: Vector2 = yo + dvec * 70.0
				spr.animation = StringName("idle_%d" % SpriteLienzo.dir8(dvec))
				var f = CombatFormas.de_habilidad_mapa(ab, yo, pisa, ALCANCE_ENEMIGO, hacia) if int(ab.forma) >= 0 else null
				var hacia_cam: float = 0.0 if f == null or int(ab.forma_apunte) == CombatFormas.Apunte.ALREDEDOR else 0.3
				_cam.global_position = yo + dvec * medida * hacia_cam
				# 1) La huella, en ROJO (es de enemigo).
				_forma_huella = f if nom != "basico" else null
				_huella.queue_redraw()
				await _viñeta(hoja, 0, fila, "%s · %s · %s · apuntando" % [ed.enemy_name, ab.nombre, dir_n])
				_forma_huella = null
				_huella.queue_redraw()
				# 2) Los tuyos que pilla (en el orden de cercania al centro de la huella).
				var cajas: Array = []
				for p in _enemigos:
					var r := Rect2((p as Vector2) - Vector2(7, 26), Vector2(14, 26))
					if f != null and f.toca(r):
						cajas.append(r)
				if f != null:
					var cu: Vector2 = f.centro_util()
					cajas.sort_custom(func(x, y): return (x as Rect2).get_center().distance_squared_to(cu) < (y as Rect2).get_center().distance_squared_to(cu))
				if nom == "basico":
					cajas = [Rect2(yo + dvec * 26.0 - Vector2(7, 13), Vector2(14, 26))]
				var boca: Vector2 = bulto.get_center() - Vector2(0.0, bulto.size.y * 0.15)
				var semilla: int = SlimeAire.semilla_con_color(700 + fila * 31, col)
				var piezas: Array = []   # {n, t0}
				var antes: int = get_child_count()
				if ab.suelo_roto >= 0 and f != null:
					SueloRoto.lanzar(self, f, ab.suelo_roto, semilla, ab.pisoton_final if ab.pisoton_final > 0.0 else ab.forma_nucleo)
					for i in range(antes, get_child_count()):
						piezas.append({"n": get_child(i), "t0": 0.0})
				elif nom == "slime_ignicion":
					piezas.append({"n": SlimeAire.sobre_cuerpo(self, SlimeAire.Modo.IGNICION, bulto.get_center(), bulto, col, semilla, 0.0, 1.0), "t0": 0.0})
				else:
					var modo_s: int = SlimeAire.Modo.GOLPE
					var vuelo: float = 0.05
					match int(ab.fx_estilo_mapa):
						CombatFX.Estilo.SLIME_ESCUPE:
							modo_s = SlimeAire.Modo.ESCUPE
							vuelo = 0.26
						CombatFX.Estilo.SLIME_TROMBA:
							modo_s = SlimeAire.Modo.TROMBA
							vuelo = 0.16
						CombatFX.Estilo.SLIME_TROZO:
							modo_s = SlimeAire.Modo.TROZO
							vuelo = 0.22
					var golpes: int = maxi(ab.golpes_max, 1) if ab.forma_reparte else 1
					if ab.forma_reparte and not cajas.is_empty():
						for g in golpes:
							var rg: Rect2 = cajas[g % cajas.size()]
							piezas.append({"n": SlimeAire.sobre_cuerpo(self, modo_s, boca, rg, col, semilla + g, vuelo, 1.0),
								"t0": 0.2 * float(g)})
					else:
						for i in cajas.size():
							piezas.append({"n": SlimeAire.sobre_cuerpo(self, modo_s, boca, cajas[i], col, semilla + i, vuelo, 1.0),
								"t0": 0.0})
				# EL EMPUJON de la Marea: los que pilla se apartan cuando les llega.
				var pasos: Array = []
				if not is_zero_approx(ab.tiron) and f != null and ab.suelo_roto >= 0:
					for i in _enemigos.size():
						var r2 := Rect2((_enemigos[i] as Vector2) - Vector2(7, 26), Vector2(14, 26))
						if f.toca(r2):
							var de: Vector2 = _enemigos[i]
							pasos.append({"fig": _figs[i], "de": de, "a": de + (de - yo).normalized() * -ab.tiron,
								"t0": SueloRoto.retraso(f, _pies_caja(r2), ab.suelo_roto)})
				for pz in piezas:
					if pz["n"] != null:
						(pz["n"] as Node).set_process(false)
				for c in tiempos.size():
					var t: float = float(tiempos[c])
					for pz in piezas:
						var n: Node2D = pz["n"]
						if n == null or not is_instance_valid(n):
							continue
						# Lo que viaja (el escupitajo, el trozo) arranca en -vuelo: su _t cuenta desde ahi.
						n.set("_t", t - float(pz["t0"]))
						n.queue_redraw()
						for hijo in ["_suelo", "_delante", "_brillo", "_atras", "_aire", "_geiser"]:
							var su = n.get(hijo)
							if su is Node2D:
								(su as Node2D).queue_redraw()
					for ps in pasos:
						var u: float = clampf((t - float(ps["t0"])) / 0.15, 0.0, 1.0)
						(ps["fig"] as ColorRect).position = (ps["de"] as Vector2).lerp(ps["a"], u) - Vector2(7, 26)
					await _viñeta(hoja, c + 1, fila, "%s · %s · %s · %.2f s" % [ed.enemy_name, ab.nombre, dir_n, t])
				for pz in piezas:
					if pz["n"] != null and is_instance_valid(pz["n"]):
						(pz["n"] as Node).queue_free()
				for ps in pasos:
					(ps["fig"] as ColorRect).position = (ps["de"] as Vector2) - Vector2(7, 26)
				await get_tree().process_frame
			var carpeta: String = "%s/enemigos/slimes/%s" % [salida, sl[0]]
			DirAccess.make_dir_recursive_absolute(carpeta)
			var ruta: String = "%s/%s.png" % [carpeta, nom]
			hoja.save_png(ruta)
			print("[hoja] ", ruta)
		cuerpo.queue_free()
		await get_tree().process_frame


# LAS BESTIAS DE LOS PISOS BAJOS (28/09): rata, rey rata, jabali y trent. ATAQUES_BESTIA=rata (el .tres) ->
# enemigos/<bestia>/<habilidad>.png. Como las de los slimes, con BestiaAire y la sangre de los que la echan.
const MOMENTOS_BESTIA := {
	"basico": [-0.1, -0.04, 0.0, 0.1, 0.3],
	"rata_mordisco_sangrante": [-0.08, 0.0, 0.1, 0.22, 0.4],
	"rata_frenesi_dentelladas": [0.05, 0.15, 0.35, 0.6, 0.9],
	"rey_rata_dentellada_real": [-0.06, 0.04, 0.26, 0.5, 0.85],
	"rey_rata_chillido": [0.06, 0.14, 0.26, 0.4, 0.62],
	"rey_rata_yugular": [0.08, 0.16, 0.22, 0.32, 0.55],
	"jabali_cornada": [-0.1, 0.0, 0.1, 0.22, 0.4],
	"jabali_embestida": [0.08, 0.16, 0.22, 0.35, 0.6],
	"jabali_pisoton": [0.03, 0.12, 0.23, 0.35, 0.8],
	"trent_savia_corrosiva": [0.1, 0.28, 0.45, 0.9, 1.8],
	"trent_raices_atenazantes": [0.12, 0.3, 0.5, 0.75, 1.2],
	"trent_ramazo": [-0.2, -0.05, 0.08, 0.2, 0.42],
	"arana_mordisco_ponzonoso": [-0.08, 0.0, 0.1, 0.3, 0.55],
	"arana_telarana": [0.1, 0.25, 0.38, 0.5, 1.4],
	# El escarabajo (29/09): la bola cruzando la linea (llega al final en InsectoAire.T_RODADA) y desenroscandose; el
	# Caparazon desde que empieza a cerrarse (-0,44) hasta el reflejo y el polvo.
	"escarabajo_rodar": [0.0, 0.11, 0.22, 0.33, 0.44, 0.55, 0.7, 1.2],
	"escarabajo_caparazon": [-0.44, -0.2, 0.0, 0.08, 0.16, 0.3, 0.6],
	# El ciempies: los picotazos de la Oleada van cada 0,22 s (el reparto: uno a cada uno).
	"ciempies_oleada": [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.7, 0.9],
	"ciempies_enrosque": [0.0, 0.05, 0.1, 0.18, 0.3],
	# La segadora: las hojas cruzando, el corte (la izquierda) y la derecha 0,075 s despues, y la X que se queda.
	"segadora_guadanas": [-0.08, -0.03, 0.0, 0.05, 0.09, 0.16, 0.3],
	# El Ensarte: se lanza, la hoja entra, asoma por detras y queda el agujero.
	"segadora_ensarte": [0.1, 0.18, 0.23, 0.27, 0.32, 0.45, 0.7],
	# El miconido: el latigo saliendo de la mano, llegando, enroscado y el atado; la nube saliendo y quedandose.
	"miconido_micelio": [-0.15, -0.08, 0.0, 0.08, 0.2, 0.45, 0.8],
	"miconido_esporas": [0.0, 0.1, 0.2, 0.35, 0.6, 1.0, 1.6],
	# La acorazada (30/09): los dos zarpazos (0 y 0,22), la carga cruzando (llega en T_RODADA) y el pisoton, y el
	# destello del caparazon.
	"bestia_zarpazo": [-0.06, 0.0, 0.06, 0.16, 0.22, 0.28, 0.45],
	"bestia_carga": [0.0, 0.11, 0.22, 0.33, 0.44, 0.55, 0.8, 1.3],
	"caparazon": [-0.02, 0.0, 0.04, 0.1, 0.2, 0.32],
	# El acechador (30/09): el salto entero con su estela (despega a -0,4) y la caida al cuello; los dos mordiscos de la
	# Dentellada (0 y 0,22) tirando; y el vaho del Olor a sangre subiendo (y secandose en la ultima).
	"acechador_salto": [-0.3, -0.2, -0.1, 0.0, 0.08, 0.2, 0.4],
	"acechador_dentellada": [-0.06, 0.0, 0.08, 0.16, 0.22, 0.3, 0.4, 0.6],
	"olor_sangre": [0.15, 0.5, 0.9, 1.4, 1.9, 2.3],
	# La aberracion (30/09): los tres tentaculos del Latigazo (0; 0,22; 0,44) brotando, restallando y recogiendose; la
	# Mirada recorriendo el cono y el ojo abriendose; el Alarido abriendose; y su pasiva (pustulas, y grietas de luz).
	"aberracion_latigazo": [-0.12, -0.04, 0.0, 0.1, 0.22, 0.3, 0.44, 0.6],
	"aberracion_mirada": [0.0, 0.1, 0.2, 0.3, 0.45, 0.6],
	"aberracion_alarido": [0.0, 0.1, 0.2, 0.3, 0.45, 0.7],
	"carne_cierra": [0.0, 0.1, 0.2, 0.3, 0.45],
	"carne_quemada": [0.1, 0.4, 0.8, 1.2, 1.6],
}
# Y los INSECTOIDES (29/09, InsectoAire), por la misma tuberia.
const ESTILO_A_INSECTO := {CombatFX.Estilo.INSECTO_QUELICEROS: InsectoAire.Modo.QUELICEROS,
	CombatFX.Estilo.INSECTO_PONZONA: InsectoAire.Modo.PONZONA, CombatFX.Estilo.INSECTO_HEBRAS: InsectoAire.Modo.HEBRAS,
	CombatFX.Estilo.INSECTO_PALA: InsectoAire.Modo.PALA, CombatFX.Estilo.INSECTO_ARROLLA: InsectoAire.Modo.ARROLLA,
	CombatFX.Estilo.INSECTO_CAPARAZON: InsectoAire.Modo.CAPARAZON,
	CombatFX.Estilo.INSECTO_FORCIPULAS: InsectoAire.Modo.FORCIPULAS, CombatFX.Estilo.INSECTO_PATITAS: InsectoAire.Modo.PATITAS,
	CombatFX.Estilo.INSECTO_APRETON: InsectoAire.Modo.APRETON,
	CombatFX.Estilo.INSECTO_TAJO: InsectoAire.Modo.TAJO, CombatFX.Estilo.INSECTO_GUADANA: InsectoAire.Modo.GUADANA,
	CombatFX.Estilo.INSECTO_ESTOCADA: InsectoAire.Modo.ESTOCADA}
# Y las SIMAS (30/09, SimaAire).
const ESTILO_A_SIMA := {CombatFX.Estilo.SIMA_PORRAZO: SimaAire.Modo.PORRAZO, CombatFX.Estilo.SIMA_TOS: SimaAire.Modo.TOS,
	CombatFX.Estilo.SIMA_LATIGO: SimaAire.Modo.LATIGO, CombatFX.Estilo.SIMA_VENTOSA: SimaAire.Modo.VENTOSA,
	CombatFX.Estilo.SIMA_CHUPADA: SimaAire.Modo.CHUPADA, CombatFX.Estilo.SIMA_OIDOS: SimaAire.Modo.OIDOS,
	CombatFX.Estilo.SIMA_PALETOS: SimaAire.Modo.PALETOS, CombatFX.Estilo.SIMA_ALA: SimaAire.Modo.ALA,
	CombatFX.Estilo.SIMA_POLVO: SimaAire.Modo.POLVO, CombatFX.Estilo.SIMA_VELO: SimaAire.Modo.VELO}
# Y las BESTIAS DE LAS SIMAS (30/09, FieraAire).
const ESTILO_A_FIERA := {CombatFX.Estilo.FIERA_TESTARAZO: FieraAire.Modo.TESTARAZO,
	CombatFX.Estilo.FIERA_ZARPA: FieraAire.Modo.ZARPA, CombatFX.Estilo.FIERA_PLACA: FieraAire.Modo.PLACA,
	CombatFX.Estilo.FIERA_FAUCES: FieraAire.Modo.FAUCES, CombatFX.Estilo.FIERA_YUGULAR: FieraAire.Modo.YUGULAR,
	CombatFX.Estilo.FIERA_DENTELLADA: FieraAire.Modo.DENTELLADA,
	CombatFX.Estilo.FIERA_TENTACULO: FieraAire.Modo.TENTACULO, CombatFX.Estilo.FIERA_MIRADA: FieraAire.Modo.MIRADA}
const ESTILO_A_BESTIA := {CombatFX.Estilo.BESTIA_MORDISCO: BestiaAire.Modo.MORDISCO,
	CombatFX.Estilo.BESTIA_MORDISCO_SANGRA: BestiaAire.Modo.MORDISCO_SANGRA, CombatFX.Estilo.BESTIA_FRENESI: BestiaAire.Modo.FRENESI,
	CombatFX.Estilo.BESTIA_DENTELLADA: BestiaAire.Modo.DENTELLADA, CombatFX.Estilo.BESTIA_YUGULAR: BestiaAire.Modo.YUGULAR,
	CombatFX.Estilo.BESTIA_TEMBLOR: BestiaAire.Modo.TEMBLOR, CombatFX.Estilo.BESTIA_COLMILLO: BestiaAire.Modo.COLMILLO,
	CombatFX.Estilo.BESTIA_CORNADA: BestiaAire.Modo.CORNADA, CombatFX.Estilo.BESTIA_CHOQUE: BestiaAire.Modo.CHOQUE,
	CombatFX.Estilo.BESTIA_RAMALAZO: BestiaAire.Modo.RAMALAZO, CombatFX.Estilo.BESTIA_PEGOTE: BestiaAire.Modo.PEGOTE}

func _hojas_bestias(salida: String, pedidas: String, bestia: String) -> void:
	BarridoAire.ritmo = 1.0
	var yo := Vector2.ZERO
	_yo_fig.visible = false
	_color_huella = Color(1.0, 0.3, 0.25)
	for fg in _figs:
		(fg as ColorRect).color = AZUL
	var ed: EnemyData = load("res://scenes/actors/enemy/%s.tres" % bestia)
	var cuerpo := Node2D.new()
	cuerpo.z_index = Game.Z_PERSONAJES   # como en el juego (enemy.gd): lo de detras de los cuerpos se tapa
	cuerpo.z_as_relative = false
	add_child(cuerpo)
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = SpritesEnemigo._generador(ed).generar_de(ed, 0.5)   # GENERADO, no el horneado: salen las animaciones nuevas antes de hornear
	spr.scale = Vector2.ONE * SpritesEnemigo.escala_de(ed)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cuerpo.add_child(spr)
	spr.play(&"idle_0")
	spr.pause()
	var rd: Rect2 = load("res://scripts/ui/combat_tactico.gd").rect_dibujo(cuerpo)
	spr.position = yo - Vector2(rd.get_center().x, rd.position.y + rd.size.y * ed.centro_suelo_real())
	var pisa: float = maxf(rd.size.x * 0.33, 4.0)
	var bulto0: Rect2 = Rect2(rd.position + spr.position, rd.size)
	var alcance: float = ed.alcance_real()
	var habs: Array = ["basico"]
	for h in ed.habilidades:
		habs.append((h as AbilityData).resource_path.get_file().get_basename())
	# LA PASIVA DEL CAPARAZON (la acorazada, 30/09): uno de los tuyos le pega de frente y se ve el destello en sus placas.
	if ed.caparazon_frente < 1.0:
		habs.append("caparazon")
	# LA PASIVA DEL OLOR A SANGRE (el acechador, 30/09): el vaho sobre uno de los tuyos que sangra.
	if ed.olor_sangre_mult != 1.0:
		habs.append("olor_sangre")
	# LA CARNE QUE SE CIERRA (la aberracion, 30/09): las pustulas al curarse y las grietas de luz cuando no puede.
	if ed.regen_turno > 0.0:
		habs.append("carne_cierra")
		habs.append("carne_quemada")
	for nom in habs:
		if pedidas != "" and not (String(nom) in pedidas.split(",")):
			continue
		var ab: AbilityData
		if nom == "caparazon":
			ab = AbilityData.new()
			ab.nombre = "Caparazon (pasiva)"
			ab.fx_estilo_mapa = CombatFX.Estilo.FIERA_PLACA
		elif nom == "olor_sangre":
			ab = AbilityData.new()
			ab.nombre = "Olor a sangre (pasiva)"
			ab.fx_estilo_mapa = CombatFX.Estilo.FIERA_FAUCES   # (para que pase; el modo es VAHO, abajo)
		elif nom in ["carne_cierra", "carne_quemada"]:
			ab = AbilityData.new()
			ab.nombre = "Carne que se cierra (pasiva)" if nom == "carne_cierra" else "Carne que se cierra (cortada por la luz)"
			ab.fx_estilo_mapa = CombatFX.Estilo.FIERA_FAUCES   # (para que pase; el modo, abajo)
		elif nom == "basico":
			ab = AbilityData.new()
			ab.nombre = "Basico"
			ab.forma = CombatFormas.Tipo.CIRCULO
			ab.forma_apunte = CombatFormas.Apunte.DELANTE
			ab.forma_radio = 8.0
			# El de su bicho (CombatEfectos._estilo_de_habilidad): la rata muerde, el jabali mete el colmillo.
			ab.fx_estilo_mapa = ed.fx_basico_mapa if ed.fx_basico_mapa >= 0 else (CombatFX.Estilo.BESTIA_COLMILLO
				if ed.fx_basico == CombatFX.Estilo.CORNADA else CombatFX.Estilo.BESTIA_MORDISCO)
		else:
			ab = load("res://resources/abilities/%s.tres" % nom)
		# Las que solo pintan el SUELO (el Pisoton) valen igual: modo -1, nada en los cuerpos.
		if not ESTILO_A_BESTIA.has(int(ab.fx_estilo_mapa)) and not ESTILO_A_INSECTO.has(int(ab.fx_estilo_mapa)) \
				and not ESTILO_A_SIMA.has(int(ab.fx_estilo_mapa)) and not ESTILO_A_FIERA.has(int(ab.fx_estilo_mapa)) 				and ab.suelo_roto < 0:
			continue   # aun sin efecto propio
		var modo_b: int = ESTILO_A_BESTIA.get(int(ab.fx_estilo_mapa), -1)
		var modo_i: int = ESTILO_A_INSECTO.get(int(ab.fx_estilo_mapa), -1)
		var modo_s: int = ESTILO_A_SIMA.get(int(ab.fx_estilo_mapa), -1)
		var modo_f: int = ESTILO_A_FIERA.get(int(ab.fx_estilo_mapa), -1)
		if nom == "olor_sangre":
			modo_f = FieraAire.Modo.VAHO
		elif nom == "carne_cierra":
			modo_f = FieraAire.Modo.PUSTULAS
		elif nom == "carne_quemada":
			modo_f = FieraAire.Modo.GRIETAS
		var sin_huella: bool = int(ab.forma) < 0
		if sin_huella:
			ab = ab.duplicate()
			ab.forma = CombatFormas.Tipo.CIRCULO
			ab.forma_apunte = CombatFormas.Apunte.DELANTE
			ab.forma_radio = 8.0
		var tiempos: Array = MOMENTOS_BESTIA.get(nom, [0.05, 0.15, 0.3, 0.5, 0.9])
		# El ramalazo del trent brota antes: se ve crecer, caer y hundirse.
		if nom == "basico" and ed.fx_basico_mapa == CombatFX.Estilo.BESTIA_RAMALAZO:
			tiempos = [-0.24, -0.1, 0.0, 0.15, 0.32]
		# El palazo del escarabajo: se ve llegar la pala, aplastarse y saltar las chispas.
		if nom == "basico" and ed.fx_basico_mapa in [CombatFX.Estilo.INSECTO_PALA, CombatFX.Estilo.INSECTO_FORCIPULAS,
				CombatFX.Estilo.INSECTO_TAJO]:
			tiempos = [-0.08, 0.0, 0.05, 0.12, 0.25]
		# Las fauces del acechador: se ven llegar abiertas, cerrar y tirar.
		if nom == "basico" and ed.fx_basico_mapa == CombatFX.Estilo.FIERA_FAUCES:
			tiempos = [-0.1, -0.04, 0.0, 0.06, 0.15, 0.3]
		# El tentaculo de la aberracion: brota, restalla y se recoge.
		if nom == "basico" and ed.fx_basico_mapa == CombatFX.Estilo.FIERA_TENTACULO:
			tiempos = [-0.12, -0.05, 0.0, 0.06, 0.15, 0.3]
		# LO QUE HACE SU CUERPO (29/09, el escarabajo: "la embestida es mas visual del sprite que de efectos"): la
		# animacion de la habilidad, en el fotograma que toca en cada momento (arranca IMPACTO_ANIM_MAPA antes del
		# golpe, como en el juego). Apuntando, la ultima de su pose de carga. Solo si el bicho la tiene.
		var anim_hab: String = String(ab.fx_anim).split(">")[0] if ab.fx_anim != &"" else ""
		# El basico, con su 'basico' si la tiene (como CombatTactico.gesto_bicho_en_mapa).
		if nom == "basico" and anim_hab == "":
			anim_hab = "basico"
			# Sin 'basico' propio, su embestida (como CombatTactico._poner_anim_bicho: el sombrero del miconido).
			if not spr.sprite_frames.has_animation(&"basico_0"):
				anim_hab = "embestida"
		var partes_carga: PackedStringArray = String(ab.fx_anim_carga).split(">", false)
		var anim_carga: String = partes_carga[partes_carga.size() - 1] if not partes_carga.is_empty() else ""
		var f0 = CombatFormas.de_habilidad_mapa(ab, yo, pisa, alcance, yo + Vector2(70, 0))
		var medida: float = maxf(maxf(f0.radio, f0.largo), 40.0)
		if int(ab.forma_apunte) == CombatFormas.Apunte.LIBRE:
			medida = maxf(medida, f0.radio + 70.0 * 0.7)
		# Los mordiscos sueltos, de cerca: si no, las mandibulas no se ven.
		# Y las huellas cortas (Dentellada real, Yugular), mas de cerca que las grandes.
		# (Los grandes, como el trent, necesitan sitio: su presa esta a su alcance mas medio cuerpo.)
		medida = maxf(32.0, alcance + rd.size.y * 0.4) if (nom == "basico" or sin_huella) \
			else maxf(medida, 90.0 if medida > 60.0 else 55.0)
		# El pisoton de la Carga acorazada cae DELANTE del final de la linea: que quepa.
		if ab.pisoton_final > 0.0:
			medida += ab.pisoton_final * 1.5
		var zoom: float = float(LADO) / (2.0 * (medida + 30.0))
		_cam.zoom = Vector2(zoom, zoom)
		var hoja := Image.create(LADO * (1 + tiempos.size()), LADO * DIRS.size(), false, Image.FORMAT_RGBA8)
		for fila in DIRS.size():
			var dvec: Vector2 = (DIRS[fila][1] as Vector2).normalized()
			var dir_n: String = DIRS[fila][0]
			var hacia: Vector2 = yo + dvec * 70.0
			# EL SALTO A LA YUGULAR va a por su presa LEJOS (hasta 110): con la del anillo, casi no saltaba.
			if modo_f == FieraAire.Modo.YUGULAR:
				hacia = yo + dvec * 100.0
			var d8: int = SpriteLienzo.dir8(dvec)
			spr.animation = StringName("idle_%d" % d8)
			spr.frame = 0
			if anim_carga != "" and spr.sprite_frames.has_animation(StringName("%s_%d" % [anim_carga, d8])):
				spr.animation = StringName("%s_%d" % [anim_carga, d8])
				spr.frame = 0
			cuerpo.position = Vector2.ZERO
			# EL FRENTE de su cuerpo hacia alli, como en el juego (CombatTactico.forma_de): de ahi salen conos y lineas
			# y de ahi se cuenta el alcance.
			var frente: float = load("res://scripts/ui/combat_tactico.gd").frente_dibujo(cuerpo, yo, dvec)
			var pisa_d: float = maxf(pisa, frente)
			# La figura que recibe el mordisco suelto (en el juego, uno de los tuyos).
			var fig_presa: ColorRect = null
			var sobre_si: bool = modo_i == InsectoAire.Modo.CAPARAZON
			if (nom == "basico" or sin_huella) and not sobre_si:
				fig_presa = _figura(yo + dvec * (pisa_d + alcance * 0.7 + 7.0) + Vector2(0, 13), AZUL)
				fig_presa.z_index = Game.Z_PERSONAJES
			var f = CombatFormas.de_habilidad_mapa(ab, yo, pisa_d, alcance, hacia, frente * 0.85)
			_cam.global_position = yo + dvec * medida * (0.0 if int(ab.forma_apunte) == CombatFormas.Apunte.ALREDEDOR else 0.3)
			_forma_huella = f if nom != "basico" and not sin_huella else null
			# EL PISOTON del final de la Carga acorazada, pintado con la linea (como CombatTactico.pisoton_de).
			_forma_huella2 = FieraAire.circulo_pisoton(f, ab.pisoton_final) 				if ab.pisoton_final > 0.0 and f.tipo == CombatFormas.Tipo.LINEA else null
			_huella.queue_redraw()
			await _viñeta(hoja, 0, fila, "%s · %s · %s · apuntando" % [ed.enemy_name, ab.nombre, dir_n])
			_forma_huella = null
			_forma_huella2 = null
			_huella.queue_redraw()
			var cajas: Array = []
			var presas_extra: Array = []
			if sobre_si:
				cajas = []   # el reflejo va sobre el (mas abajo, con su caja)
			elif nom == "basico" or sin_huella:
				cajas = [Rect2(yo + dvec * (pisa_d + alcance * 0.7 + 7.0) - Vector2(7, 13), Vector2(14, 26))]
			else:
				for q in _enemigos:
					var r := Rect2((q as Vector2) - Vector2(7, 26), Vector2(14, 26))
					if f.toca(r):
						cajas.append(r)
				var cu: Vector2 = f.centro_util()
				# SOLO AL PRIMERO (la Yugular): el mas cercano a quien se lanza, como en el juego.
				if ab.forma_solo_primero:
					cu = yo
				cajas.sort_custom(func(x, y): return (x as Rect2).get_center().distance_squared_to(cu) < (y as Rect2).get_center().distance_squared_to(cu))
				if ab.forma_solo_primero and cajas.size() > 1:
					cajas = cajas.slice(0, 1)
				# LAS HUELLAS CORTAS (la Dentellada real, cono r30): el anillo de figuras queda fuera. Dos presas dentro,
				# a los lados del cono, para que se vea a quien muerde.
				if cajas.is_empty():
					# La linea de la Yugular: una al final. El cono: dos, a los lados.
					var sitios: Array = [f.origen + dvec.rotated(-0.35) * f.radio * 0.8, f.origen + dvec.rotated(0.35) * f.radio * 0.8]
					if f.tipo == CombatFormas.Tipo.LINEA:
						sitios = [f.origen + f.dir * f.largo * 0.85]
					elif f.tipo == CombatFormas.Tipo.CIRCULO:
						sitios = [f.centro + Vector2(-f.radio * 0.4, 0.0), f.centro + Vector2(f.radio * 0.4, 0.0)]
					for sitio in sitios:
						var pies_p: Vector2 = (sitio as Vector2) + Vector2(0, 13)
						var fp: ColorRect = _figura(pies_p, AZUL)
						fp.z_index = Game.Z_PERSONAJES
						presas_extra.append(fp)
						cajas.append(Rect2(pies_p - Vector2(7, 26), Vector2(14, 26)))
			# EL SALTO (Frenesi): la bestia ya esta en el centro de su circulo cuando empiezan los mordiscos.
			if ab.salta:
				cuerpo.position = f.centro - yo
			# EL SALTO A LA YUGULAR (el acechador): se le ve volar por su arco hasta pegarse a su presa (en el juego,
			# _sitio_libre_hacia), a lo que dura el salto (_TACTICO.T_SALTO_BICHO), con la estela detras.
			var fin_salto: Vector2 = Vector2.INF
			var arco_salto: float = 0.0
			if ab.salta and modo_f == FieraAire.Modo.YUGULAR and not cajas.is_empty():
				fin_salto = _pies_caja(cajas[0]) - dvec * (pisa_d + 6.0)
				arco_salto = _TACTICO.ALTO_SALTO_BICHO * clampf(pisa / 10.0, 1.0, 2.5)
				cuerpo.position = Vector2.ZERO
			# LA CARGA (Yugular): se lanza por la linea y se queda pegada al primero (CombatTactico.mover_enemigo).
			var fin_carga: Vector2 = Vector2.INF
			if (ab.carga or ab.recorre) and f.tipo == CombatFormas.Tipo.LINEA:
				fin_carga = f.origen + f.dir * f.largo
				# La que ATRAVIESA rueda hasta el final; las demas se paran pegadas al primero.
				if not cajas.is_empty() and not ab.atraviesa and not ab.recorre:
					# El Ensarte, con la cabeza delante de su presa (como CombatTactico.mover_enemigo).
					var delante_c: float = pisa
					if ab.carga_persigue:
						delante_c = maxf(pisa, frente)
					fin_carga = _pies_caja(cajas[0]) - f.dir * (8.0 + delante_c)
				cuerpo.position = fin_carga - yo
			var bulto: Rect2 = Rect2(bulto0.position + cuerpo.position, bulto0.size)
			var semilla: int = 700 + fila * 31
			var piezas: Array = []   # {n, t0, sim}
			var antes: int = get_child_count()
			if ab.suelo_roto >= 0:
				# Lo que vuela desde el (la Telaraña): lo lejos que esta, como en el juego (CombatTactico.desde_quien_lanza).
				if ab.suelo_roto >= SueloRoto.Tipo.INSECTO_TELARANA and f.tipo == CombatFormas.Tipo.CIRCULO:
					f.ancho = yo.distance_to(f.centro)
				SueloRoto.lanzar(self, f, ab.suelo_roto, semilla, ab.pisoton_final if ab.pisoton_final > 0.0 else ab.forma_nucleo)
				for i in range(antes, get_child_count()):
					piezas.append({"n": get_child(i), "t0": 0.0, "sim": false})
			# EL TEMBLOR DEL CHILLIDO: en CADA uno de los alcanzados, cuando le pasa la onda (sobre su figura, que tiembla).
			if modo_b == BestiaAire.Modo.TEMBLOR:
				for i in cajas.size():
					var rt: Rect2 = cajas[i]
					var fig_t: ColorRect = null
					for q in _enemigos.size():
						if rt.has_point((_enemigos[q] as Vector2) - Vector2(0, 13)):
							fig_t = _figs[q]
					piezas.append({"n": BestiaAire.temblor(self, fig_t, rt, semilla + i, 0.0, 1.0),
						"t0": SueloRoto.retraso(f, _pies_caja(rt), ab.suelo_roto), "sim": false})
				cajas = []
			# EL CHOQUE DE LA EMBESTIDA: en TODOS los que arrolla, cuando les llega (y nunca antes de que el llegue).
			if modo_b == BestiaAire.Modo.CHOQUE:
				for i in cajas.size():
					var rc: Rect2 = cajas[i]
					piezas.append({"n": BestiaAire.sobre_cuerpo(self, modo_b, bulto.get_center(), rc, semilla + i, 0.0, 1.0,
						bulto.size.x), "t0": maxf(SueloRoto.retraso(f, _pies_caja(rc), ab.suelo_roto), BestiaAire.T_ESTELA),
						"sim": false})
				cajas = []
			# LA BOLA DEL ESCARABAJO: en todos los que atraviesa, cuando les pasa por encima (el primero entero, los demas a
			# area_secundario, como el peso del juego).
			if modo_i == InsectoAire.Modo.ARROLLA:
				for i in cajas.size():
					var ra2: Rect2 = cajas[i]
					piezas.append({"n": InsectoAire.sobre_cuerpo(self, modo_i, bulto.get_center(), ra2, semilla + i, 0.0, 1.0,
						bulto.size.x, 1.0 if i == 0 else ab.area_secundario),
						"t0": SueloRoto.retraso(f, _pies_caja(ra2), ab.suelo_roto), "sim": false})
				cajas = []
			# LA DOBLE GUADAÑA: a cada uno, una hoja por cada mitad del cono en la que este (como
			# CombatTactico.mitades_que_toca), la izquierda primero y la derecha 0,075 s despues (dos tandas de magia).
			if modo_i == InsectoAire.Modo.GUADANA:
				for i in cajas.size():
					var rm: Rect2 = cajas[i]
					for k in 2:
						var giro: float = deg_to_rad(f.apertura * 0.25) * (-1.0 if k == 0 else 1.0)
						if not CombatFormas.cono(f.origen, f.dir.rotated(giro), f.radio, f.apertura * 0.5).toca(rm):
							continue
						piezas.append({"n": InsectoAire.sobre_cuerpo(self, modo_i, bulto.get_center(), rm, semilla + i * 5 + k,
							0.12, 1.0, bulto.size.x, 1.0, -1.0 if k == 0 else 1.0), "t0": 0.075 * float(k), "sim": false})
				cajas = []
			# EL CAPARAZON: el reflejo sobre el, con SU caja.
			if sobre_si:
				piezas.append({"n": InsectoAire.sobre_cuerpo(self, modo_i, bulto.get_center(), bulto, semilla, 0.0, 1.0,
					bulto.size.x), "t0": 0.0, "sim": false})
			# EL CHARCO que se queda (la Savia): aparece cuando cae el goteron.
			if ab.charco_turnos > 0 and ab.charco_estilo == 1:
				piezas.append({"n": InsectoAire.red(self, f, semilla, 0.0), "t0": InsectoAire.T_TELA_CAE, "sim": false})
			elif ab.charco_turnos > 0 and ab.charco_estilo == 2:
				piezas.append({"n": SimaAire.nube(self, f, semilla, 0.0), "t0": 0.0, "sim": false})
			elif ab.charco_turnos > 0:
				piezas.append({"n": BestiaAire.charco(self, f, semilla, 0.0), "t0": BestiaAire.T_SAVIA_CAE, "sim": false})
			# LAS HEBRAS de la Telaraña: en todos los que pilla, al caer.
			if modo_i == InsectoAire.Modo.HEBRAS:
				for i in cajas.size():
					piezas.append({"n": InsectoAire.sobre_cuerpo(self, modo_i, bulto.get_center(), cajas[i], semilla + i, 0.0,
						1.0, bulto.size.x), "t0": SueloRoto.retraso(f, _pies_caja(cajas[i]), ab.suelo_roto), "sim": false})
				cajas = []
			# LAS RAICES QUE ATAN, en cada uno de los que pillan, cuando salen del todo.
			if ab.suelo_roto == SueloRoto.Tipo.BESTIA_RAICES:
				for i in cajas.size():
					var ra: Rect2 = cajas[i]
					piezas.append({"n": BestiaAire.atado(self, ra, _pies_caja(ra), semilla + i), "t0": BestiaAire.T_RAICES,
						"sim": false})
			# LOS PEGOTES del Ramazo: en todos los que pilla, en cada pasada.
			if modo_b == BestiaAire.Modo.PEGOTE:
				for g2 in maxi(ab.golpes_max, 1):
					for i in cajas.size():
						piezas.append({"n": BestiaAire.sobre_cuerpo(self, modo_b, bulto.get_center(), cajas[i], semilla + i * 7 + g2,
							0.0, 1.0, bulto.size.x), "t0": float(g2) * BestiaAire.T_RAMA_ENTRE, "sim": false})
				cajas = []
			# LA TOS de la Bocanada: en todos los de dentro a la vez.
			if modo_s in [SimaAire.Modo.TOS, SimaAire.Modo.POLVO]:
				for i in cajas.size():
					piezas.append({"n": SimaAire.sobre_cuerpo(self, modo_s, bulto, cajas[i], _pies_caja(cajas[i]),
						ed.color_visual(0.5), semilla + i, 0.0, 1.0), "t0": 0.0, "sim": false})
				cajas = []
			# LA MIRADA: el ojo en TODOS los que pilla el cono, cuando les llega.
			if modo_f == FieraAire.Modo.MIRADA:
				for i in cajas.size():
					var rmi: Rect2 = cajas[i]
					var fig_m: ColorRect = null
					for fg in _figs + presas_extra:
						if rmi.has_point((fg as ColorRect).position + Vector2(7, 13)):
							fig_m = fg
					piezas.append({"n": FieraAire.sobre_cuerpo(self, modo_f, bulto.get_center(), rmi, semilla + i, 0.0, 1.0,
						bulto.size.x, ed.color_visual(0.5), 0.0, fig_m), "t0": SueloRoto.retraso(f, _pies_caja(rmi), ab.suelo_roto),
						"sim": false})
				cajas = []
			# Solo suelo (el Pisoton): nada en los cuerpos.
			if modo_b < 0 and modo_i < 0 and modo_s < 0 and modo_f < 0:
				cajas = []
			var vuelo: float = 0.08 if modo_b == BestiaAire.Modo.FRENESI else (0.18 if modo_b in [BestiaAire.Modo.DENTELLADA,
				BestiaAire.Modo.CORNADA] else (0.12 if modo_b == BestiaAire.Modo.COLMILLO else 0.14))
			if modo_b == BestiaAire.Modo.RAMALAZO:
				vuelo = 0.3
			var golpes: int = maxi(ab.golpes_max, 1)
			for g in golpes:
				if cajas.is_empty():
					break
				var rg: Rect2 = cajas[g % cajas.size()]
				var t0: float = (0.12 * float(g) + 0.08) if modo_b == BestiaAire.Modo.FRENESI \
					else (0.26 if modo_b == BestiaAire.Modo.DENTELLADA else 0.22) * float(g)
				# La Yugular muerde al llegar (lo que tarda la estela hasta el).
				if ab.suelo_roto >= 0 and not ab.salta:
					t0 += SueloRoto.retraso(f, _pies_caja(rg), ab.suelo_roto)
				# Y nunca antes de llegar: en el juego se lanza primero (Desliz.ANTES) y muerde despues.
				if fin_carga != Vector2.INF and not ab.recorre:
					t0 = maxf(t0, BestiaAire.T_ESTELA)
				# La Cornada levanta a su figura (la del anillo, o la presa puesta dentro del cono).
				var fig_g: ColorRect = null
				if modo_b == BestiaAire.Modo.CORNADA:
					for fg in _figs + presas_extra:
						if rg.has_point((fg as ColorRect).position + Vector2(7, 13)):
							fig_g = fg
				if modo_f == FieraAire.Modo.PLACA:
					# El caparazon: el destello va SOBRE ELLA, desde la figura que le pega de frente.
					piezas.append({"n": FieraAire.sobre_cuerpo(self, modo_f, rg.get_center(), bulto, semilla, 0.0, 1.0, -1.0,
						ed.color_visual(0.5)), "t0": 0.0, "sim": false})
					break
				if modo_f == FieraAire.Modo.PUSTULAS:
					piezas.append({"n": FieraAire.sobre_cuerpo(self, modo_f, bulto.get_center(), bulto, semilla, 0.0, 1.0, -1.0,
						ed.color_visual(0.5)), "t0": 0.0, "sim": false})
					break
				if modo_f == FieraAire.Modo.GRIETAS:
					piezas.append({"n": FieraAire.grietas(self, bulto, semilla), "t0": 0.0, "sim": false})
					break
				if modo_f == FieraAire.Modo.VAHO:
					# El olor a sangre: el vaho sobre la figura que sangra.
					piezas.append({"n": FieraAire.vaho(self, rg, semilla), "t0": 0.0, "sim": false})
					break
				if modo_f >= 0:
					# La acorazada: el testarazo, y la garra (el primer golpe por un lado y el segundo por el otro).
					# El acechador: las fauces; la Yugular sale al despegar (desde donde salta, con el arco) y la
					# Dentellada arrastra a su figura.
					var espera_f: float = 0.0
					match modo_f:
						FieraAire.Modo.ZARPA: espera_f = 0.1
						FieraAire.Modo.FAUCES: espera_f = 0.14
						FieraAire.Modo.DENTELLADA: espera_f = 0.18
						FieraAire.Modo.YUGULAR: espera_f = _TACTICO.T_SALTO_BICHO
						FieraAire.Modo.TENTACULO: espera_f = 0.16
					var desde_f: Vector2 = bulto0.get_center() if modo_f == FieraAire.Modo.YUGULAR else bulto.get_center()
					var fig_f: ColorRect = null
					if modo_f == FieraAire.Modo.DENTELLADA:
						for fg in _figs + presas_extra + ([fig_presa] if fig_presa != null else []):
							if rg.has_point((fg as ColorRect).position + Vector2(7, 13)):
								fig_f = fg
					piezas.append({"n": FieraAire.sobre_cuerpo(self, modo_f, desde_f, rg, semilla + g,
						espera_f, 1.0, bulto.size.x, ed.color_visual(0.5),
						(-1.0 if g % 2 == 0 else 1.0) if modo_f == FieraAire.Modo.ZARPA
							else ([-1.0, 1.0, 0.01][g % 3] if modo_f == FieraAire.Modo.TENTACULO else 0.0), fig_f, arco_salto),
						"t0": t0, "sim": false})
					# LA SANGRE del acechador (en el juego, solo si entra): el chorro del cuello y el jiron hacia el.
					if modo_f in [FieraAire.Modo.YUGULAR, FieraAire.Modo.DENTELLADA]:
						var antes_f: int = get_child_count()
						var desde_sf: Vector2 = rg.get_center()
						var hacia_sf: Vector2 = rg.get_center() - bulto.get_center()
						var fuerza_f: float = 0.7
						if modo_f == FieraAire.Modo.YUGULAR:
							desde_sf = Vector2(rg.get_center().x, rg.position.y + rg.size.y * 0.28)
							fuerza_f = 1.4
						else:
							hacia_sf = -hacia_sf
						SangreMapa.salpicar(self, desde_sf, _pies_caja(rg), hacia_sf, fuerza_f, semilla + g)
						for i in range(antes_f, get_child_count()):
							piezas.append({"n": get_child(i), "t0": t0, "sim": true})
					continue
				if modo_s >= 0:
					# El porrazo del miconido, y su latigo (que sale de su mano y, si enraiza, se queda atado).
					var vuelo_s: float = SimaAire.T_LATIGO_VA if modo_s == SimaAire.Modo.LATIGO else 0.0
					piezas.append({"n": SimaAire.sobre_cuerpo(self, modo_s, bulto, rg, _pies_caja(rg), ed.color_visual(0.5),
						semilla + g, vuelo_s, 1.0, yo + cuerpo.position), "t0": t0, "sim": false})
					if modo_s == SimaAire.Modo.LATIGO:
						piezas.append({"n": SimaAire.atado(self, rg, _pies_caja(rg), ed.color_visual(0.5), semilla + g),
							"t0": t0 + 0.1, "sim": false})
					continue
				if modo_i >= 0:
					# Los colmillos de la araña, y el veneno que salta (en el juego, solo si entra).
					# El tajo de la segadora sale del brazo de 'basico' (el izquierdo; 'basico_der' es el otro).
					piezas.append({"n": InsectoAire.sobre_cuerpo(self, modo_i, bulto.get_center(), rg, semilla + g, 0.14, 1.0,
						bulto.size.x, 1.0, -1.0 if modo_i == InsectoAire.Modo.TAJO else 1.0), "t0": t0, "sim": false})
					if modo_i in [InsectoAire.Modo.PONZONA, InsectoAire.Modo.FORCIPULAS]:
						piezas.append({"n": InsectoAire.sobre_cuerpo(self, InsectoAire.Modo.VENENO, bulto.get_center(), rg,
							semilla + g * 3, 0.0, 1.0), "t0": t0, "sim": false})
					continue
				piezas.append({"n": BestiaAire.sobre_cuerpo(self, modo_b, bulto.get_center(), rg, semilla + g, vuelo, 1.0, bulto.size.x,
					fig_g), "t0": t0, "sim": false})
				# LA SANGRE (solo las que la echan): como en el juego, desde el cuerpo hacia donde tira quien muerde.
				if modo_b in [BestiaAire.Modo.MORDISCO_SANGRA, BestiaAire.Modo.FRENESI, BestiaAire.Modo.DENTELLADA,
						BestiaAire.Modo.YUGULAR]:
					var antes_s: int = get_child_count()
					var desde_s: Vector2 = rg.get_center()
					var fuerza_s: float = 0.4
					match modo_b:
						BestiaAire.Modo.MORDISCO_SANGRA: fuerza_s = 0.7
						BestiaAire.Modo.DENTELLADA: fuerza_s = 0.6
						BestiaAire.Modo.YUGULAR:
							fuerza_s = 1.4
							desde_s = Vector2(rg.get_center().x, rg.position.y + rg.size.y * 0.28)
					SangreMapa.salpicar(self, desde_s, _pies_caja(rg), rg.get_center() - bulto.get_center(),
						fuerza_s, semilla + g)
					for i in range(antes_s, get_child_count()):
						piezas.append({"n": get_child(i), "t0": t0, "sim": true})
			for pz in piezas:
				if pz["n"] != null:
					(pz["n"] as Node).set_process(false)
			for c in tiempos.size():
				var t: float = float(tiempos[c])
				# El salto a la yugular: por su arco, y al caer se queda pegado.
				if fin_salto != Vector2.INF:
					var us: float = clampf((t + _TACTICO.T_SALTO_BICHO) / _TACTICO.T_SALTO_BICHO, 0.0, 1.0)
					cuerpo.position = (fin_salto - yo) * us - Vector2(0.0, arco_salto * 4.0 * us * (1.0 - us))
				# La carga: el cuerpo va por la linea con la estela y llega en T_ESTELA (la bola, en T_RODADA).
				if fin_carga != Vector2.INF:
					var t_viaje: float = InsectoAire.T_RODADA if ab.atraviesa else (InsectoAire.T_OLEADA if ab.recorre else BestiaAire.T_ESTELA)
					cuerpo.position = (fin_carga - yo) * clampf(t / t_viaje, 0.0, 1.0)
				# Y su animacion, en el fotograma de este momento.
				var an_n := StringName("%s_%d" % [anim_hab, d8])
				if anim_hab != "" and spr.sprite_frames.has_animation(an_n):
					var fps_a: float = spr.sprite_frames.get_animation_speed(an_n)
					var desde_a: float = t + float(CombatFX.IMPACTO_ANIM_MAPA.get(anim_hab, CombatFX.T_ANIM_ADELANTO))
					spr.animation = an_n
					spr.frame = clampi(int(floor(desde_a * fps_a)), 0, spr.sprite_frames.get_frame_count(an_n) - 1)
				for pz in piezas:
					var n: Node2D = pz["n"]
					if n == null or not is_instance_valid(n):
						continue
					if bool(pz["sim"]):
						# La sangre se simula (va por fisica): se le da cuerda hasta este momento.
						var objetivo: float = t - float(pz["t0"])
						while float(n.get("_t")) < objetivo and is_instance_valid(n):
							n._process(1.0 / 120.0)
						n.visible = objetivo >= 0.0
						continue
					n.set("_t", t - float(pz["t0"]))
					if n.has_method("aplicar_temblor"):
						n.call("aplicar_temblor")
					n.queue_redraw()
					for hijo in ["_suelo", "_delante", "_brillo"]:
						var su = n.get(hijo)
						if su is Node2D:
							(su as Node2D).queue_redraw()
				await _viñeta(hoja, c + 1, fila, "%s · %s · %s · %.2f s" % [ed.enemy_name, ab.nombre, dir_n, t])
			if fig_presa != null:
				fig_presa.queue_free()
			for fp in presas_extra:
				(fp as Node).queue_free()
			for pz in piezas:
				if pz["n"] != null and is_instance_valid(pz["n"]):
					(pz["n"] as Node).queue_free()
			await get_tree().process_frame
		var carpeta: String = "%s/enemigos/%s" % [salida, bestia]
		DirAccess.make_dir_recursive_absolute(carpeta)
		var ruta: String = "%s/%s.png" % [carpeta, nom]
		hoja.save_png(ruta)
		print("[hoja] ", ruta)
		# LA TELARAÑA TURNO A TURNO (29/09): recien tendida, a 2/3, a 1/3 y secandose.
		if ab.charco_estilo == 1 and ab.charco_turnos > 0:
			var f_r = CombatFormas.circulo(Vector2(0, 30), ab.forma_radio)
			var zoom_r: float = float(LADO) / (2.0 * (ab.forma_radio + 20.0))
			_cam.zoom = Vector2(zoom_r, zoom_r)
			_cam.global_position = f_r.centro
			cuerpo.visible = false
			var hoja_r := Image.create(LADO * 4, LADO, false, Image.FORMAT_RGBA8)
			var textos: Array = ["recien tendida", "le quedan 2 turnos", "le queda 1 turno", "se deshace"]
			var quedas: Array = [1.0, 2.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0]
			for c2 in 4:
				var red_n: InsectoAire = InsectoAire.red(self, f_r, 4242, 0.0)
				red_n.set_process(false)
				red_n.queda = quedas[c2]
				red_n._t = 1.0
				if c2 == 3:
					red_n._secando = 0.75
				for hijo in ["_suelo", "_delante", "_brillo"]:
					var su = red_n.get(hijo)
					if su is Node2D:
						(su as Node2D).queue_redraw()
				await _viñeta(hoja_r, c2, 0, "%s · %s · %s" % [ed.enemy_name, ab.nombre, textos[c2]])
				red_n.queue_free()
			cuerpo.visible = true
			var ruta_r: String = "%s/%s_turnos.png" % [carpeta, nom]
			hoja_r.save_png(ruta_r)
			print("[hoja] ", ruta_r)
	cuerpo.queue_free()
	await get_tree().process_frame

