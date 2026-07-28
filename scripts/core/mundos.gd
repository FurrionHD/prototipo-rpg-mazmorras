# ============================================================
#  mundos.gd  (AUTOLOAD: se llama "Mundos")
#  LOS MUNDOS COMPARTIDOS: la otra coleccion de partidas, la del apartado de MULTIJUGADOR.
#  Un mundo es una partida que puede abrir cualquiera de los que juegan en el (pero UNO a la vez:
#  de eso se encarga el cerrojo, ver cloud.gd) y que lleva DENTRO a todos los personajes, cada uno
#  a nombre de su jugador. Las 3 ranuras de siempre (Perfil) no se tocan: esas son de un jugador.
#
#  POR QUE ES UN AUTOLOAD APARTE Y NO UNAS RANURAS MAS DE PERFIL:
#    - `Perfil.ranura_actual` es un entero 1..3 sin noción de coleccion. Meterle un "modo" tiene
#      como peor caso ESCRIBIR UN MUNDO ENCIMA DE slot_2, o sea cargarse una partida de verdad.
#    - Un mundo tiene cosas que una ranura no tiene: id de nube, contraseña, direccion, icono, y si
#      es mio o de otra persona.
#  Efecto de red gratis: mientras hay un mundo abierto se pone `Perfil.ranura_actual = 0`, asi que
#  cualquier `Perfil.guardar_actual()` despistado AVISA en vez de escribir en una ranura ajena.
#
#  QUE HAY EN DISCO (user://mundos/):
#    <clave>.tres       el save del mundo. Es la copia local, y es la que sostiene una subida
#                       pendiente entre reinicios: si el proceso muere sin subir, los bytes siguen
#                       aqui para reintentarlo.
#    catalogo.cfg       una seccion por mundo con lo que hace falta para PINTAR LA LISTA sin
#                       preguntarle nada a la nube (nombre, icono, cabecera cacheada...).
#
#  LA CLAVE de un mundo mio es su id de nube (24 hex). Un mundo de otra persona al que solo tienes
#  IP y contraseña no tiene id de nube todavia, asi que se le da una clave local "dir_xxxx": el
#  catalogo es TU libreta, no un registro global.
# ============================================================

extends Node

const CARPETA := "user://mundos"
const CATALOGO := "user://mundos/catalogo.cfg"

# Cada cuanto se guarda solo. En un mundo compartido el autoguardado no es una comodidad: es lo que
# evita que un cuelgue se lleve la sesion, porque cuando tu arrendamiento caduque tu compañero
# abrira el mundo con lo ULTIMO SUBIDO.
# 60 y no 30 porque exportar recorre el arbol vivo y el fichero ronda el medio mega; si no se nota,
# se baja.
const SEG_AUTOGUARDADO := 60.0

# El mundo que tengo abierto ahora mismo (clave del catalogo). Vacio = ninguno, o sea que estoy en
# una ranura de un jugador o en el menu.
var abierto: String = ""

# La contraseña del mundo abierto. Hace DOS papeles a proposito (es una sola puerta con dos
# cerraduras): la nube la exige para dar el cerrojo, y es el CODIGO DE SALA con el que entran los
# demas. Asi se escribe una vez.
var _contrasena: String = ""

# Hay que hostear en cuanto se pise el pueblo: Net.hostear() no se puede llamar desde el menu
# (exige estar en el pueblo, ver net.gd:260) y el mundo tiene que quedar ABIERTO desde el minuto uno
# para que los demas entren cuando quieran.
var _hostear_al_llegar := false

var _acum := 0.0

# Para que la UI cuente lo que pasa sin tener que sondear.
signal aviso(texto: String)
signal catalogo_cambiado


func _ready() -> void:
	# Como Nube: el autoguardado y el "hostear al llegar" tienen que seguir vivos con el arbol
	# pausado, porque los menus de este juego pausan.
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(CARPETA)


func _process(delta: float) -> void:
	if _hostear_al_llegar and not Net.activo and Net.puede_abrir_sala():
		_hostear_al_llegar = false
		Net.hostear(_contrasena)
		aviso.emit("Mundo abierto. Tus compañeros ya pueden entrar.")

	if abierto == "":
		return
	_acum += delta
	if _acum < SEG_AUTOGUARDADO:
		return
	# Con una pelea en pantalla NO se guarda: el combate no vive en el save, asi que la foto saldria
	# a medias. Se espera al siguiente tick, que llegara en cuanto se cierre la pantalla.
	if Game.hay_pelea_en_pantalla():
		return
	# Y tampoco desde el menu: exportar_partida() lee el ARBOL VIVO (el nodo del jugador, la
	# mazmorra), y sin ellos guardaria una partida mutilada.
	if not _en_partida():
		return
	_acum = 0.0
	await autoguardar()


