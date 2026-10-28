# ============================================================
#  MEDIR LOS TIRONES (plan de optimizacion, fase 1E): los fotogramas SUELTOS que se alargan, que son lo que se nota
#  aunque el fotograma normal vaya sobrado (ver medir_dibujo). Con ventana y sin vsync, con la partida de referencia:
#    1) entrar en el mundo;  2) atajo al 6 y escalera hasta el piso, y volver;  3) abrir tres peleas (y huir).
#  DESDE LA ETAPA 4 (28/10) entra COMO EL JUEGO: el jugador con su sala en otro Godot (tools/prueba_con_jugador.gd, ranura
#  85): viaja y pelea por la sala. Sin red el piso sale vacio. Va con -- nube_local.
#  De cada cosa: lo que tarda la llamada, el fotograma mas largo de despues y los que pasan de 20 ms.
#    godot --path . res://tools/medir_tirones.tscn -- nube_local --piso 8 > salida.txt
# OJO: la salida a un FICHERO, nunca por una tuberia (ver medir_fotograma.gd).
# No es una prueba (no esta en la bateria): es una herramienta de medida.
# ============================================================
extends Node

const TIRON_MS := 20.0


func _ready() -> void:
	call_deferred("_empezar")


func _empezar() -> void:
	reparent(get_tree().root)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hueco := Node.new()
	get_tree().root.add_child(hueco)
	get_tree().current_scene = hueco
	_correr()


func _arg(nombre: String, defecto: int) -> int:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = a.find(nombre)
	return int(a[i + 1]) if i >= 0 and i + 1 < a.size() else defecto


func _correr() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Game.semilla_mundo = 4016831469
	var piso: int = _arg("--piso", 8)
	var j = preload("res://tools/prueba_con_jugador.gd").new()
	add_child(j)

	# 1) EL PUEBLO. Primero, aparte, LEER la escena (y compilar sus scripts): lo que hace change_scene_to_file antes de
	# crear nada. Asi el cambio de escena de despues ya la encuentra leida y solo cuenta crear y montar.
	var tl: int = Time.get_ticks_usec()
	var _escena: PackedScene = load("res://scenes/levels/town.tscn")
	print("[TIRONES] leer town.tscn (load)          %6.1f ms" % (float(Time.get_ticks_usec() - tl) / 1000.0))
	# Entrar en el mundo: lanzar la sala, conectarse y cargar el pueblo (lo que se paga al darle a Jugar).
	var listo_arrancar := [false, false]   # [acabo, bien]
	await _tramo("entrar en el mundo (sala)", func():
		listo_arrancar[1] = await j.arrancar("medir_tirones", RANURA, 0)
		listo_arrancar[0] = true, func(): return listo_arrancar[0])
	if not listo_arrancar[1]:
		print("[TIRONES] no se pudo entrar en el mundo")
		await j.cerrar()
		get_tree().quit(1)
		return
	await _reposo(60)
	# 2) BAJAR AL PISO, como en el juego: el atajo del pueblo solo lleva al 1 o a un piso con jefe (net_pisos._conceder_entrada),
	# asi que pueblo -> 6 por el atajo y 6 -> 7 -> 8 por la escalera. Dos veces (la segunda ya tiene todo en memoria), y
	# volver al pueblo entre medias. El que se compara con la fase 1 ("bajar al piso 8") es el de la escalera al 8.
	for vez in 2:
		var cual: String = "1a vez" if vez == 0 else "2a vez"
		await _salir_de_pelea(j)
		await _tramo("atajo al piso %d (%s)" % [ATAJO, cual], func(): Net.pisos.solicitar_entrar(ATAJO),
			func(): return _en_piso(ATAJO))
		await _reposo(60)
		for p in range(ATAJO + 1, piso + 1):
			await _salir_de_pelea(j)
			await _tramo("escalera al piso %d (%s)" % [p, cual], func(): Net.pisos.solicitar_piso(p, true),
				func(): return _en_piso(p))
			await _reposo(60)
		if vez == 0:
			await _salir_de_pelea(j)
			await _tramo("volver al pueblo", func(): Net.pisos.viajar_al_pueblo(), _en_pueblo)
			await _reposo(60)
	# 3) TRES PELEAS SEGUIDAS: la primera paga lo de una vez (cargar la musica de pelea...); las otras, lo de siempre.
	# Cada una con el enemigo libre mas cercano. Se mide ABRIRLA; luego se huye (el guion no sabe andar y ganarla tarda).
	for vez in 3:
		await _salir_de_pelea(j)
		var presa: Node2D = _enemigo_cercano()
		if presa == null:
			print("[TIRONES] no hay enemigo para pelear")
			break
		await _tramo("abrir una pelea (%da)" % (vez + 1), func(): j.pelear_con(presa),
			func(): return j.pantalla() != null and Net.peleas.espejando())
		if not await _salir_de_pelea(j):
			print("[TIRONES] no pude salir de la pelea %d" % (vez + 1))
			break
		await _reposo(30)
	await j.cerrar()
	get_tree().quit(0)


