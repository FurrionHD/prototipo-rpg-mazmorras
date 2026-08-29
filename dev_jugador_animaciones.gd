# ============================================================
#  dev_jugador_animaciones.gd  -- EL VISOR DE ANIMACIONES DEL JUGADOR
#  El hermano de dev_enemigos_animaciones.gd, pero para el muñeco del personaje. Escena VIVA (no una
#  captura que se cierra sola, como ver_jugador.bat / ver_jugador_juego.bat): se recorre la lista
#  entera de PoseJugador.ANIMS -- idle, sigilo, walk, correr, golpe, guardia*, desenvainar,
#  golpe_izq, golpe_2m, encaje, muerte, cadaver -- en las 8 direcciones, con el arma equipada que
#  se quiera y en dual.
#
#  Las variantes envainado / guardia / golpe / golpe_izq / golpe_2m / desenvainar NO son un mando
#  aparte: son entradas de PoseJugador.ANIMS y se recorren con ESPACIO. El "2 manos" tampoco es un
#  toggle -- es intrinseco al arma (mandoble, hacha, martillo, baston): al equipar una sale sola a
#  la espalda y con golpe_2m.
#
#  REUTILIZA MunecoJugador tal cual (las mismas capas horneadas y el mismo shader que el mapa) y
#  PoseJugador para el ritmo de cada animacion: si el visor tuviera su propia copia acabarian
#  divergiendo y estaria enseñando algo que jugando no se ve.
#
#  Se lanza con:
#    Godot_v4.7-stable_win64.exe --path . res://dev_jugador_animaciones.tscn
#  o doble clic en ver_jugador_animaciones.bat.
#
#  TECLAS
#    ESPACIO / →   siguiente animacion    ←   la anterior
#    A / D         girar la direccion (una de las 8)
#    B / V         siguiente / anterior ARMA equipada  (incluye "sin arma")
#    N             dual on/off  (segunda arma de una mano en la otra mano)
#    P             parar / seguir el avance de fotograma
#    , / .         fotograma anterior / siguiente (con la animacion en pausa)
#    +/-           mas lento / mas rapido
#    F12           guarda una captura en user://capturas
#    ESC           salir
# ============================================================

extends Node2D

const DIR_NOMBRES := ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]
const DIR_VECS := PoseJugador.DIR_VECS
const CENTRO := Vector2(640, 470)
const ESC := 6.5

var _muneco: MunecoJugador
var _titulo: Label
var _sub: Label
var _ayuda: Label
var _flecha: Line2D

# Cada arma: {nombre, res}. res == null es "sin arma" (puños).
var _armas: Array = []
var _arma_i := 0
var _dir := 0
var _anim_i := 0
var _vel := 1.0
var _auto := true
var _frame := 0
var _reloj := 0.0
var _dual := false


func _ready() -> void:
	_cargar_armas()

	var fondo := ColorRect.new()
	fondo.size = Vector2(1280, 720)
	fondo.color = Color(0.11, 0.12, 0.15)
	add_child(fondo)

	# Rejilla de suelo para que se lea el giro y el paso adelante de los golpes.
	var suelo := Line2D.new()
	suelo.width = 1.0
	suelo.default_color = Color(1, 1, 1, 0.08)
	suelo.points = PackedVector2Array([Vector2(340, CENTRO.y), Vector2(940, CENTRO.y)])
	add_child(suelo)

	_muneco = MunecoJugador.new()
	# El muñeco se dibuja a tamaño de mundo (60 u de alto); se amplia para verlo bien. Su nodo esta a
	# la altura de los PIES, asi que se planta en el suelo de la rejilla y el cuerpo queda por encima.
	_muneco.scale = Vector2.ONE * ESC
	_muneco.position = CENTRO
	add_child(_muneco)

	var pj: PersonajeData = Game.lider()
	_muneco.tenir(pj.color, 0.0)
	_muneco.poner_cara(pj.textura())

	_titulo = _label(Vector2(24, 20), 30, Color(0.95, 0.92, 0.84))
	_sub = _label(Vector2(24, 60), 17, Color(0.70, 0.74, 0.82))
	_ayuda = _label(Vector2(24, 690), 15, Color(0.55, 0.58, 0.66))
	_ayuda.text = "ESPACIO/→ animacion   ← anterior   A/D direccion   B/V arma   N dual   P pausa   ,/. fotograma   +/- velocidad"

	_flecha = Line2D.new()
	_flecha.width = 3.0
	_flecha.default_color = Color(1, 1, 1, 0.5)
	add_child(_flecha)

	_reequipar()
	_mostrar()

	# Modo comprobacion: sin tocar teclas, hace una foto de unas cuantas combinaciones y sale. Es
	# para verificar de un vistazo que el muñeco monta bien con arma; el uso normal es interactivo.
	if "--foto" in OS.get_cmdline_user_args():
		await _tanda_de_fotos()


