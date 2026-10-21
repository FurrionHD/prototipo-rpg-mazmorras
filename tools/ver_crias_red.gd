# HERRAMIENTA (CON VENTANA). Las CRIAS EN MULTIJUGADOR (13/10, C3 del playtest 11/10: el slime brotado y el Rey
# Slime, sus crias en red salian mal "incluso siendo solo una persona"). Sala de verdad con trabajadores: la pelea
# la ejecuta un trabajador de pelea y esta ventana es el ESPEJO, lo que ve el jugador. Desde el 21/10 (fase 2, etapa 2)
# entra como en el juego: por la sala de una ranura de prueba (82), que lleva la arena; lo de dentro de la sala se lee de
# sus lineas "[S] dato" (tools/sonda_sala.gd).
#   1) Un slime brotado: le pegas hasta que cae y se divide, y luego solo PASAS turnos para que les toque a las crias.
#   2) El Rey Slime: solo pasas turnos hasta que suelta su Brote y las crias juegan.
# De verdad, no muñecos: el muñeco de la arena no usa habilidades (ni el Brote del Rey ni las de las crias).
# Un solo personaje en el grupo (los compañeros mataban a las crias antes de que les tocara).
#   godot --path . res://tools/ver_crias_red.tscn -- nube_local
# EN VIDEO: VER_SALIR=1 godot --path . --write-movie X.avi --fixed-fps 30 res://tools/ver_crias_red.tscn
# Solo una: VER_SOLO=brotado o VER_SOLO=rey. VER_TRAZA=1: lo que se ve de cada enemigo en el espejo, linea a linea.
# COMO PRUEBA (tools/prueba_town_crias_red.tscn, prueba = true): sin ventana, menos turnos, y comprueba en el espejo que
# ninguna cria se ve antes de caer de su vuelo (antes salian formadas y andando) y que todas nacen a tiempo (las del Rey
# se quedaban escondidas toda la pelea).
#   godot --headless --path . res://tools/prueba_town_crias_red.tscn -- nube_local
extends "res://tools/prueba_town_sala_comun.gd"

@export var prueba: bool = false

const TURNOS_CRIAS := 6       # turnos tuyos que pasas despues de que salgan las crias
const T_NACER_PRUEBA := 3.0   # (prueba) de que llega su cuerpo a que se levanta, como mucho
const T_ESCENA_S := 120.0

var _salir: bool = OS.get_environment("VER_SALIR") != ""
var _mal: int = 0
var _crias: Dictionary = {}   # (prueba) Combatant -> {t0, nacida, vista_antes}
var _comprobadas: Dictionary = {}   # (prueba) las ya contadas: la pantalla vieja sigue un rato
var _al_empezar: Dictionary = {}   # (prueba) pantalla -> los enemigos que tenia al empezar (los demas son crias)


func _ready() -> void:
	if prueba:
		_salir = true
	call_deferred("_empezar")


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


# (prueba) Cada fotograma, en el espejo: las que no estaban al empezar la pelea son crias. No se pueden ver hasta que se
# levantan ('nacer', al caer de su vuelo), y eso tiene que pasar poco despues de que llegue su cuerpo.
func _vigilar(p: Node) -> void:
	if p == null or not p.tactico or not p._espejo:
		return
	var tm = p.turno_mapa
	var ahora: float = Time.get_ticks_msec() / 1000.0
	if not _al_empezar.has(p):
		# Los de al empezar y SUS CUERPOS: la cria que estrena el hueco del brotado apunta un instante a su cuerpo
		# (muriendose), y eso no es la cria.
		_al_empezar[p] = p._enemies.duplicate() + p._enemies.map(func(e): return tm.cuerpo_de(e))
	for e in p._enemies:
		if e == null or e in _al_empezar[p]:
			continue
		var cu: Node2D = tm.cuerpo_de(e)
		if cu == null or cu in _al_empezar[p]:
			continue
		if _comprobadas.has(e) or (not _crias.has(e) and not e.is_alive()):
			continue
		if not _crias.has(e):
			_crias[e] = {"t0": ahora, "nacida": -1.0, "vista_antes": "", "nombre": e.nombre}
		var r: Dictionary = _crias[e]
		if float(r["nacida"]) >= 0.0:
			continue
		for d in tm._deslices:
			if d["c"] == e and bool(d.get("cria", false)):
				r["hasta"] = Vector2(d["hasta"])
		var sp = cu.get("_sprite")
		if sp is AnimatedSprite2D and String(sp.animation).begins_with("nacer"):
			r["nacida"] = ahora - float(r["t0"])
			r["donde"] = cu.global_position
		elif cu.visible and cu.modulate.a > 0.01 and e.is_alive() and String(r["vista_antes"]) == "":
			r["vista_antes"] = "a los %.2f s, %s en %s, a=%.2f" % [ahora - float(r["t0"]),
				String(sp.animation) if sp is AnimatedSprite2D else "-", str(cu.global_position.round()), cu.modulate.a]


