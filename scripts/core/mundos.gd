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
#  BASE DE DATOS (fase 2 de la BD, 07/10/2026): el mundo vive en user://bd/mundo_<clave>.sqlite (ver
#  PartidaBD) y en la nube como FILAS (servidor/nube): al guardar se escriben y se suben SOLO las filas
#  cambiadas, no el fichero entero. Al abrir manda la nube por REV, no por fecha (ver _poner_al_dia).
#  Un mundo viejo (.tres en disco, o un save entero en la nube) se migra al abrirlo, verificado
#  (MigracionBD); si no sale identico se sigue jugando con su .tres como siempre (_bd == null).
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

# Hay que hostear en cuanto se llegue a la partida: Net.hostear() no se puede llamar desde el menu
# (exige pueblo o un piso ya construido, ver Net.puede_abrir_sala) y el mundo tiene que quedar ABIERTO
# desde el minuto uno para que los demas entren cuando quieran.
var _hostear_al_llegar := false
# Cuanto lleva la escena lista para abrir sala. Se espera un poco en la mazmorra: el piso pare y
# restaura a sus enemigos DIFERIDOS, y los que nacieran despues de registrar se quedarian fuera.
var _t_listo := 0.0
const ESPERA_SALA := 1.0

var _acum := 0.0

# LA BASE DE DATOS del mundo abierto (null = un mundo que no se pudo migrar: va con su .tres, como antes).
var _bd: PartidaBD = null
var _ids := BDFilas.Ids.new()
# El rev de la nube del que parte la copia de este disco: es la "base" de cada subida (si la nube no esta
# ahi, la subida se rechaza en vez de machacar). Lo da abrir y lo sube cada sync.
var _rev_nube: int = 0
# Los que quedaron con la subida del cierre pendiente: clave -> rev de la nube (para reintentar).
var _rev_pendiente: Dictionary = {}
const RESPALDOS_CONFLICTO := "user://respaldos/conflictos"

# El SaveData del ultimo guardado de ESTE mundo, para no tener que releer el fichero solo por su
# cabecera (ver _meta). Se suelta al cerrar o al abandonar: si no es del mundo abierto, no vale.
var _cab_en_mano: SaveData = null

# SOLO LA SALA: su entrada por Steam ("steam:<id>"), que abrir() publica al final de las direcciones.
# Vacia = sin Steam: la sala va solo por Hamachi, como antes. Ver tunel_steam.gd.
const _TUNEL = preload("res://scripts/net/tunel_steam.gd")
var direccion_steam: String = ""

# Para que la UI cuente lo que pasa sin tener que sondear.
signal aviso(texto: String)
signal catalogo_cambiado


func _ready() -> void:
	# Como Nube: el autoguardado y el "hostear al llegar" tienen que seguir vivos con el arbol
	# pausado, porque los menus de este juego pausan.
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(CARPETA)


func _process(delta: float) -> void:
	# LA SALA abre la sesion ella misma al arrancar (ver sala.gd) y no tiene escena de juego delante.
	if Net.soy_sala:
		_hostear_al_llegar = false
	if _hostear_al_llegar and not Net.activo and Net.puede_abrir_sala():
		_t_listo += delta
		if _t_listo >= ESPERA_SALA:
			_hostear_al_llegar = false
			_t_listo = 0.0
			if Net.hostear(_contrasena) == OK:
				aviso.emit("Mundo abierto. Tus compañeros ya pueden entrar.")
			else:
				_hostear_al_llegar = true   # p.ej. te han metido en una pelea justo ahora: se reintenta
	else:
		_t_listo = 0.0

	if abierto == "":
		return
	_acum += delta
	if _acum < SEG_AUTOGUARDADO:
		return
	# LA SALA no tiene jugador, ni pelea en pantalla, ni pueblo delante: guarda siempre (lo de cada uno
	# se lo pide a cada uno, ver Net.partida.recoger_estados).
	if not Net.soy_sala:
		# Con una pelea en pantalla NO se guarda: el combate no vive en el save, asi que la foto saldria
		# a medias. Se espera al siguiente tick, que llegara en cuanto se cierre la pantalla.
		if Game.hay_pelea_en_pantalla():
			return
		# Y tampoco desde el menu: exportar_partida() lee el ARBOL VIVO (el nodo del jugador, la
		# mazmorra), y sin ellos guardaria una partida mutilada.
		if not en_partida():
			return
	_acum = 0.0
	await autoguardar()


# ¿Hay una PARTIDA VIVA delante (pueblo o mazmorra) y no un menu? Publica porque la pregunta no es
# solo del autoguardado: Pantalla la usa para saber si al cerrar la ventana hay algo que guardar.
func en_partida() -> bool:
	var esc: Node = get_tree().current_scene
	return esc != null and esc.scene_file_path.contains("/levels/")


# ============================================================
#  EL CATALOGO (tu libreta de mundos)
# ------------------------------------------------------------
func ruta(clave: String) -> String:
	return "%s/%s.tres" % [CARPETA, clave]


func ruta_bd(clave: String) -> String:
	return PartidaBD.ruta_de("mundo_" + clave)


## ¿Este mundo vive ya en su base de datos en este disco?
func usa_bd(clave: String) -> bool:
	return PartidaBD.existe(ruta_bd(clave))


