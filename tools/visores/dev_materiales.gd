# ============================================================
#  dev_materiales.gd  --  EL VISOR DE RECOLECTABLES
#  El hermano de dev_enemigos_*: enseña como se ve en el mapa CADA material que se recolecta
#  (vetas, carbon, sal, arboles, plantas, huerto), con su familia, su SUB-TIER metido en la forma
#  del dibujo y su tinte real sacado del .tres. Sirve para juzgar de un vistazo si el cobre bruto,
#  el veteado y el profundo se distinguen sin mirar el color -- que es justo lo que se pidio.
#
#  NO decide nada por su cuenta: pide la textura al mismo sitio que el juego (RecolectableSprites)
#  y la forma a MaterialData.forma_recolectable(), asi que lo que se ve aqui es lo que hay en la
#  mazmorra.
#
#  Va como ESCENA (no --script): los .tres de material dependen del autoload Game.
#    Godot_v4.7-stable_win64.exe --path . res://tools/visores/dev_materiales.tscn
#
#  TECLAS
#    → / ESPACIO   siguiente material      ← anterior
#    ↑ / ↓         saltar de FAMILIA
#    TAB           MODO CRUDO: todas las combinaciones forma x modelo de una familia, aunque
#                  ningun material real las use todavia (p.ej. el acero o el cipres solo tienen
#                  forma 0 hoy -- esto enseña igual las formas 1 y 2 ya dibujadas, en blanco)
#    ESC           salir
# ============================================================

extends Node2D

const DIR_MATERIALES := "res://resources/materials"
const CENTRO := Vector2(640, 320)
const ESCALA := 5.0
const SUBTIER := ["bruto", "veteado", "profundo"]
const ESPECIES := ["pino", "roble", "ciprés"]   # madera: la especie sale del TIER, no del sub-tier

var _lista: Array = []          # de MaterialData, solo los recolectables, ordenados
var _idx := 0

# MODO CRUDO: recorre TODAS las (familia, forma) que existen en RecolectableSprites, las tenga
# asignadas algun material o no. Es lo que hace falta para ver el acero veteado/profundo o el
# cipres veteado/profundo -- ya estan dibujados (el horno genera todas las formas de la familia),
# solo que hoy ningun .tres los usa.
var _modo_crudo := false
var _cruda: Array = []          # de Dictionary {familia, forma}
var _idx_cruda := 0

var _muestra: Node2D
var _tira: Node2D
var _titulo: Label
var _sub: Label
var _ayuda: Label


func _ready() -> void:
	_cargar()
	_cargar_crudo()
	if _lista.is_empty():
		push_error("[visor materiales] no he encontrado ningun material recolectable en %s" % DIR_MATERIALES)
		get_tree().quit()
		return

	var fondo := ColorRect.new()
	fondo.size = Vector2(1280, 720)
	fondo.color = Color(0.10, 0.11, 0.13)
	add_child(fondo)

	# El suelo de referencia: una banda para que se vea que los sprites se apoyan con el pie.
	var suelo := ColorRect.new()
	suelo.size = Vector2(1280, 220)
	suelo.position = Vector2(0, CENTRO.y - 40)
	suelo.color = Color(0.15, 0.16, 0.19)
	add_child(suelo)

	_muestra = Node2D.new()
	add_child(_muestra)
	_tira = Node2D.new()
	add_child(_tira)

	_titulo = _label(Vector2(24, 20), 30, Color(0.95, 0.92, 0.84))
	_sub = _label(Vector2(24, 60), 18, Color(0.70, 0.74, 0.82))
	_ayuda = _label(Vector2(24, 690), 15, Color(0.55, 0.58, 0.66))
	_ayuda.text = "→/ESPACIO siguiente   ← anterior   ↑/↓ familia   TAB modo crudo   ESC salir"

	_mostrar()


