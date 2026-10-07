# BD FASE 4: LA MAZMORRA VIVA sobrevive a cerrar el juego (un jugador y mundo compartido).
#   godot --headless --path . res://tools/prueba_bd_mazmorra_viva.tscn
# Sin red ni ficheros de verdad (la BD va a user://prueba_mazmorra_viva.sqlite y se borra). Mira:
#   1. UN JUGADOR: guardas en el pueblo con dos pisos recordados -> al cargar vuelven LOS DOS (antes solo
#      el que pisabas) y vuelves a tu calle del pueblo;
#   2. MUNDO: lo que la sala llevaba en memoria (pisos congelados, el piso que simula un trabajador, lo
#      tirado, jefes, vetas, donde estaba cada jugador) va al guardado, pasa por la BD y se siembra igual;
#   3. sin sesion (antes de abrir la sala), guardar vuelve a escribir lo que vino: no se pierde;
#   4. las posiciones sueltas (cada 5 s) escriben solo sus filas, y el guardado entero despues no las reescribe.
extends Node

const RUTA := "user://prueba_mazmorra_viva.sqlite"
var fallos := 0


func ok(c: bool, t: String) -> void:
	print(("  OK   " if c else "  MAL: ") + t)
	if not c:
		fallos += 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Perfil.nube_activa = false
	call_deferred("_correr")


# Ida y vuelta por la BD de verdad (filas en un fichero), como al cerrar y abrir el juego.
func _por_la_bd(d: SaveData) -> SaveData:
	PartidaBD.borrar(RUTA)
	var bd := PartidaBD.new()
	bd.abrir(RUTA)
	bd.escribir(BDFilas.a_filas(d, BDFilas.Ids.new()))
	bd.cerrar()
	bd = PartidaBD.new()
	bd.abrir(RUTA)
	var v: SaveData = BDFilas.de_filas(bd.leer(), BDFilas.Ids.new())
	bd.cerrar()
	return v