func _comprobar_crias(titulo: String) -> void:
	_ver(not _crias.is_empty(), "%s: salen crias en el espejo (%d)" % [titulo, _crias.size()])
	var ahora: float = Time.get_ticks_msec() / 1000.0
	for e in _crias:
		var r: Dictionary = _crias[e]
		# Una que acaba de llegar (un Brote justo al acabar) aun esta en el aire: no cuenta.
		if float(r["nacida"]) < 0.0 and ahora - float(r["t0"]) < T_NACER_PRUEBA:
			print("  (%s: llego hace %.2f s, aun en su vuelo)" % [r["nombre"], ahora - float(r["t0"])])
			continue
		_ver(String(r["vista_antes"]) == "", "%s: %s no se ve antes de caer de su vuelo%s" % [titulo, r["nombre"],
			"" if String(r["vista_antes"]) == "" else " (se vio %s)" % r["vista_antes"]])
		if r.has("hasta") and r.has("donde"):
			var lejos: float = Vector2(r["donde"]).distance_to(Vector2(r["hasta"]))
			_ver(lejos < 6.0, "%s: %s se levanta donde cae su bola (a %.0f px)" % [titulo, r["nombre"], lejos])
		else:
			_ver(false, "%s: %s sin vuelo o sin levantarse" % [titulo, r["nombre"]])
		_ver(float(r["nacida"]) >= 0.0 and float(r["nacida"]) <= T_NACER_PRUEBA,
			"%s: %s se levanta a tiempo (%.2f s desde que llega su cuerpo; llego hace %.1f s)" % [titulo, r["nombre"],
			float(r["nacida"]), ahora - float(r["t0"])])
	for e in _crias:
		_comprobadas[e] = true
	_crias.clear()


