# ============================================================
#  dev_gestos.gd  -- EL VISOR DE GESTOS
#  Lanza todos los dibujos de ataque del jugador en bucle, EN MOVIMIENTO, cada repeticion sobre un
#  muñeco distinto, para poder mirarlos de verdad en vez de en capturas sueltas.
#
#  Se lanza con:
#    Godot_v4.7-stable_win64.exe --path . res://dev_gestos.tscn
#
#  TECLAS
#    ESPACIO / →   siguiente gesto            ←   el anterior
#    1..5          imbuicion (acero, veneno, fuego, agua, rayo)
#    P             parar / seguir el bucle
#    R             repetir el gesto AHORA
#    + / -         mas lento / mas rapido
#    F12           guarda una captura en user://capturas
# ============================================================

extends Node2D

const MUÑECOS := 4      # los enemigos, arriba
const MIOS := 4         # tu fila, abajo: el que ataca (el 0) y tres compañeros
const CADA := 1.15          # segundos entre repeticiones
const REPETICIONES := 3     # veces que se ve cada gesto antes de pasar al siguiente

# Todos los del jugador: arma, estilo y LA HABILIDAD de la que sale ("" si es el golpe basico del
# arma). El .tres es el que manda cuantos golpes pega y cual de ellos es de escudo -- asi el visor
# enseña una Rafaga de DOS tajos y una Guardia rota de tajo + escudazo, como en la pelea, en vez de
# un golpe suelto por gesto.
const GESTOS := [
	["daga", "DAGA_CORTE", ""], ["daga", "DAGA_RAFAGA", "rafaga"],
	["daga", "PUNALADA", "punalada"], ["daga", "IMBUIR_FILO", "filo_emponzonado"],
	["daga", "DESVANECER", "desaparecer"],
	["estoque", "ESTOQUE_PUNZADA", ""], ["estoque", "ESTOCADA_PENETRANTE", "estocada_penetrante"],
	["estoque", "FINTAS", "fintas"], ["estoque", "EN_GUARDIA", "en_guardia"],
	["estoque", "PASO_LIGERO", "paso_ligero"], ["estoque", "PUNZADA_NERVIO", "punzada_al_nervio"],
	["estoque", "DANZA_ACERO", "danza_de_acero"],
	["espada corta", "ESPADA_TAJO", ""], ["espada corta", "TAJO_QUEBRANTADOR", "tajo_quebrantador"],
	["espada corta", "DOBLE_TAJO", "doble_tajo"], ["espada corta", "CAMBIO_RITMO", "cambio_de_ritmo"],
	["espada corta", "SENALAR_HUECO", "senalar_el_hueco"],
	["espada corta", "CORTE_TENDONES", "corte_de_tendones"],
	["espada larga", "ESPADA_LARGA_TAJO", ""], ["espada larga", "TAJO_PESADO", "tajo_pesado"],
	["espada larga", "TAJO_DESARMANTE", "tajo_desarmante"],
	["espada larga", "GUARDIA_ROTA", "guardia_rota"],
	["espada larga", "VOTO_GUARDIA", "voto_de_guardia"],
	["espada larga", "ESTOCADA_MARCIAL", "estocada_marcial"],
	["espada larga", "VOZ_MANDO", "voz_de_mando"], ["escudo", "ESCUDAZO", "golpe_escudo_normal"],
	["mandobles", "MANDOBLE_TAJO", ""], ["mandobles", "TAJO_DEVASTADOR", "tajo_devastador"],
	["mandobles", "MOLINETE", "molinete"], ["mandobles", "GRITO_GUERRA", "grito_de_guerra"],
	["mandobles", "TAJO_VERDUGO", "tajo_del_verdugo"], ["mandobles", "SEGAR", "segar"],
	["maza pequeña", "MAZA_GOLPE", ""],
	["maza pequeña", "GOLPE_DEMOLEDOR", "golpe_demoledor"],
	["maza pequeña", "ROMPEPIERNAS", "rompepiernas"],
	["maza pequeña", "APLASTAMIENTO", "aplastamiento"],
	["maza pequeña", "CULATAZO", "culatazo"],
	["maza pequeña", "GRITO_ALIENTO", "grito_de_aliento"],
	["maza pequeña", "MURO_ALIADOS", "muro_de_aliados"],
	["hacha grande", "HACHA_TAJO", ""],
	["hacha grande", "HENDEDURA", "hendedura"],
	["hacha grande", "HACHAZO_BRUTAL", "hachazo_brutal"],
	["hacha grande", "CARNICERIA", "carniceria"],
	["hacha grande", "DESGARRO", "desgarro"],
	["hacha grande", "SED_SANGRE", "sed_de_sangre"],
	["martillo grande", "MARTILLO_GOLPE", ""],
	["martillo grande", "GOLPE_SISMICO", "golpe_sismico"],
	["martillo grande", "ONDA_EXPANSIVA", "onda_expansiva"],
	["martillo grande", "TEMBLOR_SUELO", "temblor"],
	["martillo grande", "ROMPECORAZAS", "rompecorazas"],
	["martillo grande", "MARTILLO_GUERRA", "martillo_de_guerra"],
	["baston", "BASTON_GOLPE", ""],
	["baston", "BASTONAZO", "bastonazo"],
	["baston", "FOCO_ARCANO", "canalizar"],
	["baston", "SELLO_ARCANO", "sello_arcano"],
	["baston", "VELO_UMBRIO", "velo_umbrio"],
	["baston", "VIENTO_LIMPIO", "viento_limpio"],
	["punos", "PUNOS_GOLPE", ""],
	["escudo", "EMBESTIDA_ESCUDO", "embestida"],
	["escudo", "PROVOCACION_FX", "provocacion"],
	["escudo", "GUARDIA_CARNE_FX", "guardia_de_carne"],
	["escudo", "COBERTURA", "cobertura"],
	["varita", "FOCO_ARCANO", "canalizar_varita"],
	["varita", "PURIFICAR", "purificar"],
	["varita", "CHISPA_VINCULADA", "chispa_vinculada"],
	["varita", "EGIDA_MENOR", "egida_menor"],
]
# Lo que tarda un golpe en seguir al anterior dentro de la misma habilidad (CombatFX.T_ENCADENADO).
const ENTRE_GOLPES := 0.20
# Los que alcanzan a VARIOS: se lanzan contra toda la fila a la vez.
const DE_GRUPO := ["MOLINETE", "GRITO_GUERRA", "SEGAR",
	# Las tres del martillo que sacuden el suelo: un terremoto es UNO y coge a los que coge.
	"GOLPE_SISMICO", "ONDA_EXPANSIVA", "TEMBLOR_SUELO"]
