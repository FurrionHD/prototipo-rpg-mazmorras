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
	for esc in ["prueba_4v3_atacar", "mundo_rey_slime", "mundo_venenos_huir"]:
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
	if escenario.begins_with("mundo_"):
		if not _montar_con_mundo(pelea, escenario):
			pelea.free()
			return PackedStringArray(["SIN PARTIDA DE REFERENCIA (tools/huellas/mundo_ref.tres)"])
	add_child(pelea)
	var f := 0
	var turnos := 0
	var espera := 0
	var ultimo_estado := -1
	while f < MAX_FRAMES:
		await get_tree().process_frame
		f += 1
		_apuntar(pelea, f)
		var st: int = int(pelea.get("_state"))
		if st == 3:   # FINISHED
			break
		if st != ultimo_estado:
			ultimo_estado = st
			espera = 0
			if st == 1:
				turnos += 1
		if st != 1:   # WAITING_PLAYER: el piloto decide (tras dos fotogramas, que la UI se monte)
			continue
		espera += 1
		if espera < 3 or espera % 3 != 0:
			continue
		if espera > 600:
			_traza.append("f%d ATASCADO: nadie contesta en el turno %d" % [f, turnos])
			break
		match escenario:
			"prueba_4v3_atacar":
				pelea._accion_atacar()
			_:
				var pulsado: String = _piloto(pelea, escenario, turnos)
				if pulsado != "":
					_traza.append("f%d PULSA %s" % [f, pulsado])
	_apuntar(pelea, f)
	_traza.append("FIN f%d estado=%d" % [f, int(pelea.get("_state"))])
	pelea.queue_free()
	await get_tree().process_frame
	return _traza


# ------------------------------------------------------------
#  CON UNA PARTIDA DE VERDAD: el grupo de la partida congelada contra enemigos del juego
# ------------------------------------------------------------
const MUNDO_REF := "res://tools/huellas/mundo_ref.tres"
const ENEMIGOS := {
	"mundo_rey_slime": [["rey_slime", 0.5, true], ["slime", 0.4, false], ["slime_veneno", 0.6, false]],
	"mundo_venenos_huir": [["arana", 0.7, false], ["trent", 0.5, false], ["jabali", 0.3, false]],
}

func _montar_con_mundo(pelea: Node, escenario: String) -> bool:
	if not FileAccess.file_exists(MUNDO_REF):
		return false
	var d = ResourceLoader.load(MUNDO_REF, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not (d is SaveData):
		return false
	Game.importar_partida(d)
	var pjs: Array = [Game.lider()]
	for comp in Game.companeros():
		pjs.append(comp)
	var pcs: Array = []
	for pj in pjs:
		var c: Combatant = Game.crear_player_combatant(pj)
		# La energia la pone start_combat con el aguante del mapa (player._calc_max_aguante), que aqui no
		# hay: se calcula con la misma formula y se entra descansado.
		c.max_energy = maxf(1.0, 100.0 + Game.stat_consolidado("resistencia", pj) * 0.075
			+ Game.stat_consolidado("agilidad", pj) * 0.025)
		c.current_energy = c.max_energy
		pcs.append(c)
	Game._active_player_pjs = pjs
	Game._active_player_cs = pcs
	var ecs: Array = []
	for spec in ENEMIGOS[escenario]:
		var ed: EnemyData = load("res://scenes/actors/enemy/%s.tres" % spec[0])
		ecs.append(ed.crear_combatant(float(spec[1]), false, bool(spec[2])))
	pelea.setup(pcs, ecs, false)
	var nombres: Array = pjs.map(func(p): return "%s (%s)" % [p.nombre,
		p.equipped_main.nombre if p.equipped_main != null else "puños"])
	_traza.append("GRUPO " + ", ".join(nombres))
	return true


# EL PILOTO: pulsa botones de verdad, como un jugador. Devuelve lo que ha pulsado ("" = nada).
#  - recitando: la frase correcta; disparo o soltar carga: el unico boton
#  - con un submenu abierto: la primera opcion que se pueda (no "Volver")
#  - en el menu: la accion que toque por turno, o Atacar si esa no se puede
const POLITICA := {
	"mundo_rey_slime": ["Habilidad", "Magia", "Atacar", "Objeto", "Defender"],
	"mundo_venenos_huir": ["Magia", "Habilidad", "Atacar", "Atacar", "Defender", "Objeto", "Huir"],
}

var _turno_atras := -1   # el turno en el que el piloto ya tuvo que volver atras de un submenu

func _piloto(pelea: Node, escenario: String, turno: int) -> String:
	var cast: Control = pelea.get("_cast_box")
	if cast != null and cast.visible:
		var botones := _botones(cast)
		var sp = pelea.get("_cast_spell")
		var idx: int = int(pelea.get("_cast_index"))
		if sp != null and idx < sp.frases.size():
			var correcta: String = sp.frases[idx]
			for b in botones:
				if b.text.ends_with(correcta):
					b.pressed.emit()
					return "frase " + correcta
		for b in botones:
			if not b.text.begins_with("◄"):
				b.pressed.emit()
				return b.text
	for caja in ["_ability_box", "_objeto_box", "_spell_box"]:
		var c: Control = pelea.get(caja)
		if c != null and c.visible:
			for b in _botones(c):
				if not b.text.begins_with("◄") and not b.text.to_lower().contains("volver"):
					b.pressed.emit()
					return "%s: %s" % [caja, b.text]
			# Nada que elegir: atras, y en este turno ya no se vuelve a probar (se ataca). Se apunta POR QUE
			# no habia nada: es parte de la huella (si cambia la razon, cambia el juego).
			var motivos: Array = []
			for h in _todos_botones(c):
				if (h as BaseButton).disabled:
					motivos.append("%s [%s]" % [h.text, String(h.tooltip_text).get_slice("
", 0)])
			_turno_atras = turno
			for b in _botones(c):
				b.pressed.emit()
				return "%s: atras (apagados: %s)" % [caja, "; ".join(motivos)]
	var acciones: Dictionary = pelea.get("_action_buttons")
	var nombres: Array = POLITICA[escenario]
	var quiero: String = nombres[turno % nombres.size()]
	if _turno_atras == turno:
		quiero = "Atacar"
	var ids := {"Atacar": 0, "Habilidad": 1, "Magia": 2, "Defender": 3, "Objeto": 4, "Huir": 5}
	var b: BaseButton = acciones.get(ids[quiero])
	if b == null or b.disabled or not b.is_visible_in_tree():
		quiero = "Atacar"
		b = acciones.get(0)
	if b != null and not b.disabled:
		b.pressed.emit()
		return quiero
	return ""


func _todos_botones(nodo: Node) -> Array:
	var out: Array = []
	for h in nodo.get_children():
		if h is BaseButton:
			out.append(h)
		out.append_array(_todos_botones(h))
	return out


func _botones(nodo: Node) -> Array:
	var out: Array = []
	for h in nodo.get_children():
		if h is BaseButton and not (h as BaseButton).disabled and (h as Control).is_visible_in_tree():
			out.append(h)
		out.append_array(_botones(h))
	return out


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
