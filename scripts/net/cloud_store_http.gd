# ============================================================
#  cloud_store_http.gd   (class_name NubeAlmacenHttp)
#  EL ALMACEN DE VERDAD del mundo compartido: habla por HTTPS con el Worker de Cloudflare
#  (servidor/nube). Mismas operaciones y mismas respuestas que NubeAlmacenLocal, que sigue siendo
#  el que usan las pruebas: Nube no sabe con cual de los dos habla.
#
#  Lo que cambia respecto al local, y por que:
#    - LA CONTRASEÑA VIAJA EN CADA PETICION. En el local, latir y subir solo pedian el token, porque
#      nadie de fuera podia tocar la carpeta. El Worker es publico y el token es un contador pequeño:
#      solo con el, cualquiera que supiera el codigo del mundo podria subir encima. Asi que se recuerda
#      la contraseña de cada mundo abierto (en memoria, nunca en disco) y va siempre.
#    - "OTRA VENTANA DE ESTE PC". El local miraba si el proceso que cogio el cerrojo seguia vivo; el
#      Worker no puede mirar procesos de tu ordenador, asi que contesta "comprobar" con el pid y la
#      comprobacion la hace el juego aqui, volviendo con reclamar=true si ese proceso ya no existe.
#    - EL SAVE SE BAJA APARTE, despues de coger el cerrojo y con su token: abrir contesta JSON y los
#      4 MB van en una peticion binaria propia.
#    - LA BASE DE DATOS DEL MUNDO va por paginas: sync parte las filas en lotes de ~1 MB (el servidor
#      las aparca y aplica todas con la ultima) y bajar_bd pide paginas hasta que no hay mas.
# ============================================================

extends RefCounted
class_name NubeAlmacenHttp

# Cuanto se espera a la nube. Subir o bajar el mundo entero (varios MB) lleva mas que un latido.
const PLAZO_CORTO := 20.0
const PLAZO_LARGO := 120.0
# Lo que lleva cada parte de una subida de filas (texto). Las normales caben en una.
const PARTE_SYNC := 1024 * 1024

var url: String = ""
var _padre: Node = null
# id del mundo -> contraseña, de los que he abierto o creado en esta sesion. Solo en memoria.
var _pass: Dictionary = {}


# padre: un nodo del arbol para colgar las HTTPRequest (sin arbol no hay peticiones).
func _init(padre: Node, url_base: String) -> void:
	_padre = padre
	url = url_base.strip_edges().trim_suffix("/")


# quien_soy = el primer MIEMBRO del mundo (el unico que puede abrirlo hasta que se suba un save con mas
# jugadores dentro; ver "miembros" en servidor/nube).
func crear(id: String, contrasena: String, quien_soy := "") -> Dictionary:
	if id.strip_edges() == "" or contrasena == "":
		return _fallo("peticion_mala", "Hace falta un id de mundo y una contraseña.")
	var r: Dictionary = await _peticion("crear", id, contrasena, {}, _json({"quien_soy": quien_soy}))
	if r.get("ok", false):
		_pass[id] = contrasena
	return r


func abrir(id: String, contrasena: String, direcciones: Array, sello_version: int,
		sello_build: String, forzar_build := false, quien_soy := "", formato_bd := 0) -> Dictionary:
	var datos := {
		"formato_bd": formato_bd,
		"direcciones": direcciones,
		"sello_version": sello_version,
		"sello_build": sello_build,
		"forzar_build": forzar_build,
		"quien_soy": quien_soy,
		# 'quien' es solo para ENSEÑARLO ("lo tiene dasui"); lo que se compara es 'quien_soy'.
		"quien": Identidad.nombre,
		"pid": OS.get_process_id(),
		"equipo": _este_equipo(),
	}
	var r: Dictionary = await _peticion("abrir", id, contrasena, {}, _json(datos))
	if r.get("ok", false) and String(r.get("resultado", "")) == "comprobar":
		# El cerrojo es mio y esta vivo, cogido desde otro proceso de este PC. Si ese proceso sigue
		# ahi es otra ventana del juego jugando: no se le quita el mundo.
		if OS.is_process_running(int(r.get("pid", 0))):
			return _fallo("ya_abierto", "Ya tienes este mundo abierto en otra ventana del juego.")
		datos["reclamar"] = true
		r = await _peticion("abrir", id, contrasena, {}, _json(datos))
	if not r.get("ok", false) or String(r.get("resultado", "")) != "host":
		return r

	_pass[id] = contrasena
	var save := PackedByteArray()
	if bool(r.get("tiene_save", false)):
		var b: Dictionary = await _peticion("bajar", id, contrasena, {"x-token": int(r.get("token", 0))},
			PackedByteArray(), true, PLAZO_LARGO)
		if not b.get("ok", false):
			# El cerrojo ya es mio (a mi identidad): el siguiente intento lo recoge sin esperar.
			return b
		save = b["bytes"]
	r["save"] = save
	return r


