# HERRAMIENTA. No forma parte del juego.
#
#   godot --headless --fixed-fps 60 --path . res://tools/simulador_peleas.tscn -- pisos=1,6 clases=guerrero,mago veces=3
#   (o el lanzador: python tools/simulador.py, que reparte el trabajo entre varios Godot a la vez y junta los numeros)
#
# EL SIMULADOR DE PELEAS (19/11/2026, memoria stats-misma-formula-todos). Peleas DE VERDAD, no formulas copiadas: la
# misma pantalla de combate en el mapa, en la ARENA DE PRUEBAS (una sala grande: nadie se engancha en esquinas), abierta
# por donde la abre la sala (tools/prueba_sala_propia.gd). Un PILOTO AUTOMATICO hace de jugador: anda hasta tener a tiro,
# elige y pulsa los botones, apunta las huellas y recita las frases, como lo haria alguien con el raton.
#
# EL PERSONAJE DE REFERENCIA de cada piso (la progresion que aprobo, la de tools/tabla_formulas.gd): nivel, habilidades
# del nivel, lo bakeado de los anteriores y equipo del tier del piso con sus mejoras. Dos clases:
#   guerrero  mandoble + placas; sus 4 habilidades del arma (las aprende todas); y de magia un Filo (imbuicion del
#             elemento que mejor le entre al enemigo), Manto de brasas y Vendaje de luz.
#   mago      baston + tela; seis magias de todo tipo: debiles (Pulso menor, Brasa), media (Torrente), fuertes (Tormenta,
#             Voragine de sombra) y la cura (Vendaje de luz), de elementos distintos: unas le entran bien al enemigo y
#             otras las resiste.
# 'arma=<archivo de resources/weapons>' cambia el arma del guerrero (para comparar armas entre si).
#
# CONTRA: cada enemigo que sale en ese piso (las tablas de spawns), CADA UNA DE SUS MUTACIONES (o el mutante generico si
# no tiene arbol) y los jefes de su piso. Uno contra uno, el enemigo con su 't' al azar como al nacer.
#
# EL PILOTO decide cada turno:
#   - con poca vida (< 40 %) y mana para la cura: se cura
#   - guerrero: si no va imbuido y le llega el mana, el Filo; el Manto una vez por pelea; si no, la habilidad que mas
#     pega de las que puede pagar (si pega mas que el ataque normal); si no, Atacar
#   - mago: el hechizo que mas daño espera POR TURNO DE RECITADO contra ese enemigo (StatsMath.resolve_spell, con sus
#     resistencias) entre los que puede pagar; sin mana, Atacar con el baston
#   - anda hasta tenerlo a tiro (alcance del arma, o el del hechizo); si no llega, Defender
#
# SALIDA: una linea por pelea, 'R|...' (ver CABECERA). 'tanda=<nombre>' la apunta en cada linea. 'trozo=i/n' juega solo
# los casos i, i+n, i+2n... (para repartir entre varios procesos).
extends Node

const CABECERA := "R|tanda|reglas|piso|clase|arma|enemigo|mutacion|jefe|t|gana|turnos_yo|turnos_el|vida_perdida|mp_gastado|dano_por_turno|dano_recibido_por_turno_suyo|segundos|acciones|fotogramas|ms_por_fotograma"
const PISOS_NIVEL := 12
# piso: [nivel, habilidad del nivel, [bakeados], tier, mejoras, piezas de armadura]  (la de tabla_formulas)
const PROGRESION := {
	1: [1, 50, [], 1, 0, 2],
	2: [1, 100, [], 1, 1, 5],
	6: [1, 350, [], 1, 7, 5],
	7: [1, 400, [], 2, 0, 5],
	12: [1, 700, [], 2, 7, 5],
	13: [2, 100, [700.0], 3, 0, 5],
	18: [2, 500, [700.0], 3, 7, 5],
	25: [3, 100, [700.0, 800.0], 5, 0, 5],
	31: [3, 600, [700.0, 800.0], 6, 0, 5],
}
const JEFES := {6: "res://scenes/actors/enemy/rey_slime.tres", 12: "res://scenes/actors/enemy/guardian_rango.tres"}
const SLOTS := ["casco", "pecho", "manos", "pantalones", "botas"]
const MAGIAS_MAGO := ["pulso_menor", "brasa", "chorro_agua", "tormenta", "voragine_sombra", "vendaje_de_luz"]
const FILOS := ["filo_ardiente", "filo_fulgurante", "filo_torrente", "filo_radiante", "filo_umbrio"]
const MAGIAS_GUERRERO := ["manto_brasas", "vendaje_de_luz"]
const VIDA_CURA := 0.4
const TOPE_TURNOS := 120       # turnos tuyos: mas = tablas
const TOPE_SEGUNDOS := 30.0    # reloj de verdad por pelea: mas = atascada (se apunta y se sigue)
const DIST_INICIO := 200.0

