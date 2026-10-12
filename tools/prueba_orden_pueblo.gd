# EL ORDEN DE DIBUJO EN EL PUEBLO (12/10, C2 del playtest 11/10): las piezas (farola, brasero, cartel, verja, columna,
# puestos, bancos, fuente, casas...) entran en el orden por altura de Game._ordenar_munecos. Con UNO DETRAS y OTRO
# DELANTE a la vez (tu grupo, que va en fila), la pieza tiene que quedar entre los dos: por encima del de detras y por
# debajo del de delante, ella y lo que lleva pegado (el fuego, el cartel de la fachada). Antes tenia una sola z para
# todos y le atravesaba la cabeza al de delante. Se arrima con la fisica (hasta donde de verdad deja llegar). Sin ventana:
#   godot --headless --path . res://tools/prueba_orden_pueblo.tscn
# Las capturas para mirarlo: tools/ver_solapes_pueblo.tscn (con ventana) + tools/hoja_solapes_pueblo.py.
extends Node

const PUEBLO := "res://scenes/levels/town.tscn"
const PartidaDePrueba = preload("res://tools/visores/partida_de_prueba.gd")

var _mal: int = 0
var _pueblo: Node2D = null
var _jug: CharacterBody2D = null
var _comp: Node2D = null
var _pies: Vector2 = Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PartidaDePrueba.llenar()
	get_tree().current_scene.scene_file_path = PUEBLO
	_pueblo = (load(PUEBLO) as PackedScene).instantiate() as Node2D
	add_child(_pueblo)
	_jug = _pueblo.get_node("Player") as CharacterBody2D
	for _i in 10:
		await get_tree().physics_frame
	_pies = (_jug.get_node("CollisionShape2D") as Node2D).position
	_jug.set_physics_process(false)
	# La fila del grupo, quieta: si no, el que pongo delante vuelve andando detras del jugador.
	for t in _con_script(get_tree().root, "party_trail.gd"):
		(t as Node).set_physics_process(false)
	for n in get_tree().get_nodes_in_group("aliado"):
		if n != _jug and n is Node2D and _comp == null:
			_comp = n
		elif n != _jug and n is Node2D:
			(n as Node2D).global_position = Vector2(-5000, -5000)
	_ver(_comp != null, "hay un compañero para ponerlo delante")
	if _comp == null:
		_fin()
		return
	var cam: Camera2D = _jug.get_node("Camera2D") as Camera2D
	cam.position_smoothing_enabled = false

	var casos: Array = [
		["poste_antorcha", Rect2i(PuebloPlano.POSTES[0], Vector2i.ONE)],
		["brasero", Rect2i(PuebloPlano.BRASEROS[0], Vector2i.ONE)],
		["cartel_indicador", Rect2i(PuebloPlano.CARTELES[3]["casilla"], Vector2i.ONE)],
		["altar_columna", Rect2i(PuebloPlano.ALTAR, Vector2i.ONE)],
		["verja", Rect2i(Vector2i(PuebloPlano.JARDIN.position.x + 2, PuebloPlano.JARDIN.end.y - 1), Vector2i.ONE)],
		["fuente", PuebloPlano.FUENTE],
	]
	var vistos := {}
	for m in PuebloPlano.MUEBLES:
		if not vistos.has(m[0]):
			vistos[m[0]] = true
			casos.append([String(m[0]), m[1]])
	for casa in PuebloPlano.CASAS:
		if String(casa["clave"]) == "taberna":
			casos.append(["casa_", casa["rect"]])
	for c in casos:
		await _probar(String(c[0]), c[1])

	# LO QUE ES TODO SUELO no entra en el orden: la escalera de la plaza (un pozo) se queda por debajo de quien la pisa.
	var esc: PiezaPueblo = _buscar("escalera_caracol", PuebloPlano.ESCALERA)
	_ver(esc != null and not esc.is_in_group(PiezaPueblo.GRUPO) and esc.z_index == PiezaPueblo.Z_DEBAJO,
		"la escalera de la plaza (todo suelo) se queda con el suelo")
	_fin()