func latido(id: String, token: int) -> Dictionary:
	return await _peticion("latido", id, String(_pass.get(id, "")), {"x-token": token})


func subir(id: String, token: int, save: PackedByteArray, meta: Dictionary,
		sello_version: int, sello_build: String) -> Dictionary:
	return await _subir("subir", id, token, save, meta, sello_version, sello_build)


func cerrar(id: String, token: int, save: PackedByteArray, meta: Dictionary,
		sello_version: int, sello_build: String) -> Dictionary:
	var r: Dictionary = await _subir("cerrar", id, token, save, meta, sello_version, sello_build)
	if r.get("ok", false):
		_pass.erase(id)
	return r


func estado(id: String, contrasena: String, quien_soy := "") -> Dictionary:
	return await _peticion("estado", id, contrasena, {}, _json({"quien_soy": quien_soy}))


# LA BASE DE DATOS DEL MUNDO (ver servidor/nube). p = {base, completa, soltar, foto, filas}: las filas se
# parten en partes de un mismo lote; el servidor solo aplica con la ultima.
func sync(id: String, token: int, p: Dictionary, meta: Dictionary, sello_version: int,
		sello_build: String) -> Dictionary:
	var cab := {
		"x-token": token,
		"x-sello-version": sello_version,
		"x-sello-build": sello_build,
		"x-meta": JSON.stringify(meta),
	}
	var r: Dictionary = await _sync_en_partes("sync", id, String(_pass.get(id, "")), cab, p, "")
	if r.get("ok", false) and bool(p.get("soltar", false)):
		_pass.erase(id)
	return r


# Sube las filas partidas en partes de un mismo lote: el servidor solo las aplica con la ultima.
func _sync_en_partes(op: String, id: String, contrasena: String, cab: Dictionary, p: Dictionary,
		consulta: String) -> Dictionary:
	var filas: Array = p.get("filas", [])
	var partes: Array = [[]]
	var talla: int = 0
	for f in filas:
		var t: int = String(f[1]).length() + (String(f[2]).length() if f[2] is String else 8) + 24
		if talla + t > PARTE_SYNC and not partes[-1].is_empty():
			partes.append([])
			talla = 0
		partes[-1].append(f)
		talla += t
	var lote: String = str(Time.get_ticks_usec()).sha256_text().substr(0, 16)
	var r: Dictionary = {}
	for i in partes.size():
		var cuerpo := {"base": int(p.get("base", 0)), "lote": lote, "parte": i, "fin": i == partes.size() - 1,
			"completa": bool(p.get("completa", false)), "soltar": bool(p.get("soltar", false)),
			"foto": bool(p.get("foto", false)), "foto_antes": bool(p.get("foto_antes", false)), "filas": partes[i]}
		r = await _peticion(op, id, contrasena, cab, _json(cuerpo), false, PLAZO_LARGO, consulta)
		if not r.get("ok", false):
			return r
	return r


# Las filas cambiadas desde el rev `desde` (0 = todas), juntando todas las paginas.
func bajar_bd(id: String, token: int, desde: int) -> Dictionary:
	return await _bajar_paginas("bajar_bd", id, String(_pass.get(id, "")), {"x-token": token}, desde, "")


func _bajar_paginas(op: String, id: String, contrasena: String, cab: Dictionary, desde: int,
		consulta: String) -> Dictionary:
	var filas: Array = []
	var tras: int = 0
	var r: Dictionary = {}
	while true:
		r = await _peticion(op, id, contrasena, cab, _json({"desde": desde, "tras": tras}), false,
			PLAZO_LARGO, consulta)
		if not r.get("ok", false):
			return r
		filas.append_array(r.get("filas", []))
		tras = int(r.get("tras", 0))
		if not bool(r.get("mas", false)):
			break
	r["filas"] = filas
	return r


# LAS PARTIDAS DE UN JUGADOR Y SU CUENTA (ver servidor/nube). La llave es la clave del jugador (X-Clave).
func cuenta_lista(cuenta: String, clave: String) -> Dictionary:
	return await _peticion("cuenta_lista", "", "", {"x-clave": clave}, _json({}), false, PLAZO_CORTO,
		"cuenta=" + cuenta)


func p_sync(cuenta: String, clave: String, partida: String, p: Dictionary, meta: Dictionary) -> Dictionary:
	return await _sync_en_partes("p_sync", "", "", {"x-clave": clave, "x-meta": JSON.stringify(meta)}, p,
		"cuenta=%s&partida=%s" % [cuenta, partida])


func p_bajar(cuenta: String, clave: String, partida: String, desde: int) -> Dictionary:
	return await _bajar_paginas("p_bajar", "", "", {"x-clave": clave}, desde,
		"cuenta=%s&partida=%s" % [cuenta, partida])


