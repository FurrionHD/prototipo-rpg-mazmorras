# ============================================================
#  cloud_store_local.gd   (class_name NubeAlmacenLocal)
#  ALMACEN FALSO del mundo compartido: ficheros en user://nube_test/.
#
#  Esto NO es "una maqueta que devuelve lo que hace falta": es el PORTERO ENTERO, la misma logica
#  que en la Fase 2 vive en el Worker de Cloudflare (test-and-set del cerrojo, contraseña,
#  caducidad del arrendamiento y token de vallado). Se escribe aqui primero a proposito: asi toda
#  la maquina de estados se prueba sin cuenta, sin red y sin poder romper nada de nadie, y la
#  Fase 2 es cambiar este objeto por uno que hable HTTP con las MISMAS cuatro operaciones y las
#  mismas respuestas.
#
#  Las operaciones (los futuros endpoints):
#    abrir(id, pass, direcciones, sello)  -> POST /abrir    test-and-set + save + token
#    latido(id, token)                    -> POST /latido   renueva el arrendamiento
#    subir(id, token, save, meta)         -> PUT  /subir    sube y SE QUEDA el cerrojo (autoguardado)
#    cerrar(id, token, save, meta)        -> PUT  /cerrar    sube y LUEGO suelta
#    estado(id, pass)                     -> GET  /estado    metadatos, sin bajarse el save
#  Mas crear(id, pass), que en el Worker sera el alta de un mundo nuevo.
#
#  RESPUESTAS: siempre un Dictionary con "ok": bool. Si ok es false trae "error" (un codigo
#  estable, para que el juego decida) y "mensaje" (para el jugador). Los codigos son los que
#  devolvera el Worker; el juego no debe mirar nada mas.
#
#  ⚠ MISMO ERROR PARA "no existe" y "contraseña incorrecta" (codigo "no_autorizado"): si se
#  distinguieran, el propio mensaje de error seria un buscador de mundos ajenos.
#
#  EL RELOJ: todo lo temporal pasa por _ahora(), que suma `desfase_prueba`. Es lo que permite
#  probar la caducidad de verdad (adelantar el reloj cinco minutos) sin puertas traseras del tipo
#  "caduca esto ya", que probarian un camino que en produccion no existe.
# ============================================================

extends RefCounted
class_name NubeAlmacenLocal

const CARPETA := "user://nube_test"

# Cuanto vive un arrendamiento sin latido. El host late cada Nube.SEGUNDOS_LATIDO (~30 s), asi
# que dos minutos son cuatro latidos perdidos: no salta por un pico de lag, y un cuelgue no
# congela el mundo mas de dos minutos.
const SEGUNDOS_ARRENDAMIENTO := 120

# Segundos que se le suman al reloj. SOLO para pruebas (adelantar el tiempo); en juego vale 0.
var desfase_prueba: int = 0


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(CARPETA)


# ============================================================
#  ALTA de un mundo
#  El id lo elige quien crea el mundo y tiene que ser LARGO Y ALEATORIO (ver Nube.nuevo_id): el
#  Worker es publico, y un id adivinable es un mundo que cualquiera puede aporrear.
# ------------------------------------------------------------
func crear(id: String, contrasena: String) -> Dictionary:
	if id.strip_edges() == "" or contrasena == "":
		return _fallo("peticion_mala", "Hace falta un id de mundo y una contraseña.")
	if FileAccess.file_exists(_ruta_mundo(id)):
		return _fallo("ya_existe", "Ese mundo ya existe.")
	var mundo := {
		"id": id,
		"pass": _huella(id, contrasena),   # nunca la contraseña en claro, ni en el almacen falso
		"token": 0,                        # contador de vallado: sube en CADA apertura
		"creado": _ahora(),
		"meta": {},                        # cabecera ligera para /estado (nivel, piso, dinero...)
		"sello_version": 0,                # version de SaveData del ultimo que cerro (0 = sin save)
		"sello_build": "",
	}
	_escribir_json(_ruta_mundo(id), mundo)
	return {"ok": true, "id": id}