func _probar(clave: String, huella: Rect2i) -> void:
	var pieza: PiezaPueblo = _buscar(clave, huella)
	if pieza == null:
		_ver(false, "encuentro la pieza %s" % clave)
		return
	var caja: Rect2 = _caja(huella, clave.begins_with("casa_"))
	var cx: float = caja.get_center().x
	var detras: Vector2 = _arrimar(Vector2(cx, caja.position.y - 44.0), Vector2(0, 88))
	var delante: Vector2 = _arrimar(Vector2(cx, caja.end.y + 44.0), Vector2(0, -88))
	if detras == Vector2.INF or delante == Vector2.INF:
		_ver(false, "%s: llego por detras y por delante" % pieza.clave)
		return
	for vuelta in 2:
		# Y al reves: se cambian de sitio y se cambia el orden.
		var a: Node2D = _jug if vuelta == 0 else _comp
		var b: Node2D = _comp if vuelta == 0 else _jug
		a.global_position = detras
		b.global_position = delante
		(_jug.get_node("Camera2D") as Camera2D).offset = pieza.rect_global().get_center() - _jug.global_position
		for _i in 3:
			await get_tree().process_frame
		var z_detras: int = _z_muneco(a)
		var z_delante: int = _z_muneco(b)
		var z_p: int = pieza.z_index
		var z_pegado: int = z_p + 1   # lo que lleva pegado (fuego, cartel) va a su z + 1, relativo
		_ver(z_detras < z_p and z_pegado < z_delante,
			"%s, %s: detras %d < pieza %d (+1 lo pegado) < delante %d" % [pieza.clave,
				"jugador detras" if vuelta == 0 else "cambiados", z_detras, z_p, z_delante])


func _arrimar(desde_pies: Vector2, mov: Vector2) -> Vector2:
	var desde: Vector2 = desde_pies - _pies
	if _jug.test_move(Transform2D(0.0, desde), Vector2.ZERO):
		return Vector2.INF
	_jug.global_position = desde
	if _jug.move_and_collide(mov) == null:
		return Vector2.INF
	return _jug.global_position


func _buscar(clave: String, huella: Rect2i) -> PiezaPueblo:
	var centro: Vector2 = (Vector2(huella.position) + Vector2(huella.size) * 0.5) * float(PuebloPlano.CELDA)
	var mejor: PiezaPueblo = null
	var mejor_d: float = INF
	for p in _piezas(_pueblo):
		var vale: bool = p.clave.begins_with(clave) if clave.ends_with("_") or clave == "verja" else p.clave == clave
		if not vale:
			continue
		var d: float = p.rect_global().get_center().distance_to(centro)
		if d < mejor_d:
			mejor_d = d
			mejor = p
	return mejor


func _piezas(n: Node) -> Array:
	var out: Array = []
	if n is PiezaPueblo:
		out.append(n)
	for h in n.get_children():
		out.append_array(_piezas(h))
	return out


func _con_script(n: Node, fin: String) -> Array:
	var out: Array = []
	var sc: Script = n.get_script()
	if sc != null and sc.resource_path.ends_with(fin):
		out.append(n)
	for h in n.get_children():
		out.append_array(_con_script(h, fin))
	return out


func _caja(huella: Rect2i, entera: bool) -> Rect2:
	var cel: float = float(PuebloPlano.CELDA)
	var px := Rect2(Vector2(huella.position) * cel, Vector2(huella.size) * cel)
	if entera:
		return px
	var out := Rect2()
	for r in PuebloPlano.cajas_pequenas():
		if px.grow(2.0).has_point(r.get_center()):
			out = r if out.size == Vector2.ZERO else out.merge(r)
	return out if out.size != Vector2.ZERO else px


func _z_muneco(n: Node) -> int:
	for h in n.get_children():
		if h.is_in_group(&"munecos_jugador"):
			return int(h.z_index)
	return -9999


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _fin() -> void:
	print("=== FIN (%s) ===" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)