var sala = null
var _tanda := "sin_nombre"
var _reglas := "hoy"
var _pisos: Array = []
var _clases: Array = ["guerrero", "mago"]
var _veces := 1
var _solo := ""
var _arma := "mandobles"
var _trozo := 0
var _trozos := 1
var _escala_tiempo := 3.0
var _sin_mutantes := false
var _sin_jefes := false
var _ver := false


func _ready() -> void:
	call_deferred("_empezar")


func _empezar() -> void:
	reparent(get_tree().root)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hueco := Node.new()
	get_tree().root.add_child(hueco)
	get_tree().current_scene = hueco
	OS.set_environment("PRUEBA_SIN_MUTANTES", "1")   # los mutantes se piden por su nombre, no salen solos
	_leer_args()
	await _correr()
	print("[sim] FIN")
	get_tree().quit(0)


func _leer_args() -> void:
	_pisos = PROGRESION.keys()
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = String(a).split("=", true, 1)
		if kv.size() != 2:
			continue
		match kv[0]:
			"pisos": _pisos = Array(kv[1].split(",")).map(func(x): return int(x))
			"clases": _clases = Array(kv[1].split(","))
			"veces": _veces = maxi(1, int(kv[1]))
			"solo": _solo = kv[1]
			"arma": _arma = kv[1]
			"tanda": _tanda = kv[1]
			"reglas": _reglas = kv[1]
			"escala": _escala_tiempo = maxf(1.0, float(kv[1]))
			"sin_mutantes": _sin_mutantes = kv[1] == "1"
			"sin_jefes": _sin_jefes = kv[1] == "1"
			"ver": _ver = kv[1] == "1"
			"trozo":
				var t: PackedStringArray = kv[1].split("/")
				_trozo = int(t[0])
				_trozos = maxi(1, int(t[1]))


