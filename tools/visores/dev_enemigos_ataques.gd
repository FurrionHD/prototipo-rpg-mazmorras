# ============================================================
#  dev_bichos.gd  -- EL VISOR DE ATAQUES DE LOS BICHOS
#  El gemelo de dev_gestos.gd, pero del otro lado de la mesa: aqui pegan ELLOS. Lanza en bucle el
#  ataque basico y todas las habilidades de cada enemigo, EN MOVIMIENTO, para poder mirarlos de
#  verdad en vez de en capturas sueltas.
#
#  Se lanza con:
#    Godot_v4.7-stable_win64.exe --path . res://tools/visores/dev_bichos.tscn
#
#  TECLAS
#    ESPACIO / →   siguiente golpe           ←   el anterior
#    B / V         siguiente / anterior BICHO (salta a su ataque basico)
#    T             el bicho DEBIL / el FUERTE de su franja (color_visual aclara con la 't')
#    P             parar / seguir el bucle
#    R             repetir el golpe AHORA
#    + / -         mas lento / mas rapido
#    F12           guarda una captura en user://capturas
#
#  LO QUE CAMBIA RESPECTO AL VISOR DEL JUGADOR
#   - La lista NO esta escrita a mano: se lee de los EnemyData de scenes/actors/enemy/. Asi un bicho
#     nuevo o una habilidad nueva salen aqui solos, sin tocar este archivo.
#   - EL COLOR NO ES ACERO: lo pone el bicho (EnemyData.color_visual) salvo que su elemento tenga
#     color propio, exactamente como decide combat.gd._color_golpe.
#   - El sentido va al reves: los bichos estan ARRIBA y pegan hacia ABAJO, contra tu grupo.
#
#  DOS TRAMPAS QUE YA MORDIERON UNA VEZ Y QUE AQUI SE EVITAN:
#   1. alta() tiene los tres ultimos argumentos con valor por defecto (elem, golpe, escudo). Pasar
#      valores INVENTADOS desde el visor es lo que oculto durante meses que el juego no los pasaba.
#      Aqui NO se inventan: el elemento sale del propio bicho (como _elem_encima) y el indice de
#      golpe es el del golpe que se esta soltando, igual que hace la cola de combat_fx.
#   2. Un estilo SIN entrada en T_VUELO no se dibuja NUNCA en la partida de verdad (ver el
#      'vuelo > 0.0' de combat_fx). El visor respeta esa regla y lo canta en el titulo en vez de
#      inventarse un vuelo de 0.1 y enseñar un dibujo que en combate no se ve.
# ============================================================

extends Node2D

const VICTIMAS := 4     # tu grupo, abajo: a quien le cae
const BICHOS := 4       # la fila de enfrente: el que pega (el 0) y tres congeneres
const CADA := 1.15          # segundos entre repeticiones
const REPETICIONES := 3     # veces que se ve cada golpe antes de pasar al siguiente

const DIR_BICHOS := "res://scenes/actors/enemy"

# Un golpe = [EnemyData, AbilityData o null si es el ataque basico].
var _lista: Array = []
var _capa: CapaHechizos
var _titulo: Label
var _sub: Label
var _sfx_txt: Label   # que fichero de sonido suena (ver Sonido.info)
var _ayuda: Label
var _victimas: Array = []   # tu grupo, abajo
var _fila: Array = []       # la fila de bichos, arriba
var _yo: ColorRect          # el que pega: el primero de la fila de arriba
var _idx := 0
var _rep := 0
var _turno := 0            # a que victima le toca
# NUMERO DE SERIE del lanzamiento en curso: sube uno en cada _lanzar. Una tanda de varios golpes se
# guarda el suyo en una LOCAL y lo compara antes de cada golpe, asi que si mientras espera entre
# golpes se lanza otra cosa, la tanda vieja se corta sola.
#
# Comparar el INDICE de la lista (que es lo que hacia el visor del jugador) NO vale: el nuevo
# lanzamiento reescribe el campo antes de que el bucle viejo lo mire, y los dos ven lo mismo. Se veia
# como un dibujo del ataque anterior cayendo encima del que acababas de pedir.
var _serie := 0
var _golpe := 0            # que golpe de la habilidad se esta soltando
var _reloj := 0.0
var _auto := true
var _vel := 1.0
var _t_franja := 1.0       # 1 = el mas fuerte de su franja (sale mas claro); 0 = el mas debil


