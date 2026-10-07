# BD FASE 2: LOS MUNDOS EN LA NUBE COMO FILAS (Mundos + Nube + servidor/nube).
#   godot --headless --path . res://tools/prueba_bd_nube.tscn -- nube_local
#   godot --headless --path . res://tools/prueba_bd_nube.tscn -- nube_url=http://127.0.0.1:8787
#   (lo segundo con `npx wrangler dev --port 8787 --ip 127.0.0.1` en servidor/nube; NUNCA la nube de verdad)
#   HUELLA_FICHERO=<ruta a un .tres>  el mundo viejo que se migra (por defecto el de referencia)
# Mundos de prueba con id al azar, borrados al acabar (catalogo, BD y .tres). Mira:
#   1. un mundo nuevo nace en su BD; la primera subida va entera y las siguientes solo lo cambiado;
#   2. "otro PC" (sin copia local): se lo baja entero y sale con la MISMA huella que se guardo;
#   3. una copia vieja SIN cambios: se baja solo lo cambiado desde su rev;
#   4. CONFLICTO (la copia de aqui cambio sin subir y otro jugo encima): manda la nube y la de aqui va a
#      respaldos/conflictos;
#   5. subir desde un rev que no es el de la nube se rechaza (rev_distinto);
#   6. el historial: hay fotos y restaurar una vuelve a ella;
#   7. un mundo VIEJO en la nube (save entero): se migra al abrirlo y sube entero; el juego viejo ya no lo
#      abre; bajado de cero sale identico; y "legado" lo devuelve a como estaba.
extends Node

const PASS := "clave-prueba"
const POR_DEFECTO := "res://tools/huellas/mundo_ref.tres"
const COPIA := "user://prueba_bd_nube_copia.sqlite"

var fallos := 0


func ok(c: bool, t: String) -> void:
	print(("  OK   " if c else "  MAL: ") + t)
	if not c:
		fallos += 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_correr")


func _correr() -> void:
	if Nube.es_remota() and not String(Nube.almacen.url).begins_with("http://127.0.0.1"):
		print("Esta prueba va con `-- nube_local` o con `-- nube_url=http://127.0.0.1:8787` (wrangler dev): NUNCA contra la nube de verdad.")
		get_tree().quit(1)
		return
	print("almacen: ", "wrangler dev" if Nube.es_remota() else "local (user://nube_test)")
	var id: String = Nube.nuevo_id()
	var id2: String = Nube.nuevo_id()
	await _nuevo_y_otro_pc(id)
	await _legado(id2)
	_nube_vieja(id)
	_limpiar(id)
	_limpiar(id2)
	print("FIN: TODO BIEN" if fallos == 0 else "FIN: %d MAL" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)


func _alta(id: String) -> void:
	Mundos._escribir_entrada(id, {"nombre": "prueba bd nube", "mio": true, "id_nube": id,
		"contrasena": PASS, "direccion": "", "fecha": "", "cab": ""})


func _limpiar(id: String) -> void:
	if Mundos.abierto == id:
		Mundos.abandonar()
	Mundos.borrar(id)
	PartidaBD.borrar(COPIA)


# El dinero que hay en la BD de este disco (sin cargarla en Game).
func _dinero_en_disco(id: String) -> int:
	var d: SaveData = PartidaBD.inspeccionar_ruta(Mundos.ruta_bd(id))["datos"]
	return d.money if d != null else -1


func _rev_nube_en_disco(id: String) -> int:
	var bd := PartidaBD.new()
	bd.abrir(Mundos.ruta_bd(id))
	var r: int = bd.rev_nube()
	bd.cerrar()
	return r


func _copiar(de: String, a: String) -> void:
	PartidaBD.borrar(a)
	DirAccess.copy_absolute(ProjectSettings.globalize_path(de), ProjectSettings.globalize_path(a))