# Los que NO pegan y se pintan sobre uno mismo: van sobre el muñeco de abajo (el que ataca). Las
# que SI pegan y ademas se echan algo encima (Desaparecer, Voto de guardia) no van aqui: eso sale
# de su fx_sobre_mi, y el visor pinta las dos mitades.
const SOBRE_MI := ["IMBUIR_FILO", "EN_GUARDIA", "DESVANECER", "VOTO_GUARDIA",
	"FOCO_ARCANO", "VELO_UMBRIO", "PROVOCACION_FX", "GUARDIA_CARNE_FX"]
# LOS QUE SE ECHAN A LOS TUYOS. No van contra nadie: se pintan una vez SOBRE CADA ALIADO (en la
# pelea salen de _fx_adorno recorriendo _objetivos_area_aliados, que es TU fila). Aqui se sueltan
# sobre los cuatro de ABAJO a la vez -- con uno solo no se entiende que es de grupo, y sobre los de
# arriba se entenderia lo contrario de lo que hacen.
#
# La VOZ DE MANDO estaba en SOBRE_MI y estaba MAL: se pintaba sobre el que ataca cuando en combate
# va sobre los suyos. Se veia bien igual (es la misma forma) pero en el sitio equivocado.
const A_LOS_MIOS := ["VOZ_MANDO", "GRITO_ALIENTO", "MURO_ALIADOS", "VIENTO_LIMPIO",
	"COBERTURA"]
# Y estos van a UN SOLO compañero (objetivo_aliado = 1), no a todos: se sueltan sobre el segundo de
# tu fila, que es un compañero y no el que lanza.
const A_UN_MIO := ["PURIFICAR", "CHISPA_VINCULADA", "EGIDA_MENOR"]