func _label(pos: Vector2, tam: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", col)
	add_child(l)
	return l


# Todos los .tres de material que salen como NODO en el mapa, ordenados por familia -> tier ->
# sub-tier -> id, para que el recorrido siga la progresion natural (cobre, cobre veteado, cobre
# profundo, hierro...).
func _cargar() -> void:
	var d := DirAccess.open(DIR_MATERIALES)
	if d == null:
		return
	var nombres: Array = []
	for f in d.get_files():
		var n: String = f.trim_suffix(".remap")
		if n.ends_with(".tres"):
			nombres.append(n)
	for n in nombres:
		var m = load("%s/%s" % [DIR_MATERIALES, n])
		# Solo lo que de verdad SALE COMO NODO en el mapa: familia corriente, con una familia de
		# dibujo, y con exigencia > 0 (lo que cuesta picarlo/talarlo/cortarlo). La 'exigencia' es el
		# filtro que deja fuera los drops de enemigo -- runa de arcilla, quitina, placa antigua... --,
		# que son tipo MINERAL en el .tres pero no se recolectan: se venden en el pueblo.
		if m is MaterialData and m.familia == MaterialData.Familia.CORRIENTE \
				and _familia(m) != "" and m.exigencia > 0.0:
			_lista.append(m)
	_lista.sort_custom(func(a: MaterialData, b: MaterialData) -> bool:
		var ka := "%s%d%d%s" % [_familia(a), int(a.tier), a.forma_recolectable(), a.id]
		var kb := "%s%d%d%s" % [_familia(b), int(b.tier), b.forma_recolectable(), b.id]
		return ka < kb)


# Todas las (familia, forma) que existen en RecolectableSprites, aunque ningun material las use.
func _cargar_crudo() -> void:
	for fam in RecolectableSprites.FAMILIAS:
		var f: String = String(fam)
		for forma in RecolectableSprites.formas_de(f):
			_cruda.append({"familia": f, "forma": forma})


# Material -> familia de dibujo (RecolectableSprites). El mismo reparto que hace resource_node por
# su enum Tipo, traducido aqui desde el Tipo del material.
func _familia(m: MaterialData) -> String:
	match m.tipo:
		MaterialData.Tipo.MINERAL: return "veta"
		MaterialData.Tipo.COMBUSTIBLE: return "carbon"
		MaterialData.Tipo.MADERA: return "madera"
		MaterialData.Tipo.PLANTA: return "planta"
		MaterialData.Tipo.DESPENSA:
			# La sal es roca (pico); el resto de la despensa es mata (hoz).
			return "sal" if String(m.id).contains("sal") else "huerto"
	return ""


# La 'forma' que le toca a este material para RecolectableSprites: el sub-tier de siempre, salvo
# en madera, que ademas cruza la especie por tier -- MISMA cuenta que resource_node._crear_sprite,
# para que el visor enseñe exactamente lo que se ve en la mazmorra.
func _forma_de(m: MaterialData) -> int:
	var f: int = m.forma_recolectable()
	var fam: String = _familia(m)
	if fam == "madera" or fam == "planta" or fam == "veta":
		f = (clampi(int(m.tier), 1, 3) - 1) * 3 + f
	return f


func _nodo(fam: String, forma: int, modelo: int, color: Color) -> Node2D:
	var n := Node2D.new()
	var t: Vector2i = RecolectableSprites.lienzo(fam)
	for tinte in [false, true]:
		var s := Sprite2D.new()
		s.texture = RecolectableSprites.textura(fam, forma, modelo, tinte)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.centered = false
		s.position = Vector2(-float(t.x) * 0.5, -float(t.y))
		# Mismo criterio que resource_node: el cuerpo lleva un lavado suave, no el color a saco.
		s.modulate = color if tinte else RecolectableSprites.tinte_cuerpo(color)
		if tinte and fam == "veta":
			s.material = RecolectableSprites.material_metal()
		n.add_child(s)
	return n


# Texto "sub-tier X/Y (nombre)" [-- y la especie si es madera], compartido entre el modo normal y
# el crudo para no mantener la logica dos veces.
func _desc_forma(fam: String, forma: int) -> String:
	var nf: int = RecolectableSprites.formas_de(fam)
	# madera/planta/veta cruzan tier: el sub-tier real es forma % 3, no forma a pelo (eso solo
	# vale para carbon/sal, que no cruzan y se quedan en 0..2).
	var cruza_tier: bool = fam == "madera" or fam == "planta" or fam == "veta"
	var st: int = (forma % 3) if cruza_tier else forma
	if fam == "madera":
		var especie: String = ESPECIES[clampi(forma / 3, 0, ESPECIES.size() - 1)]
		return "(%s)  ·  sub-tier %d/3 (%s)" % [especie, st + 1, SUBTIER[st]]
	if cruza_tier:
		return "sub-tier %d/3 (%s)" % [st + 1, SUBTIER[st]]
	var stx: String = SUBTIER[forma] if nf > 1 and forma < SUBTIER.size() else "unico"
	return "sub-tier %d/%d (%s)" % [forma + 1, nf, stx]


func _mostrar() -> void:
	if _modo_crudo:
		_mostrar_crudo()
		return
	for c in _muestra.get_children():
		c.queue_free()
	for c in _tira.get_children():
		c.queue_free()

	var m: MaterialData = _lista[_idx]
	var fam: String = _familia(m)
	var forma: int = _forma_de(m)

	_titulo.text = m.nombre
	var prefijo: String = "familia madera " if fam == "madera" else "familia %s  ·  " % fam
	_sub.text = "%s%s  ·  Tier %d  ·  %d de %d" % [
		prefijo, _desc_forma(fam, forma), int(m.tier), _idx + 1, _lista.size()]

	# Los CUATRO modelos de esta forma, en fila. El que le toca a una veta concreta lo elige el hash
	# de su celda; aqui se ven los cuatro juntos.
	for modelo in RecolectableSprites.MODELOS:
		var nodo := _nodo(fam, forma, modelo, m.color)
		nodo.scale = Vector2(ESCALA, ESCALA)
		nodo.position = CENTRO + Vector2((float(modelo) - 1.5) * 190.0, 60.0)
		_muestra.add_child(nodo)

	# Tira de comparacion: todos los materiales de la MISMA familia, pequeños, el actual marcado.
	var hermanos: Array = _lista.filter(func(x: MaterialData) -> bool: return _familia(x) == fam)
	var x0: float = 640.0 - float(hermanos.size() - 1) * 70.0 * 0.5
	for i in hermanos.size():
		var hm: MaterialData = hermanos[i]
		var mini := _nodo(fam, _forma_de(hm), 0, hm.color)
		mini.scale = Vector2(1.7, 1.7)
		mini.position = Vector2(x0 + float(i) * 70.0, 640.0)
		_tira.add_child(mini)
		if hm == m:
			var marco := ColorRect.new()
			marco.size = Vector2(58, 6)
			marco.position = Vector2(x0 + float(i) * 70.0 - 29.0, 650.0)
			marco.color = Color(0.95, 0.85, 0.4)
			_tira.add_child(marco)


# MODO CRUDO: la (familia, forma) de turno, tinte blanco (no hay material real del que sacar
# color) y SIN tira de hermanos (no hay materiales reales que comparar).
func _mostrar_crudo() -> void:
	for c in _muestra.get_children():
		c.queue_free()
	for c in _tira.get_children():
		c.queue_free()

	var e: Dictionary = _cruda[_idx_cruda]
	var fam: String = String(e["familia"])
	var forma: int = int(e["forma"])

	_titulo.text = "%s -- MODO CRUDO (sin material asignado)" % fam
	_sub.text = "%s  ·  %d de %d  ·  TAB: volver a materiales reales" % [
		_desc_forma(fam, forma), _idx_cruda + 1, _cruda.size()]

	for modelo in RecolectableSprites.MODELOS:
		var nodo := _nodo(fam, forma, modelo, Color(1, 1, 1))
		nodo.scale = Vector2(ESCALA, ESCALA)
		nodo.position = CENTRO + Vector2((float(modelo) - 1.5) * 190.0, 60.0)
		_muestra.add_child(nodo)


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo):
		return
	var n: int = _cruda.size() if _modo_crudo else _lista.size()
	match (ev as InputEventKey).keycode:
		KEY_RIGHT, KEY_SPACE:
			if _modo_crudo:
				_idx_cruda = (_idx_cruda + 1) % n
			else:
				_idx = (_idx + 1) % n
			_mostrar()
		KEY_LEFT:
			if _modo_crudo:
				_idx_cruda = (_idx_cruda - 1 + n) % n
			else:
				_idx = (_idx - 1 + n) % n
			_mostrar()
		KEY_DOWN:
			_salto_familia(1)
		KEY_UP:
			_salto_familia(-1)
		KEY_TAB:
			_modo_crudo = not _modo_crudo
			_mostrar()
		KEY_ESCAPE:
			get_tree().quit()