# ------------------------------------------------------------
#  EL PERSONAJE DE REFERENCIA
# ------------------------------------------------------------
func _personaje(piso: int, clase: String) -> PersonajeData:
	var pr: Array = PROGRESION[piso]
	var p := PersonajeData.new()
	var viejo: PersonajeData = Game.lider()
	if viejo != null:
		p.nombre = viejo.nombre
	var mago: bool = clase == "mago"
	var hp: float = p.base_hp
	var at: float = p.base_attack
	var de: float = p.base_defense
	var sp: float = p.base_speed
	var mg: float = p.base_magic
	var mf: float = p.base_magia_factor
	for s in pr[2]:
		var a := Abilities.new()
		if mago:
			a.magia = int(s); a.resistencia = int(s * 0.5); a.agilidad = int(s * 0.5); a.voluntad = int(s * 0.5)
			mf = mf * StatsMath.magia_factor(float(s)) * 1.1
		else:
			a.fuerza = int(s); a.resistencia = int(s); a.agilidad = int(s); a.voluntad = int(s * 0.5)
			at = at * StatsMath.fuerza_factor(s) * 1.1
		hp = StatsMath.max_hp_jugador(a, hp) * 1.1
		de = StatsMath.defense_jugador(a, de) * 1.1
		sp = StatsMath.speed_jugador(a, sp) * 1.1
		mg = StatsMath.magic_jugador(a, mg) * 1.1
	p.base_attack = at; p.base_hp = hp; p.base_defense = de; p.base_speed = sp; p.base_magic = mg; p.base_magia_factor = mf
	var h: int = int(pr[1])
	if mago:
		p.magia = h; p.resistencia = h / 2; p.agilidad = h / 2; p.voluntad = h / 2; p.fuerza = h / 4
	else:
		p.fuerza = h; p.resistencia = h; p.agilidad = h; p.destreza = h / 2; p.voluntad = h / 2
	var arma: String = "baston" if mago else _arma
	p.equipped_main = load("res://resources/weapons/%s.tres" % arma)
	var mejora = Upgrades.POTENCIA if mago else Upgrades.AGUDEZA
	p.equip_meta["main"] = {"tier": int(pr[3]), "rareza": 0, "mejoras": {mejora: int(pr[4])}, "durabilidad": 1.0, "banda": 0}
	var tela: String = "tela" if mago else "placas"
	for i in int(pr[5]):
		var s: String = SLOTS[(i + 1) % 5] if int(pr[5]) < 5 else SLOTS[i]
		p.set("equipped_" + s, load("res://resources/armor/%s_%s.tres" % [tela, s]))
		p.equip_meta[s] = {"tier": int(pr[3]), "rareza": 0, "mejoras": {Upgrades.DUREZA: int(pr[4])}, "durabilidad": 1.0, "banda": 0}
	# Las habilidades del arma: todas sabidas, las cuatro primeras puestas (el autorrelleno de siempre).
	p.habilidades_aprendidas = Game.pool_habilidades(p).duplicate()
	var magias: Array = MAGIAS_MAGO if mago else MAGIAS_GUERRERO + FILOS
	var hz: Array = []
	for m in magias:
		hz.append(load("res://resources/spells/%s.tres" % m))
	p.hechizos_aprendidos = hz.duplicate()
	p.equipped_spells = hz.slice(0, Game.MAX_HECHIZOS) if mago else []
	return p


# El guerrero lleva UN filo: el del elemento que mejor le entre a este enemigo (y el manto y la cura).
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


func _preparar_personaje(p: PersonajeData) -> void:
	Game.party = [p]
	Game.lider_idx = 0
	p.current_hp = -1.0
	p.current_mp = -1.0
	var maxi_: float = 100.0 + Game.stat_consolidado("resistencia", p) * 0.075 + Game.stat_consolidado("agilidad", p) * 0.025
	p.set_meta("aguante", [maxi_, maxi_])
	p.remove_meta("sin_fuelle")
	Game.ability_cooldowns_persist.clear()


# ------------------------------------------------------------
#  LOS CASOS
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


# [piso, clase, EnemyData, mutacion (StringName), mutante, jefe]
func _casos() -> Array:
	var out: Array = []
	for piso in _pisos:
		if not PROGRESION.has(piso):
			continue
		var lista: Array = []
		for ed in _enemigos_de(piso):
			lista.append([ed, &"", false, false])
			if not _sin_mutantes:
				var muts: Array = (ed.mutaciones as Array).filter(func(m): return m != null)
				if muts.is_empty():
					lista.append([ed, &"", true, false])
				for m in muts:
					lista.append([ed, m.id, true, false])
		if JEFES.has(piso) and not _sin_jefes:
			lista.append([load(JEFES[piso]), &"", false, true])
		for clase in _clases:
			for x in lista:
				if _solo != "" and not Array(_solo.split(",")).any(func(q): return String(x[0].resource_path.get_file().get_basename()).contains(q)):
					continue
				out.append([piso, clase] + x)
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
	var piso_montado: int = -1
	for caso in mios:
		var piso: int = caso[0]
		if piso != piso_montado:
			Game.arena_piso_juego = piso
			var ok: bool = await sala.arrancar("simulador_peleas_%d" % _trozo, Game.PISO_ARENA, 424242, false) \
				if piso_montado < 0 else await sala.remontar(Game.PISO_ARENA)
			if not ok:
				print("[sim] MAL: no se monta la arena del piso %d" % piso)
				return
			piso_montado = piso
		for _v in _veces:
			var r: String = await _pelea(caso)
			print(r)