func _ready() -> void:
	_cargar_bichos()
	if _lista.is_empty():
		push_error("[visor bichos] no he encontrado ningun EnemyData en %s" % DIR_BICHOS)
		get_tree().quit()
		return
	# Tamaño explicito: colgando de un Node2D el preset de anclas no estira nada.
	var fondo := ColorRect.new()
	fondo.size = Vector2(1280, 720)
	fondo.color = Color(0.11, 0.12, 0.15)
	add_child(fondo)
	# LA FILA DE BICHOS, arriba. El primero es el que pega y se pinta de SU color: asi se ve de un
	# vistazo de quien es el golpe que esta cayendo.
	for i in BICHOS:
		var b := ColorRect.new()
		b.size = Vector2(110, 140)
		b.position = Vector2(385 + i * 130, 120)
		b.color = Color(0.22, 0.24, 0.30)
		add_child(b)
		_fila.append(b)
	_yo = _fila[0]
	# TU GRUPO, abajo: los cuatro. Van bien separados porque es la fila que barren los golpes de
	# grupo (el chillido del Rey, el pisoton del coloso), y con las tarjetas juntas no se distingue
	# un area de un golpe suelto.
	for i in VICTIMAS:
		var v := ColorRect.new()
		v.size = Vector2(120, 160)
		v.position = Vector2(190 + i * 240, 420)
		v.color = Color(0.20, 0.25, 0.23)
		add_child(v)
		_victimas.append(v)
	_capa = CapaHechizos.new()
	_capa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_capa)
	_titulo = Label.new()
	_titulo.position = Vector2(24, 20)
	_titulo.add_theme_font_size_override("font_size", 30)
	_titulo.add_theme_color_override("font_color", Color(0.95, 0.92, 0.84))
	add_child(_titulo)
	_sub = Label.new()
	_sub.position = Vector2(24, 60)
	_sub.add_theme_font_size_override("font_size", 17)
	_sub.add_theme_color_override("font_color", Color(0.70, 0.74, 0.82))
	add_child(_sub)
	_sfx_txt = Label.new()
	_sfx_txt.position = Vector2(24, 84)
	_sfx_txt.add_theme_font_size_override("font_size", 15)
	_sfx_txt.add_theme_color_override("font_color", Color(0.87, 0.72, 0.40))
	add_child(_sfx_txt)
	_ayuda = Label.new()
	_ayuda.position = Vector2(24, 668)
	_ayuda.add_theme_font_size_override("font_size", 15)
	_ayuda.add_theme_color_override("font_color", Color(0.55, 0.58, 0.66))
	_ayuda.text = "ESPACIO/→ siguiente   ← anterior   B/V bicho   T débil/fuerte   P pausa   R repetir   +/- velocidad"
	add_child(_ayuda)
	_lanzar()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--foto" in args or "--foto-todo" in args:
		await _tanda_de_fotos()


# LA LISTA, leida de los .tres. Por bicho: primero su ataque basico y despues sus habilidades, en el
# orden en que las lleva. Se ordena por nombre de archivo para que el recorrido sea siempre el mismo.
func _cargar_bichos() -> void:
	var d := DirAccess.open(DIR_BICHOS)
	if d == null:
		return
	var archivos: Array = []
	for f in d.get_files():
		# En una version exportada los recursos llevan .remap detras; aqui se corre desde fuente,
		# pero quitarlo no cuesta nada y evita una lista vacia si alguna vez se prueba en el .exe.
		var n: String = f.trim_suffix(".remap")
		if n.ends_with(".tres"):
			archivos.append(n)
	archivos.sort()
	for n in archivos:
		var ed = load("%s/%s" % [DIR_BICHOS, n])
		if ed == null or not (ed is EnemyData):
			continue
		_lista.append([ed, null])          # su ataque basico
		for ab in ed.habilidades:
			if ab != null:
				_lista.append([ed, ab])


