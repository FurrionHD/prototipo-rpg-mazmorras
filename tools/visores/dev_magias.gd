# ============================================================
#  dev_magias.gd  --  EL VISOR DE MAGIAS
#  Lanza el dibujo de cada hechizo EN BUCLE y en movimiento, uno cada vez, para poder mirarlo de
#  verdad en vez de en capturas sueltas.
#
#  Nace porque las capturas no bastaban: un efecto dura medio segundo, y sacar fotos por reloj sale
#  MAL — guardar cada PNG bloquea el bucle del juego, asi que el efecto se queda atras respecto al
#  reloj de pared y las fotos caen donde no toca. Aqui se ve corriendo y se para donde uno quiera.
#
#  Los hechizos salen de la carpeta: los que piden dibujo propio (fx_estilo) se enseñan con el suyo,
#  y los demas con el generico de su elemento, que es como se ven en combate. Uno nuevo aparece aqui
#  solo con crear su .tres.
#
#  TECLAS
#    ESPACIO / →   siguiente hechizo         ←   el anterior
#    P             parar / seguir el bucle
#    R             repetir el efecto AHORA
#    + / -         mas rapido / mas lento
#    S             pasar UN paso con el bucle parado (para mirar fotograma a fotograma)
#    F12           captura en tools/salida/
#
#  Se lanza con herramientas/ver_magias.bat, o:
#    godot --path . res://tools/visores/dev_magias.tscn
# ============================================================
extends Node

const SALIDA := "res://tools/salida/"
const SPELLS_DIR := "res://resources/spells/"
const CADA := 1.6          # segundos entre repeticiones
const PASO := 1.0 / 60.0   # lo que avanza la tecla S

var _capa: CapaHechizos = null
var _hechizos: Array = []      # SpellData, ordenados por rareza y nombre
var _idx: int = 0
var _reloj: float = 0.0
var _parado: bool = false
var _vel: float = 1.0
var _rotulo: Label = null
var _ficha: Label = null
var _origen := Vector2(240.0, 560.0)
var _blanco := Vector2(820.0, 300.0)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(1280, 720))

	var fondo := ColorRect.new()
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# El MISMO fondo que el combate. Sobre gris claro un efecto oscuro se ve perfecto y luego en el
	# juego desaparece: la voragine de sombra ya se colo asi una vez.
	fondo.color = Color(0.07, 0.08, 0.11)
	add_child(fondo)

	# La marca de donde esta el enemigo, para juzgar el tamaño del efecto contra algo.
	var marca := ColorRect.new()
	marca.color = Color(1.0, 1.0, 1.0, 0.06)
	marca.size = Vector2(120.0, 150.0)
	marca.position = _blanco - marca.size * 0.5
	add_child(marca)

	_capa = CapaHechizos.new()
	add_child(_capa)

	_rotulo = Label.new()
	_rotulo.position = Vector2(24.0, 20.0)
	_rotulo.add_theme_font_size_override("font_size", 22)
	_rotulo.add_theme_color_override("font_color", Color(0.95, 0.72, 0.36))
	add_child(_rotulo)

	_ficha = Label.new()
	_ficha.position = Vector2(24.0, 54.0)
	_ficha.add_theme_color_override("font_color", Color(0.72, 0.76, 0.84))
	add_child(_ficha)

	var ayuda := Label.new()
	ayuda.position = Vector2(24.0, 660.0)
	ayuda.text = "←/→ hechizo   ·   P parar   ·   S un paso   ·   R repetir   ·   +/− velocidad   ·   F12 foto"
	ayuda.add_theme_color_override("font_color", Color(0.5, 0.54, 0.6))
	add_child(ayuda)

	_cargar()
	if _hechizos.is_empty():
		printerr("[magias] no hay hechizos en %s" % SPELLS_DIR)
		get_tree().quit(1)
		return
	_lanzar()


# TODOS los hechizos de la carpeta, ordenados por rareza (de comun a mitico) y dentro de la rareza
# por nombre. Asi al ir pasando se recorre la escala de menos a mas, que es como se juzga si un
# mitico se ve mas gordo que un epico.
func _cargar() -> void:
	var d := DirAccess.open(SPELLS_DIR)
	if d == null:
		return
	for f in d.get_files():
		if not f.ends_with(".tres"):
			continue
		var s: SpellData = load(SPELLS_DIR + f) as SpellData
		if s != null:
			_hechizos.append(s)
	_hechizos.sort_custom(func(a, b):
		if int(a.rareza) != int(b.rareza):
			return int(a.rareza) < int(b.rareza)
		return String(a.nombre) < String(b.nombre))


func _proceso_de(s: SpellData) -> void:
	pass