# ------------------------------------------------------------
#  UNA PELEA
# ------------------------------------------------------------
var _cb: Node = null
var _turnos: Dictionary = {}
var _acciones: Dictionary = {}
var _turno_visto: int = -1
var _plan: Dictionary = {}
var _quieto: int = 0
var _pasos: int = 0
var _mejor_dist: float = INF
var _pos_antes: Vector2 = Vector2.ZERO
var _manto_usado := false
var _apuntes := 0
var _clase := ""
var _hist: Dictionary = {}
var _rehacer_arena := false


func _pelea(caso: Array) -> String:
	var piso: int = caso[0]
	var clase: String = caso[1]
	var ed: EnemyData = caso[2]
	var mutacion: StringName = caso[3]
	var mutante: bool = caso[4]
	var jefe: bool = caso[5]
	var p: PersonajeData = _personaje(piso, clase)
	_clase = clase
	if clase == "guerrero":
		_poner_magias_guerrero(p, ed, mutacion)
	_preparar_personaje(p)
	var suelo: Node = sala.piso.primero(&"dungeon_floor")
	if suelo != null and suelo.has_method("limpiar_arena"):
		suelo.limpiar_arena()
	await _esperar(2)
	var jug: Node2D = sala.jugador
	# SIEMPRE EN EL CENTRO DE LA SALA (19/11): pelea tras pelea el jugador acababa pegado al borde o al porton, y el enemigo
	# nacia donde no habia camino entre los dos (120 turnos mirandose: "no llega a nadie y se queda a la espera").
	var centro: Vector2 = suelo.gen.centro_px((suelo.gen.salas[0] as Rect2i).get_center())
	jug.recolocar(centro - Vector2(DIST_INICIO * 0.5, 0))
	await _esperar(2)
	var t: float = randf()
	var nodo = suelo.crear_enemigo(ed, centro + Vector2(DIST_INICIO * 0.5, 0), 90.0, t, 1 if mutante else 0, jefe, {}, mutacion)
	if nodo == null:
		return "R|%s|%s|%d|%s|%s|%s|%s|%d|%.2f|ERROR_NO_NACE" % [_tanda, _reglas, piso, clase, _nombre_arma(clase), ed.enemy_name, mutacion, 1 if jefe else 0, t]
	await _esperar(3)
	var t0: int = Time.get_ticks_msec()
	_cb = await sala.pelear([nodo], false)
	if _cb == null:
		return "R|%s|%s|%d|%s|%s|%s|%s|%d|%.2f|ERROR_NO_ABRE" % [_tanda, _reglas, piso, clase, _nombre_arma(clase), ed.enemy_name, mutacion, 1 if jefe else 0, t]
	_cb._aplicar_velocidad(4.0)
	_cb.turno_empieza.connect(func(c): _turnos[c] = int(_turnos.get(c, 0)) + 1)
	Engine.time_scale = _escala_tiempo
	_turnos.clear()
	_acciones.clear()
	_turno_visto = -1
	_plan = {}
	_manto_usado = false
	var yo: Combatant = _cb._aliados[0]
	var vida0: float = yo.current_hp
	var mp0: float = yo.current_mp
	var hp_enem0: Dictionary = {}
	for e in _cb._enemies:
		hp_enem0[e] = e.max_hp
	_hist.clear()
	var resultado := "?"
	var fotos: int = 0
	while true:
		await get_tree().process_frame
		fotos += 1
		if _ver and is_instance_valid(_cb):
			var k: String = "st%d fase%d %s" % [int(_cb._state), int(_cb.turno_mapa._fase), "cast" if _cb._cast_box != null and _visible(_cb._cast_box) else ""]
			_hist[k] = int(_hist.get(k, 0)) + 1
		if not is_instance_valid(_cb):
			resultado = "CERRADA"
			break
		if int(_cb._state) == 3:
			resultado = "GANA" if not _cb._aliados_vivos().is_empty() else "PIERDE"
			break
		if int(_turnos.get(yo, 0)) >= TOPE_TURNOS:
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
	var seg: float = (Time.get_ticks_msec() - t0) / 1000.0
	# Lo que le quitaste: todos los de su bando que llegaron a estar (crias incluidas cuentan aparte, no aqui).
	var quitado: float = 0.0
	for e in hp_enem0:
		quitado += float(hp_enem0[e]) - maxf(0.0, e.current_hp)
	var mis_turnos: int = int(_turnos.get(yo, 0))
	var sus_turnos: int = 0
	for c in _turnos:
		if c != yo:
			sus_turnos += int(_turnos[c])
	var perdida: float = (vida0 - maxf(0.0, yo.current_hp)) / maxf(1.0, yo.max_hp)
	var acc: Array = []
	for k in _acciones:
		acc.append("%s:%d" % [k, _acciones[k]])
	var linea := "R|%s|%s|%d|%s|%s|%s|%s|%d|%.2f|%s|%d|%d|%.3f|%.1f|%.2f|%.2f|%.1f|%s|%d|%.1f" % [_tanda, _reglas, piso, clase,
		_nombre_arma(clase), ed.enemy_name, String(mutacion) if mutante and mutacion != &"" else ("mutante" if mutante else "-"),
		1 if jefe else 0, t, resultado, mis_turnos, sus_turnos, perdida, mp0 - yo.current_mp,
		quitado / maxf(1.0, float(mis_turnos)), (vida0 - maxf(0.0, yo.current_hp)) / maxf(1.0, float(sus_turnos)), seg,
		",".join(acc), fotos, seg * 1000.0 / maxf(1.0, float(fotos))]
	if _ver:
		print("   [fotogramas] ", _hist)
	if _ver and is_instance_valid(_cb):
		for l in _cb._log_lines:
			print("   LOG ", l)
	await _cerrar()
	return linea


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
		print("   [atasco] pies %s inicio %s radio %.0f eje %s estados %s" % [str(tm.pies_de(yo).round()), str(tm._inicio.round()),
			float(tm._radio), str(Input.get_vector("move_left", "move_right", "move_up", "move_down")),
			str(yo.statuses.map(func(x): return x.d.get("nombre", "?")) if yo.get("statuses") != null else [])])
	print("   [atasco] estado %d jugador %s plan %s cajas %s apuntando %s fase %d quien %s andando %s" % [int(_cb._state),
		_cb._player.nombre if _cb._player != null else "-", str(_plan), str(cajas), str(tm.esta_apuntando()), int(tm._fase),
		tm._quien.nombre if tm._quien != null else "-", str(tm._andando)])
	for e in _cb._enemies:
		print("   [atasco]   %s vida %.1f/%.1f elegible %s gauge %.1f" % [e.nombre, e.current_hp, e.max_hp, str(not e.no_elegible()),
			float(_cb._gauge.get(e, -1.0))])
	var ls: Array = _cb._log_lines
	for i in range(maxi(0, ls.size() - 6), ls.size()):
		print("   [atasco]   LOG ", ls[i])