# Modo comprobacion: dispara los golpes y guarda una foto de cada uno, sin tocar teclas. Con --foto
# van solo los basicos (una foto por bicho); con --foto-todo van tambien todas sus habilidades.
func _tanda_de_fotos() -> void:
	DirAccess.make_dir_recursive_absolute("user://capturas")
	var todo: bool = "--foto-todo" in OS.get_cmdline_user_args()
	_auto = false
	for i in _lista.size():
		if _lista[i][1] != null and not todo:
			continue   # solo los basicos: una foto por bicho
		_idx = i
		_turno = 0
		_lanzar()
		var est: int = _estilo(_lista[i][0], _lista[i][1])
		# POR TIEMPO, no por frames: sin vsync esto corre a cientos de fps y "esperar N frames" son
		# milisegundos -- un gesto que tarda en arrancar saldria en una foto vacia. Y la foto va A
		# MITAD DE VUELO, no al final: esperar el vuelo entero retrata el efecto YA APAGADO.
		var vida: float = maxf(float(CombatFX.T_VUELO.get(est, 0.1)) * 0.8, 0.12)
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
			_idx = (_idx + 1) % _lista.size()
		_lanzar()


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo):
		return
	var k: int = (ev as InputEventKey).keycode
	if k == KEY_SPACE or k == KEY_RIGHT:
		_ir_a((_idx + 1) % _lista.size())
	elif k == KEY_LEFT:
		_ir_a((_idx - 1 + _lista.size()) % _lista.size())
	elif k == KEY_B:
		_ir_a(_otro_bicho(1))
	elif k == KEY_V:
		_ir_a(_otro_bicho(-1))
	elif k == KEY_T:
		_t_franja = 0.0 if _t_franja > 0.5 else 1.0
		_lanzar()
	elif k == KEY_R:
		_reloj = 0.0
		_lanzar()
	elif k == KEY_P:
		_auto = not _auto
	elif k == KEY_EQUAL or k == KEY_KP_ADD:
		_vel = minf(_vel * 1.35, 4.0)
	elif k == KEY_MINUS or k == KEY_KP_SUBTRACT:
		_vel = maxf(_vel / 1.35, 0.15)
	elif k == KEY_F12:
		_foto()
	elif k == KEY_ESCAPE:
		get_tree().quit()


func _ir_a(i: int) -> void:
	_idx = i
	_rep = 0
	_reloj = 0.0
	_lanzar()


# El ataque BASICO del bicho anterior o siguiente: saltar de bicho en bicho sin pasar por sus ocho
# habilidades es lo que hace usable una lista de veinte bichos.
func _otro_bicho(paso: int) -> int:
	var actual = _lista[_idx][0]
	var i: int = _idx
	for _n in _lista.size():
		i = (i + paso + _lista.size()) % _lista.size()
		if _lista[i][0] != actual and _lista[i][1] == null:
			return i
	return _idx


func _foto() -> void:
	DirAccess.make_dir_recursive_absolute("user://capturas")
	var img: Image = get_viewport().get_texture().get_image()
	var f: String = "user://capturas/bicho_%s.png" % _clave().to_lower()
	img.save_png(f)
	print("[visor] ", ProjectSettings.globalize_path(f))


func _clave() -> String:
	var ed = _lista[_idx][0]
	var ab: AbilityData = _lista[_idx][1]
	var nom: String = String(ed.enemy_name).to_lower().replace(" ", "_")
	return nom if ab == null else "%s_%s" % [nom, String(ab.nombre).to_lower().replace(" ", "_")]


# ============================================================
#  EL MISMO CAMINO QUE LA PARTIDA
# ============================================================
# COMO PEGA: manda la habilidad si pide dibujo y, si no, como pega el bicho. Es lo mismo que hace
# combat.gd._estilo_de_habilidad, que es el UNICO sitio del juego donde se decide esto.
# LA CLAVE DE SONIDO de la habilidad en curso, por el mismo criterio que combat.gd._sfx_de_habilidad:
# el nombre de su .tres, y solo si esta en Sonido.CLAVES. Lo que no esta ahi suena por su estilo.
func _sfx_hab() -> String:
	var ab: AbilityData = _lista[_idx][1]
	if ab == null or ab.resource_path == "":
		return ""
	var clave: String = ab.resource_path.get_file().get_basename()
	return clave if Sonido.CLAVES.has(clave) else ""


func _estilo(ed, ab: AbilityData) -> int:
	if ab != null and ab.fx_estilo >= 0:
		return ab.fx_estilo
	if ed != null and ed.fx_basico >= 0:
		return ed.fx_basico
	return CombatFX.Estilo.MELEE