# Lo que se sabe de la copia de este disco (SaveIO.inspeccionar_ruta): de su BD si la tiene (solo la
# cabecera si se pide: pintar la lista), y si no del .tres.
func inspeccionar(clave: String, solo_cabecera := false) -> Dictionary:
	if usa_bd(clave):
		return PartidaBD.inspeccionar_ruta(ruta_bd(clave), solo_cabecera)
	return SaveIO.inspeccionar_ruta(ruta(clave))


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
	var info: Dictionary = inspeccionar(clave, true)
	e["estado"] = int(info["estado"])
	e["motivo"] = SaveIO.motivo_texto(info)
	return e


# Todos los mundos, los mios primero y dentro de cada grupo el mas reciente arriba.
func catalogo() -> Array:
	var salida: Array = []
	for clave in _cfg().get_sections():
		var e: Dictionary = entrada(clave)
		# Los TEMPORALES (apuntados solo para entrar invitado, ver apuntar_invitacion) no son tuyos.
		if not e.is_empty() and not bool(e.get("temporal", false)):
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
	PartidaBD.borrar(ruta_bd(clave))
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
	# La SALA por Steam ("steam:<id>"), SIEMPRE LA ULTIMA: el juego de antes de Steam solo mira la primera.
	if direccion_steam != "":
		dirs.append(direccion_steam)

	var r: Dictionary = await Nube.abrir(id, contrasena, dirs, forzar_build)
	# UN MUNDO MIO QUE LA NUBE NO CONOCE: es uno creado antes de que existiera la nube de verdad (vivia
	# en el almacen de pruebas de este PC). Se da de alta alli con SU MISMO codigo --asi los que ya lo
	# tienen apuntado no tienen que cambiar nada-- y se vuelve a abrir: como la nube no tiene partida,
	# manda la copia de este disco (ver mas abajo) y se sube en el primer guardado.
	# Solo con la contraseña que este PC recuerda, si recuerda alguna: una tecleada mal daria de alta
	# el mundo con una contraseña que no es la suya.
	if not r.get("ok", false) and String(r.get("error", "")) == "no_autorizado" \
			and bool(e.get("mio", false)) and int(e.get("estado", SaveIO.VACIA)) == SaveIO.OK \
			and (String(e.get("contrasena", "")) == "" or String(e.get("contrasena", "")) == contrasena):
		var alta: Dictionary = await Nube.crear_mundo(id, contrasena)
		if alta.get("ok", false):
			print("[mundos] %s no estaba en la nube: dado de alta con su codigo de siempre" % id)
			r = await Nube.abrir(id, contrasena, dirs, forzar_build)
	if not r.get("ok", false):
		return {"ok": false, "error": String(r.get("error", "")),
			"mensaje": String(r.get("mensaje", "No se pudo abrir el mundo."))}

	if String(r.get("resultado", "")) == "unirse":
		return {"ok": true, "resultado": "unirse", "direcciones": r.get("direcciones", []),
			"quien": String(r.get("quien", ""))}

	# El cerrojo es mio.
	# Que direccion se ha publicado, para poder DECIRSELO: es lo unico que tienen que teclear los
	# demas, y el juego no puede saber a ciencia cierta cual de las tuyas es la que ellos alcanzan.
	_escribir_entrada(clave, {"publicada": dirs[0] if not dirs.is_empty() else ""})
	var listo: Dictionary = await _poner_al_dia(clave, e, r)
	if not listo.get("ok", false):
		return listo
	_contrasena = contrasena
	listo["clave"] = clave
	listo["direcciones"] = dirs
	return listo