var _capa: CapaHechizos
var _titulo: Label
var _sfx_txt: Label   # que fichero de sonido suena (ver Sonido.info)
var _ayuda: Label
var _tarjetas: Array = []   # los enemigos
var _mios: Array = []       # los tuyos
var _yo: ColorRect
var _idx := 0
var _rep := 0
var _turno := 0            # a que muñeco le toca
# NUMERO DE SERIE del lanzamiento en curso: sube uno en cada _lanzar. Una tanda de varios golpes se
# guarda el suyo en una LOCAL y lo compara antes de cada golpe, asi que si mientras espera entre
# golpes se lanza otra cosa, la tanda vieja se corta sola.
#
# Antes esto comparaba el INDICE del gesto contra un campo que el nuevo lanzamiento acababa de
# reescribir, o sea que los dos veian lo mismo y NO cortaba nada: se colaba un golpe del gesto
# anterior encima del que acababas de pedir.
var _serie := 0
var _golpe := 0            # que golpe de la habilidad se esta soltando (lo mira el Doble tajo)
var _reloj := 0.0
var _auto := true
var _vel := 1.0
var _imb := 0

var _colores: Array = []
var _nombres_col := ["acero", "veneno", "fuego", "agua", "rayo"]
# El elemento de cada una: el color dice el tono, el elemento dice COMO se comporta el dibujo.
var _elems: Array = []


func _ready() -> void:
	_colores = [CombatFX.ACERO, StatusEffects.def(StatusEffects.Id.VENENO)["color"],
		Elementos.color(Elementos.Elemento.FUEGO), Elementos.color(Elementos.Elemento.AGUA),
		Elementos.color(Elementos.Elemento.RAYO)]
	_elems = [Elementos.Elemento.NINGUNO, Elementos.Elemento.NINGUNO, Elementos.Elemento.FUEGO,
		Elementos.Elemento.AGUA, Elementos.Elemento.RAYO]
	# Tamaño explicito: colgando de un Node2D, el preset de anclas no estira nada y se quedaba
	# viendose el gris por defecto de Godot.
	var fondo := ColorRect.new()
	fondo.size = Vector2(1280, 720)
	fondo.color = Color(0.11, 0.12, 0.15)
	add_child(fondo)
	# La fila de muñecos, con su numero.
	for i in MUÑECOS:
		var tj := ColorRect.new()
		tj.size = Vector2(120, 160)
		tj.position = Vector2(190 + i * 240, 200)
		tj.color = Color(0.22, 0.24, 0.30)
		add_child(tj)
		_tarjetas.append(tj)
	# TU FILA, abajo: el que ataca y sus compañeros. Los compañeros no estaban y hacian falta -- los
	# buffs de grupo (Voz de mando, Grito de aliento, Muro de aliados) van sobre LOS TUYOS, y sin fila
	# propia el visor los soltaba sobre los muñecos de arriba, o sea sobre los ENEMIGOS. En la pelea
	# van bien (combat.gd los reparte con _objetivos_area_aliados, que recorre _aliados); era el visor
	# el que los enseñaba en el sitio equivocado.
	for i in MIOS:
		var mio := ColorRect.new()
		mio.size = Vector2(120, 130)
		mio.position = Vector2(370 + i * 140, 520)
		# El primero es el que ataca y va mas claro: tiene que distinguirse de sus compañeros para
		# poder leer los que se echa encima el (fx_sobre_mi) frente a los que reparte.
		mio.color = Color(0.26, 0.34, 0.28) if i == 0 else Color(0.20, 0.25, 0.23)
		add_child(mio)
		_mios.append(mio)
	_yo = _mios[0]
	_capa = CapaHechizos.new()
	_capa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_capa)
	_titulo = Label.new()
	_titulo.position = Vector2(24, 24)
	_titulo.add_theme_font_size_override("font_size", 30)
	_titulo.add_theme_color_override("font_color", Color(0.95, 0.92, 0.84))
	add_child(_titulo)
	_sfx_txt = Label.new()
	_sfx_txt.position = Vector2(24, 62)
	_sfx_txt.add_theme_font_size_override("font_size", 15)
	_sfx_txt.add_theme_color_override("font_color", Color(0.87, 0.72, 0.40))
	add_child(_sfx_txt)
	_ayuda = Label.new()
	_ayuda.position = Vector2(24, 668)
	_ayuda.add_theme_font_size_override("font_size", 15)
	_ayuda.add_theme_color_override("font_color", Color(0.55, 0.58, 0.66))
	_ayuda.text = "ESPACIO/→ siguiente   ← anterior   1-5 imbuición   P pausa   R repetir   +/- velocidad"
	add_child(_ayuda)
	_lanzar()
	if "--foto" in OS.get_cmdline_user_args():
		await _tanda_de_fotos()