# ============================================================
#  ABRIR: test-and-set del cerrojo
#  Tres desenlaces, y los tres son "ok": true -- el que importa lo dice "resultado":
#    "host"    lo has cogido tu: vienen "save" (bytes, vacio si el mundo es nuevo) y "token"
#    "unirse"  lo tiene otro y su arrendamiento esta VIVO: vienen sus "direcciones"
#    "fantasma" lo tiene otro pero su arrendamiento esta MUERTO y no se ha podido reclamar
#  El sello (version de SaveData + build) se comprueba ANTES de dar nada: un build viejo no puede
#  abrir un mundo que dejo uno nuevo, y se le dice por que en vez de dejarle un save que cargaria
#  a medias o, peor, que veria como ranura vacia.
# ------------------------------------------------------------
func abrir(id: String, contrasena: String, direcciones: Array, sello_version: int,
		sello_build: String, forzar_build := false) -> Dictionary:
	var mundo: Dictionary = _leer_mundo(id, contrasena)
	if mundo.is_empty():
		return _no_autorizado()

	# ¿Lo tiene alguien? El cerrojo es un fichero aparte: existir = estar cogido.
	var cerrojo: Dictionary = _leer_json(_ruta_cerrojo(id))
	if not cerrojo.is_empty():
		if _vivo(cerrojo):
			# Cogido y con latido reciente: esto no es un "no puedes", es un "entra con el".
			return {
				"ok": true,
				"resultado": "unirse",
				"quien": String(cerrojo.get("quien", "")),
				"direcciones": cerrojo.get("direcciones", []),
				"desde": int(cerrojo.get("desde", 0)),
			}
		# Arrendamiento CADUCADO: el que lo tenia se cayo. Se le quita y se sigue. Su token queda
		# atras para siempre porque abajo se incrementa el contador: si revive, su subida se rechaza.
		if DirAccess.remove_absolute(_ruta_cerrojo(id)) != OK:
			return _fallo("fantasma", "El mundo lo tiene alguien que ya no responde y no se ha podido liberar.")

	# El sello: ¿entiende este build lo que hay guardado?
	var v: int = int(mundo.get("sello_version", 0))
	if v > sello_version:
		return _fallo("version_nueva",
			"Este mundo lo guardó una versión más nueva del juego (v%d). Actualiza antes de abrirlo." % v)
	var b: String = String(mundo.get("sello_build", ""))
	if b != "" and sello_build != "" and b != sello_build and not forzar_build:
		# Los saves llevan rutas res:// dentro, asi que entre builds distintos PUEDEN cargar roto (si
		# se movio o se renombro un recurso). Pero al revés de la version, esto NO es una perdida de
		# datos segura: la mayoria de las veces son dos builds con las mismas rutas y carga perfecto.
		# Por eso se avisa y se deja FORZAR (forzar_build), en vez de dejar el mundo inaccesible para
		# siempre por haberle subido el numero de version al juego -- que durante el desarrollo pasa
		# cada dos por tres.
		return _fallo("build_distinto",
			"Este mundo se guardó con el build %s y tú tienes el %s. Tienen que ser el mismo." % [b, sello_build])

	# Test-and-set: el token sube SIEMPRE en cada apertura, y ese es el vallado. Se escribe primero
	# el contador del mundo y solo despues el cerrojo, para que un corte a media no deje un cerrojo
	# con un token que el mundo no reconoce.
	var token: int = int(mundo.get("token", 0)) + 1
	mundo["token"] = token
	_escribir_json(_ruta_mundo(id), mundo)

	var ahora: int = _ahora()
	_escribir_json(_ruta_cerrojo(id), {
		"token": token,
		"quien": OS.get_environment("USERNAME") if OS.has_environment("USERNAME") else "alguien",
		"desde": ahora,
		"latido": ahora,
		"direcciones": direcciones,
	})

	var save := PackedByteArray()
	if FileAccess.file_exists(_ruta_save(id)):
		var f := FileAccess.open(_ruta_save(id), FileAccess.READ)
		if f != null:
			save = f.get_buffer(f.get_length())
			f.close()
	return {"ok": true, "resultado": "host", "token": token, "save": save, "meta": mundo.get("meta", {})}