# ============================================================
#  QUE COPIA MANDA AL ABRIR (con el cerrojo ya en la mano). Deja la copia de este disco al dia y dice
#  si hay partida ("host") o el mundo esta por estrenar ("nuevo").
#  Con el mundo YA EN BASE DE DATOS en la nube manda el REV, no la fecha:
#    - mi copia parte del rev de la nube           -> es la buena (lo que tenga sin subir, sube luego)
#    - la nube va por delante y yo no tengo nada sin subir -> me bajo SOLO lo cambiado desde mi rev
#    - la nube va por delante y yo TAMBIEN cambie (un cierre que no llego a subir mientras otro jugaba)
#      -> manda la nube (alguien jugo encima) y mi copia va a respaldos/conflictos: no se pierde
#    - no tengo copia -> me la bajo entera
#  Con el mundo VIEJO en la nube (un save entero) o sin nada: el save de la nube manda salvo que la
#  copia de aqui sea mas nueva y se quedara sin subir (como antes); la que gane se MIGRA a la BD y se
#  sube entera. Si no se puede migrar (no sale identica), el mundo sigue con su .tres como siempre.
# ------------------------------------------------------------
func _poner_al_dia(clave: String, e: Dictionary, r: Dictionary) -> Dictionary:
	var formato: String = String(r.get("formato", ""))
	_rev_nube = int(r.get("bd_rev", 0))
	_cerrar_bd()
	if formato == "bd":
		return await _al_dia_desde_bd(clave)

	var bytes: PackedByteArray = r.get("save", PackedByteArray())
	var fecha_nube: String = String((r.get("meta", {}) as Dictionary).get("fecha", ""))
	var local: Dictionary = inspeccionar(clave, true)
	var hay_local: bool = int(local["estado"]) == SaveIO.OK and local["datos"] != null
	# UNA SUBIDA QUE QUEDO PENDIENTE: la copia de este disco es MAS NUEVA que la de la nube (se guardo y
	# no llego a subir). Bajar la de la nube encima tiraria ese rato. Solo si de verdad es mas nueva: si
	# mientras tanto otro abrio el mundo y jugo, la de la nube manda.
	# Y si la nube no tiene partida pero AQUI si (una subida que nunca llego, o un almacen que se vacio),
	# manda la de aqui: decir "mundo nuevo" seria ofrecer crear personaje encima de la partida del disco.
	var manda_local: bool = hay_local and (bytes.is_empty() or (bool(e.get("pendiente", false))
		and String((local["datos"] as SaveData).fecha) > fecha_nube))
	if manda_local:
		push_warning("[mundos] %s: manda la copia de este disco (%s)" % [clave,
			"la nube no tiene partida" if bytes.is_empty() else "tenia la subida pendiente"])
	elif bytes.is_empty():
		return {"ok": true, "resultado": "nuevo"}
	else:
		# Manda la de la nube: se escribe como .tres (como siempre) y se migra desde ahi.
		if not SaveIO.escribir_bytes(ruta(clave), bytes):
			Nube._olvidar()   # el cerrojo caduca solo (y a mi me lo devuelve antes)
			return {"ok": false, "mensaje": "No se pudo escribir la copia local del mundo."}
		var info: Dictionary = SaveIO.inspeccionar_ruta(ruta(clave))
		if int(info["estado"]) != SaveIO.OK:
			Nube._olvidar()
			return {"ok": false, "mensaje": SaveIO.motivo_texto(info)}
		PartidaBD.borrar(ruta_bd(clave))   # una BD de aqui de antes de esto ya no vale

	# A la base de datos (si no lo estaba ya), y entera a la nube.
	if not usa_bd(clave):
		var m: Dictionary = MigracionBD.migrar(ruta(clave), ruta_bd(clave))
		if not m["ok"]:
			push_warning("[mundos] %s NO se pasa a la base de datos (%s): sigue con su .tres" % [clave, m["motivo"]])
			return {"ok": true, "resultado": "host", "solo_local": manda_local}
	if not _abrir_bd(clave):
		return {"ok": false, "mensaje": "No se pudo abrir la base de datos del mundo."}
	_bd.olvidar_nube()   # la nube no tiene estas filas: la proxima subida va entera
	var s: Dictionary = await _subir_bd(false, _meta_de(clave))
	if not s.get("ok", false):
		# No pasa nada: queda apuntado y se reintenta en el siguiente guardado.
		push_warning("[mundos] %s: migrado aqui pero sin subir aun (%s)" % [clave, String(s.get("mensaje", ""))])
	_cerrar_bd()
	return {"ok": true, "resultado": "host", "solo_local": manda_local}


func _al_dia_desde_bd(clave: String) -> Dictionary:
	var habia: bool = usa_bd(clave)   # sin copia aqui: se baja entera, no hay nada que respaldar
	var bd := PartidaBD.new()
	if not bd.abrir(ruta_bd(clave)):
		Nube._olvidar()
		return {"ok": false, "mensaje": "No se pudo abrir la base de datos del mundo."}
	var mia: int = bd.rev_nube()
	var desde: int = 0
	if mia == _rev_nube and mia >= 0:
		bd.cerrar()
		print("[mundos] %s: la copia de este disco esta al dia (rev %d)" % [clave, mia])
		return {"ok": true, "resultado": "host"}
	if mia >= 0 and mia < _rev_nube and not bd.hay_pendientes():
		desde = mia
	elif habia:
		# Las dos han cambiado (o la de aqui nunca subio): manda la nube y la de aqui se guarda aparte.
		bd.cerrar()
		_respaldar_conflicto(clave)
		bd.abrir(ruta_bd(clave))
	var b: Dictionary = await Nube.bajar_bd(desde)
	if not b.get("ok", false):
		bd.cerrar()
		Nube._olvidar()
		return {"ok": false, "mensaje": String(b.get("mensaje", "No se pudo bajar el mundo."))}
	var ok: bool = bd.aplicar(b.get("filas", []), bool(b.get("completa", desde == 0)), int(b.get("rev", _rev_nube)))
	_rev_nube = int(b.get("rev", _rev_nube))
	bd.cerrar()
	if not ok:
		Nube._olvidar()
		return {"ok": false, "mensaje": "No se pudo escribir la copia local del mundo."}
	print("[mundos] %s: bajado de la nube %s (%d filas, rev %d)" % [clave,
		"entero" if bool(b.get("completa", desde == 0)) else "lo cambiado desde el rev %d" % desde, (b.get("filas", []) as Array).size(), _rev_nube])
	if int(inspeccionar(clave, true)["estado"]) != SaveIO.OK:
		return {"ok": false, "mensaje": SaveIO.motivo_texto(inspeccionar(clave, true))}
	return {"ok": true, "resultado": "host"}