# EL ELEMENTO del golpe. En la partida sale de _elem_encima(e): la imbuicion si la lleva encima y,
# si no, el elemento del bicho. Aqui no hay imbuiciones, asi que es el suyo y punto.
func _elem(ed) -> int:
	return int(ed.elemento)


# EL COLOR, calcado de combat.gd._color_golpe por la rama de los bichos: manda el elemento si tiene
# color propio; si no, el color del bicho. El puñetazo pelado (MELEE sin elemento) se queda con el
# blanco de siempre.
func _color(ed, estilo: int) -> Color:
	var el: int = _elem(ed)
	if Elementos.tiene_color(el):
		return Elementos.color(el)
	if estilo != CombatFX.Estilo.MELEE:
		return ed.color_visual(_t_franja)
	return Color(1, 0.95, 0.9)


func _lanzar() -> void:
	var ed = _lista[_idx][0]
	var ab: AbilityData = _lista[_idx][1]
	var est: int = _estilo(ed, ab)
	var nombre_est: String = String(CombatFX.Estilo.keys()[est])
	# CUANTOS GOLPES PEGA DE VERDAD, sacados de su .tres: el Doble embate del slime son dos placajes
	# y el Frenesi de la rata tres dentelladas. Enseñar uno solo no dice como se ve el ataque.
	var golpes: int = 1
	var adorno: bool = false     # no hace daño: es una postura, un grito o una coraza
	if ab != null:
		if ab.dano_mult > 0.0:
			golpes = maxi(1, ab.golpes_min)
		else:
			adorno = true
	# El color del que pega, en su tarjeta: el visor tiene que enseñar de que bicho es el golpe.
	_yo.color = ed.color_visual(_t_franja).darkened(0.35)
	for i in range(1, BICHOS):
		_fila[i].color = Color(0.22, 0.24, 0.30)
	var vuelo: float = float(CombatFX.T_VUELO.get(est, 0.0))
	_titulo.text = "%s  ·  %s" % [ed.enemy_name, "ataque básico" if ab == null else ab.nombre]
	var aviso: String = "" if vuelo > 0.0 else "   ⚠ sin T_VUELO: en combate NO se dibuja"
	_sub.text = "[%s]   %d golpe%s%s   %s   %d/%d      x%.2f%s%s" % [nombre_est.to_lower(),
		golpes, "" if golpes == 1 else "s", "   (adorno, sin daño)" if adorno else "",
		"el fuerte de su franja" if _t_franja > 0.5 else "el débil de su franja",
		_rep + 1, REPETICIONES, _vel, "" if _auto else "   (PAUSA)", aviso]
	# QUE FICHERO SUENA, escrito en pantalla. Es la mitad del trabajo: oir que algo suena mal no
	# sirve de nada si luego hay que adivinar cual de los 154 ficheros es.
	_sfx_txt.text = "🔊 " + Sonido.info(_sfx_hab(), est)
	_capa.escala_tiempo = 1.0
	_capa.limpiar()
	_serie += 1
	var serie: int = _serie
	# El objetivo se elige UNA vez por ejecucion: los golpes de una misma habilidad caen sobre el
	# mismo, como en la pelea. Lo que cambia de victima es cada REPETICION.
	_turno = (_turno + 1) % VICTIMAS
	if adorno:
		_soltar_adorno(ed, ab, est)
		return
	for i in golpes:
		if i > 0:
			await get_tree().create_timer(CombatFX.T_ENCADENADO / maxf(_vel, 0.1)).timeout
			if serie != _serie:
				return   # han pedido otra cosa a mitad: esta tanda ya no toca
		_golpe = i
		_soltar(ed, ab, est)
	# LO QUE SE ECHA ENCIMA EL QUE PEGA, despues del golpe (AbilityData.fx_sobre_mi): hay ataques
	# que hacen las dos cosas -pegan y dejan al bicho en postura-, y enseñar solo una mitad hace
	# parecer que la habilidad esta mal montada.
	if ab != null and ab.fx_sobre_mi >= 0:
		_sobre_mi(ed, ab.fx_sobre_mi)


