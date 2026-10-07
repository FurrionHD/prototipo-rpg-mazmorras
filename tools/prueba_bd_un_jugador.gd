# BD FASE 3: LAS PARTIDAS DE UN JUGADOR EN LA NUBE (Perfil + Nube + servidor/nube, cuenta y partidas).
#   godot --headless --path . res://tools/prueba_bd_un_jugador.tscn -- nube_local
#   godot --headless --path . res://tools/prueba_bd_un_jugador.tscn -- nube_url=http://127.0.0.1:8787
#   (lo segundo con `npx wrangler dev --port 8787 --ip 127.0.0.1` en servidor/nube; NUNCA la nube de verdad)
# Usa la RANURA 97 y las que se bajen de la nube (las borra todas al acabar, tambien de la nube). Mira:
#   1. subir: la primera entera, despues solo lo cambiado; sale en tu cuenta;
#   2. OTRO PC: la partida sale "en la nube", se baja a una ranura nueva igual que se subio;
#   3. una copia vieja sin cambios: al cargar se baja solo lo cambiado;
#   4. CONFLICTO (cambio aqui y en otro PC): se detecta al cargar; "aqui" la sube entera (la de la nube a
#      su historial), "nube" la baja (la de aqui a respaldos/conflictos);
#   5. otra clave no lee tu cuenta;
#   6. borrada desde otro PC: la copia que queda vuelve a subir entera.
extends Node

const SLOT := 97

var fallos := 0
var _creadas: Array = []


func ok(c: bool, t: String) -> void:
	print(("  OK   " if c else "  MAL: ") + t)
	if not c:
		fallos += 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_correr")


func _dinero(slot: int) -> int:
	var d: SaveData = Perfil.cabecera_ligera(slot)
	return -1 if d == null else int(PartidaBD.inspeccionar_ruta(Perfil.ruta_bd(slot))["datos"].money)


# Cambiar el dinero de una ranura como si se jugara: cargar, tocar, guardar.
func _jugar(slot: int, dinero: int) -> void:
	Perfil.cargar(slot)
	Game.money = dinero
	Perfil.guardar(slot)


# "Cerrar el juego" en este PC: soltar la BD abierta de Perfil (para poder tocar sus ficheros).
func _soltar() -> void:
	Perfil._cerrar_bd()
	Perfil.ranura_actual = 0


