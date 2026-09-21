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
# ============================================================

extends RefCounted
class_name NubeAlmacenHttp

# Cuanto se espera a la nube. Subir o bajar el mundo entero (varios MB) lleva mas que un latido.
const PLAZO_CORTO := 20.0
const PLAZO_LARGO := 120.0

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
		sello_build: String, forzar_build := false, quien_soy := "") -> Dictionary:
	var datos := {
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


func estado(id: String, contrasena: String) -> Dictionary:
	return await _peticion("estado", id, contrasena)


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
		plazo: float = PLAZO_CORTO) -> Dictionary:
	if _padre == null or not _padre.is_inside_tree():
		return _fallo("sin_red", "La nube no está lista.")
	var h := HTTPRequest.new()
	h.timeout = plazo
	h.use_threads = true   # subir 4 MB no puede congelar el juego
	_padre.add_child(h)
	var hs := PackedStringArray(["x-pass: " + contrasena.uri_encode()])
	if op == "abrir" or op == "crear":
		hs.append("content-type: application/json")
	for k in cabeceras:
		hs.append("%s: %s" % [k, str(cabeceras[k]).uri_encode()])
	var err: int = h.request_raw("%s/v1/%s?id=%s" % [url, op, id.uri_encode()], hs,
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