func _en_partida() -> bool:
	var esc: Node = get_tree().current_scene
	return esc != null and esc.scene_file_path.contains("/levels/")


# ============================================================
#  EL CATALOGO (tu libreta de mundos)
# ------------------------------------------------------------
func ruta(clave: String) -> String:
	return "%s/%s.tres" % [CARPETA, clave]


func _cfg() -> ConfigFile:
	var cfg := ConfigFile.new()
	var err: int = cfg.load(CATALOGO)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("[mundos] no se pudo leer el catalogo (error %d)" % err)
	return cfg


func _guardar_cfg(cfg: ConfigFile) -> void:
	var err: int = cfg.save(CATALOGO)
	if err != OK:
		push_warning("[mundos] no se pudo guardar el catalogo (error %d)" % err)
	else:
		catalogo_cambiado.emit()


# Una entrada del catalogo, ya con su estado en disco resuelto. Vacio si no existe.
func entrada(clave: String) -> Dictionary:
	var cfg := _cfg()
	if not cfg.has_section(clave):
		return {}
	var e := {"clave": clave}
	for k in cfg.get_section_keys(clave):
		e[k] = cfg.get_value(clave, k)
	var info: Dictionary = SaveIO.inspeccionar_ruta(ruta(clave))
	e["estado"] = int(info["estado"])
	e["motivo"] = SaveIO.motivo_texto(info)
	return e


# Todos los mundos, los mios primero y dentro de cada grupo el mas reciente arriba.
func catalogo() -> Array:
	var salida: Array = []
	for clave in _cfg().get_sections():
		var e: Dictionary = entrada(clave)
		if not e.is_empty():
			salida.append(e)
	salida.sort_custom(func(a, b):
		var ma: bool = bool(a.get("mio", false))
		var mb: bool = bool(b.get("mio", false))
		if ma != mb:
			return ma
		return String(a.get("fecha", "")) > String(b.get("fecha", "")))
	return salida


func _escribir_entrada(clave: String, campos: Dictionary) -> void:
	var cfg := _cfg()
	for k in campos:
		cfg.set_value(clave, k, campos[k])
	_guardar_cfg(cfg)


# ============================================================
#  ALTA de mundos
# ------------------------------------------------------------
# Un mundo MIO: lo doy de alta en la nube (que es quien guarda la contraseña) y en mi catalogo.
# El icono y el color son solo para reconocerlo en la lista.
func alta_propio(nombre: String, contrasena: String, icono: PackedByteArray = PackedByteArray(),
		color: Color = Color(0.45, 0.72, 1.0), recordar := true) -> Dictionary:
	var n := nombre.strip_edges()
	if n == "":
		return {"ok": false, "mensaje": "Ponle un nombre al mundo."}
	if contrasena == "":
		return {"ok": false, "mensaje": "Hace falta una contraseña: es la que pedirá a quien entre."}
	var id: String = Nube.nuevo_id()
	var r: Dictionary = await Nube.crear_mundo(id, contrasena)
	if not r.get("ok", false):
		return {"ok": false, "mensaje": String(r.get("mensaje", "No se pudo crear el mundo."))}
	_escribir_entrada(id, {
		"nombre": n,
		"icono": icono,
		"color": color,
		"mio": true,
		"id_nube": id,
		"contrasena": contrasena if recordar else "",
		"direccion": "",
		"fecha": Time.get_datetime_string_from_system(),
		"cab": "sin empezar",
	})
	print("[mundos] mundo propio creado: ", n, " (", id, ")")
	return {"ok": true, "clave": id}