# ============================================================
#  LATIDO: "sigo aqui"
#  Rechazar un latido no es un detalle: es como el host se ENTERA de que perdio el cerrojo (se
#  quedo sin red un rato, caduco y otro abrio el mundo). Mejor saberlo mientras juegas que al
#  intentar subir.
# ------------------------------------------------------------
func latido(id: String, token: int) -> Dictionary:
	var cerrojo: Dictionary = _leer_json(_ruta_cerrojo(id))
	if cerrojo.is_empty():
		return _fallo("sin_cerrojo", "El mundo ya no está a tu nombre.")
	if int(cerrojo.get("token", 0)) != token:
		return _fallo("token_viejo", "El mundo lo ha abierto alguien después de ti.")
	if not _vivo(cerrojo):
		# Caducado pero todavia sin reclamar: no se renueva a destiempo, porque el que llegue
		# despues tiene que poder quitarlo.
		return _fallo("caducado", "Tu turno en el mundo caducó por falta de conexión.")
	cerrojo["latido"] = _ahora()
	_escribir_json(_ruta_cerrojo(id), cerrojo)
	return {"ok": true}


# ============================================================
#  SUBIR: sube la partida y SE QUEDA con el cerrojo
#  Es lo que usa el AUTOGUARDADO, y no es un lujo: mientras juegas, el mundo solo existe en tu
#  disco. Si se te muere el PC, tu arrendamiento caduca, tu compañero abre el mundo y se encuentra
#  con lo ULTIMO SUBIDO -- sin subidas periodicas eso seria la partida de ayer y la sesion entera
#  se iria a la basura. Es el mismo agujero del cuelgue que tapa el arrendamiento, pero por el
#  otro lado.
#
#  Aqui vive el VALLADO de verdad: el token tiene que ser el vigente. Es lo que impide que el que
#  revive tras caducar pise al que abrio despues.
# ------------------------------------------------------------
func subir(id: String, token: int, save: PackedByteArray, meta: Dictionary,
		sello_version: int, sello_build: String) -> Dictionary:
	var mundo: Dictionary = _leer_json(_ruta_mundo(id))
	if mundo.is_empty():
		return _no_autorizado()
	if int(mundo.get("token", 0)) != token:
		# El caso del dossier: A se cuelga, caduca, B abre y juega, A revive y sube. NO.
		return _fallo("token_viejo",
			"El mundo lo ha abierto alguien después de ti: tu partida no se puede subir encima de la suya.")
	var cerrojo: Dictionary = _leer_json(_ruta_cerrojo(id))
	if cerrojo.is_empty() or int(cerrojo.get("token", 0)) != token:
		return _fallo("sin_cerrojo", "El mundo ya no está a tu nombre.")
	if save.is_empty():
		return _fallo("save_vacio", "No hay partida que subir.")

	var f := FileAccess.open(_ruta_save(id), FileAccess.WRITE)
	if f == null:
		return _fallo("subida_fallida", "No se pudo subir la partida.")
	f.store_buffer(save)
	f.close()

	mundo["meta"] = meta
	mundo["sello_version"] = sello_version
	mundo["sello_build"] = sello_build
	mundo["subido"] = _ahora()
	_escribir_json(_ruta_mundo(id), mundo)
	return {"ok": true}


# ============================================================
#  CERRAR: subir y LUEGO soltar (en ese orden, nunca al reves)
#  Si la subida falla, el cerrojo se queda a tu nombre: mejor un mundo bloqueado dos minutos que un
#  mundo libre con la partida de ayer dentro. Por eso esto es subir() + soltar, y no dos caminos:
#  toda la validacion y el vallado viven en un solo sitio.
# ------------------------------------------------------------
func cerrar(id: String, token: int, save: PackedByteArray, meta: Dictionary,
		sello_version: int, sello_build: String) -> Dictionary:
	var r: Dictionary = subir(id, token, save, meta, sello_version, sello_build)
	if not r.get("ok", false):
		return r
	# Y AHORA se suelta. La direccion del host se va con el cerrojo: nunca se reparte la IP del que
	# jugo ayer.
	DirAccess.remove_absolute(_ruta_cerrojo(id))
	return {"ok": true}