func _nuevo_y_otro_pc(id: String) -> void:
	print("--- 1. mundo nuevo")
	ok((await Nube.crear_mundo(id, PASS)).get("ok", false), "mundo creado en la nube")
	_alta(id)
	Game.nueva_partida("Ana", {})
	var r: Dictionary = await Mundos.abrir(id, PASS)
	ok(String(r.get("resultado", "")) == "nuevo", "abrir dice 'nuevo': %s" % str(r))
	ok(Mundos.estrenar(id), "estrenado")
	ok(Mundos.usa_bd(id), "nace en su base de datos")
	var s: Dictionary = await Mundos._subir_bd(false)
	ok(s.get("ok", false) and int(s.get("rev", 0)) == 1, "primera subida, entera: %d filas, rev %d" % [int(s.get("subidas", 0)), int(s.get("rev", 0))])
	Game.money += 7
	Mundos.guardar_actual()
	s = await Mundos._subir_bd(false)
	ok(s.get("ok", false) and int(s.get("rev", 0)) == 2 and int(s.get("subidas", 99)) <= 5,
		"+7 de dinero: suben %d filas (rev %d)" % [int(s.get("subidas", 0)), int(s.get("rev", 0))])
	s = await Mundos._subir_bd(false)
	ok(s.get("ok", false) and bool(s.get("nada", false)), "sin cambios no se habla con la nube")
	var dinero: int = Game.money
	ok((await Mundos.cerrar_y_subir()).get("ok", false), "cerrado y subido")
	# Lo que quedo en disco al cerrar (cerrar vuelve a guardar: la fecha puede pasar al segundo siguiente).
	var guardado: SaveData = PartidaBD.inspeccionar_ruta(Mundos.ruta_bd(id))["datos"]
	var est: Dictionary = await Nube.consultar(id, PASS)
	ok(String(est.get("formato", "")) == "bd" and int(est.get("bd_rev", 0)) == 2 and not bool(est.get("abierto", true)),
		"en la nube: formato bd, rev 2, sin cerrojo (%s, %d)" % [est.get("formato", ""), int(est.get("bd_rev", 0))])
	_copiar(Mundos.ruta_bd(id), COPIA)   # la copia de este disco en el rev 2, sin nada pendiente

	print("--- 2. otro PC: sin copia local")
	PartidaBD.borrar(Mundos.ruta_bd(id))
	r = await Mundos.abrir(id, PASS)
	ok(String(r.get("resultado", "")) == "host", "abre como host: %s" % str(r.get("mensaje", "")))
	ok(Mundos.cargar(id) and Game.money == dinero, "cargado con su dinero (%d)" % Game.money)
	var bajado: SaveData = PartidaBD.inspeccionar_ruta(Mundos.ruta_bd(id))["datos"]
	var dif: Array = HuellaSave.diferencias(HuellaSave.de(guardado), HuellaSave.de(bajado), 20)
	ok(dif.is_empty(), "bajado de la nube = lo guardado (huella) %s" % str(dif))
	Game.money += 5
	ok((await Mundos.cerrar_y_subir()).get("ok", false), "cerrado con +5 (rev 3)")

	print("--- 3. copia vieja sin cambios: solo lo cambiado")
	_copiar(COPIA, Mundos.ruta_bd(id))
	ok(_rev_nube_en_disco(id) == 2, "la copia de aqui parte del rev 2")
	r = await Mundos.abrir(id, PASS)
	ok(String(r.get("resultado", "")) == "host", "abre")
	ok(_rev_nube_en_disco(id) == 3 and _dinero_en_disco(id) == dinero + 5,
		"al dia: rev %d, dinero %d" % [_rev_nube_en_disco(id), _dinero_en_disco(id)])
	ok(Mundos.cargar(id), "cargado")
	ok((await Mundos.cerrar_y_subir()).get("ok", false), "cerrado sin cambios")

	print("--- 4. conflicto")
	# A: la copia de aqui con un cambio SIN subir (como un cierre que no llego a la nube).
	var bd := PartidaBD.new()
	bd.abrir(Mundos.ruta_bd(id))
	bd.rastrear = true
	var filas: Dictionary = bd.leer()
	filas["campos"]["money"] = var_to_str(1)
	bd.escribir(filas)
	ok(bd.hay_pendientes(), "la copia A tiene algo sin subir")
	bd.cerrar()
	_copiar(Mundos.ruta_bd(id), COPIA)
	# Mientras, otro PC juega encima.
	PartidaBD.borrar(Mundos.ruta_bd(id))
	await Mundos.abrir(id, PASS)
	Mundos.cargar(id)
	Game.money = 4242
	ok((await Mundos.cerrar_y_subir()).get("ok", false), "otro PC: dinero 4242 (rev 4)")
	_copiar(COPIA, Mundos.ruta_bd(id))
	var antes: int = _respaldos()
	r = await Mundos.abrir(id, PASS)
	ok(String(r.get("resultado", "")) == "host", "abre la copia A")
	ok(_dinero_en_disco(id) == 4242, "manda la nube: dinero %d" % _dinero_en_disco(id))
	ok(_respaldos() == antes + 1, "la copia A queda en respaldos/conflictos")
	Mundos.cargar(id)

	print("--- 5. subir desde otro rev")
	var mal: Dictionary = await Nube.sincronizar({"base": 1, "filas": [["campos", "x", "1"]]})
	ok(String(mal.get("error", "")) == "rev_distinto", "rechazado: %s" % str(mal.get("error", "")))

	print("--- 6. historial")
	var f: Dictionary = await Nube.fotos()
	var lista: Array = f.get("fotos", [])
	ok(f.get("ok", false) and lista.size() >= 2, "hay %d fotos" % lista.size())
	# La mas vieja es la del rev 1 (dinero 0).
	var vieja: Dictionary = lista[-1] if not lista.is_empty() else {}
	var rr: Dictionary = await Nube.restaurar(int(vieja.get("id", 0)))
	ok(rr.get("ok", false), "restaurada la foto del rev %d: %s" % [int(vieja.get("rev", 0)), str(rr.get("mensaje", ""))])
	Nube._olvidar()
	Mundos.abandonar()
	r = await Mundos.abrir(id, PASS)
	ok(String(r.get("resultado", "")) == "host" and _dinero_en_disco(id) == 0,
		"al reabrir esta la foto: dinero %d" % _dinero_en_disco(id))
	Mundos.cargar(id)
	ok((await Mundos.cerrar_y_subir()).get("ok", false), "cerrado")