# Modo comprobacion: dispara unos cuantos gestos y guarda una foto de cada uno, sin tocar teclas.
func _tanda_de_fotos() -> void:
	DirAccess.make_dir_recursive_absolute("user://capturas")
	_auto = false
	for nombre in ["DANZA_ACERO", "FINTAS", "MOLINETE", "SENALAR_HUECO", "TAJO_VERDUGO"]:
		for i in GESTOS.size():
			if String(GESTOS[i][1]) == nombre:
				_idx = i
				break
		_imb = 0
		_turno = 0
		_lanzar()
		await get_tree().create_timer(0.62).timeout
		var img2: Image = get_viewport().get_texture().get_image()
		img2.save_png("user://capturas/hab_%s.png" % nombre.to_lower())
		print("[visor] hab_%s" % nombre.to_lower())
		# POR TIEMPO, no por frames: sin vsync esto corre a cientos de fps y "esperar 22 frames" eran
		# 40 ms -- el Tajo del verdugo, que tarda 0.30 s solo en empezar, salia en una foto vacia.
		var est2: int = int(CombatFX.Estilo[nombre])
		var vida: float = float(CombatFX.T_VUELO.get(est2, 0.1)) + 0.35
		await get_tree().create_timer(vida).timeout
		_foto()
	get_tree().quit()


func _process(delta: float) -> void:
	_reloj += delta * _vel
	if _auto and _reloj >= CADA:
		_reloj = 0.0
		_rep += 1
		if _rep >= REPETICIONES:
			_rep = 0
			_idx = (_idx + 1) % GESTOS.size()
		_lanzar()


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo):
		return
	var k: int = (ev as InputEventKey).keycode
	if k == KEY_SPACE or k == KEY_RIGHT:
		_idx = (_idx + 1) % GESTOS.size()
		_rep = 0
		_reloj = 0.0
		_lanzar()
	elif k == KEY_LEFT:
		_idx = (_idx - 1 + GESTOS.size()) % GESTOS.size()
		_rep = 0
		_reloj = 0.0
		_lanzar()
	elif k == KEY_R:
		_reloj = 0.0
		_lanzar()
	elif k == KEY_P:
		_auto = not _auto
	elif k >= KEY_1 and k <= KEY_5:
		_imb = k - KEY_1
		_lanzar()
	elif k == KEY_EQUAL or k == KEY_KP_ADD:
		_vel = minf(_vel * 1.35, 4.0)
	elif k == KEY_MINUS or k == KEY_KP_SUBTRACT:
		_vel = maxf(_vel / 1.35, 0.15)
	elif k == KEY_F12:
		_foto()
	elif k == KEY_ESCAPE:
		get_tree().quit()


func _foto() -> void:
	DirAccess.make_dir_recursive_absolute("user://capturas")
	var img: Image = get_viewport().get_texture().get_image()
	var f: String = "user://capturas/visor_%s.png" % String(GESTOS[_idx][1]).to_lower()
	img.save_png(f)
	print("[visor] ", ProjectSettings.globalize_path(f))