# El mundo de OTRA PERSONA. Dos formas, y las dos valen:
#   - con su ID DE NUBE: el camino nativo del cerrojo (te dara la direccion de quien lo tenga
#     abierto ahora mismo, asi que no depende de que su IP sea siempre la misma).
#   - con su IP a pelo: conexion directa, sin pasar por la nube. Es lo que funciona HOY, porque el
#     almacen todavia es local (user://nube_test) y el mundo de tu compañero no esta en tu disco.
# En los dos casos hace falta la contraseña: es la que valida su juego al entrar.
func alta_ajeno(nombre: String, id_nube: String, contrasena: String, ip: String,
		icono: PackedByteArray = PackedByteArray(), color: Color = Color(0.8, 0.6, 0.4),
		recordar := true) -> Dictionary:
	var n := nombre.strip_edges()
	if n == "":
		return {"ok": false, "mensaje": "Ponle un nombre para reconocerlo en tu lista."}
	var idn := id_nube.strip_edges().to_lower()
	var dir := ip.strip_edges()
	if idn == "" and dir == "":
		return {"ok": false, "mensaje": "Hace falta su dirección o su código de mundo."}
	if contrasena == "":
		return {"ok": false, "mensaje": "Hace falta la contraseña del mundo."}
	# Un mundo del que solo tienes IP no tiene id de nube: se le da clave local (el catalogo es tu
	# libreta, no un registro global).
	var clave: String = idn if idn != "" else "dir_" + str(Time.get_ticks_usec()).sha256_text().substr(0, 12)
	_escribir_entrada(clave, {
		"nombre": n,
		"icono": icono,
		"color": color,
		"mio": false,
		"id_nube": idn,
		"contrasena": contrasena if recordar else "",
		"direccion": dir,
		"fecha": Time.get_datetime_string_from_system(),
		"cab": "mundo de otra persona",
	})
	print("[mundos] mundo ajeno dado de alta: ", n, " (", clave, ")")
	return {"ok": true, "clave": clave}


func borrar(clave: String) -> void:
	if clave == abierto:
		push_warning("[mundos] no se borra %s: esta abierto" % clave)
		return
	if FileAccess.file_exists(ruta(clave)):
		DirAccess.remove_absolute(ruta(clave))
	var cfg := _cfg()
	if cfg.has_section(clave):
		cfg.erase_section(clave)
	_guardar_cfg(cfg)


# ============================================================
#  ABRIR un mundo mio: coger el cerrojo y bajarse la partida
#  Tres desenlaces, y el que manda es "resultado":
#    "nuevo"   el cerrojo es mio y el mundo esta VACIO: hay que crear personaje (ver estrenar()).
#    "host"    el cerrojo es mio y hay partida: cargar y jugar.
#    "unirse"  lo tiene otro AHORA MISMO: en "direcciones" estan las suyas.
# ------------------------------------------------------------
func abrir(clave: String, contrasena: String, forzar_build := false) -> Dictionary:
	if abierto != "":
		return {"ok": false, "mensaje": "Ya tienes un mundo abierto."}
	var e: Dictionary = entrada(clave)
	if e.is_empty():
		return {"ok": false, "mensaje": "Ese mundo no está en tu lista."}
	if int(e.get("estado", SaveIO.VACIA)) not in [SaveIO.VACIA, SaveIO.OK]:
		# Una copia local que este build no entiende: NO se abre y se dice por que. Lo que no se
		# puede hacer es tratarla como un mundo vacio y estrenarlo encima.
		return {"ok": false, "mensaje": String(e.get("motivo", "Ese mundo no se puede abrir."))}

	var id: String = String(e.get("id_nube", ""))
	if id == "":
		return {"ok": false, "error": "sin_nube",
			"mensaje": "Ese mundo es de otra persona y solo tienes su dirección: hay que unirse, no abrirlo."}

	var dirs: Array = []
	if Identidad.direccion_preferida != "":
		dirs.append(Identidad.direccion_preferida)
	for d in Nube.direcciones_locales():
		if not dirs.has(d):
			dirs.append(d)

	var r: Dictionary = await Nube.abrir(id, contrasena, dirs, forzar_build)
	if not r.get("ok", false):
		return {"ok": false, "error": String(r.get("error", "")),
			"mensaje": String(r.get("mensaje", "No se pudo abrir el mundo."))}

	if String(r.get("resultado", "")) == "unirse":
		return {"ok": true, "resultado": "unirse", "direcciones": r.get("direcciones", []),
			"quien": String(r.get("quien", ""))}

	# El cerrojo es mio. Los bytes que baja la nube MANDAN sobre la copia local: puede haber jugado
	# el otro desde que yo cerre.
	# Que direccion se ha publicado, para poder DECIRSELO: es lo unico que tienen que teclear los
	# demas, y el juego no puede saber a ciencia cierta cual de las tuyas es la que ellos alcanzan.
	_escribir_entrada(clave, {"publicada": dirs[0] if not dirs.is_empty() else ""})

	var bytes: PackedByteArray = r.get("save", PackedByteArray())
	if bytes.is_empty():
		_contrasena = contrasena
		# La nube no tiene partida... pero puede haberla AQUI: una subida que nunca llego, o un
		# almacen que se vacio. Si hay copia local jugable, esa MANDA. Decir "mundo nuevo" aqui seria
		# ofrecer crear personaje, y estrenar() machacaria la partida que hay en el disco.
		var local: Dictionary = SaveIO.inspeccionar_ruta(ruta(clave))
		if int(local["estado"]) == SaveIO.OK:
			push_warning("[mundos] %s no esta en el almacen pero SI en el disco: manda la copia local" % clave)
			return {"ok": true, "resultado": "host", "clave": clave, "direcciones": dirs,
				"solo_local": true}
		return {"ok": true, "resultado": "nuevo", "clave": clave, "direcciones": dirs}
	if not SaveIO.escribir_bytes(ruta(clave), bytes):
		# Ojo: el cerrojo YA es mio. Se suelta para no dejar el mundo bloqueado por un fallo de disco.
		await Nube.cerrar(SaveIO.bytes_de_ruta(ruta(clave)), {})
		return {"ok": false, "mensaje": "No se pudo escribir la copia local del mundo."}
	var info: Dictionary = SaveIO.inspeccionar_ruta(ruta(clave))
	if int(info["estado"]) != SaveIO.OK:
		return {"ok": false, "mensaje": SaveIO.motivo_texto(info)}
	_contrasena = contrasena
	return {"ok": true, "resultado": "host", "clave": clave, "direcciones": dirs}