# LOS QUE NO PEGAN: un caparazon, una muralla, un bramido, una invocacion. Van por el mismo reparto
# que combat.gd._fx_adorno.
func _soltar_adorno(ed, ab: AbilityData, est: int) -> void:
	if est == CombatFX.Estilo.MELEE:
		return   # sin dibujo propio: un empujon de tarjeta sin golpe no se ve, y mejor asi
	if CombatFX.SOBRE_SI_MISMO.has(est):
		_sobre_mi(ed, est)
		return
	# LO QUE INVOCA (la Escision del Rey slime) se pinta sobre las CRIAS, o sea sobre su propia fila.
	if ab != null and ab.invoca_cantidad > 0:
		for i in range(1, mini(1 + ab.invoca_cantidad, BICHOS)):
			_fila[i].color = ed.color_visual(_t_franja).darkened(0.55)
			_a_la_tarjeta(ed, est, _fila[i], 120.0)
		return
	if ab != null and ab.objetivo_aliado != AbilityData.Objetivo.ENEMIGO:
		# A LOS SUYOS: va sobre la fila de arriba, no sobre la tuya.
		for b in _fila:
			_a_la_tarjeta(ed, est, b, 110.0)
		return
	_repartir(ed, ab, est)


# Un golpe suelto, ya con la victima elegida.
func _soltar(ed, ab: AbilityData, est: int) -> void:
	if CombatFX.SOBRE_SI_MISMO.has(est):
		# Raro en un golpe con daño, pero si el estilo no viaja hay que pintarlo donde nace o sale
		# un efecto plantado en medio de la nada.
		_sobre_mi(ed, est)
		return
	_repartir(ed, ab, est)


# A QUIEN LE CAE. Sin area, a la victima de turno. Con area, a todo tu grupo -- y ahi los estilos de
# grupo (un chillido, un pisoton, una rodada) se pintan UNA sola vez cubriendo la fila entera, que es
# exactamente lo que hace _marcar_efectos_de_grupo en la cola: un terremoto es UNO y coge a los que
# coge, no uno pequeño por cabeza.
func _repartir(ed, ab: AbilityData, est: int) -> void:
	var area: bool = ab != null and ab.es_area()
	if not area:
		_a_la_tarjeta(ed, est, _victimas[_turno], 120.0)
		return
	if CombatFX._ESTILOS_DE_GRUPO.has(est):
		var izq: float = _victimas[0].position.x
		var der: float = _victimas[VICTIMAS - 1].position.x + 120.0
		var centro := Vector2((izq + der) * 0.5, _victimas[0].position.y + 80.0)
		_alta(ed, est, centro, der - izq)
		return
	for v in _victimas:
		_a_la_tarjeta(ed, est, v, 120.0)


func _a_la_tarjeta(ed, est: int, tj: ColorRect, ancho: float) -> void:
	_alta(ed, est, tj.position + tj.size * 0.5, ancho)


func _sobre_mi(ed, est: int) -> void:
	# Nace y muere en la tarjeta del propio bicho.
	_alta(ed, est, _yo.position + _yo.size * 0.5, 110.0)


# LA UNICA PUERTA a la capa de dibujos. Los tres ultimos argumentos NO son inventados: el elemento
# sale del bicho y el indice de golpe es el del golpe en curso, igual que hace la cola de combat_fx.
# El escudo va a -1 a proposito: los bichos no llevan ninguno (Combatant.fx_escudo).
func _alta(ed, est: int, destino: Vector2, ancho: float) -> void:
	# EL SONIDO, y ANTES del corte por vuelo. En la partida el sonido NO depende de T_VUELO (ver
	# CombatFX._process): un puñetazo no dibuja nada y suena igual. Ponerlo detras del return dejaria
	# mudos en el visor justo los ataques que en la pelea si se oyen, que es el peor error posible en
	# una herramienta que existe para decidir si un sonido esta bien.
	Sonido.golpe(_sfx_hab(), est, 1.0, false, _elem(ed))
	var vuelo: float = float(CombatFX.T_VUELO.get(est, 0.0))
	if vuelo <= 0.0:
		return   # sin vuelo no hay dibujo, igual que en la partida
	_capa.alta(est, _yo.position + _yo.size * 0.5, destino, _color(ed, est), 1.0, vuelo, ancho,
		_elem(ed), _golpe, -1)