const RANURA := 85   # la de esta herramienta (las pruebas de red usan 70-84 y 86-89)
const ATAJO := 6     # el piso con jefe mas cercano al 8 (Game.BOSSES)


# HUIR de la pelea que tenga en pantalla (si hay): en mi turno, el cuerpo al borde de la zona y el sexto boton, que ahi
# es Huir. En el ESPEJO la arena es la de la pantalla (turno_mapa._arena), no Game._arena_nodo: por eso no vale
# prueba_town_dos_comun.huir(), que solo la busca en Game. Devuelve si salio.
func _salir_de_pelea(j) -> bool:
	var t := 0.0
	while (Game.hay_pelea_en_pantalla() or Net.peleas.espejando()) and t < 60.0:
		var p: Node = j.pantalla()
		if p != null and p.tactico and int(p.get("_state")) == 1:
			var arena = p.turno_mapa._arena()
			var cuerpo = p.turno_mapa.get("_cuerpo")
			if arena != null and is_instance_valid(cuerpo):
				var tramo: Dictionary = arena._tramo_cercano(cuerpo.global_position)
				if not tramo.is_empty():
					var q: Vector2 = tramo["q"]
					cuerpo.global_position = q + (cuerpo.global_position - q).limit_length(2.0)
			j.pulsar(5)
		if p != null and p.acabada():
			p._on_continue_pressed()
		await j._esperar(0.25)
		t += 0.25
	return not Game.hay_pelea_en_pantalla()


func _en_piso(piso: int) -> bool:
	return Net._mi_lugar == "piso:%d" % piso and get_tree().get_first_node_in_group("dungeon_floor") != null 		and _hay_jugador()


func _en_pueblo() -> bool:
	var esc: Node = get_tree().current_scene
	return esc != null and esc.scene_file_path.ends_with("town.tscn") and _hay_jugador()


func _enemigo_cercano() -> Node2D:
	var jugador: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var mejor: Node2D = null
	var mejor_d: float = INF
	for nid in Net.enemigos._enem_nodos:
		var n = Net.enemigos._enem_nodos[nid]
		if not is_instance_valid(n) or n.esta_muerto() or int(n.get("pelea_de")) != 0:
			continue
		var d: float = (n as Node2D).global_position.distance_to(jugador.global_position)
		if d < mejor_d:
			mejor_d = d
			mejor = n
	return mejor


func _hay_jugador() -> bool:
	return get_tree().get_first_node_in_group("player") != null and not get_tree().paused


# Llama a 'accion', espera a que 'listo' diga que si y 60 fotogramas mas, y cuenta.
func _tramo(que: String, accion: Callable, listo: Callable) -> void:
	await get_tree().process_frame
	var t0: int = Time.get_ticks_usec()
	accion.call()
	var t_llamada: float = float(Time.get_ticks_usec() - t0) / 1000.0
	var fots: Array = []
	var t_ant: int = Time.get_ticks_usec()
	var hasta_listo: float = -1.0
	var despues: int = 0
	while float(Time.get_ticks_usec() - t0) < 60000000.0:
		await get_tree().process_frame
		var ahora: int = Time.get_ticks_usec()
		fots.append(float(ahora - t_ant) / 1000.0)
		t_ant = ahora
		if hasta_listo < 0.0 and listo.call():
			hasta_listo = float(ahora - t0) / 1000.0
		if hasta_listo >= 0.0:
			despues += 1
			if despues >= 60:
				break
	var largos: Array = []
	for i in fots.size():
		if fots[i] > TIRON_MS:
			largos.append("#%d %.0f" % [i, fots[i]])
	var peor: float = 0.0
	for f in fots:
		peor = maxf(peor, f)
	print("[TIRONES] %-28s llamada %6.1f ms | listo a los %6.1f ms | peor fotograma %6.1f ms | de mas de %.0f ms: %s" % [
		que, t_llamada, hasta_listo, peor, TIRON_MS, ", ".join(largos) if not largos.is_empty() else "ninguno"])


# Fotogramas normales: la mediana y el peor, para ver si queda algo coleando.
func _reposo(n: int) -> void:
	var fots: Array = []
	var t_ant: int = Time.get_ticks_usec()
	for i in n:
		await get_tree().process_frame
		var ahora: int = Time.get_ticks_usec()
		fots.append(float(ahora - t_ant) / 1000.0)
		t_ant = ahora
	fots.sort()
	print("[TIRONES]   y luego, quieto: mediana %.2f ms, peor %.1f ms" % [fots[n / 2], fots[n - 1]])