# La copia de este disco que pierde un conflicto: aparte, con la fecha, para no perder nada.
func _respaldar_conflicto(clave: String) -> void:
	DirAccess.make_dir_recursive_absolute(RESPALDOS_CONFLICTO)
	var destino: String = "%s/mundo_%s_%s.sqlite" % [RESPALDOS_CONFLICTO, clave,
		Time.get_datetime_string_from_system().replace(":", "-") + "_%d" % (Time.get_ticks_msec() % 100000)]
	DirAccess.copy_absolute(ProjectSettings.globalize_path(ruta_bd(clave)), ProjectSettings.globalize_path(destino))
	push_warning("[mundos] %s: la nube y este disco habian cambiado los dos; manda la nube y la copia de aqui queda en %s" % [clave, destino])


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
# invitacion = el token de una invitacion de Steam (ver invitaciones_steam.gd): con el, la sala me deja
# pasar sin preguntar a los de dentro.
func unirse(clave: String, contrasena: String, invitacion := "") -> Dictionary:
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
	Net.invitacion_saludo = invitacion
	var manual: String = String(e.get("direccion", ""))
	if manual != "" and not direcciones.has(manual):
		direcciones.append(manual)

	# POR STEAM, si la sala lo ha publicado: sin Hamachi ni IPs (ver tunel_steam.gd). Si Steam no esta,
	# se cae a las direcciones de siempre; solo se falla si no queda ninguna.
	var id_steam: int = _TUNEL.id_en(direcciones)
	var ips: Array = direcciones.filter(func(d): return not String(d).begins_with(_TUNEL.PREFIJO))
	if id_steam != 0:
		var motivo: String = _TUNEL.iniciar_cuenta()
		if motivo == "":
			var st: Object = Engine.get_singleton("Steam")
			var puerto: int = Net.tunel.abrir_cliente(_TUNEL.TransporteSteam.new(st, id_steam), id_steam)
			if puerto > 0 and Net.unirse("127.0.0.1", contrasena, puerto, true) == OK:
				uniendome = clave
				return {"ok": true, "direccion": "Steam"}
			Net.tunel.cerrar()
			motivo = "No se pudo preparar la conexión por Steam."
		print("[mundos] por Steam no: %s" % motivo)
		if ips.is_empty():
			return {"ok": false, "mensaje": motivo + " Quien tiene el mundo lo ha abierto por Steam."}

	if ips.is_empty():
		return {"ok": false, "mensaje": "No sé a qué dirección conectarme: añade la suya en la ficha "
			+ "de este mundo."}

	# Se prueba la primera; si no contesta, Net avisa y el jugador puede reintentar (probar la lista
	# entera en cadena necesita saber que un intento ha FALLADO, y eso solo lo dice el timeout de
	# ENet: se deja para cuando haya varias de verdad, que es con el Worker).
	var ip: String = String(ips[0])
	var err: int = Net.unirse(ip, contrasena, Net.PUERTO, true)
	if err != OK:
		return {"ok": false, "mensaje": "No se pudo conectar a %s." % ip}
	# Se recuerda a quien nos estamos uniendo: al llegar el personaje hay que saber de que mundo es.
	uniendome = clave
	return {"ok": true, "direccion": ip}


# ============================================================
#  ENTRAR (fase 3): EL UNICO BOTON
#  El mundo compartido ya no lo abre el juego del jugador: lo abre LA SALA (scripts/net/sala.gd), un
#  Godot sin ventana, y todos los jugadores entran como clientes, tambien quien la lanza. Asi la
#  partida sigue para los demas aunque el que abrio cierre su juego.
#  Tres casos, en este orden:
#    1. Mi sala de este mundo sigue viva en ESTE PC -> me reconecto a ella.
#    2. Lo tiene abierto OTRO (la nube lo dice) -> me uno a el.
#    3. No hay nadie (o el cerrojo es de mi propia sala, que se cayo) -> lanzo la sala y entro.
#  Lo que pase despues (me dan mi personaje, o me piden que lo cree) es el camino de siempre del que
#  se une: Net.partida._tu_jugador / _crea_tu_personaje.
# ------------------------------------------------------------
const _SALA = preload("res://scripts/net/sala.gd")
# Lo que se espera a que la sala arranque: carga el mundo, habla con la nube y abre el puerto.
const PLAZO_SALA := 60.0

func entrar(clave: String, contrasena: String, forzar_build := false) -> Dictionary:
	if abierto != "":
		return {"ok": false, "mensaje": "Tienes un mundo abierto: ciérralo antes."}
	if Net.activo:
		return {"ok": false, "mensaje": "Ya estás en una sesión."}
	var e: Dictionary = entrada(clave)
	if e.is_empty():
		return {"ok": false, "mensaje": "Ese mundo no está en tu lista."}
	if contrasena == "":
		return {"ok": false, "mensaje": "Hace falta la contraseña del mundo."}
	var id: String = String(e.get("id_nube", ""))
	if id == "":
		return await unirse(clave, contrasena)   # solo tengo su direccion: no hay nada que abrir
	var viva: Dictionary = await _sala_viva(clave)
	if not viva.is_empty():
		print("[mundos] %s: mi sala sigue abierta en este PC, me reconecto" % clave)
		return await _conectar_a_mi_sala(clave, contrasena, int(viva.get("pid", 0)))
	var est: Dictionary = await Nube.consultar(id, contrasena)
	if not est.get("ok", false):
		# UN MUNDO MIO QUE LA NUBE AUN NO CONOCE (de antes de la nube de verdad): "no existe" aqui
		# significa "todavia no esta subido". Se lanza la sala, que lo da de alta con su mismo codigo
		# y sube la copia de este disco (ver abrir). Si la contraseña no es la que este PC recuerda,
		# la sala lo rechazara con el mismo mensaje.
		if String(est.get("error", "")) == "no_autorizado" and bool(e.get("mio", false)) \
				and int(e.get("estado", SaveIO.VACIA)) == SaveIO.OK:
			print("[mundos] %s no esta en la nube todavia: lo sube la sala" % clave)
			return await _lanzar_sala(clave, contrasena, forzar_build)
		return {"ok": false, "error": String(est.get("error", "")),
			"mensaje": String(est.get("mensaje", "No se pudo consultar el mundo."))}
	if bool(est.get("abierto", false)) and not bool(est.get("caducado", false)) \
			and not bool(est.get("es_mio", false)):
		return await unirse(clave, contrasena)
	return await _lanzar_sala(clave, contrasena, forzar_build)