func _nombre_arma(clase: String) -> String:
	return "baston" if clase == "mago" else _arma


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
	# Si ha caido, la arena puede haberle sacado: se vuelve a montar (y al jugador dentro). Tambien tras una pelea atascada
	# o en tablas: que lo que se quedara roto no se arrastre a las siguientes.
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
func _objetivo(yo: Combatant) -> Combatant:
	var tm = _cb.turno_mapa
	var mejor: Combatant = null
	var d: float = INF
	for e in _cb._enemies:
		if not e.is_alive() or e.no_elegible():
			continue
		var dd: float = tm.pies_de(e).distance_to(tm.pies_de(yo))
		if dd < d:
			d = dd
			mejor = e
	return mejor


# Nadie elegible (en las sombras...): el primero vivo, para tener hacia donde mirar.
func _cualquiera() -> Combatant:
	for e in _cb._enemies:
		if e.is_alive():
			return e
	return null


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
	var obj: Combatant = _objetivo(yo)
	if obj == null:
		obj = _cualquiera()
	if obj == null:
		return
	_cb._target_idx = _cb._enemies.find(obj)
	# 1) RECITANDO: la frase que toca (y al final, Lanzar hacia donde esta ahora)
	var cast: Control = _cb._cast_box
	if cast != null and _visible(cast):
		_soltar_teclas()
		if tm.recolocando():
			tm.arrastrar_recolocar(tm.pies_de(obj))
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
	# 2) APUNTANDO una huella: al enemigo (o a mi, si es para los mios)
	if tm.esta_apuntando():
		_soltar_teclas()
		var ab: AbilityData = tm._apuntando
		var punto: Vector2 = tm.pies_de(yo) if ab.forma_a_aliados else tm.pies_de(obj)
		tm.raton_simulado = punto
		tm._andando = false
		tm._refrescar_apunte(punto)
		tm._confirmar_apunte()
		_apuntes += 1
		if tm.esta_apuntando() and _apuntes > 20:
			tm._cancelar_apunte()
			_plan = {"que": "defender"}
		return
	_apuntes = 0
	# 3) UN SUBMENU ABIERTO: el boton de lo planeado
	for caja in ["_spell_box", "_ability_box"]:
		var c: Control = _cb.get(caja)
		if c != null and _visible(c):
			_soltar_teclas()
			var nombre: String = _plan.get("nombre", "")
			for b in _botones(c):
				if nombre != "" and b.text.begins_with(nombre):
					b.pressed.emit()
					_apuntar_accion(nombre)
					if _plan.get("que", "") == "manto":
						_manto_usado = true
					_plan["hecho"] = true
					return
				if b.text == yo.nombre or b.text.begins_with(yo.nombre + " "):
					b.pressed.emit()   # el aliado al que va (yo)
					return
			# no esta (sin mana, en recarga...): atras y a Atacar
			for b in _botones(c):
				if b.text.begins_with("◄") or b.text.to_lower().contains("volver"):
					b.pressed.emit()
					break
			_plan = {"que": "atacar", "turno": _plan.get("turno", -1)}
			return
	# 4) EL MENU DE ACCIONES: plan del turno, andar y actuar
	var acciones_box: Control = _cb._actions_box
	if acciones_box == null or not _visible(acciones_box):
		return
	var turno_id: int = int(_turnos.get(yo, 0))
	if _plan.get("turno", -2) != turno_id or _plan.get("hecho", false):
		_plan = _decidir(yo, obj, obj.no_elegible())
		_plan["turno"] = turno_id
		if _ver:
			print("   [piloto] turno %d plan %s dist %.0f llega %s oculto %s radio %.0f" % [turno_id, str(_plan),
				tm.pies_de(yo).distance_to(tm.pies_de(obj)), str(tm.llega(yo, obj)), str(obj.no_elegible()), float(tm._radio)])
		_pasos = 0
		_quieto = 0
		_mejor_dist = INF
		_pos_antes = tm.pies_de(yo)
		# ¿ME CAE ENCIMA LO QUE ESTA CARGANDO? (el «¡Apartate!»): primero, fuera de su huella.
		var sitio = _sitio_a_salvo(yo)
		if sitio != null:
			_plan["huir_a"] = sitio
			_apuntar_accion("apartarse")
	if _plan.has("huir_a"):
		var p0: Vector2 = tm.pies_de(yo)
		var meta: Vector2 = _plan["huir_a"]
		if _sitio_a_salvo(yo) != null and p0.distance_to(meta) > 2.0 and _quieto < 6 and _pasos < 120:
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
	# ¿a tiro?
	var a_tiro: bool
	var rango: float = float(_plan.get("rango", -1.0))
	if rango >= 0.0:
		a_tiro = tm.pies_de(yo).distance_to(tm.pies_de(obj)) <= rango
	else:
		a_tiro = tm.llega(yo, obj)
	if not a_tiro and _plan.get("que", "") != "defender":
		var p: Vector2 = tm.pies_de(yo)
		# Se para en cuanto deja de ACERCARSE (el circulo se acabo, o resbala contra algo).
		var dist: float = p.distance_to(tm.pies_de(obj))
		if dist > _mejor_dist - 0.5:
			_quieto += 1
		else:
			_quieto = 0
			_mejor_dist = dist
		_pasos += 1
		if _quieto < 6 and _pasos < 240:
			_andar_hacia((tm.pies_de(obj) - p).normalized())
			return
		# no llega (se acabo el circulo): lo que se pueda desde aqui, o defender
		_plan = {"que": "defender", "turno": turno_id}
	_soltar_teclas()
	if tm._andando:
		return   # parandose: un fotograma
	var ids := {"atacar": 0, "habilidad": 1, "magia": 2, "manto": 2, "cura": 2, "filo": 2, "defender": 3}
	var que: String = _plan.get("que", "atacar")
	var b: BaseButton = _cb._action_buttons.get(ids.get(que, 0))
	if b == null or b.disabled or not b.visible:
		if _ver:
			print("   [piloto] %s no se puede" % que)
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
				b = null
				_apuntar_accion("pasar")
				_plan["hecho"] = true
				_cb._accion_esperar()
				return
	if b != null and not b.disabled:
		if que == "atacar" or que == "defender" or que == "pasar":
			_apuntar_accion(que)
			_plan["hecho"] = true
		b.pressed.emit()