func _empezar() -> void:
	reparent(get_tree().root)
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Mira lo que se ve DESPUES de que el juego mueva sus cosas en el fotograma (el cuerpo de una cria nace visible y la
	# pelea lo esconde en su _process: mirandolo antes, saldria "vista" sin haberse llegado a pintar).
	process_priority = 100000
	var hueco := Node.new()
	get_tree().root.add_child(hueco)
	get_tree().current_scene = hueco
	_correr()


func _process(_delta: float) -> void:
	if Net.activo and Net.peleas.espejando():
		_traza(Net.peleas._pantalla_combate(), Time.get_ticks_msec() / 1000.0)
		if prueba:
			_vigilar(Net.peleas._pantalla_combate())


func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout


func _correr() -> void:
	slot = 82
	puerto = 24616
	# Un solo personaje en el grupo (ver la cabecera), por la sala de su ranura.
	if not preparar_mundo(["Agirato ochinan"], CASA_A, [], CASA_B) or not await abrir_sala_y_entrar():
		_ver(false, "entro en la sala")
		await _acabar_sala()
		return
	# UN ARMA CHETADA (lo propuso el, 13/10): una espada larga T3 pristina +15, para rematar rapido al brotado y a las
	# crias (con el baston de la partida de referencia la pelea del brotado se iba a mas de un minuto).
	Game.equipar_arma(load("res://resources/weapons/espada_larga.tres") as WeaponData)
	Game.lider().equip_meta["main"] = {"tier": 3, "rareza": Upgrades.RAREZA_SLOTS.size() - 1,
		"mejoras": {Upgrades.AGUDEZA: 15}, "durabilidad": 1.0, "banda": 0}
	var t := 0.0
	while dato_sala("trabajadores") == "" and t < 40.0:
		await _esperar(0.5)
		t += 0.5
	print("[ver] trabajadores de la sala listos en %.1f s" % t)
	Game.entrar_arena_de_pruebas()
	t = 0.0
	while (get_tree().get_first_node_in_group("dungeon_floor") == null or not Game.es_arena()) and t < 30.0:
		await _esperar(0.5)
		t += 0.5
	await _esperar(3.0)
	Cargando.ocultar()
	print("[ver] en la arena (dueño del piso: %s; 1 = la sala)" % dato_sala("dueno_piso_%d" % Game.PISO_ARENA))
	var que: String = OS.get_environment("VER_SOLO")
	if que in ["", "brotado"]:
		await _escena("SLIME BROTADO", "res://scenes/actors/enemy/slime.tres", {"mutacion": "brotado"}, true)
	if que == "":
		await _vaciar_arena()
	if que in ["", "rey"]:
		await _escena("REY SLIME", "res://scenes/actors/enemy/rey_slime.tres", {}, false)
	print("[ver] FIN")
	if prueba:
		print("FIN: TODO BIEN" if _mal == 0 else "FIN: %d MAL" % _mal)
	if _salir:
		await _acabar_sala()


# Me voy, la sala se cierra sola (con sus trabajadores) y se borra la ranura de prueba.
func _acabar_sala() -> void:
	var pids: Array = Array(dato_sala("pids_trab").split(",", false)).map(func(x): return int(x))
	Net.desconectar()
	var t := 0.0
	while OS.is_process_running(_pid_sala) and t < 20.0:
		await _esperar(0.5)
		t += 0.5
	for pid in [_pid_sala] + pids:
		if proceso_vivo(pid):
			OS.kill(pid)
	if _nube_id != "":
		await Nube.partida_borrar(_nube_id)
	_borrar_ranura()
	get_tree().quit(0 if _mal == 0 else 1)


func _pelea_libre_arena() -> int:
	return int(dato_sala("pelea_libre_%d" % Game.PISO_ARENA))


# En la prueba la pelea TIENE que ir por el trabajador (lo que se mira es el espejo): si cae en mi PC, otra vez.
func _escena(titulo: String, ruta: String, muneco: Dictionary, pegarle: bool) -> void:
	for intento in 3:
		if await _escena_una(titulo, ruta, muneco, pegarle) or not prueba:
			return
		print("[ver] la pelea no fue por el trabajador: otra vez")
		await _vaciar_arena()
	_ver(false, "%s: la pelea va por el trabajador" % titulo)


# Devuelve false si la pelea se monto en mi PC (no hay espejo que mirar).
func _escena_una(titulo: String, ruta: String, muneco: Dictionary, pegarle: bool) -> bool:
	print("[ver] ===== %s =====" % titulo)
	var tc := 0.0
	while (Game.hay_pelea_en_pantalla() or Net.peleas._desgaste_pendiente) and tc < 10.0:
		await _esperar(0.25)
		tc += 0.25
	# Como en el juego: la pelea la monta el trabajador DE PELEA que espera en el piso (si no lo hay aun, iria en mi PC).
	var tw := 0.0
	while _pelea_libre_arena() == 0 and tw < 30.0:
		await _esperar(0.5)
		tw += 0.5
	print("[ver] trabajador de pelea esperando en la arena: %d (%.1f s)" % [_pelea_libre_arena(), tw])
	# Recien llegado aun no conoce los enemigos del piso: rechazaria la pelea ("0 de 1 bichos") y la montaria yo.
	if tw > 0.0:
		await _esperar(3.0)
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var antes: Array = Net.enemigos._enem_nodos.keys()
	# Lejos de mi (que no me vea y me embista mientras el trabajador de pelea se entera de que existe).
	var sala_px: Vector2 = jug.global_position + Vector2(0, 160)
	var piso: Node = get_tree().get_first_node_in_group("dungeon_floor")
	if piso != null:
		var sala: Rect2i = piso.gen.salas[0]
		var c: float = float(DungeonGenerator.CELDA)
		sala_px = Vector2(sala.position.x + 6, sala.end.y - 4) * c
		jug.recolocar(Vector2(sala.end.x - 6, sala.position.y + 4) * c)
	Net.pisos.pedir_spawn_arena(ruta, sala_px, muneco)
	var presa: Node2D = null
	var t := 0.0
	while presa == null and t < 10.0:
		for nid in Net.enemigos._enem_nodos:
			var n = Net.enemigos._enem_nodos[nid]
			if nid not in antes and is_instance_valid(n) and not n.esta_muerto():
				presa = n
		await _esperar(0.25)
		t += 0.25
	if presa == null:
		print("[ver] MAL: no aparece el enemigo pedido")
		_mal += 1
		return true
	print("[ver] aparece %s (mutacion '%s')" % [presa.name, str(presa.get("mutacion"))])
	# Que el trabajador de pelea ya lo tenga apuntado (recien nacido, con 1 s decia "0 de 1 bichos" y la montaba yo).
	await _esperar(4.0)
	# Le ataco YO nada mas llegar: si me embiste el primero, en esta rama la pelea se monta en mi PC (A1, arreglado en
	# fix/peleas-red) y no se veria el espejo, que es lo que falla.
	jug.recolocar(presa.global_position + Vector2(0, -110))
	presa.atacado_por_jugador(0.3)
	t = 0.0
	while not Game.hay_pelea_en_pantalla() and t < 10.0:
		await _esperar(0.25)
		t += 0.25
	var p: Node = Net.peleas._pantalla_combate()
	if p == null:
		print("[ver] MAL: no se abre la pelea")
		_mal += 1
		return true
	print("[ver] pelea abierta (la ejecuta el trabajador %d; aqui, espejo: %s)" % [Net.peleas._pelea_anfitrion,
		str(Net.peleas.espejando())])
	await _esperar(1.0)
	Cargando.ocultar()
	if prueba and not Net.peleas.espejando():
		await _huir(p)
		return false
	# A JUGAR: le pego al brotado hasta que cae; despues (y con el Rey, desde el principio) solo paso turnos.
	var pasados: int = 0
	var vistas: int = 1
	t = 0.0
	while is_instance_valid(p) and not p.acabada() and t < T_ESCENA_S and pasados < _turnos():
		p = _pantalla(p)
		var vivos: Array = p._enemies.filter(func(e): return e.is_alive())
		if vivos.size() != vistas:
			print("[ver] %.1f s: en la pelea %d enemigos vivos: %s" % [t, vivos.size(), ", ".join(vivos.map(func(e): return e.nombre))])
			vistas = vivos.size()
		var brotado_vivo: bool = vivos.any(func(e): return String(e.get("mutacion")) == "brotado")
		var crias: bool = vivos.size() > 1
		if int(p.get("_state")) == 1 and not _caja_abierta(p):
			if pegarle and brotado_vivo:
				await _pegar(p)
			elif _pasar(p) and crias:
				pasados += 1
				print("[ver] %.1f s: paso mi turno (%d de %d)" % [t, pasados, _turnos()])
		await _esperar(0.25)
		t += 0.25
	# El brotado: remato a las crias (que se vea tambien como les pega uno) y la pelea acaba limpia.
	t = 0.0
	while pegarle and is_instance_valid(p) and not p.acabada() and t < 120.0:
		p = _pantalla(p)
		if int(p.get("_state")) == 1 and not _caja_abierta(p):
			await _pegar(p)
		await _esperar(0.25)
		t += 0.25
	if prueba:
		_comprobar_crias(titulo)
	print("[ver] %s: la pelea %s" % [titulo, "acaba" if is_instance_valid(p) and p.acabada() else "sigue (huyo)"])
	await _esperar(2.0)
	# Fuera de la pelea: huyo (desde el borde) o, si acabo, Continuar. Y la arena limpia para la siguiente.
	if is_instance_valid(p) and p.acabada():
		p._on_continue_pressed()
	else:
		await _huir(p)
	t = 0.0
	while (Game.hay_pelea_en_pantalla() or Net.peleas._desgaste_pendiente) and t < 10.0:
		await _esperar(0.25)
		t += 0.25
	Net.pisos.pedir_limpiar_arena()
	return true


# LA ARENA VACIA para la siguiente escena: si no, lo que quede vivo se mete en la pelea de la otra.
func _vaciar_arena() -> void:
	var t := 0.0
	while _vivos_sueltos() > 0 and t < 15.0:
		Net.pisos.pedir_limpiar_arena()
		await _esperar(1.0)
		t += 1.0
	if _vivos_sueltos() > 0:
		print("[ver] MAL: la arena no se queda vacia (%d vivos)" % _vivos_sueltos())
		_mal += 1
	await _esperar(1.0)


func _vivos_sueltos() -> int:
	var n: int = 0
	for nid in Net.enemigos._enem_nodos:
		var e = Net.enemigos._enem_nodos[nid]
		if is_instance_valid(e) and not e.esta_muerto():
			n += 1
	return n


# LA TRAZA DE LAS CRIAS en el espejo (VER_TRAZA=1): una linea cada vez que cambia lo que se ve de cada enemigo.
var _ult_traza: Dictionary = {}

func _traza(p: Node, t: float) -> void:
	if OS.get_environment("VER_TRAZA") == "" or p == null:
		return
	var tm = p.turno_mapa
	for i in p._enemies.size():
		var e: Combatant = p._enemies[i]
		if e == null:
			continue
		var cu: Node2D = tm.cuerpo_de(e)
		var linea: String
		if cu == null:
			linea = "sin cuerpo"
		else:
			var sp = cu.get("_sprite")
			var anim: String = "%s:%d%s" % [sp.animation, sp.frame, "" if sp.is_playing() else "(quieto)"] if sp is AnimatedSprite2D else "-"
			var desl: String = ""
			for d in tm._deslices:
				if d["c"] == e:
					desl = " desliz(t=%.2f tope=%s espera=%.2f)" % [float(d["t"]), str(d["tope"]), float(d["espera"])]
			linea = "visible=%s a=%.2f pos=%s anim=%s%s%s sin_formar=%s" % [cu.visible, cu.modulate.a,
				str(cu.global_position.round()), anim, desl, " por_nacer" if tm._por_nacer.has(e) else "",
				tm.cria_sin_formar(cu)]
		var clave: String = "%d" % i
		if _ult_traza.get(clave, "") != linea:
			_ult_traza[clave] = linea
			print("[traza] %.2f %d %s: %s" % [t, i, e.nombre, linea])


# La pantalla de la pelea de AHORA (la del espejo se rehace al llegar la pelea del trabajador).
func _pantalla(p: Node) -> Node:
	var q: Node = Net.peleas._pantalla_combate()
	return q if q != null else p


# Atacar; si no llega, se acerca y lo vuelve a intentar; y si tampoco, pasa (si no, la pelea se queda esperandome).
func _pegar(p: Node) -> void:
	if _pulsar(p, 0):
		return
	await _andar_hacia_objetivo(p)
	await get_tree().process_frame
	if int(p.get("_state")) == 1 and not _caja_abierta(p) and not _pulsar(p, 0):
		_pasar(p)


func _caja_abierta(p: Node) -> bool:
	for caja in ["_cast_box", "_ability_box", "_objeto_box", "_spell_box"]:
		var c: Control = p.get(caja)
		if c != null and c.visible:
			return true
	return false


func _pulsar(p: Node, id: int) -> bool:
	var b: BaseButton = (p.get("_action_buttons") as Dictionary).get(id)
	if b == null or b.disabled or not b.is_visible_in_tree():
		return false
	b.pressed.emit()
	return true


# PASAR: en mitad de la zona, Huir es Pasar; si estoy en el borde, Defender.
func _pasar(p: Node) -> bool:
	if p._huir_es_pasar():
		return _pulsar(p, 5)
	return _pulsar(p, 3)


func _huir(p: Node) -> void:
	var t := 0.0
	while is_instance_valid(p) and not p.acabada() and Game.hay_pelea_en_pantalla() and t < 20.0:
		if int(p.get("_state")) == 1 and not _caja_abierta(p):
			var tm = p.turno_mapa
			if tm._fase == tm.Fase.MOVIENDO and is_instance_valid(tm._cuerpo) and not tm.en_el_borde():
				for k in 24:
					var q: Vector2 = tm._inicio + Vector2.RIGHT.rotated(TAU * k / 24.0) * (tm._radio - 4.0)
					if tm._puede_estar(q, tm._cuerpo) and tm._en_arena(q):
						tm._colocar(tm._quien, tm._cuerpo, q)
						break
			_pulsar(p, 5)
		await _esperar(0.25)
		t += 0.25


func _andar_hacia_objetivo(p: Node) -> void:
	var tm = p.get("turno_mapa")
	if tm == null or tm._fase != tm.Fase.MOVIENDO or not is_instance_valid(tm._cuerpo):
		return
	var antes: Vector2 = tm._cuerpo.global_position
	var mejor: Node2D = null
	for e in p._enemies:
		var ce: Node2D = tm.cuerpo_de(e) if e.is_alive() else null
		if ce != null and (mejor == null or ce.global_position.distance_to(antes) < mejor.global_position.distance_to(antes)):
			mejor = ce
	if mejor == null:
		return
	for r in [22.0, 30.0, 40.0, 60.0]:
		for k in 12:
			var q: Vector2 = mejor.global_position + Vector2.RIGHT.rotated(TAU * float(k) / 12.0) * r
			if q.distance_to(tm._inicio) <= tm._radio and tm._puede_estar(q, tm._cuerpo) and tm._en_arena(q):
				tm._colocar(tm._quien, tm._cuerpo, q)
				return
	# Ni a tiro de un paso: hasta el borde de mi circulo, hacia el.
	var q2: Vector2 = tm._inicio + (mejor.global_position - tm._inicio).normalized() * (tm._radio - 4.0)
	if tm._puede_estar(q2, tm._cuerpo):
		tm._colocar(tm._quien, tm._cuerpo, q2)


# Turnos que pasas con las crias en juego (VER_TURNOS=N lo cambia).
func _turnos() -> int:
	var n: int = int(OS.get_environment("VER_TURNOS"))
	return n if n > 0 else (2 if prueba else TURNOS_CRIAS)