# La sala de ESTE mundo que sigue viva en este PC (su estado), o vacio. Si esta cerrandose, se espera a
# que acabe: su cierre es la ultima escritura del mundo y la nueva sala tiene que partir de ella.
func _sala_viva(clave: String) -> Dictionary:
	var est: Dictionary = _SALA.leer_estado(clave)
	var pid: int = int(est.get("pid", 0))
	if est.is_empty() or pid <= 0 or not OS.is_process_running(pid):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_SALA.ruta_estado(clave)))
		return {}
	if String(est.get("estado", "")) == "cerrando":
		var t := 0.0
		while OS.is_process_running(pid) and t < 30.0:
			await get_tree().create_timer(0.25).timeout
			t += 0.25
		return {}
	if String(est.get("estado", "")) in ["lista", "arrancando"]:
		return est
	return {}


func _lanzar_sala(clave: String, contrasena: String, forzar_build: bool) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(_SALA.CARPETA)
	# La contraseña, por un fichero que la sala lee y borra (en la linea de ordenes la veria cualquiera).
	var f := FileAccess.open(_SALA.ruta_pedido(clave), FileAccess.WRITE)
	if f == null:
		return {"ok": false, "mensaje": "No se pudo preparar la sala del mundo."}
	f.store_string(contrasena)
	f.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_SALA.ruta_estado(clave)))
	var registro := OS.get_user_data_dir().path_join("logs")
	DirAccess.make_dir_recursive_absolute(registro)
	var args: PackedStringArray = ["--headless"]
	if OS.has_feature("editor"):
		args.append_array(["--path", ProjectSettings.globalize_path("res://")])
	args.append_array(["--log-file", registro.path_join("sala.log"),
		"--", _SALA.ARG, clave, str(Net.PUERTO), Identidad.id])
	# La sala habla con la MISMA nube que yo (las pruebas van contra la local o contra wrangler dev).
	for a in OS.get_cmdline_user_args():
		if a.begins_with("nube_url=") or a == "nube_local" or a.begins_with("sala_vacia=") \
				or a.begins_with("sala_espera="):
			args.append(a)
	if forzar_build:
		args.append("forzar_build")
	var pid := OS.create_process(OS.get_executable_path(), args)
	if pid <= 0:
		return {"ok": false, "mensaje": "No se pudo arrancar la sala del mundo."}
	print("[mundos] sala de %s lanzada (pid %d)" % [clave, pid])
	aviso.emit("Abriendo el mundo...")
	return await _conectar_a_mi_sala(clave, contrasena, pid)


# Esperar a que la sala este lista y entrar como un cliente mas, por 127.0.0.1.
func _conectar_a_mi_sala(clave: String, contrasena: String, pid: int) -> Dictionary:
	var est: Dictionary = {}
	var t := 0.0
	while t < PLAZO_SALA:
		est = _SALA.leer_estado(clave)
		var estado: String = String(est.get("estado", ""))
		if estado == "lista":
			break
		if estado == "error":
			return {"ok": false, "error": String(est.get("error", "")),
				"mensaje": String(est.get("mensaje", "No se pudo abrir el mundo."))}
		if estado == "unirse":
			# Otro lo abrio justo a la vez: se entra con el.
			return await unirse(clave, contrasena)
		if pid > 0 and not OS.is_process_running(pid):
			return {"ok": false, "mensaje": "La sala del mundo se ha cerrado al arrancar (mira logs/sala.log)."}
		await get_tree().create_timer(0.2).timeout
		t += 0.2
	if String(est.get("estado", "")) != "lista":
		return {"ok": false, "mensaje": "La sala del mundo no ha arrancado a tiempo."}
	var err: int = Net.unirse("127.0.0.1", contrasena, int(est.get("puerto", Net.PUERTO)), true)
	if err != OK:
		return {"ok": false, "mensaje": "No se pudo conectar con la sala del mundo."}
	uniendome = clave
	return {"ok": true, "resultado": "conectando", "direccion": "127.0.0.1",
		"direcciones": est.get("direcciones", [])}


# La sala de este mundo, si esta abierta en ESTE PC: {"humanos": n} o vacio. Lo pinta la lista de mundos.
func sala_en_este_pc(clave: String) -> Dictionary:
	var est: Dictionary = _SALA.leer_estado(clave)
	var pid: int = int(est.get("pid", 0))
	if est.is_empty() or pid <= 0 or not OS.is_process_running(pid):
		return {}
	return {"humanos": int(est.get("humanos", 0)), "estado": String(est.get("estado", ""))}


# La clave del mundo AJENO al que me estoy uniendo (vacio = a ninguno). No es `abierto`: ese mundo no
# es mio y yo no tengo su cerrojo ni su fichero; solo estoy jugando dentro.
var uniendome: String = ""


