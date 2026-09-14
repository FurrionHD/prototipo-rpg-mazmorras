# ============================================================
#  HUELLA DEL COMBATE (red de seguridad para partir combat.gd)
#  Juega peleas guionizadas SIN ventana, con el azar y el reloj fijados, y apunta una traza de todo
#  lo que pasa: cada linea nueva del registro y cada cambio de vida/energia/mana. Si al trocear el
#  combate la traza sale IDENTICA a la de referencia, el troceo no ha cambiado nada del juego.
#
#  Hay que lanzarla con --fixed-fps 60 (sin eso el ATB avanza con el reloj real y cambia cada vez):
#    godot --headless --fixed-fps 60 --path . res://tools/prueba_huella_combate.tscn -- grabar
#    godot --headless --fixed-fps 60 --path . res://tools/prueba_huella_combate.tscn -- comparar
# ============================================================
extends Node

const SEMILLA := 20260914
const MAX_FRAMES := 60 * 60 * 6    # 6 minutos de pelea como mucho
const CARPETA := "res://tools/huellas"

var _modo := "comparar"
var _traza: PackedStringArray = []
var _ultimo_log := ""
var _ultimo_estado := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	if args.has("grabar"):
		_modo = "grabar"
	var fallos := 0
	for esc in ["prueba_4v3_atacar"]:
		var traza: PackedStringArray = await _jugar(esc)
		fallos += _guardar_o_comparar(esc, traza)
	print("[huella] RESULTADO: ", "TODO IGUAL" if fallos == 0 else "CAMBIA %d" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)


func _jugar(escenario: String) -> PackedStringArray:
	seed(SEMILLA)
	_traza = []
	_ultimo_log = ""
	_ultimo_estado = {}
	var pelea: Node = load("res://scenes/ui/combat.tscn").instantiate()
	add_child(pelea)
	var f := 0
	while f < MAX_FRAMES:
		await get_tree().process_frame
		f += 1
		_apuntar(pelea, f)
		var st: int = int(pelea.get("_state"))
		if st == 3:   # FINISHED
			break
		if st == 1:   # WAITING_PLAYER: el piloto decide
			match escenario:
				"prueba_4v3_atacar":
					pelea._accion_atacar()
	_apuntar(pelea, f)
	_traza.append("FIN f%d estado=%d" % [f, int(pelea.get("_state"))])
	pelea.queue_free()
	await get_tree().process_frame
	return _traza


func _apuntar(pelea: Node, f: int) -> void:
	var lineas: Array = pelea.get("_log_lines")
	var ult: String = String(lineas[lineas.size() - 1]) if not lineas.is_empty() else ""
	if ult != _ultimo_log:
		_ultimo_log = ult
		_traza.append("f%d LOG %s" % [f, ult])
	for grupo in ["_aliados", "_enemies"]:
		for c in pelea.get(grupo):
			var e := "%s hp=%.3f mp=%.3f en=%.3f" % [c.nombre, c.current_hp, c.current_mp, c.current_energy]
			var clave := "%s:%s" % [grupo, c.nombre]
			if _ultimo_estado.get(clave, "") != e:
				_ultimo_estado[clave] = e
				_traza.append("f%d %s" % [f, e])


func _guardar_o_comparar(escenario: String, traza: PackedStringArray) -> int:
	var ruta := CARPETA.path_join(escenario + ".txt")
	if _modo == "grabar":
		var fw := FileAccess.open(ruta, FileAccess.WRITE)
		fw.store_string("\n".join(traza) + "\n")
		print("[huella] grabada %s: %d lineas" % [escenario, traza.size()])
		return 0
	var fr := FileAccess.open(ruta, FileAccess.READ)
	if fr == null:
		print("[huella] FALTA la referencia de %s: grabala primero" % escenario)
		return 1
	var ref := fr.get_as_text().strip_edges().split("\n")
	for i in maxi(ref.size(), traza.size()):
		var a: String = ref[i] if i < ref.size() else "(nada)"
		var b: String = traza[i] if i < traza.size() else "(nada)"
		if a != b:
			print("[huella] %s CAMBIA en la linea %d:\n   antes: %s\n   ahora: %s" % [escenario, i + 1, a, b])
			return 1
	print("[huella] %s igual (%d lineas)" % [escenario, traza.size()])
	return 0