# Lo que hace este turno: {"que": atacar|habilidad|magia|cura|filo|manto|defender, "nombre": boton, "rango": px o -1}.
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
	var cuerpo: Node2D = tm.cuerpo_de(yo)
	var pies: Vector2 = tm.pies_de(yo)
	var radio: float = float(tm._radio)
	var mejor = null
	var mejor_d: float = INF
	for k in 24:
		var dir := Vector2.RIGHT.rotated(TAU * float(k) / 24.0)
		var dist: float = 20.0
		while dist <= radio:
			var p: Vector2 = pies + dir * dist
			if tm._inicio.distance_to(cuerpo.global_position + (p - pies)) <= radio 					and not tm._en_peligro(yo, p, formas, true) 					and tm._puede_estar(cuerpo.global_position + (p - pies), cuerpo):
				if dist < mejor_d:
					mejor_d = dist
					mejor = p
				break
			dist += 15.0
	return mejor


func _decidir(yo: Combatant, obj: Combatant, oculto: bool = false) -> Dictionary:
	if oculto:
		return _decidir_area(yo, obj)
	var mago: bool = _clase == "mago"
	var vida: float = yo.current_hp / maxf(1.0, yo.max_hp)
	var cura: SpellData = null
	for s in yo.spells:
		if s.tipo == SpellData.TipoEfecto.CURACION and s.coste_mana <= yo.current_mp:
			cura = s
	if vida < VIDA_CURA and cura != null:
		return {"que": "cura", "nombre": cura.nombre, "rango": 99999.0}
	if not mago:
		for s in yo.spells:
			if s.es_imbuicion() and yo.imbue_usos <= 0 and yo.imbue_pct <= 0.0 and s.coste_mana <= yo.current_mp:
				return {"que": "filo", "nombre": s.nombre, "rango": 99999.0}
			if not s.es_imbuicion() and s.tipo == SpellData.TipoEfecto.BUFF and not _manto_usado and s.coste_mana <= yo.current_mp:
				return {"que": "manto", "nombre": s.nombre, "rango": 99999.0}
		var mejor: AbilityData = null
		var mejor_v: float = 1.05
		for ab in yo.abilities_combate:
			if ab == null or ab.es_preparacion() or ab.dano_mult <= 0.0 or ab.objetivo_aliado == AbilityData.Objetivo.ALIADO:
				continue
			if yo.ability_cd_left(ab) > 0 or not yo.has_energy(ab.coste(yo.ability_manos(ab))):
				continue
			var v: float = ab.dano_mult * float(ab.num_golpes(yo.ability_manos(ab), 1))
			if v > mejor_v:
				mejor_v = v
				mejor = ab
		if mejor != null:
			return {"que": "habilidad", "nombre": mejor.nombre, "rango": -1.0}
		return {"que": "atacar", "rango": -1.0}
	if _ver:
		print("   [piloto] mp %.1f/%.1f hechizos %s" % [yo.current_mp, yo.max_mp, yo.spells.map(func(x): return "%s t%d c%.0f" % [x.nombre, x.tipo, x.coste_mana])])
	# EL MAGO: el que mas daño espera por turno de recitado, entre los que puede pagar
	var mejor_s: SpellData = null
	var mejor_d: float = 0.0
	for s in yo.spells:
		if s.tipo != SpellData.TipoEfecto.ATAQUE or s.coste_mana > yo.current_mp or s.dano_base <= 0.0:
			continue
		var d: float = 0.0
		for _i in 12:
			d += float(StatsMath.resolve_spell(yo, obj, s, s.elemento, 1.0).damage)
		d /= 12.0 * float(maxi(1, s.frases.size()))
		if _ver:
			print("   [piloto] %s: %.2f por turno" % [s.nombre, d])
		if d > mejor_d:
			mejor_d = d
			mejor_s = s
	if mejor_s != null:
		var r: float = mejor_s.forma_rango * 0.85 if mejor_s.forma_rango > 0.0 else 99999.0
		return {"que": "magia", "nombre": mejor_s.nombre, "rango": r}
	return {"que": "atacar", "rango": -1.0}