func dejar_de_unirse() -> void:
	uniendome = ""


# ============================================================
#  LAS INVITACIONES DE STEAM (ver invitaciones_steam.gd)
#  La que ha llegado y aun no se ha atendido: {id_nube, contrasena, token, nombre, de}. La atiende el
#  menu de Multijugador (multi_menu.atender_invitacion) en cuanto esta delante.
# ------------------------------------------------------------
var invitacion: Dictionary = {}


# Apunta el mundo de la invitacion en el catalogo, si no estaba, y devuelve su clave. Para entrar hace
# falta una entrada (unirse lee de ella), asi que si el jugador NO quiere quedarse el mundo se apunta
# igual, marcado TEMPORAL: no sale en la lista y se borra en cuanto se vuelve al menu (quitar_temporales).
func apuntar_invitacion(inv: Dictionary, quedarselo: bool) -> String:
	var clave: String = String(inv.get("id_nube", ""))
	if not entrada(clave).is_empty():
		if quedarselo:
			_escribir_entrada(clave, {"temporal": false, "contrasena": String(inv.get("contrasena", ""))})
		return clave
	var r: Dictionary = alta_ajeno(String(inv.get("nombre", "Mundo")), clave,
		String(inv.get("contrasena", "")), "")
	if not r.get("ok", false):
		return ""
	if not quedarselo:
		_escribir_entrada(clave, {"temporal": true})
	return clave


# Borra los mundos apuntados solo para entrar invitado. El que estoy usando ahora mismo se queda.
func quitar_temporales() -> void:
	var cfg := _cfg()
	for clave in cfg.get_sections():
		if bool(cfg.get_value(clave, "temporal", false)) and not (Net.activo and clave == uniendome):
			print("[mundos] fuera de la lista: %s (solo era para entrar invitado)" % clave)
			borrar(clave)


# ESTRENAR un mundo recien creado: se llama DESPUES de Game.nueva_partida(). Deja el mundo por
# abierto y escrito en disco, listo para irse al pueblo.
func estrenar(clave: String) -> bool:
	abierto = clave
	_cab_en_mano = null
	# Un mundo nuevo nace ya en su base de datos (vacia: lo de una partida anterior con esta clave fuera).
	_cerrar_bd()
	PartidaBD.borrar(ruta_bd(clave))
	if not _abrir_bd(clave):
		abierto = ""
		return false
	_bd.olvidar_nube()
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
	var info: Dictionary
	if usa_bd(clave):
		if not _abrir_bd(clave):
			push_warning("[mundos] no se puede abrir la base de datos de %s" % clave)
			return false
		var ids := BDFilas.Ids.new()
		info = PartidaBD.inspeccionar(_bd, ids)
		_ids = ids   # el primer guardado reconoce los mismos objetos y no reescribe nada
	else:
		_cerrar_bd()
		info = SaveIO.inspeccionar_ruta(ruta(clave))
	if int(info["estado"]) != SaveIO.OK:
		push_warning("[mundos] no se puede cargar %s: %s" % [clave, SaveIO.motivo_texto(info)])
		return false
	var datos: SaveData = info["datos"] as SaveData
	Game.importar_partida(datos)
	abierto = clave
	_cab_en_mano = null   # la de este mundo aun no se ha escrito: hasta el primer guardado, a releerla
	# Un mundo NO es una ranura: dejar aqui la ranura vieja haria que un Perfil.guardar_actual()
	# despistado escribiera el mundo encima de una partida de un jugador.
	Perfil.ranura_actual = 0
	_acum = 0.0
	_hostear_al_llegar = true
	print("[mundos] mundo cargado: ", clave, " -> ", datos.resumen())
	return true


func datos_cabecera(clave: String) -> SaveData:
	return inspeccionar(clave, true)["datos"] as SaveData


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
	if _bd != null:
		# En la base de datos: solo las filas que han cambiado (y quedan apuntadas para subirlas).
		if _bd.escribir(BDFilas.a_filas(datos, _ids)) < 0:
			push_warning("[mundos] no se pudo guardar el mundo %s en su base de datos" % abierto)
			return false
	else:
		var err: int = ResourceSaver.save(datos, ruta(abierto))
		if err != OK:
			push_warning("[mundos] no se pudo guardar el mundo %s (error %d)" % [abierto, err])
			return false
	# Lo que se acaba de escribir, para que la cabecera de la nube salga de aqui y no de releer el
	# fichero (ver _meta). Es el MISMO objeto que ha ido al disco, asi que dice exactamente lo mismo.
	_cab_en_mano = datos
	_escribir_entrada(abierto, {
		"fecha": Time.get_datetime_string_from_system(),
		"cab": datos.resumen(),
	})
	return true


# Lo que dispara el temporizador: guarda en disco y SUBE sin soltar el cerrojo.
#
# DE UNO EN UNO, Y LOS QUE SE PISEN SE JUNTAN EN UNO. Aqui llegan el temporizador, el boton de
# guardar, cada tanda del gacha y CADA PETICION DE CADA INVITADO (ver net_partida._pedir_guardar),
# y no habia ningun freno: en el playtest del 19/09 salieron 91 subidas de un fichero de 5 MB en una
# sesion, con cinco seguidas nada mas empezar. Si ya hay uno corriendo, el que llega no arranca otro:
# se apunta, espera a que acabe y con eso se hace UNA sola pasada mas al final —que hace falta,
# porque lo que haya pasado despues de empezar la anterior todavia no esta escrito—.
var _guardando := false
var _repetir := false
var _ultimo_ok := true