# ============================================================
#  UNIRSE al mundo de otra persona
#  ES EL UNICO CAMINO para unirse, y esta escrito asi a proposito: aqui vive la ULTIMA costura que
#  depende de la nube. La direccion se resuelve en dos intentos:
#    1. POR EL CERROJO: si tengo el codigo del mundo, se le pregunta al almacen quien lo tiene
#       abierto AHORA y se usan las direcciones que ha publicado. Es el camino bueno: no depende de
#       que la IP de tu compañero sea siempre la misma, ni de que te la vuelva a pasar.
#    2. LA QUE ESCRIBI A MANO. Con el almacen local esto es lo unico que funciona (el mundo de tu
#       compañero esta en SU disco, no en el mio), asi que hoy manda siempre.
#  El dia que el almacen sea el Worker de Cloudflare, (1) empieza a funcionar y no hay que tocar ni
#  este menu ni la capa de red: es literalmente el mismo codigo.
#
#  Lo que NO cambia nunca: la partida es ENet directo entre las dos maquinas. El almacen reparte la
#  direccion; que se pueda LLEGAR a ella sigue siendo cosa de Hamachi o del puerto abierto.
# ------------------------------------------------------------
func unirse(clave: String, contrasena: String) -> Dictionary:
	if abierto != "":
		return {"ok": false, "mensaje": "Tienes un mundo abierto: ciérralo antes de unirte a otro."}
	if Net.activo:
		return {"ok": false, "mensaje": "Ya estás en una sesión."}
	var e: Dictionary = entrada(clave)
	if e.is_empty():
		return {"ok": false, "mensaje": "Ese mundo no está en tu lista."}
	if contrasena == "":
		return {"ok": false, "mensaje": "Hace falta la contraseña del mundo."}

	var direcciones: Array = []
	var id: String = String(e.get("id_nube", ""))
	if id != "":
		var est: Dictionary = await Nube.consultar(id, contrasena)
		if est.get("ok", false):
			if not bool(est.get("abierto", false)):
				return {"ok": false, "error": "cerrado",
					"mensaje": "Ese mundo no lo tiene abierto nadie ahora mismo."}
			# caducado = el que lo tenia se cayo y su direccion esta MUERTA: no se intenta.
			if bool(est.get("caducado", false)):
				return {"ok": false, "error": "caducado",
					"mensaje": "Quien lo tenía abierto ha perdido la conexión. Espera un par de minutos."}
			for d in est.get("direcciones", []):
				direcciones.append(String(d))
	var manual: String = String(e.get("direccion", ""))
	if manual != "" and not direcciones.has(manual):
		direcciones.append(manual)
	if direcciones.is_empty():
		return {"ok": false, "mensaje": "No sé a qué dirección conectarme: añade la suya en la ficha "
			+ "de este mundo."}

	# Se prueba la primera; si no contesta, Net avisa y el jugador puede reintentar (probar la lista
	# entera en cadena necesita saber que un intento ha FALLADO, y eso solo lo dice el timeout de
	# ENet: se deja para cuando haya varias de verdad, que es con el Worker).
	var ip: String = String(direcciones[0])
	var err: int = Net.unirse(ip, contrasena, Net.PUERTO, true)
	if err != OK:
		return {"ok": false, "mensaje": "No se pudo conectar a %s." % ip}
	# Se recuerda a quien nos estamos uniendo: al llegar el personaje hay que saber de que mundo es.
	uniendome = clave
	return {"ok": true, "direccion": ip}