func _correr() -> void:
	print("--- 1. un jugador")
	Game.nueva_partida("Viva", {})
	Game.memoria_pisos = {2: {"enemigos": [{"pos": Vector2(1, 2)}]}, 3: {"enemigos": [], "suelo": [{"x": 1}]}}
	var d: SaveData = Game.exportar_partida()
	d.pos_jugador = Vector2(321, 456)   # sin escena no hay jugador: su calle del pueblo, a mano
	var v: SaveData = _por_la_bd(d)
	Game.memoria_pisos = {}
	Game.importar_partida(v)
	ok(Game.memoria_pisos.has(2) and Game.memoria_pisos.has(3), "vuelven los dos pisos: %s" % str(Game.memoria_pisos.keys()))
	ok(Game.pos_cargada_pueblo == Vector2(321, 456), "y vuelves a tu calle del pueblo: %s" % str(Game.pos_cargada_pueblo))

	print("--- 2. mundo compartido: lo de la sala")
	Game.nueva_partida("Sala", {})
	Game.mundo_compartido = true
	Net.activo = true
	Net.es_host = true
	Net.mundo_compartido = true
	Net._fotos_piso = {4: {"enemigos": [{"pos": Vector2(5, 6), "hp": 12.5}]}}
	Net._fotos_vivas = {5: {"enemigos": [{"pos": Vector2(7, 8)}]}, 6: {"enemigos": []}}
	Net._dueno_piso = {5: 99}   # el 5 lo simula un trabajador; el 6 ya no tiene dueño: su foto viva no vale
	Net.suelo._suelo = {7: {"d": {"t": "mat", "ruta": "res://x.tres", "calidad": 1, "cm": 0.0}, "pos": Vector2(1, 1), "lugar": "piso:4"},
		8: {"d": {"t": "cri", "categoria": 2, "calidad": 0}, "pos": Vector2(2, 2), "lugar": "pueblo"}}
	Net.suelo._next_id = 9
	Net.jefes._bosses_sello = {6: 1791380000.0}
	Net.recoleccion._nonces_sesion = {Vector3i(2, 3, 4): 99}
	Net._identidades = {50: "aaaaaaaaaaaaaaaaaaaaaaaa", 51: "bbbbbbbbbbbbbbbbbbbbbbbb"}
	Net._peers = {50: {"lugar": "piso:4", "pos": Vector2(100, 200)}, 51: {"lugar": "pueblo", "pos": Vector2(30, 40)}}
	Net._posiciones = {"cccccccccccccccccccccccc": {"lugar": "pueblo", "pos": Vector2(9, 9)}}   # uno que ya se fue
	d = Game.exportar_partida()
	var n_fotos: int = d.sesion_fotos_piso.size()
	ok(d.sesion_fotos_piso.has(4) and d.sesion_fotos_piso.has(5) and not d.sesion_fotos_piso.has(6),
		"pisos congelados y el vivo del trabajador (no el que ya no tiene dueño): %s" % str(d.sesion_fotos_piso.keys()))
	ok(d.posiciones.size() == 3, "las posiciones de los tres (dos conectados, uno que se fue): %d" % d.posiciones.size())
	v = _por_la_bd(d)
	# "Cerrar la sala" y abrir otra.
	Net._fotos_piso = {}
	Net._fotos_vivas = {}
	Net._dueno_piso = {}
	Net.suelo._suelo = {}
	Net.suelo._next_id = 1
	Net.jefes._bosses_sello = {}
	Net.recoleccion._nonces_sesion = {}
	Net._posiciones = {}
	Net._peers = {}
	Net._identidades = {}
	Game.importar_partida(v)
	Net.pisos.sembrar_sesion(Game.sesion_guardada)
	ok(Net._fotos_piso.size() == n_fotos and Net._fotos_piso.has(4) and Net._fotos_piso.has(5), "pisos congelados al abrir: %s" % str(Net._fotos_piso.keys()))
	ok(var_to_str(Net._fotos_piso.get(4)) == var_to_str({"enemigos": [{"pos": Vector2(5, 6), "hp": 12.5}]}), "la foto del 4 igual")
	ok(Net.suelo._suelo.size() == 2 and Net.suelo._next_id == 9, "lo tirado (%d) y el siguiente id (%d)" % [Net.suelo._suelo.size(), Net.suelo._next_id])
	ok(float(Net.jefes._bosses_sello.get(6, 0.0)) == 1791380000.0, "el jefe del 6 sigue muerto con su reloj")
	ok(int(Net.recoleccion._nonces_sesion.get(Vector3i(2, 3, 4), 0)) == 99, "el nonce de la veta")
	ok(String(Net._posiciones.get("aaaaaaaaaaaaaaaaaaaaaaaa", {}).get("lugar", "")) == "piso:4"
		and Net._posiciones.get("aaaaaaaaaaaaaaaaaaaaaaaa", {}).get("pos") == Vector2(100, 200), "Ana estaba en el piso 4, en su sitio")
	ok(Net._posiciones.has("cccccccccccccccccccccccc"), "y el que ya se habia ido, donde lo dejo")

	print("--- 3. guardar antes de abrir la sala")
	Net.activo = false
	Net.es_host = false
	d = Game.exportar_partida()
	ok(d.sesion_fotos_piso.has(4) and d.sesion_suelo.size() == 2 and d.posiciones.size() == 3,
		"sin sesion se vuelve a escribir lo que vino")

	print("--- 4. posiciones sueltas")
	PartidaBD.borrar(RUTA)
	var bd := PartidaBD.new()
	bd.abrir(RUTA)
	bd.rastrear = true
	bd.olvidar_nube()
	bd.escribir(BDFilas.a_filas(d, BDFilas.Ids.new()))
	bd.marcar_subido(bd.rev, 1)
	d.posiciones["aaaaaaaaaaaaaaaaaaaaaaaa"] = {"lugar": "pueblo", "pos": Vector2(1, 1)}
	var filas := {"posiciones": var_to_str({"§partido": true})}
	for ident in d.posiciones:
		filas["posiciones/" + var_to_str(ident)] = var_to_str(d.posiciones[ident])
	ok(bd.escribir_campos(filas) == 1, "se mueve uno: 1 fila")
	ok(bd.contar_sin_subir() == 1, "y queda apuntada para la nube")
	ok(bd.escribir(BDFilas.a_filas(d, BDFilas.Ids.new())) == 0, "el guardado entero despues no la reescribe")
	bd.cerrar()
	PartidaBD.borrar(RUTA)

	Net.activo = false
	Net.es_host = false
	Net.mundo_compartido = false
	Game.mundo_compartido = false
	print("FIN: TODO BIEN" if fallos == 0 else "FIN: %d MAL" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)