func autoguardar() -> bool:
	if _guardando:
		_repetir = true
		while _guardando:
			await get_tree().create_timer(0.1).timeout
		return _ultimo_ok
	_guardando = true
	var ok: bool = await _autoguardar_ya()
	while _repetir:
		_repetir = false
		ok = await _autoguardar_ya()
	_ultimo_ok = ok
	_guardando = false
	return ok


func _autoguardar_ya() -> bool:
	# Y EL RELOJ DEL AUTOGUARDADO SE PONE A CERO. Sin esto, guardar por tu cuenta (una tirada del
	# gacha, el boton de guardar) no contaba como guardado: el periodico saltaba igual a los pocos
	# segundos y salian dos vueltas enteras seguidas.
	_acum = 0.0
	# El HOST tampoco veia nada al autoguardar (el aviso solo iba al invitado). Ahora los dos ven la
	# misma pildora discreta abajo a la derecha, y el "Guardando..." va ANTES del await: recoger los
	# estados tiene un plazo de segundo y medio y durante ese rato el juego parece parado.
	_avisar_hud("Guardando…")
	# PRIMERO se recoge lo de los demas y DESPUES se escribe: al reves (como estaba) el save saldria
	# sin el ultimo rato de tu compañero. Cada uno manda lo suyo y de aqui sale UN save.
	if Net.activo and Net.es_host:
		await Net.partida.recoger_estados()
	if not guardar_actual():
		_avisar_hud("No se pudo guardar")
		return false
	var r: Dictionary
	if _bd != null:
		r = await _subir_bd(false)
	else:
		r = await Nube.subir(SaveIO.bytes_de_ruta(ruta(abierto)), _meta())
	if not r.get("ok", false):
		aviso.emit("Autoguardado: guardado en tu disco, pero sin subir (%s)." % String(r.get("mensaje", "")))
		_avisar_hud("Guardado sin subir")
		return false
	_avisar_hud("Partida guardada")
	return true


# Acuse de recibo en MI pantalla. La señal `aviso` solo la escucha el menu de mundos, asi que dentro
# de la partida no habia forma de enterarse de nada; esto habla con el HUD por el grupo, como Net.
func _avisar_hud(texto: String) -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("mostrar_aviso_esquina"):
		hud.mostrar_aviso_esquina(texto)


# CERRAR el mundo: guardar, subir y soltar el cerrojo (en ese orden; si la subida falla el mundo
# sigue siendo tuyo y la Nube lo deja en PENDIENTE_SUBIR).
func cerrar_y_subir() -> Dictionary:
	if abierto == "":
		return {"ok": true}
	var clave := abierto
	# Si hay un autoguardado a medias, se le deja terminar: son dos escrituras sobre el mismo fichero
	# y la de cerrar tiene que ser la ULTIMA.
	while _guardando:
		await get_tree().create_timer(0.1).timeout
	_avisar_hud("Guardando…")
	# Lo mismo que en el autoguardado: primero lo de los demas, y AVISANDOLES de que se cierra (se van
	# al menu con su personaje ya dentro del save), y despues se escribe.
	if Net.activo and Net.es_host:
		await Net.partida.recoger_estados(true)
	if not guardar_actual():
		return {"ok": false, "mensaje": "No se pudo guardar el mundo (no se cierra)."}
	var r: Dictionary
	if _bd != null:
		r = await _subir_bd(true)
		if not r.get("ok", false):
			_rev_pendiente[clave] = _rev_nube
		_cerrar_bd()
	else:
		r = await Nube.cerrar(SaveIO.bytes_de_ruta(ruta(clave)), _meta())
	# Se suelta lo local en cualquier caso: si la subida fallo, la Nube se queda en PENDIENTE_SUBIR
	# y lo que falta por subir sigue en disco (en la BD, apuntado) para reintentarlo.
	abierto = ""
	_cab_en_mano = null
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
	# En el menu principal no estoy dentro de NINGUN mundo, tampoco de uno ajeno. Esto se quedaba
	# puesto al salir por los caminos normales (el de unirse no lo limpiaba nadie), y el siguiente
	# intento de entrar arrancaba con banderas de la sesion anterior.
	uniendome = ""
	quitar_temporales()
	if abierto == "":
		Game.mundo_compartido = false
		return ""
	var clave := abierto
	push_warning("[mundos] se abandona %s sin cerrar: el cerrojo caducara solo" % clave)
	# "Caducara solo" solo es verdad si se deja de LATIR: Nube late cada 30 s mientras este en HOST, asi
	# que el arrendamiento no caducaba nunca y el mundo decia "ya tienes uno abierto" hasta cerrar el
	# juego. Se olvida en local; el almacen lo suelta al vencer el arrendamiento (y a mi me lo devuelve
	# antes, porque reconoce mi identidad).
	if Nube.estado == Nube.HOST:
		Nube._olvidar()
	_cerrar_bd()
	abierto = ""
	_cab_en_mano = null
	_contrasena = ""
	_hostear_al_llegar = false
	_acum = 0.0
	Game.mundo_compartido = false
	Game.jugadores_mundo.clear()
	return clave