# Da de alta el efecto del hechizo actual. Se replica lo que hace combat.gd: el estilo propio si lo
# pide, y si no el generico de su elemento; y el golpe de un elemento que NO es el de identidad usa
# el estilo de salpicadura (asi el Shock saca su bola y, detras, el vapor).
func _lanzar() -> void:
	_capa.limpiar()
	var s: SpellData = _hechizos[_idx]
	_rotulo.text = "%s   ·   %s" % [s.nombre, _nombre_rareza(int(s.rareza))]
	var frases: String = "  |  ".join(Array(s.frases))
	_ficha.text = "%s  ·  %d MP  ·  %d golpe(s)  ·  %s\n«%s»" % [
		Elementos.nombre(int(s.elemento)), s.coste_mana, s.hits,
		"dibujo propio" if s.fx_estilo >= 0 else "dibujo del elemento", frases]

	var n: int = maxi(1, s.hits)
	for i in n:
		var elem: int = s.elemento_de_golpe(i, n)
		var estilo: int = _estilo(s, elem)
		var vuelo: float = float(CombatFX.T_VUELO.get(estilo, 0.20))
		# Cada golpe entra un poco despues del anterior, como las tandas del combate. Sin esto, el
		# vapor del Shock se abria encima de su propia bola.
		var retraso: float = float(i) * 0.30
		_alta_tras(retraso, estilo, vuelo, elem, i)


func _estilo(s: SpellData, elem: int) -> int:
	if s.fx_estilo >= 0:
		if elem != s.elemento and s.fx_estilo_salpicon >= 0:
			return s.fx_estilo_salpicon
		if elem == s.elemento:
			return s.fx_estilo
	match elem:
		Elementos.Elemento.FUEGO: return CombatFX.Estilo.PROYECTIL
		Elementos.Elemento.RAYO: return CombatFX.Estilo.RAYO
		Elementos.Elemento.AGUA: return CombatFX.Estilo.BARRIDO
		Elementos.Elemento.LUZ: return CombatFX.Estilo.LUZ_ESTALLIDO
		Elementos.Elemento.OSCURIDAD: return CombatFX.Estilo.SOMBRA_VORAGINE
	return CombatFX.Estilo.ARCANO


func _alta_tras(retraso: float, estilo: int, vuelo: float, elem: int, golpe: int) -> void:
	if retraso > 0.0:
		await get_tree().create_timer(retraso, true, false, true).timeout
	if not is_inside_tree():
		return
	_capa.alta(estilo, _origen, _blanco, Elementos.color(elem), 1.5, vuelo, 120.0, elem, golpe)


func _process(delta: float) -> void:
	_capa.escala_tiempo = _vel
	if _parado:
		return
	_reloj += delta * _vel
	if _reloj >= CADA:
		_reloj = 0.0
		_lanzar()


func _input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not ev.pressed or ev.echo:
		return
	match (ev as InputEventKey).keycode:
		KEY_RIGHT, KEY_SPACE:
			_idx = (_idx + 1) % _hechizos.size()
			_reloj = 0.0
			_lanzar()
		KEY_LEFT:
			_idx = (_idx - 1 + _hechizos.size()) % _hechizos.size()
			_reloj = 0.0
			_lanzar()
		KEY_R:
			_reloj = 0.0
			_lanzar()
		KEY_P:
			_parado = not _parado
			# Parar de verdad: si la capa sigue corriendo, el efecto se acaba solo mientras miras.
			_capa.escala_tiempo = 0.0 if _parado else _vel
		KEY_S:
			# UN PASO con el bucle parado. Es lo que deja mirar el fotograma exacto del impacto, que
			# es donde se ve si el reventon sale antes o despues de que llegue la bola.
			if _parado:
				_capa.escala_tiempo = 1.0
				await get_tree().process_frame
				_capa.escala_tiempo = 0.0
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			_vel = minf(4.0, _vel * 1.5)
		KEY_MINUS, KEY_KP_SUBTRACT:
			# Hasta muy lento: los efectos duran medio segundo y a velocidad normal no da tiempo a
			# ver si la secuencia es la que se ha escrito.
			_vel = maxf(0.05, _vel / 1.5)
		KEY_F12:
			DirAccess.make_dir_recursive_absolute(SALIDA)
			await RenderingServer.frame_post_draw
			var ruta: String = "%smagia_%s.png" % [SALIDA,
				String(_hechizos[_idx].nombre).to_lower().replace(" ", "_")]
			get_viewport().get_texture().get_image().save_png(ruta)
			print("[magias] ", ProjectSettings.globalize_path(ruta))
	if not _parado:
		_capa.escala_tiempo = _vel
	_rotulo.modulate = Color(1, 1, 1) if not _parado else Color(0.7, 0.7, 0.7)


func _nombre_rareza(r: int) -> String:
	var n := ["Común", "Poco común", "Raro", "Épico", "Legendario", "Mítico", "Obra maestra",
		"Prístino"]
	return n[r] if r >= 0 and r < n.size() else "?"