# ============================================================
#  ESTADO: para pintar la lista del menu SIN bajarse el save
#  Devuelve tambien "caducado": si el cerrojo esta ahi pero sin latido, la direccion que lleva
#  dentro esta MUERTA y el cliente no debe intentar conectarse a ella.
# ------------------------------------------------------------
func estado(id: String, contrasena: String) -> Dictionary:
	var mundo: Dictionary = _leer_mundo(id, contrasena)
	if mundo.is_empty():
		return _no_autorizado()
	var r := {
		"ok": true,
		"id": id,
		"abierto": false,
		"caducado": false,
		"quien": "",
		"desde": 0,
		"meta": mundo.get("meta", {}),
		"sello_version": int(mundo.get("sello_version", 0)),
		"sello_build": String(mundo.get("sello_build", "")),
		"tiene_save": FileAccess.file_exists(_ruta_save(id)),
	}
	var cerrojo: Dictionary = _leer_json(_ruta_cerrojo(id))
	if not cerrojo.is_empty():
		r["abierto"] = true
		r["caducado"] = not _vivo(cerrojo)
		r["quien"] = String(cerrojo.get("quien", ""))
		r["desde"] = int(cerrojo.get("desde", 0))
		# La direccion SOLO si el arrendamiento esta vivo: con el host caido, mientras caduca, no se
		# reparte una direccion rancia.
		if not r["caducado"]:
			r["direcciones"] = cerrojo.get("direcciones", [])
	return r


# ============================================================
#  Cosas de dentro
# ------------------------------------------------------------
func _ahora() -> int:
	return int(Time.get_unix_time_from_system()) + desfase_prueba


func _vivo(cerrojo: Dictionary) -> bool:
	return _ahora() - int(cerrojo.get("latido", 0)) < SEGUNDOS_ARRENDAMIENTO


# El mundo, pero solo si la contraseña casa. Vacio = no existe O contraseña mala, y quien llama NO
# puede saber cual de las dos (ver la cabecera).
func _leer_mundo(id: String, contrasena: String) -> Dictionary:
	var mundo: Dictionary = _leer_json(_ruta_mundo(id))
	if mundo.is_empty():
		return {}
	if String(mundo.get("pass", "")) != _huella(id, contrasena):
		return {}
	return mundo


# La contraseña no se guarda en claro ni aqui. Va con el id dentro (sal): dos mundos con la misma
# contraseña no comparten huella.
func _huella(id: String, contrasena: String) -> String:
	return ("dungeon-oratoria|%s|%s" % [id, contrasena]).sha256_text()


func _ruta_mundo(id: String) -> String:
	return "%s/%s.mundo.json" % [CARPETA, id]


func _ruta_cerrojo(id: String) -> String:
	return "%s/%s.cerrojo.json" % [CARPETA, id]


func _ruta_save(id: String) -> String:
	return "%s/%s.save" % [CARPETA, id]


func _leer_json(ruta: String) -> Dictionary:
	if not FileAccess.file_exists(ruta):
		return {}
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	var d = JSON.parse_string(txt)
	return d if d is Dictionary else {}


func _escribir_json(ruta: String, d: Dictionary) -> void:
	var f := FileAccess.open(ruta, FileAccess.WRITE)
	if f == null:
		push_warning("[nube-falsa] no se pudo escribir %s" % ruta)
		return
	f.store_string(JSON.stringify(d, "  "))
	f.close()


func _fallo(codigo: String, mensaje: String) -> Dictionary:
	return {"ok": false, "error": codigo, "mensaje": mensaje}


func _no_autorizado() -> Dictionary:
	return _fallo("no_autorizado", "No hay ningún mundo con ese id y esa contraseña.")