func _tanda_de_fotos() -> void:
	DirAccess.make_dir_recursive_absolute("user://capturas")
	_auto = false
	# [arma, anim, dir, dual, frac_fotograma]. frac 0..1 sobre los marcos de la anim (el tajo cae
	# hacia 0.68).
	var casos := [
		["daga", "golpe_izq", 1, true, 0.7], ["daga", "golpe_izq", 2, true, 0.7],
		["daga", "golpe_izq", 6, true, 0.7], ["daga", "golpe_izq", 0, true, 0.7],
		["mandobles", "golpe_2m", 0, false, 0.68], ["mandobles", "golpe_2m", 2, false, 0.68],
		["mandobles", "golpe_2m", 4, false, 0.68], ["mandobles", "golpe_2m", 0, false, 0.4],
		["mandobles", "golpe_2m", 3, false, 0.68], ["mandobles", "golpe_2m", 4, false, 0.85],
		["hacha_grande", "golpe_2m", 2, false, 0.68], ["baston", "golpe_2m", 0, false, 0.68],
		["mandobles", "encaje", 4, false, 0.0], ["espada_larga", "encaje", 4, false, 0.0],
		["mandobles", "muerte", 4, false, 0.9], ["sin arma", "muerte", 4, false, 0.5],
		["espada_larga", "golpe", 2, false, 0.68], ["mandobles", "walk", 4, false, 0.5],
	]
	for c in casos:
		for i in _armas.size():
			if String(_armas[i]["nombre"]) == String(c[0]):
				_arma_i = i
				break
		for j in PoseJugador.ANIMS.size():
			if String(PoseJugador.ANIMS[j]["n"]) == String(c[1]):
				_anim_i = j
				break
		_dir = int(c[2])
		_dual = bool(c[3])
		var marcos: int = int(PoseJugador.ANIMS[_anim_i]["marcos"])
		_frame = clampi(int(round(float(c[4]) * (marcos - 1))), 0, marcos - 1)
		_reequipar()
		_mostrar()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		_foto()
	get_tree().quit()


func _label(pos: Vector2, tam: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", col)
	add_child(l)
	return l


# Lee todos los WeaponData / WandData de resources. Ordenados por nombre de archivo para que el
# recorrido con B/V sea siempre el mismo. El primero es "sin arma".
func _cargar_armas() -> void:
	_armas.append({"nombre": "sin arma", "res": null})
	for carpeta in ["res://resources/weapons/", "res://resources/wands/"]:
		var d := DirAccess.open(carpeta)
		if d == null:
			continue
		var archivos: Array = []
		for f in d.get_files():
			var n: String = f.trim_suffix(".remap")
			if n.ends_with(".tres"):
				archivos.append(n)
		archivos.sort()
		for n in archivos:
			var r = load(carpeta + n)
			if r == null:
				continue
			if r is WeaponData and int(r.tipo) == WeaponData.Tipo.PUNOS:
				continue   # los puños ya son "sin arma"
			if r is WeaponData or r is WandData:
				_armas.append({"nombre": n.trim_suffix(".tres"), "res": r})


# Deja en el lider el arma elegida (y su copia en la otra mano si 'dual'), y remonta el muñeco.
func _reequipar() -> void:
	var pj: PersonajeData = Game.lider()
	var item = _armas[_arma_i]["res"]
	pj.equipped_main = item
	# Dual: solo tiene sentido con un arma de una mano de verdad (ni 2 manos, ni varita, ni la larga,
	# que no va en dual). Se mete la MISMA en la otra mano -- es un visor, no importa cual.
	var puede_dual: bool = item is WeaponData and not bool(item.dos_manos) \
		and int(item.tipo) != WeaponData.Tipo.ESPADA_LARGA
	pj.equipped_off = item if (_dual and puede_dual) else null
	_muneco.montar(pj)


func _process(delta: float) -> void:
	if not _auto or not _muneco.hay_dibujo():
		return
	var fila: Dictionary = PoseJugador.ANIMS[_anim_i]
	var fps: float = float(fila["fps"])
	var marcos: int = int(fila["marcos"])
	var loop: bool = bool(fila["loop"])
	_reloj += delta * _vel
	var i: int = int(_reloj * fps)
	if loop:
		i = i % maxi(1, marcos)
	else:
		i = mini(i, marcos - 1)
	if i != _frame:
		_frame = i
		_aplicar()


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo):
		return
	var k: int = (ev as InputEventKey).keycode
	if k == KEY_SPACE or k == KEY_RIGHT:
		_anim_i = (_anim_i + 1) % PoseJugador.ANIMS.size()
		_reiniciar()
	elif k == KEY_LEFT:
		_anim_i = (_anim_i - 1 + PoseJugador.ANIMS.size()) % PoseJugador.ANIMS.size()
		_reiniciar()
	elif k == KEY_A:
		_dir = (_dir - 1 + 8) % 8
		_reiniciar()
	elif k == KEY_D:
		_dir = (_dir + 1) % 8
		_reiniciar()
	elif k == KEY_B:
		_arma_i = (_arma_i + 1) % _armas.size()
		_reequipar()
		_mostrar()
	elif k == KEY_V:
		_arma_i = (_arma_i - 1 + _armas.size()) % _armas.size()
		_reequipar()
		_mostrar()
	elif k == KEY_N:
		_dual = not _dual
		_reequipar()
		_mostrar()
	elif k == KEY_P:
		_auto = not _auto
		_mostrar()
	elif k == KEY_COMMA:
		_auto = false
		_frame = maxi(0, _frame - 1)
		_aplicar()
		_mostrar()
	elif k == KEY_PERIOD:
		_auto = false
		_frame = mini(int(PoseJugador.ANIMS[_anim_i]["marcos"]) - 1, _frame + 1)
		_aplicar()
		_mostrar()
	elif k == KEY_EQUAL or k == KEY_KP_ADD:
		_vel = minf(_vel * 1.35, 4.0)
		_mostrar()
	elif k == KEY_MINUS or k == KEY_KP_SUBTRACT:
		_vel = maxf(_vel / 1.35, 0.15)
		_mostrar()
	elif k == KEY_F12:
		_foto()
	elif k == KEY_ESCAPE:
		get_tree().quit()