func _lanzar() -> void:
	var arma: String = String(GESTOS[_idx][0])
	var nombre: String = String(GESTOS[_idx][1])
	var est: int = int(CombatFX.Estilo[nombre])
	# CUANTOS GOLPES PEGA DE VERDAD, sacados de su .tres. Una Rafaga son dos tajos y una Danza tres:
	# enseñar uno solo no dice como se ve la habilidad.
	var ab: AbilityData = null
	var golpes: int = 1
	var est_sobre_mi: int = -1
	if String(GESTOS[_idx][2]) != "":
		ab = load("res://resources/abilities/%s.tres" % String(GESTOS[_idx][2]))
		if ab != null:
			if ab.dano_mult > 0.0:
				golpes = maxi(1, ab.golpes_min)
				# El estilo del GOLPE sale de la habilidad, no de la lista de aqui arriba: hay
				# habilidades que pegan con un gesto y ademas se echan OTRO encima.
				if ab.fx_estilo >= 0:
					est = ab.fx_estilo
			# Y lo que se echa encima el que ataca, que se pinta sobre SU tarjeta.
			est_sobre_mi = ab.fx_sobre_mi
	_titulo.text = "%s  ·  %s        [%s]   %d golpe%s   %d/%d      x%.2f%s" % [arma,
		nombre.to_lower(), _nombres_col[_imb], golpes, "" if golpes == 1 else "s",
		_rep + 1, REPETICIONES, _vel, "" if _auto else "   (PAUSA)"]
	# QUE FICHERO SUENA, escrito en pantalla. Oir que algo suena mal no sirve de nada si luego hay
	# que adivinar cual de los 154 ficheros hay que retocar.
	_sfx_txt.text = "🔊 " + Sonido.info("", est)
	_capa.escala_tiempo = 1.0
	_capa.limpiar()
	_serie += 1
	var serie: int = _serie
	# El objetivo se elige UNA vez por ejecucion: los golpes de una misma habilidad caen sobre el
	# mismo, como en la pelea. Lo que cambia de muñeco es cada REPETICION.
	_turno = (_turno + 1) % MUÑECOS
	for i in golpes:
		if i > 0:
			await get_tree().create_timer(ENTRE_GOLPES / maxf(_vel, 0.1)).timeout
			if serie != _serie:
				return   # han pedido otra cosa a mitad: esta tanda ya no toca
		# El golpe que la habilidad marca como de escudo se ve como un escudazo, igual que en combate.
		var est_i: int = est
		if ab != null and ab.golpe_es_de_escudo(i):
			est_i = CombatFX.Estilo.ESCUDAZO
		_golpe = i
		_soltar(est_i, String(CombatFX.Estilo.keys()[est_i]))
	# LO QUE SE ECHA ENCIMA EL QUE ATACA, despues del golpe. Desaparecer es el ejemplo: el tajo va
	# contra el enemigo y el humo sale en TU tarjeta, no en la suya. Sin esto, el visor enseñaba solo
	# una de las dos mitades y parecia que la habilidad estuviera mal montada.
	if est_sobre_mi >= 0:
		var origen2: Vector2 = _yo.position + _yo.size * 0.5
		_capa.alta(est_sobre_mi, origen2, origen2, _colores[_imb], 1.0,
			float(CombatFX.T_VUELO.get(est_sobre_mi, 0.1)), 140.0, _elems[_imb])


# Un golpe suelto, ya con el objetivo elegido.
func _soltar(est: int, nombre: String) -> void:
	# EL SONIDO, para poder juzgarlo aqui igual que se juzga el dibujo. Va con el elemento de la
	# imbuicion elegida (teclas 1-5), asi que tambien se oye la capa de fuego / agua / rayo encima.
	Sonido.golpe("", est, 1.0, false, _elems[_imb])
	var col: Color = _colores[_imb]
	var dur: float = float(CombatFX.T_VUELO.get(est, 0.1))
	var origen: Vector2 = _yo.position + _yo.size * 0.5
	if SOBRE_MI.has(nombre):
		# Va sobre el que ataca: nace y muere en su propia tarjeta.
		_capa.alta(est, origen, origen, col, 1.0, dur, 140.0, _elems[_imb], _golpe)
		return
	if A_UN_MIO.has(nombre):
		# La CHISPA es la unica que VIAJA: necesita el punto de salida (tu) y el de llegada (el), asi
		# que aqui se le pasan los dos de verdad en vez de nacer sobre la tarjeta de destino.
		var otro: ColorRect = _mios[1]
		_capa.alta(est, origen, otro.position + otro.size * 0.5, col, 1.0, dur, 120.0,
			_elems[_imb], _golpe)
		return
	if A_LOS_MIOS.has(nombre):
		# SOBRE LOS TUYOS, uno por compañero: van a TU fila (la de abajo), no a la de enfrente. Estaban
		# saliendo sobre los muñecos enemigos, que es justo lo contrario de lo que hacen.
		for mio in _mios:
			_capa.alta(est, origen, mio.position + mio.size * 0.5, col, 1.0, dur, 120.0,
				_elems[_imb], _golpe)
		return
	if DE_GRUPO.has(nombre):
		# A TODA la fila: el ancho del grupo es lo que hace que el efecto los cubra a todos.
		var izq: float = _tarjetas[0].position.x
		var der: float = _tarjetas[MUÑECOS - 1].position.x + 120.0
		var centro := Vector2((izq + der) * 0.5, _tarjetas[0].position.y + 80.0)
		_capa.alta(est, origen, centro, col, 1.0, dur, der - izq, _elems[_imb], _golpe)
		return
	var tj: ColorRect = _tarjetas[_turno]
	_capa.alta(est, origen, tj.position + tj.size * 0.5, col, 1.0, dur, 120.0, _elems[_imb], _golpe)