func p_borrar(cuenta: String, clave: String, partida: String) -> Dictionary:
	return await _peticion("p_borrar", "", "", {"x-clave": clave}, _json({}), false, PLAZO_CORTO,
		"cuenta=%s&partida=%s" % [cuenta, partida])


func fotos(id: String, token: int) -> Dictionary:
	return await _peticion("fotos", id, String(_pass.get(id, "")), {"x-token": token}, _json({}))


func restaurar(id: String, token: int, foto) -> Dictionary:
	return await _peticion("restaurar", id, String(_pass.get(id, "")), {"x-token": token},
		_json({"foto": foto}), false, PLAZO_LARGO)


# EL VINCULO DE STEAM (ver la cabecera de servidor/nube). Va por ?steam= en vez de ?id=, y sin contraseña.
func vinculo_leer(steam_id: int, ticket := "") -> Dictionary:
	return await _peticion("vinculo_leer", "", "", {}, _json({"ticket": ticket}), false, PLAZO_CORTO,
		"steam=%d" % steam_id)


func vinculo_poner(steam_id: int, id: String, ticket := "", clave := "") -> Dictionary:
	return await _peticion("vinculo_poner", "", "", {}, _json({"id": id, "ticket": ticket, "clave": clave}), false,
		PLAZO_CORTO, "steam=%d" % steam_id)


# ============================================================
#  Cosas de dentro
# ------------------------------------------------------------
func _subir(op: String, id: String, token: int, save: PackedByteArray, meta: Dictionary,
		sello_version: int, sello_build: String) -> Dictionary:
	if save.is_empty():
		return _fallo("save_vacio", "No hay partida que subir.")
	return await _peticion(op, id, String(_pass.get(id, "")), {
		"x-token": token,
		"x-sello-version": sello_version,
		"x-sello-build": sello_build,
		"x-meta": JSON.stringify(meta),
	}, save, false, PLAZO_LARGO)


# Una peticion al Worker. Las cabeceras van codificadas (uri_encode): la contraseña y la cabecera del
# mundo llevan acentos, y una cabecera HTTP solo admite ASCII.
func _peticion(op: String, id: String, contrasena: String, cabeceras: Dictionary = {},
		cuerpo: PackedByteArray = PackedByteArray(), binario := false,
		plazo: float = PLAZO_CORTO, consulta := "") -> Dictionary:
	if _padre == null or not _padre.is_inside_tree():
		return _fallo("sin_red", "La nube no está lista.")
	var h := HTTPRequest.new()
	h.timeout = plazo
	h.use_threads = true   # subir 4 MB no puede congelar el juego
	_padre.add_child(h)
	var hs := PackedStringArray(["x-pass: " + contrasena.uri_encode()])
	if op in ["abrir", "crear", "estado", "sync", "bajar_bd", "fotos", "restaurar", "cuenta_lista", "p_sync",
			"p_bajar", "p_borrar"] or op.begins_with("vinculo_"):
		hs.append("content-type: application/json")
	for k in cabeceras:
		hs.append("%s: %s" % [k, str(cabeceras[k]).uri_encode()])
	if consulta == "":
		consulta = "id=" + id.uri_encode()
	var err: int = h.request_raw("%s/v1/%s?%s" % [url, op, consulta], hs,
		HTTPClient.METHOD_POST, cuerpo)
	if err != OK:
		h.queue_free()
		return _fallo("sin_red", "No se pudo hablar con la nube (error %d)." % err)
	var res: Array = await h.request_completed   # [resultado, codigo HTTP, cabeceras, cuerpo]
	h.queue_free()
	var resultado: int = int(res[0])
	var codigo: int = int(res[1])
	var bytes: PackedByteArray = res[3]
	if resultado != HTTPRequest.RESULT_SUCCESS:
		push_warning("[nube-http] %s: sin respuesta (resultado %d)" % [op, resultado])
		return _fallo("sin_red", "No hay conexión con la nube. Mira tu internet y vuelve a probar.")
	if binario and codigo == 200:
		return {"ok": true, "bytes": bytes}
	var d = JSON.parse_string(bytes.get_string_from_utf8())
	if d is Dictionary and (d as Dictionary).has("ok"):
		return d
	push_warning("[nube-http] %s: respuesta rara (HTTP %d)" % [op, codigo])
	return _fallo("respuesta_mala", "La nube ha contestado algo raro (HTTP %d)." % codigo)


func _json(d: Dictionary) -> PackedByteArray:
	return JSON.stringify(d).to_utf8_buffer()


func _este_equipo() -> String:
	return String(OS.get_environment("COMPUTERNAME")) if OS.has_environment("COMPUTERNAME") else ""


func _fallo(codigo: String, mensaje: String) -> Dictionary:
	return {"ok": false, "error": codigo, "mensaje": mensaje}