func _reiniciar() -> void:
	_reloj = 0.0
	_frame = 0
	_aplicar()
	_mostrar()


# El nombre de animacion que toca, con su direccion. Para golpe/guardia se respeta la variante
# elegida a mano (dual -> golpe_izq, 2 manos -> golpe_2m); el resto sale de PoseJugador.animacion
# indirectamente eligiendo el nombre base de la lista.
func _nombre_anim() -> String:
	var base: String = String(PoseJugador.ANIMS[_anim_i]["n"])
	var dirs: int = int(PoseJugador.ANIMS[_anim_i]["dirs"])
	var d: int = _dir if dirs > 1 else PoseJugador.ancla_de(base)
	return "%s_%d" % [base, d]


func _aplicar() -> void:
	if not _muneco.hay_dibujo():
		return
	# SIEMPRE por 'fijar' y nunca por 'animar': el reloj lo llevamos nosotros en _process, que es lo
	# que deja pausar y pisar fotograma a mano. 'fijar' ademas remonta la anim si cambio el nombre.
	var marcos: int = int(PoseJugador.ANIMS[_anim_i]["marcos"])
	_muneco.fijar(_nombre_anim(), clampi(_frame, 0, marcos - 1))


func _mostrar() -> void:
	var base: String = String(PoseJugador.ANIMS[_anim_i]["n"])
	var marcos: int = int(PoseJugador.ANIMS[_anim_i]["marcos"])
	var dirs: int = int(PoseJugador.ANIMS[_anim_i]["dirs"])
	_aplicar()

	var una_dir: bool = dirs <= 1
	_flecha.visible = not una_dir
	if not una_dir:
		_flecha.points = PackedVector2Array([CENTRO, CENTRO + DIR_VECS[_dir] * 90.0])

	_titulo.text = "%s  ·  %s (%s)" % [_armas[_arma_i]["nombre"], base,
		"—" if una_dir else DIR_NOMBRES[_dir]]
	var flags: String = "  [DUAL]" if _dual else ""
	_sub.text = "arma %d/%d   ·   fotograma %d/%d   ·   x%.2f%s%s" % [
		_arma_i + 1, _armas.size(), _frame + 1, marcos, _vel,
		"   (PAUSA)" if not _auto else "", flags]


func _foto() -> void:
	DirAccess.make_dir_recursive_absolute("user://capturas")
	var img: Image = get_viewport().get_texture().get_image()
	var nom: String = String(_armas[_arma_i]["nombre"]).replace(" ", "_")
	var f: String = "user://capturas/jug_%s_%s_%s_f%d%s.png" % [
		String(PoseJugador.ANIMS[_anim_i]["n"]), nom, DIR_NOMBRES[_dir], _frame,
		"_dual" if _dual else ""]
	img.save_png(f)
	print("[visor jugador] ", ProjectSettings.globalize_path(f))
