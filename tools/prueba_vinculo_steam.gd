# PRUEBA (Steam F2b): EL VINCULO "cuenta de Steam -> identidad de jugador", sin Steam (cuentas falsas) y
# sin pisar la identidad de verdad de este PC (escribe en user://prueba_identidad.cfg).
# Simula varios PCs cambiando Identidad.id a mano:
#   - PC1 sin vinculo -> pregunta -> lo vincula; la segunda vez ya es "igual";
#   - "todavia no" -> no se escribe nada en la nube y no se vuelve a preguntar;
#   - PC2 recien instalado (sin mundos) -> adopta el id de Steam sin preguntar y guarda el suyo;
#   - PC3 con mundos -> pregunta; "usar el de Steam", "volver", "solo aqui" y "que Steam use este";
#   - el PC2 recoge el vinculo cambiado; todo lo guardado se relee del fichero.
# Se lanza con:  <godot> --headless --path . res://tools/prueba_vinculo_steam.tscn -- nube_local
#   o contra el Worker en este PC (servidor/nube, `npx wrangler dev --port 8787 --ip 127.0.0.1`):
#                <godot> --headless --path . res://tools/prueba_vinculo_steam.tscn -- nube_url=http://127.0.0.1:8787
extends Node

const A := "aaaaaaaaaaaaaaaaaaaaaaaa"
const B := "bbbbbbbbbbbbbbbbbbbbbbbb"
const C := "cccccccccccccccccccccccc"
const RUTA_PRUEBA := "user://prueba_identidad.cfg"

var fallos := 0


func ok(c: bool, t: String) -> void:
	print(("  OK   " if c else "  FALLO ") + t)
	if not c:
		fallos += 1


# Un "PC": una identidad sin nada de Steam decidido todavia.
func _pc(id_: String) -> void:
	Identidad.id = id_
	Identidad.id_anterior = ""
	Identidad._steam_ignorar = ""
	Identidad.vinculo = ""


func _caso(tengo_mundos: bool, steam: int) -> String:
	var r: Dictionary = await Identidad.comprobar_steam(tengo_mundos, steam, "Cuenta%d" % (steam % 100))
	return String(r.get("caso", ""))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var url := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("nube_url="):
			url = a.substr(9)
	if Nube.es_remota() and not url.contains("127.0.0.1"):
		print("Esta prueba va con `-- nube_local` o con un wrangler dev en 127.0.0.1 (no con la nube de verdad).")
		get_tree().quit(1)
		return
	print("== vinculo de Steam contra %s" % ("el Worker en " + url if url != "" else "la nube local"))
	var orig := {"id": Identidad.id, "anterior": Identidad.id_anterior, "ignorar": Identidad._steam_ignorar}
	Identidad.ruta = RUTA_PRUEBA
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RUTA_PRUEBA))
	# Cuentas de Steam nuevas en cada pasada (17 cifras, como las de verdad): el vinculo de la anterior
	# se queda en el almacen, y asi no molesta.
	var base: int = 76561190000000000 + (int(Time.get_unix_time_from_system()) % 1000000) * 100
	var S: int = base + 1
	var S2: int = base + 2

	# --- PC1: sin vinculo -> lo vincula ---
	_pc(A)
	ok(await _caso(true, S) == "sin_vinculo", "PC1: la cuenta no tiene vinculo -> se pregunta")
	var r: Dictionary = await Identidad.vincular_este_pc()
	ok(r.get("ok", false) and Identidad.vinculo == A, "PC1: vinculada con A (%s)" % str(r))
	ok(await _caso(true, S) == "igual", "PC1: la siguiente vez ya es la misma, nada que preguntar")

	# --- "Todavia no" ---
	_pc(A)
	ok(await _caso(true, S2) == "sin_vinculo", "otra cuenta sin vinculo -> se pregunta")
	Identidad.steam_ahora_no()
	ok(await _caso(true, S2) == "callado", "tras «todavía no» no se vuelve a preguntar")
	ok(String((await Nube.vinculo_leer(S2)).get("id", "?")) == "", "y en la nube no se ha escrito nada")

	# --- PC2 recien instalado: adopta sin preguntar ---
	_pc(B)
	ok(await _caso(false, S) == "adoptado", "PC2 sin mundos: adopta la identidad de Steam")
	ok(Identidad.id == A and Identidad.id_anterior == B, "PC2: ahora es A y guarda B para volver (%s / %s)"
		% [Identidad.id, Identidad.id_anterior])

	# --- PC3 con mundos: pregunta ---
	_pc(C)
	ok(await _caso(true, S) == "distinto", "PC3 con mundos: se pregunta")
	Identidad.usar_la_de_steam()
	ok(Identidad.id == A and Identidad.id_anterior == C, "PC3 «usar el de Steam»: es A, guarda C")
	ok(Identidad.volver_al_anterior() and Identidad.id == C and Identidad.id_anterior == A,
		"PC3 «volver»: vuelve a C (y se puede volver a A)")
	Identidad._steam_ignorar = ""
	ok(await _caso(true, S) == "distinto", "PC3: sigue siendo distinto")
	Identidad.steam_ahora_no()
	ok(await _caso(true, S) == "callado", "PC3 «solo aquí»: no se vuelve a preguntar")
	r = await Identidad.vincular_este_pc()
	ok(r.get("ok", false) and String(r.get("anterior", "")) == A, "PC3 «que Steam use este»: el vínculo pasa a C")
	ok(Identidad.id_anterior == A, "PC3: el vínculo que había (A) queda apuntado para deshacerlo")
	ok(String((await Nube.vinculo_leer(S)).get("id", "")) == C, "en la nube, la cuenta ya es C")

	# --- Todo eso quedo escrito ---
	var cfg := ConfigFile.new()
	ok(cfg.load(RUTA_PRUEBA) == OK and String(cfg.get_value("jugador", "id", "")) == C
		and String(cfg.get_value("jugador", "id_anterior", "")) == A, "el fichero de identidad guarda id y anterior")

	# --- El PC2 (que era A y no tiene mundos) recoge el cambio ---
	_pc(A)
	ok(await _caso(false, S) == "adoptado" and Identidad.id == C, "PC2 recoge el vínculo cambiado: ahora es C")
	# --- Y el PC1, con mundos, pregunta ---
	_pc(A)
	ok(await _caso(true, S) == "distinto", "PC1 con mundos: ve que su Steam ahora es otro y pregunta")

	# Se deja la identidad de este proceso como estaba (el fichero de verdad no se ha tocado).
	Identidad.ruta = Identidad.RUTA
	Identidad.id = orig["id"]
	Identidad.id_anterior = orig["anterior"]
	Identidad._steam_ignorar = orig["ignorar"]
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RUTA_PRUEBA))
	print("TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)