# 8. Una nube que aun no sabe de bases de datos (su abrir no trae bd_rev): el mundo sigue con su .tres, y
# la copia de la BD de este disco vuelve a .tres sin perder nada.
func _nube_vieja(id: String) -> void:
	print("--- 8. nube sin base de datos (Worker sin publicar)")
	var dinero: int = _dinero_en_disco(id)
	var r: Dictionary = await Mundos._poner_al_dia(id, Mundos.entrada(id),
		{"ok": true, "resultado": "host", "token": 1, "save": PackedByteArray(), "meta": {}})
	ok(String(r.get("resultado", "")) == "host", "abre como siempre: %s" % str(r))
	ok(not Mundos.usa_bd(id), "sin BD en este disco")
	var d: SaveData = SaveIO.inspeccionar_ruta(Mundos.ruta(id))["datos"]
	ok(d != null and d.money == dinero, "el .tres tiene lo de la BD (dinero %d)" % (d.money if d != null else -1))


func _respaldos() -> int:
	var d := DirAccess.open(Mundos.RESPALDOS_CONFLICTO)
	return 0 if d == null else d.get_files().size()


func _legado(id: String) -> void:
	print("--- 7. un mundo VIEJO en la nube")
	var fichero: String = OS.get_environment("HUELLA_FICHERO")
	if fichero == "":
		fichero = POR_DEFECTO
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(fichero)
	ok((await Nube.crear_mundo(id, PASS)).get("ok", false), "creado")
	_alta(id)
	# Como lo dejaria el juego de antes: abrir y subir el fichero entero.
	ok(String((await Nube.abrir(id, PASS, [])).get("resultado", "")) == "host", "cerrojo para subirlo a la vieja usanza")
	ok((await Nube.cerrar(bytes, {"fecha": "2026-01-01T00:00:00"})).get("ok", false), "subido como save entero (%d KB)" % (bytes.size() / 1024))

	var t0: int = Time.get_ticks_msec()
	var r: Dictionary = await Mundos.abrir(id, PASS)
	ok(String(r.get("resultado", "")) == "host", "abierto: %s" % str(r.get("mensaje", "")))
	print("  abrir + migrar + subir entero: %d ms" % (Time.get_ticks_msec() - t0))
	ok(Mundos.usa_bd(id), "migrado a su BD en este disco")
	var f: Dictionary = await Nube.fotos()
	ok(bool(f.get("legado", false)), "el save viejo queda de legado en la nube")
	t0 = Time.get_ticks_msec()
	ok(Mundos.cargar(id), "cargado (%d ms)" % (Time.get_ticks_msec() - t0))
	t0 = Time.get_ticks_msec()
	Mundos.guardar_actual()
	var s: Dictionary = await Mundos._subir_bd(false)
	print("  primer guardado tras cargar: %d filas, %d ms" % [int(s.get("subidas", 0)), Time.get_ticks_msec() - t0])
	Game.money += 1
	t0 = Time.get_ticks_msec()
	Mundos.guardar_actual()
	s = await Mundos._subir_bd(false)
	ok(s.get("ok", false) and int(s.get("subidas", 99)) <= 5, "+1 de dinero: %d filas (%d ms, la nube escribio %d)" % [
		int(s.get("subidas", 0)), Time.get_ticks_msec() - t0, int(s.get("escritas", 0))])
	ok((await Mundos.cerrar_y_subir()).get("ok", false), "cerrado")
	var guardado: SaveData = PartidaBD.inspeccionar_ruta(Mundos.ruta_bd(id))["datos"]
	var est: Dictionary = await Nube.consultar(id, PASS)
	ok(String(est.get("formato", "")) == "bd", "en la nube ya es formato bd")
	var viejo: Dictionary = await Nube.almacen.abrir(id, PASS, [], Nube._sello(), Game.VERSION, false,
		Identidad.para_cerrojo(), 0)
	ok(String(viejo.get("error", "")) == "version_nueva", "el juego viejo no lo abre: %s" % str(viejo.get("error", "")))

	# Bajado de cero = lo guardado.
	PartidaBD.borrar(Mundos.ruta_bd(id))
	t0 = Time.get_ticks_msec()
	r = await Mundos.abrir(id, PASS)
	print("  bajarlo entero: %d ms" % (Time.get_ticks_msec() - t0))
	var bajado: SaveData = PartidaBD.inspeccionar_ruta(Mundos.ruta_bd(id))["datos"]
	var dif: Array = HuellaSave.diferencias(HuellaSave.de(guardado), HuellaSave.de(bajado), 20)
	ok(dif.is_empty(), "bajado de cero = lo guardado (huella) %s" % str(dif))
	# Lo de reescribir media partida es solo el primer guardado tras MIGRAR: cargado de la BD, ya no.
	Mundos.cargar(id)
	Mundos.guardar_actual()
	var pen: Array = Mundos._bd.pendientes()["filas"]
	ok(pen.size() <= 5, "cargado de la BD y guardado: %d filas por subir" % pen.size())

	# Vuelta atras: el legado.
	var rr: Dictionary = await Nube.restaurar("legado")
	ok(rr.get("ok", false) and String(rr.get("formato", "")) == "tres", "restaurado el legado")
	Nube._olvidar()
	Mundos.abandonar()
	r = await Mundos.abrir(id, PASS)
	ok(String(r.get("resultado", "")) == "host" and Mundos.usa_bd(id), "reabierto: se vuelve a migrar desde el legado")
	var de_nuevo: SaveData = PartidaBD.inspeccionar_ruta(Mundos.ruta_bd(id))["datos"]
	ok(de_nuevo != null and de_nuevo.money == (SaveIO.inspeccionar_ruta(fichero)["datos"] as SaveData).money,
		"con el dinero de antes de migrar")
	Mundos.cargar(id)
	ok((await Mundos.cerrar_y_subir()).get("ok", false), "cerrado")
