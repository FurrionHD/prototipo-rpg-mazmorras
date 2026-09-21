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
func crear(id: String, contrasena: String, quien_soy := "") -> Dictionary:
	if id.strip_edges() == "" or contrasena == "":
		return _fallo("peticion_mala", "Hace falta un id de mundo y una contraseña.")
	if FileAccess.file_exists(_ruta_mundo(id)):
		return _fallo("ya_existe", "Ese mundo ya existe.")
	var mundo := {
		"id": id,
		# Quien puede ABRIRLO estando cerrado: empieza con quien lo crea y se pone al dia al subir (los
		# jugadores con personaje en el save). Vacio = mundo de antes de esto: lo abre cualquiera.
		"miembros": [quien_soy] if quien_soy != "" else [],
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
#    "host"    lo has cogido tu: vienen "save" (bytes, vacio si el mundo es nuevo) y "token".
#              Tambien por aqui cuando el cerrojo YA ERA TUYO y estaba suelto (ver 'quien_soy').
#    "unirse"  lo tiene OTRO y su arrendamiento esta VIVO: vienen sus "direcciones"
#    "fantasma" lo tiene otro pero su arrendamiento esta MUERTO y no se ha podido reclamar
#  'quien_soy' es MI identidad (Identidad.id). Con ella, un cerrojo a mi nombre no me manda a
#  "unirse" a mi propia sesion muerta: me lo quedo. Es lo que hace que cerrar con la X o colgarse no
#  deje el mundo inaccesible durante los dos minutos del arrendamiento.
#  El sello (version de SaveData + build) se comprueba ANTES de dar nada: un build viejo no puede
#  abrir un mundo que dejo uno nuevo, y se le dice por que en vez de dejarle un save que cargaria
#  a medias o, peor, que veria como ranura vacia.
# ------------------------------------------------------------
func abrir(id: String, contrasena: String, direcciones: Array, sello_version: int,
		sello_build: String, forzar_build := false, quien_soy := "") -> Dictionary:
	var mundo: Dictionary = _leer_mundo(id, contrasena)
	if mundo.is_empty():
		return _no_autorizado()

	# ¿Lo tiene alguien? El cerrojo es un fichero aparte: existir = estar cogido.
	var cerrojo: Dictionary = _leer_json(_ruta_cerrojo(id))
	if not cerrojo.is_empty():
		# ¿Es MIO? Entonces no hay a quien unirse: es mi propia sesion anterior, que se fue sin
		# soltarlo (cerrar con la X, un cuelgue, matar el proceso). Se recoge y se sigue.
		#
		# Sin esto el mundo quedaba inaccesible hasta DOS MINUTOS despues de cerrar con la X, y lo que
		# se ofrecia entretanto era "unirse" a la direccion de un host que ya no existe: o sea, no
		# poder entrar en tu propio mundo sin saber por que. Y no se arregla solo con soltar el cerrojo
		# al cerrar la ventana, porque un cuelgue no da ese aviso.
		#
		# Nadie sale perjudicado: solo una maquina tiene mi identidad, asi que el unico al que le puedo
		# quitar el cerrojo con esto soy yo.
		var dueno := String(cerrojo.get("identidad", ""))
		var es_mio: bool = quien_soy != "" and dueno == quien_soy
		if _vivo(cerrojo) and not es_mio:
			# Cogido por OTRO y con latido reciente: esto no es un "no puedes", es un "entra con el".
			return {
				"ok": true,
				"resultado": "unirse",
				"quien": String(cerrojo.get("quien", "")),
				"direcciones": cerrojo.get("direcciones", []),
				"desde": int(cerrojo.get("desde", 0)),
			}
		# ...SALVO QUE SIGA ABIERTO EN OTRA VENTANA DE ESTE MISMO PC. "Solo una maquina tiene mi
		# identidad" no basta: dos ventanas del juego en el mismo ordenador la comparten, y la segunda le
		# quitaba el mundo a la primera, que seguia jugando y guardando (15/09/2026). Si el cerrojo es de
		# este equipo, tiene latido y el proceso que lo cogio sigue vivo, no es una sesion muerta: se dice.
		# Tras un cuelgue de verdad ese proceso ya no existe y se recoge como siempre.
		if es_mio and _vivo(cerrojo) and _abierto_en_otra_ventana(cerrojo):
			return _fallo("ya_abierto", "Ya tienes este mundo abierto en otra ventana del juego.")
	# Nadie dentro (o el cerrojo es mio o ha caducado): lo va a abrir ESTE. Solo si es de la casa; uno de
	# fuera, aunque tenga codigo y contraseña, solo puede unirse a alguien de dentro que le acepte.
	var miembros: Array = mundo.get("miembros", [])
	if not miembros.is_empty() and not miembros.has(quien_soy):
		return _fallo("no_miembro", "Este mundo solo lo puede abrir quien ya juega en él. Entra cuando "
			+ "alguien de dentro lo tenga abierto: te tendrá que aceptar.")
	if not cerrojo.is_empty():
		var es_mio: bool = quien_soy != "" and String(cerrojo.get("identidad", "")) == quien_soy
		if es_mio:
			print("[nube] el cerrojo de %s ya era mio: lo recojo en vez de unirme a mi mismo" % id)
		# Cerrojo MIO, o arrendamiento CADUCADO (el que lo tenia se cayo). Se le quita y se sigue. Su
		# token queda atras para siempre porque abajo se incrementa el contador: si revive, su subida
		# se rechaza -- y eso es justo lo que protege del caso raro de tener el mundo abierto DOS veces
		# en esta misma maquina.
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
		# 'quien' es para ENSEÑARLO ("lo tiene Kapu"); 'identidad' es la que se compara arriba para
		# saber si el cerrojo es mio. El nombre de usuario de Windows no sirve para eso: dos personas
		# distintas pueden llamarse igual, y la misma persona cambia de maquina.
		"quien": OS.get_environment("USERNAME") if OS.has_environment("USERNAME") else "alguien",
		"identidad": quien_soy,
		# Que proceso y que equipo lo cogieron: para no quitarselo a otra ventana viva (ver arriba).
		"pid": OS.get_process_id(),
		"equipo": _este_equipo(),
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

	# Los miembros viajan en la cabecera (los jugadores con personaje en este save).
	var cab: Dictionary = meta.duplicate()
	var m = cab.get("miembros", [])
	if m is Array and not (m as Array).is_empty():
		mundo["miembros"] = m
	cab.erase("miembros")
	mundo["meta"] = cab
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


# ¿Lo tiene OTRO proceso de este mismo equipo que sigue abierto? Un cerrojo viejo (sin pid) no se
# puede comprobar y se da por muerto, que es lo que se hacia antes. OJO para la Fase 2: el Worker no
# puede mirar procesos ajenos; esta comprobacion tiene que seguir haciendola el cliente con lo que
# devuelva el servidor.
func _abierto_en_otra_ventana(cerrojo: Dictionary) -> bool:
	var pid: int = int(cerrojo.get("pid", 0))
	if pid <= 0 or pid == OS.get_process_id():
		return false
	if String(cerrojo.get("equipo", "")) != _este_equipo():
		return false
	return OS.is_process_running(pid)


func _este_equipo() -> String:
	return String(OS.get_environment("COMPUTERNAME")) if OS.has_environment("COMPUTERNAME") else ""


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