# Visible dentro de la pantalla de combate (la capa de la sala no se pinta: nadie la mira).
func _visible(c: CanvasItem) -> bool:
	var n: Node = c
	while n != null and n != _cb:
		if n is CanvasItem and not (n as CanvasItem).visible:
			return false
		n = n.get_parent()
	return true


# EN LAS SOMBRAS no se le puede elegir: solo le dan las AREAS. La habilidad (o el hechizo) con huella que mas pegue, y a
# andar hasta tenerlo dentro de su alcance. Sin ninguna, Defender.
func _decidir_area(yo: Combatant, obj: Combatant) -> Dictionary:
	var tm = _cb.turno_mapa
	if _clase == "mago":
		var mejor_s: SpellData = null
		for s in yo.spells:
			if s.tipo == SpellData.TipoEfecto.ATAQUE and s.dano_base > 0.0 and s.coste_mana <= yo.current_mp 					and tm.usa_huella_hechizo(s) and (mejor_s == null or s.dano_base / s.frases.size() > mejor_s.dano_base / mejor_s.frases.size()):
				mejor_s = s
		if mejor_s != null:
			return {"que": "magia", "nombre": mejor_s.nombre, "rango": mejor_s.forma_rango * 0.85 if mejor_s.forma_rango > 0.0 else 99999.0}
		return {"que": "defender"}
	var mejor: AbilityData = null
	for ab in yo.abilities_combate:
		if ab == null or ab.es_preparacion() or ab.dano_mult <= 0.0 or not tm.usa_huella(ab) or ab.forma_a_aliados:
			continue
		if yo.ability_cd_left(ab) > 0 or not yo.has_energy(ab.coste(yo.ability_manos(ab))):
			continue
		if mejor == null or ab.dano_mult > mejor.dano_mult:
			mejor = ab
	if mejor != null:
		var r: float = mejor.forma_rango if mejor.forma_rango > 0.0 else mejor.forma_radio
		return {"que": "habilidad", "nombre": mejor.nombre, "rango": maxf(30.0, r * 0.8)}
	return {"que": "defender"}


func _botones(nodo: Node) -> Array:
	var out: Array = []
	for h in nodo.get_children():
		if h is BaseButton and not (h as BaseButton).disabled and (h as Control).visible:
			out.append(h)
		out.append_array(_botones(h))
	return out