# Salta al primer elemento de la familia siguiente (o anterior), en la lista que este activa.
func _salto_familia(dir: int) -> void:
	if _modo_crudo:
		var fam_actual: String = String(_cruda[_idx_cruda]["familia"])
		var n: int = _cruda.size()
		var i: int = _idx_cruda
		for _paso in n:
			i = (i + dir + n) % n
			if String(_cruda[i]["familia"]) != fam_actual:
				break
		if dir < 0:
			var fam_nueva: String = String(_cruda[i]["familia"])
			for _paso in n:
				var j: int = (i - 1 + n) % n
				if String(_cruda[j]["familia"]) != fam_nueva:
					break
				i = j
		_idx_cruda = i
		_mostrar()
		return

	var fam_actual: String = _familia(_lista[_idx])
	var n: int = _lista.size()
	# primero avanza hasta salir de la familia actual
	var i: int = _idx
	for _paso in n:
		i = (i + dir + n) % n
		if _familia(_lista[i]) != fam_actual:
			break
	# si vamos hacia atras, retrocede hasta el principio de esa familia
	if dir < 0:
		var fam_nueva: String = _familia(_lista[i])
		for _paso in n:
			var j: int = (i - 1 + n) % n
			if _familia(_lista[j]) != fam_nueva:
				break
			i = j
	_idx = i
	_mostrar()