func _correr() -> void:
	if Nube.es_remota() and not String(Nube.almacen.url).begins_with("http://127.0.0.1"):
		print("Esta prueba va con `-- nube_local` o con `-- nube_url=http://127.0.0.1:8787` (wrangler dev): NUNCA contra la nube de verdad.")
		get_tree().quit(1)
		return
	Perfil.nube_activa = true
	_limpiar_slot(SLOT)
	print("--- 1. subir")
	Game.nueva_partida("Uno", {})
	Game.money = 100
	ok(Perfil.guardar(SLOT), "partida en la ranura %d" % SLOT)
	var pid: String = Perfil.nube_id(SLOT)
	ok(pid.length() == 24, "con su codigo de nube %s" % pid)
	var r: Dictionary = await Perfil.subir_nube(SLOT)
	ok(r.get("ok", false) and int(r.get("rev", 0)) == 1, "primera subida, entera: %d filas (rev %d) %s" % [
		int(r.get("subidas", 0)), int(r.get("rev", 0)), str(r.get("mensaje", ""))])
	Game.money = 110
	Perfil.guardar(SLOT)
	r = await Perfil.subir_nube(SLOT)
	ok(r.get("ok", false) and int(r.get("rev", 0)) == 2 and int(r.get("subidas", 99)) <= 5,
		"+10 de dinero: %d filas (rev %d)" % [int(r.get("subidas", 0)), int(r.get("rev", 0))])
	r = await Perfil.subir_nube(SLOT)
	ok(bool(r.get("nada", false)), "sin cambios no se habla con la nube")
	ok(not Perfil.sin_subir(SLOT), "sin nada por subir")
	ok(await Perfil.mirar_nube() and int(Perfil.en_nube.get(pid, {}).get("rev", 0)) == 2, "en tu cuenta, rev 2")
	ok(String(Perfil.en_nube.get(pid, {}).get("meta", {}).get("nombre", "")) == "Uno", "con su nombre en la cuenta")
	_soltar()
	var copia: String = "user://prueba_un_jugador_copia.sqlite"
	_copiar(Perfil.ruta_bd(SLOT), copia)

	print("--- 2. otro PC")
	PartidaBD.borrar(Perfil.ruta_bd(SLOT))   # SOLO el fichero de aqui (Perfil.borrar la quitaria de la nube)
	var nube: Array = Perfil.solo_en_nube()
	ok(nube.any(func(e): return e["id"] == pid), "sale en la lista como «en la nube»")
	var otro: int = await Perfil.bajar_de_nube(pid)
	_creadas.append(otro)
	ok(otro > 0 and _dinero(otro) == 110, "bajada a la ranura %d con su dinero (%d)" % [otro, _dinero(otro)])
	ok(not Perfil.solo_en_nube().any(func(e): return e["id"] == pid), "y ya no sale como «en la nube»")
	_jugar(otro, 150)
	r = await Perfil.subir_nube(otro)
	ok(r.get("ok", false) and int(r.get("rev", 0)) == 3, "el otro PC juega y sube (rev %d)" % int(r.get("rev", 0)))
	_soltar()

	print("--- 3. copia vieja sin cambios")
	_copiar(copia, Perfil.ruta_bd(SLOT))
	r = await Perfil.preparar_carga(SLOT)
	ok(r.get("ok", false) and _dinero(SLOT) == 150, "al cargar se pone al dia: dinero %d" % _dinero(SLOT))

	print("--- 4. conflicto")
	_jugar(SLOT, 1)          # aqui, sin subir
	_soltar()
	_jugar(otro, 4242)       # en el otro PC, y sube
	ok((await Perfil.subir_nube(otro)).get("ok", false), "el otro PC sube 4242")
	_soltar()
	ok(Perfil.sin_subir(SLOT), "aqui queda algo sin subir (icono ↑)")
	r = await Perfil.preparar_carga(SLOT)
	ok(bool(r.get("conflicto", false)), "al cargar: CONFLICTO")
	ok(int(r.get("aqui", {}).get("cab_dinero", -1)) == 1 and int(r.get("nube", {}).get("cab_dinero", -1)) == 4242,
		"enseña las dos: aqui %s, nube %s" % [str(r.get("aqui", {}).get("cab_dinero")), str(r.get("nube", {}).get("cab_dinero"))])
	ok(await Perfil.resolver_conflicto(SLOT, "aqui", int(r.get("rev_nube", 0))), "eliges la de aqui: sube entera")
	r = await Perfil.preparar_carga(otro)
	ok(r.get("ok", false) and _dinero(otro) == 1, "el otro PC la recibe: dinero %d" % _dinero(otro))
	# Y al reves: eliges la de la nube.
	_jugar(otro, 7)
	_soltar()
	_jugar(SLOT, 77)
	ok((await Perfil.subir_nube(SLOT)).get("ok", false), "aqui sube 77")
	_soltar()
	r = await Perfil.preparar_carga(otro)
	ok(bool(r.get("conflicto", false)), "en el otro PC: CONFLICTO")
	var antes: int = _ficheros(Perfil.RESPALDOS_CONFLICTO)
	ok(await Perfil.resolver_conflicto(otro, "nube", int(r.get("rev_nube", 0))), "eliges la de la nube")
	ok(_dinero(otro) == 77 and not Perfil.sin_subir(otro), "baja la de la nube: dinero %d" % _dinero(otro))
	ok(_ficheros(Perfil.RESPALDOS_CONFLICTO) == antes + 1, "la de aqui queda en respaldos/conflictos")

	print("--- 5. otra clave")
	var mala: Dictionary = await Nube.almacen.cuenta_lista(Identidad.id, "f".repeat(32))
	ok(String(mala.get("error", "")) == "no_autorizado", "otra clave no lee tu cuenta: %s" % str(mala.get("error", "")))

	print("--- 6. borrada desde otro PC")
	Perfil.borrar(otro)
	_creadas.erase(otro)
	await get_tree().create_timer(0.5).timeout
	ok(await Perfil.mirar_nube() and not Perfil.en_nube.has(pid), "borrada tambien de la nube")
	r = await Perfil.preparar_carga(SLOT)
	ok(r.get("ok", false), "la copia que queda se carga")
	r = await Perfil.subir_nube(SLOT)
	ok(r.get("ok", false) and int(r.get("rev", 0)) == 1, "y vuelve a subir entera (rev %d)" % int(r.get("rev", 0)))

	# Fuera todo (tambien de la nube).
	_soltar()
	for s in _creadas:
		Perfil.borrar(s)
	Perfil.borrar(SLOT)
	await get_tree().create_timer(0.5).timeout
	PartidaBD.borrar(copia)
	_quitar_respaldos(["slot_%d.tres" % SLOT, "slot_%d_" % SLOT])
	if otro > 3:   # proteccion extra: las de sus ranuras de siempre (1..3) nunca se tocan
		_quitar_respaldos(["slot_%d_" % otro])
	print("FIN: TODO BIEN" if fallos == 0 else "FIN: %d MAL" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)


func _limpiar_slot(slot: int) -> void:
	_soltar()
	PartidaBD.borrar(Perfil.ruta_bd(slot))
	if FileAccess.file_exists(Perfil.ruta(slot)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Perfil.ruta(slot)))
	if slot > 3:   # proteccion extra: las copias de sus ranuras de siempre (1..3) nunca se tocan
		_quitar_respaldos(["slot_%d.tres" % slot, "slot_%d_" % slot])


func _copiar(de: String, a: String) -> void:
	PartidaBD.borrar(a)
	DirAccess.copy_absolute(ProjectSettings.globalize_path(de), ProjectSettings.globalize_path(a))


func _ficheros(carpeta: String) -> int:
	var d := DirAccess.open(carpeta)
	return 0 if d == null else d.get_files().size()


# Lo que la partida de prueba dejo en las carpetas de respaldos (la copia de antes de migrar, las de los
# conflictos): son ficheros de la prueba, no del jugador, y sin esto se acumulan en cada pasada.
func _quitar_respaldos(prefijos: Array) -> void:
	for carpeta in [MigracionBD.RESPALDOS, "user://respaldos/conflictos"]:
		var abs_c: String = ProjectSettings.globalize_path(carpeta)
		if not DirAccess.dir_exists_absolute(abs_c):
			continue
		for f in DirAccess.get_files_at(abs_c):
			for pre in prefijos:
				if String(f).begins_with(String(pre)):
					DirAccess.remove_absolute(abs_c + "/" + f)
					break