# Reintentar una subida que quedo a medias (el mundo sigue reservado a tu nombre).
func reintentar(clave: String) -> Dictionary:
	if usa_bd(clave) and _rev_pendiente.has(clave):
		if Nube.estado != Nube.PENDIENTE_SUBIR or not _abrir_bd(clave):
			return {"ok": false, "error": "nada_pendiente", "mensaje": "No hay ninguna subida pendiente."}
		_rev_nube = int(_rev_pendiente[clave])
		var rb: Dictionary = await _subir_bd(true, _meta_de(clave))
		_cerrar_bd()
		if rb.get("ok", false):
			_rev_pendiente.erase(clave)
			_escribir_entrada(clave, {"pendiente": false})
		return rb
	var bytes: PackedByteArray = SaveIO.bytes_de_ruta(ruta(clave))
	if bytes.is_empty():
		return {"ok": false, "mensaje": "No hay copia local que subir."}
	var r: Dictionary = await Nube.reintentar_subida(bytes, _meta_de(clave))
	if r.get("ok", false):
		_escribir_entrada(clave, {"pendiente": false})
	return r


# ============================================================
#  LA BASE DE DATOS DEL MUNDO ABIERTO
# ------------------------------------------------------------
func _abrir_bd(clave: String) -> bool:
	_cerrar_bd()
	_bd = PartidaBD.new()
	if not _bd.abrir(ruta_bd(clave)):
		_bd = null
		return false
	_bd.rastrear = true   # cada fila que cambia queda apuntada para subirla
	_ids = BDFilas.Ids.new()
	return true


func _cerrar_bd() -> void:
	if _bd != null:
		_bd.cerrar()
	_bd = null


# SUBIR lo que falta (las filas apuntadas, o todas si la nube no tiene esta copia) partiendo de
# _rev_nube. Con soltar es el cierre: sube y suelta el cerrojo, con una foto para el historial.
# Sin nada que subir y sin soltar no se habla con la nube (el latido ya dice "sigo aqui").
func _subir_bd(soltar: bool, meta: Dictionary = {}) -> Dictionary:
	var bd: PartidaBD = _bd
	var pen: Dictionary = bd.pendientes()
	if not soltar and (pen["filas"] as Array).is_empty() and not pen["completa"]:
		return {"ok": true, "rev": _rev_nube, "nada": true}
	var t0: int = Time.get_ticks_msec()
	var r: Dictionary = await Nube.sincronizar({"base": _rev_nube, "completa": pen["completa"],
		"filas": pen["filas"], "soltar": soltar, "foto": soltar}, meta if not meta.is_empty() else _meta())
	if r.get("ok", false):
		_rev_nube = int(r.get("rev", _rev_nube))
		r["subidas"] = (pen["filas"] as Array).size()
		if bd.abierta():
			bd.marcar_subido(int(pen["marca"]), _rev_nube)
		print("[mundos] subidas %d filas%s en %d ms (rev %d, la nube escribio %d)" % [(pen["filas"] as Array).size(),
			" (entera)" if pen["completa"] else "", Time.get_ticks_msec() - t0, _rev_nube, int(r.get("escritas", 0))])
	elif String(r.get("error", "")) == "rev_distinto":
		# Con el cerrojo en la mano nadie mas escribe: la nube solo cambia sola si se restauro una
		# foto. No se machaca: se dice, y lo de aqui sigue apuntado.
		push_warning("[mundos] la nube esta en el rev %d y esta copia parte del %d: no se sube encima" % [
			int(r.get("rev", -1)), _rev_nube])
	return r


# La cabecera LIGERA que se le deja a la nube para pintar la lista sin bajarse el save entero.
#
# SALE DE LO QUE ACABAMOS DE ESCRIBIR, no de releer el fichero. Antes esto llamaba a datos_cabecera(),
# que hace ResourceLoader.load(..., CACHE_MODE_IGNORE): o sea que cada guardado escribia el save
# entero, lo leia otra vez a bytes para subirlo y ADEMAS lo volvia a interpretar de cabo a rabo —con
# sus miles de materiales, cada uno un bloque del fichero, y los PNG de las caras en base64— solo para
# sacar estos seis campos, que ya los teniamos en la mano. Tres pasadas sobre medio mega, en el mismo
# fotograma, y la culpa del tiron al guardar. Ver guardar_actual.
func _meta() -> Dictionary:
	if _cab_en_mano != null:
		return _cab_de(_cab_en_mano)
	return _meta_de(abierto)


func _meta_de(clave: String) -> Dictionary:
	var datos: SaveData = datos_cabecera(clave)
	if datos == null:
		return {}
	return _cab_de(datos)


# Lleva tambien los MIEMBROS: las identidades con personaje en este save. La nube solo deja ABRIR el
# mundo a ellos (y se la quita de la cabecera al guardarla); uno nuevo entra uniendose a alguien de
# dentro, que le acepta en el juego (ver Net._pedir_permiso).
func _cab_de(datos: SaveData) -> Dictionary:
	var miembros: Array = []
	for k in datos.jugadores:
		miembros.append(String(k))
	return {
		"miembros": miembros,
		"nombre": datos.nombre,
		"cab_nivel": datos.cab_nivel,
		"cab_piso": datos.cab_piso,
		"cab_dinero": datos.cab_dinero,
		"cab_lugar": datos.cab_lugar,
		"fecha": datos.fecha,
	}