# La clave del mundo AJENO al que me estoy uniendo (vacio = a ninguno). No es `abierto`: ese mundo no
# es mio y yo no tengo su cerrojo ni su fichero; solo estoy jugando dentro.
var uniendome: String = ""


func dejar_de_unirse() -> void:
	uniendome = ""


# ESTRENAR un mundo recien creado: se llama DESPUES de Game.nueva_partida(). Deja el mundo por
# abierto y escrito en disco, listo para irse al pueblo.
func estrenar(clave: String) -> bool:
	abierto = clave
	Perfil.ranura_actual = 0
	_acum = 0.0
	# A partir de aqui esta partida es un MUNDO: al guardar, mis personajes y lo mio se empaquetan a
	# nombre de mi identidad, para que el dia que entre otro tenga su propio hueco al lado del mio.
	Game.mundo_compartido = true
	if not guardar_actual():
		abierto = ""
		return false
	_hostear_al_llegar = true
	return true


# CARGAR en memoria un mundo ya abierto (deja a Game listo). Quien llama decide a que escena ir.
func cargar(clave: String) -> bool:
	var info: Dictionary = SaveIO.inspeccionar_ruta(ruta(clave))
	if int(info["estado"]) != SaveIO.OK:
		push_warning("[mundos] no se puede cargar %s: %s" % [clave, SaveIO.motivo_texto(info)])
		return false
	var datos: SaveData = info["datos"] as SaveData
	Game.importar_partida(datos)
	abierto = clave
	# Un mundo NO es una ranura: dejar aqui la ranura vieja haria que un Perfil.guardar_actual()
	# despistado escribiera el mundo encima de una partida de un jugador.
	Perfil.ranura_actual = 0
	_acum = 0.0
	_hostear_al_llegar = true
	print("[mundos] mundo cargado: ", clave, " -> ", datos.resumen())
	return true


func datos_cabecera(clave: String) -> SaveData:
	return SaveIO.inspeccionar_ruta(ruta(clave))["datos"] as SaveData


# ============================================================
#  GUARDAR
#  guardar_actual() escribe SOLO en disco (rapido). La subida a la nube va aparte: en el
#  autoguardado (subir sin soltar) y al cerrar (subir y soltar).
# ------------------------------------------------------------
func guardar_actual() -> bool:
	if abierto == "":
		push_warning("[mundos] no hay mundo abierto: no se guarda")
		return false
	# ANTES de exportar, no despues: es `Game.mundo_compartido` lo que hace que exportar_partida
	# empaquete a los jugadores dentro. Si se pusiera solo en el SaveData de abajo, un mundo que se
	# hubiera cargado de un fichero SIN la marca (una partida de un jugador ascendida a mundo, o de un
	# build anterior a esto) se guardaria marcado como mundo pero con `jugadores` VACIO: seguiria
	# jugandose bien, pero el mundo habria dejado de recordar de quien es cada personaje EN SILENCIO,
	# que es justo lo unico que tiene que hacer.
	Game.mundo_compartido = true
	var datos: SaveData = Game.exportar_partida()
	# Y el mundo va SIEMPRE marcado como tal, con su version de esquema: es lo que permite que un
	# build viejo se niegue a abrirlo en vez de comerse los jugadores de dentro.
	datos.mundo_compartido = true
	datos.version_mundo = SaveData.VERSION_MUNDO
	var err: int = ResourceSaver.save(datos, ruta(abierto))
	if err != OK:
		push_warning("[mundos] no se pudo guardar el mundo %s (error %d)" % [abierto, err])
		return false
	_escribir_entrada(abierto, {
		"fecha": Time.get_datetime_string_from_system(),
		"cab": datos.resumen(),
	})
	return true


# Lo que dispara el temporizador: guarda en disco y SUBE sin soltar el cerrojo.
func autoguardar() -> bool:
	# PRIMERO se recoge lo de los demas y DESPUES se escribe: al reves (como estaba) el save saldria
	# sin el ultimo rato de tu compañero. Cada uno manda lo suyo y de aqui sale UN save.
	if Net.activo and Net.es_host:
		await Net.recoger_estados()
	if not guardar_actual():
		return false
	var r: Dictionary = await Nube.subir(SaveIO.bytes_de_ruta(ruta(abierto)), _meta())
	if not r.get("ok", false):
		aviso.emit("Autoguardado: guardado en tu disco, pero sin subir (%s)." % String(r.get("mensaje", "")))
		return false
	return true


# CERRAR el mundo: guardar, subir y soltar el cerrojo (en ese orden; si la subida falla el mundo
# sigue siendo tuyo y la Nube lo deja en PENDIENTE_SUBIR).
func cerrar_y_subir() -> Dictionary:
	if abierto == "":
		return {"ok": true}
	var clave := abierto
	# Lo mismo que en el autoguardado: primero lo de los demas, y AVISANDOLES de que se cierra (se van
	# al menu con su personaje ya dentro del save), y despues se escribe.
	if Net.activo and Net.es_host:
		await Net.recoger_estados(true)
	if not guardar_actual():
		return {"ok": false, "mensaje": "No se pudo guardar el mundo (no se cierra)."}
	var r: Dictionary = await Nube.cerrar(SaveIO.bytes_de_ruta(ruta(clave)), _meta())
	# Se suelta lo local en cualquier caso: si la subida fallo, la Nube se queda en PENDIENTE_SUBIR
	# y el .tres sigue en disco para reintentarlo.
	abierto = ""
	_contrasena = ""
	_hostear_al_llegar = false
	if not r.get("ok", false):
		_escribir_entrada(clave, {"pendiente": true})
		return {"ok": false, "mensaje": String(r.get("mensaje", "No se pudo subir el mundo."))}
	_escribir_entrada(clave, {"pendiente": false})
	return {"ok": true}


# ABANDONAR el mundo sin guardar. NO es un boton: es la red de seguridad del menu principal.
#
# Hay caminos anomalos que vuelven al menu sin pasar por "guardar y salir" (por ejemplo
# dungeon_floor cuando se encuentra sin partida cargada). Si el mundo se quedara marcado como
# abierto, lo siguiente seria GORDO: Game.guardar_mi_partida() mira `abierto` ANTES que la ranura,
# asi que al cargar despues una partida de un jugador sus autoguardados (morir, subir de nivel)
# irian a parar DENTRO del fichero del mundo, y su ranura no se guardaria nunca.
#
# Lo que NO se hace aqui es subir nada: no hay arbol vivo del que exportar, asi que la copia buena
# es la ultima que se guardo. El cerrojo se queda cogido hasta que caduque el arrendamiento (para
# eso existe), y por eso quien llama tiene que DECIRLO.
func abandonar() -> String:
	if abierto == "":
		return ""
	var clave := abierto
	push_warning("[mundos] se abandona %s sin cerrar: el cerrojo caducara solo" % clave)
	abierto = ""
	_contrasena = ""
	_hostear_al_llegar = false
	_acum = 0.0
	Game.mundo_compartido = false
	Game.jugadores_mundo.clear()
	return clave


# Reintentar una subida que quedo a medias (el mundo sigue reservado a tu nombre).
func reintentar(clave: String) -> Dictionary:
	var bytes: PackedByteArray = SaveIO.bytes_de_ruta(ruta(clave))
	if bytes.is_empty():
		return {"ok": false, "mensaje": "No hay copia local que subir."}
	var r: Dictionary = await Nube.reintentar_subida(bytes, _meta_de(clave))
	if r.get("ok", false):
		_escribir_entrada(clave, {"pendiente": false})
	return r


# La cabecera LIGERA que se le deja a la nube para pintar la lista sin bajarse el save entero.
func _meta() -> Dictionary:
	return _meta_de(abierto)


func _meta_de(clave: String) -> Dictionary:
	var datos: SaveData = datos_cabecera(clave)
	if datos == null:
		return {}
	return {
		"nombre": datos.nombre,
		"cab_nivel": datos.cab_nivel,
		"cab_piso": datos.cab_piso,
		"cab_dinero": datos.cab_dinero,
		"cab_lugar": datos.cab_lugar,
		"fecha": datos.fecha,
	}
