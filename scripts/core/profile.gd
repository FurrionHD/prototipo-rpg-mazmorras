# ============================================================
#  profile.gd  (AUTOLOAD: se llama "Perfil")
#  RANURAS de guardado. Cada partida es un SaveData escrito con ResourceSaver en
#  user://saves/slot_N.tres  (en Windows: %APPDATA%\Godot\app_userdata\<proyecto>\saves\).
#
#  Varias ranuras a proposito: cada una es un MUNDO distinto (su propia semilla), asi que se
#  pueden llevar partidas en paralelo sin pisarse.
#
#  El fichero es TEXTO: quien quiera hacer trampa puede abrirlo y ponerse dinero. Para un
#  build entre amigos es asumible; si algun dia molesta, se guarda en binario (.res) cambiando
#  la extension (no es seguridad de verdad, pero deja de ser una invitacion).
#
#  BASE DE DATOS (07/10/2026): cada ranura tiene ahora SU base de datos, user://bd/slot_N.sqlite
#  (ver PartidaBD). La primera vez que se mira una ranura vieja se MIGRA (MigracionBD: copia de
#  seguridad, y solo si sale identica); si no se pudo migrar, esa ranura sigue con su .tres como
#  siempre. Con la BD se GUARDA SOLO cada 2 s mientras juegas (a trocitos, sin tiron, y solo lo que
#  ha cambiado): un alt+F4 ya no se lleva la partida desde el ultimo guardado.
# ============================================================

extends Node

const CARPETA := "user://saves"
# Ya NO hay tope de partidas (fase 3 de la BD): las que haya, ver ranuras().

# En que ranura se esta jugando ahora (1..RANURAS). 0 = ninguna (estamos en el menu).
var ranura_actual: int = 0

# --- El guardado continuo (solo ranuras con BD) ---
const SEG_GUARDADO := 2.0        # cada cuanto se empieza un guardado nuevo (contado desde el anterior)
const PRESUPUESTO_US := 2500     # cuanto puede gastar el guardado por fotograma
var _bd: PartidaBD = null        # la BD de la ranura que se esta jugando
var _bd_slot: int = 0
var _ids := BDFilas.Ids.new()    # los objetos de la partida en juego <-> sus filas
var _volcado: BDFilas.Volcado = null
var _t: float = 0.0
var _no_migradas: Dictionary = {}   # slot -> motivo: no se reintenta en cada repintado del menu


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CARPETA)


func ruta(slot: int) -> String:
	return "%s/slot_%d.tres" % [CARPETA, slot]


func ruta_bd(slot: int) -> String:
	return PartidaBD.ruta_de("slot_%d" % slot)


## ¿Esta ranura vive ya en su base de datos?
func usa_bd(slot: int) -> bool:
	return PartidaBD.existe(ruta_bd(slot))


func existe(slot: int) -> bool:
	return usa_bd(slot) or FileAccess.file_exists(ruta(slot))


## ¿Hay alguna ranura vieja (.tres) por pasar a la BD? (Para enseñar "Cargando" antes de hacerlo.)
func hay_por_migrar() -> bool:
	for i in ranuras():
		if not usa_bd(i) and not _no_migradas.has(i) and FileAccess.file_exists(ruta(i)):
			return true
	return false


## Migra todas las ranuras viejas de una vez (ver _asegurar_migrada).
func migrar_todas() -> void:
	for i in ranuras():
		_asegurar_migrada(i)


# Una ranura vieja (.tres) pasa a su BD la primera vez que se mira. Si no se puede, se queda con su
# .tres (y no se reintenta en esta sesion: la migracion de un mundo grande tarda unos segundos).
func _asegurar_migrada(slot: int) -> void:
	if usa_bd(slot) or _no_migradas.has(slot) or not FileAccess.file_exists(ruta(slot)):
		return
	var r: Dictionary = MigracionBD.migrar(ruta(slot), ruta_bd(slot))
	if not r["ok"]:
		_no_migradas[slot] = r["motivo"]


# ============================================================
#  EN QUE ESTADO ESTA UNA RANURA
#  Antes esto era un booleano de hecho ("se puede leer o no") y las cuatro razones para NO poder
#  leerla caian en el mismo saco: cabecera() devolvia null y el menu pintaba "vacia · Nueva
#  partida" encima. Con una partida MAS NUEVA (un build viejo abriendo un save de un build nuevo,
#  que es justo lo que pasa al compartir mundo) eso es una PERDIDA DE DATOS SILENCIOSA: la ranura
#  esta llena y el juego te invita a machacarla.
#  Ahora se distingue, y sobre todo se distingue "mas vieja" de "mas nueva": ninguna de las dos es
#  un hueco libre, y solo VACIA lo es.
# ------------------------------------------------------------
#  Los estados y su lectura viven en SaveIO (scripts/core/save_io.gd), porque los MUNDOS
#  COMPARTIDOS (autoload Mundos) necesitan exactamente lo mismo sobre otra carpeta. Aqui solo se
#  reexportan los nombres para no tocar a quien ya llamaba a Perfil.VACIA / Perfil.OK.
#
#  ¡OJO CON ESTE `OK`! Sombrea al OK global de Godot DENTRO DE TODO ESTE SCRIPT. Y no valen lo
#  mismo: el de SaveIO es un enum sin valores explicitos, asi que SaveIO.OK == 1, mientras que el
#  de Godot (el que devuelve ResourceSaver.save) es 0 = EXITO. Escribir `if err != OK` aqui es
#  comparar el error contra 1: SIEMPRE es distinto, asi que TODO guardado "fallaba" con el
#  desconcertante mensaje "error 0" y devolvia false -- se perdia la ranura activa y "Guardar y
#  salir" no dejaba salir nunca. Por eso en este script el error de Godot va SIEMPRE cualificado:
#  `Error.OK`. Mundos hace el mismo `if err != OK` y funciona solo porque ahi no se reexporta nada.
# ------------------------------------------------------------
const VACIA := SaveIO.VACIA
const OK := SaveIO.OK
const MAS_VIEJA := SaveIO.MAS_VIEJA
const MAS_NUEVA := SaveIO.MAS_NUEVA
const ILEGIBLE := SaveIO.ILEGIBLE


# Todo lo que se sabe de una ranura sin tener que adivinarlo:
#   {"estado": uno de los de arriba, "version": int (0 si no se pudo leer), "datos": SaveData|null}
# 'datos' solo viene si estado == OK: una partida que no entendemos no se toca ni para leerla.
func inspeccionar(slot: int) -> Dictionary:
	_asegurar_migrada(slot)
	if usa_bd(slot):
		return _inspeccionar_bd(slot, BDFilas.Ids.new())
	return SaveIO.inspeccionar_ruta(ruta(slot))


# Lo que pinta la lista de partidas, y nada mas: con BD se leen estos campos sueltos en vez de montar
# la partida entera (en su mundo, 240 ms por ranura y el menu lo pedia varias veces).
const CAMPOS_CABECERA := PartidaBD.CAMPOS_CABECERA


## Como inspeccionar(), pero "datos" solo trae la CABECERA (CAMPOS_CABECERA) si la ranura tiene BD.
## Para pintar listas; para jugar o importar la partida, inspeccionar().
func inspeccionar_ligera(slot: int) -> Dictionary:
	_asegurar_migrada(slot)
	if usa_bd(slot):
		return _inspeccionar_bd(slot, BDFilas.Ids.new(), true)
	return SaveIO.inspeccionar_ruta(ruta(slot))


func cabecera_ligera(slot: int) -> SaveData:
	return inspeccionar_ligera(slot).get("datos") as SaveData


# Lo mismo que SaveIO.inspeccionar_ruta, pero leyendo de la BD. `ids` se queda con los objetos leidos.
func _inspeccionar_bd(slot: int, ids: BDFilas.Ids, solo_cabecera := false) -> Dictionary:
	var bd := _bd if (_bd != null and _bd_slot == slot) else PartidaBD.new()
	if not bd.abierta() and not bd.abrir(ruta_bd(slot)):
		return {"estado": SaveIO.ILEGIBLE, "version": 0, "version_mundo": 0, "datos": null}
	var info: Dictionary = PartidaBD.inspeccionar(bd, ids, solo_cabecera)
	if bd != _bd:
		bd.cerrar()
	return info


# Como se llama la razon por la que una ranura no se puede jugar, para pintarla tal cual.
# Cadena vacia si la ranura esta bien o esta vacia (ahi no hay nada que explicar).
func motivo_texto(info: Dictionary) -> String:
	return SaveIO.motivo_texto(info)


# Carga solo para LEER la cabecera (pintar la lista del menu). null si la ranura esta vacia o si
# es de una version que este build no entiende -- que NO es lo mismo que estar vacia: quien pinte
# la lista tiene que usar inspeccionar() para no ofrecer "Nueva partida" encima de una partida.
func cabecera(slot: int) -> SaveData:
	return inspeccionar(slot).get("datos") as SaveData


# La ranura usada mas recientemente (para el boton "Continuar"). 0 si no hay ninguna.
func ultima_ranura() -> int:
	var mejor: int = 0
	var mejor_fecha: String = ""
	for i in ranuras():
		var c: SaveData = cabecera_ligera(i)
		if c != null and c.fecha > mejor_fecha:   # las fechas van en formato ordenable
			mejor_fecha = c.fecha
			mejor = i
	return mejor


func guardar(slot: int) -> bool:
	var datos: SaveData = Game.exportar_partida()
	# Las partidas NUEVAS nacen ya en su BD; las viejas que no se pudieron migrar siguen en .tres.
	if usa_bd(slot) or not FileAccess.file_exists(ruta(slot)):
		if not _guardar_bd(slot, datos):
			return false
		ranura_actual = slot
		print("[perfil] partida guardada en la ranura ", slot, " (bd rev ", _bd.rev, "): ", datos.resumen())
		return true
	var err: int = ResourceSaver.save(datos, ruta(slot))
	if err != Error.OK:   # Error.OK, NO el OK de arriba: ver la nota de las constantes
		push_warning("[perfil] no se pudo guardar la ranura %d (error %d)" % [slot, err])
		return false
	ranura_actual = slot
	print("[perfil] partida guardada en la ranura ", slot, ": ", datos.resumen())
	return true


# Carga la ranura EN MEMORIA (deja a Game listo). Quien llama decide a que escena ir.
func cargar(slot: int) -> bool:
	_asegurar_migrada(slot)
	var datos: SaveData
	if usa_bd(slot):
		# Con los ids de ESTA lectura: asi el primer guardado reconoce los mismos objetos y no
		# reescribe nada que no haya cambiado.
		_abrir_bd(slot)
		var ids := BDFilas.Ids.new()
		datos = _inspeccionar_bd(slot, ids).get("datos")
		if datos != null:
			_ids = ids
	else:
		datos = cabecera(slot)
	if datos == null:
		return false
	Game.importar_partida(datos)
	ranura_actual = slot
	print("[perfil] partida cargada de la ranura ", slot, ": ", datos.resumen())
	return true


func borrar(slot: int) -> void:
	# Tambien de la nube (si no hay conexion, queda apuntado y se borra la proxima vez que se mire).
	var pid: String = nube_id(slot) if usa_bd(slot) else ""
	if pid != "" and nube_activa:
		var l: Array = _leer_borrar()
		if not l.has(pid):
			l.append(pid)
		_escribir_borrar(l)
		en_nube.erase(pid)
		_borrar_pendientes_en_nube()
	if _bd_slot == slot:
		_cerrar_bd()
	PartidaBD.borrar(ruta_bd(slot))
	_no_migradas.erase(slot)
	if FileAccess.file_exists(ruta(slot)):
		DirAccess.remove_absolute(ruta(slot))


# Reescribe SOLO el ASPECTO de una ranura (el boton "Editar" del menu). Toca el .tres a pelo y NO
# pasa por Game a proposito, aunque cargar-cambiar-guardar parezca lo natural: `exportar_partida()`
# lee el ARBOL VIVO (busca el nodo de la mazmorra y el del jugador para sacar en_mazmorra, la
# posicion y el aguante), y desde el menu no hay ni lo uno ni lo otro. Guardar desde aqui marcaria
# la partida como "en el pueblo", sin posicion y con el aguante a -1: cambiarte el color te
# teletransportaria fuera del piso 9 y te quedarias sin la bajada hecha.
#
# Asi solo se mueven estos cinco campos y el resto del fichero se queda EXACTAMENTE como estaba.
func editar_aspecto(slot: int, nombre: String, color: Color, metalico: float,
		imagen: PackedByteArray, color_alpha: float) -> bool:
	var datos: SaveData = cabecera(slot)
	if datos == null:
		push_warning("[perfil] no se puede editar la ranura %d" % slot)
		return false
	var n: String = nombre.strip_edges()
	datos.nombre = n if n != "" else Game.NOMBRE_POR_DEFECTO   # sin nombre no te quedas
	datos.color = color
	datos.metalico = clampf(metalico, 0.0, 1.0)
	datos.imagen = imagen
	datos.color_alpha = clampf(color_alpha, 0.0, 1.0)
	if usa_bd(slot):
		# Igual que con el .tres: lo leido con esos cinco campos cambiados, sin pasar por Game.
		var bd := PartidaBD.new()
		if not bd.abrir(ruta_bd(slot)):
			return false
		var ids := BDFilas.Ids.new()
		var leida: SaveData = BDFilas.de_filas(bd.leer(), ids)
		leida.nombre = datos.nombre
		leida.color = datos.color
		leida.metalico = datos.metalico
		leida.imagen = datos.imagen
		leida.color_alpha = datos.color_alpha
		var ok: bool = bd.escribir(BDFilas.a_filas(leida, ids)) >= 0
		bd.cerrar()
		if ok:
			print("[perfil] aspecto de la ranura ", slot, " actualizado: ", leida.nombre)
		return ok
	var err: int = ResourceSaver.save(datos, ruta(slot))
	if err != Error.OK:   # Error.OK, NO el OK de arriba: ver la nota de las constantes
		push_warning("[perfil] no se pudo editar la ranura %d (error %d)" % [slot, err])
		return false
	print("[perfil] aspecto de la ranura ", slot, " actualizado: ", datos.nombre)
	return true


# Guarda en la ranura en la que se esta jugando. Lo usan el menu de ESC y la MUERTE (que
# guarda sola: morir es definitivo y no se puede deshacer recargando).
func guardar_actual() -> bool:
	if ranura_actual <= 0:
		push_warning("[perfil] no hay ranura activa: no se guarda")
		return false
	return guardar(ranura_actual)


# Igual que guardar_actual(), pero con un SaveData YA ARMADO en vez de pedirselo a Game. Lo usa el
# guardado del INVITADO en multijugador (Game.exportar_partida_invitado): esa partida no se puede
# volcar tal cual, porque durante la sesion se juega en el mundo del HOST y hay campos que son suyos.
func guardar_actual_con(datos: SaveData) -> bool:
	if ranura_actual <= 0:
		push_warning("[perfil] no hay ranura activa: no se guarda")
		return false
	if datos == null:
		return false
	if usa_bd(ranura_actual):
		if not _guardar_bd(ranura_actual, datos):
			return false
		print("[perfil] partida guardada en la ranura ", ranura_actual, " (bd rev ", _bd.rev, "): ", datos.resumen())
		return true
	var err: int = ResourceSaver.save(datos, ruta(ranura_actual))
	if err != Error.OK:   # Error.OK, NO el OK de arriba: ver la nota de las constantes
		push_warning("[perfil] no se pudo guardar la ranura %d (error %d)" % [ranura_actual, err])
		return false
	print("[perfil] partida guardada en la ranura ", ranura_actual, ": ", datos.resumen())
	return true


# ============================================================
#  LA BD DE LA RANURA EN JUEGO Y EL GUARDADO CONTINUO
# ------------------------------------------------------------
func _abrir_bd(slot: int) -> bool:
	if _bd != null and _bd_slot == slot and _bd.abierta():
		return true
	_cerrar_bd()
	_bd = PartidaBD.new()
	if not _bd.abrir(ruta_bd(slot)):
		_bd = null
		return false
	_bd.rastrear = true   # lo que cambia queda apuntado para subirlo a la nube
	_bd_slot = slot
	_t_nube = 0.0
	_ids = BDFilas.Ids.new()
	return true


func _cerrar_bd() -> void:
	_volcado = null
	if _bd != null:
		_bd.cerrar()
	_bd = null
	_bd_slot = 0


# Guardar YA y entero (los guardados de siempre: menu, morir, subir de nivel, cerrar la ventana).
# Escribe solo lo que ha cambiado, pero sacando las filas de golpe (puede tardar unas decimas).
func _guardar_bd(slot: int, datos: SaveData) -> bool:
	if not _abrir_bd(slot):
		push_warning("[perfil] no se pudo abrir la base de datos de la ranura %d" % slot)
		return false
	_volcado = null   # el que iba a medias ya es viejo
	_t = 0.0
	if _bd.escribir(BDFilas.a_filas(datos, _ids)) < 0:
		push_warning("[perfil] no se pudo guardar la ranura %d en su base de datos" % slot)
		return false
	return true


# Cada SEG_GUARDADO, la partida en juego se guarda a trocitos (PRESUPUESTO_US por fotograma). Mismas
# condiciones que el autoguardado de los mundos: nunca con una pelea en pantalla (el combate no vive
# en el save) ni fuera del juego (exportar_partida lee el arbol vivo). En una sesion de otro (invitado)
# tampoco: ahi lo suyo se guarda en los momentos de siempre, con exportar_partida_invitado.
func _process(delta: float) -> void:
	if _bd == null or _bd_slot != ranura_actual or ranura_actual <= 0:
		return
	if Mundos.abierto != "" or Net.soy_trabajador or Net.soy_sala or (Net.activo and not Net.es_host):
		_volcado = null
		return
	# Con una pelea en pantalla SI se guarda (fase 6 de la BD): su foto va en la partida y al cargar sigue.
	# Solo no si no se puede guardar (ya acabada, la arena...): ver Game.pelea_para_guardar.
	if (Game.hay_pelea_en_pantalla() and Game.pelea_para_guardar().is_empty()) or not Mundos.en_partida():
		_volcado = null   # lo que llevaba a medias se tira: el siguiente empieza de cero
		return
	if _volcado == null:
		_t += delta
		if _t < SEG_GUARDADO:
			return
		_t = 0.0
		_volcado = BDFilas.Volcado.new(Game.exportar_partida(), _ids)
	if _volcado.paso(PRESUPUESTO_US):
		var filas: Dictionary = _volcado.out
		_volcado = null
		if _bd.escribir(filas) < 0:
			push_warning("[perfil] el guardado continuo de la ranura %d ha fallado" % _bd_slot)
		# Y a la nube, cada SEG_NUBE (solo lo cambiado; sin red, queda apuntado).
		_t_nube += SEG_GUARDADO
		if _t_nube >= SEG_NUBE and nube_activa and not _subiendo:
			_t_nube = 0.0
			subir_nube(_bd_slot)


# ============================================================
#  TUS PARTIDAS EN LA NUBE (fase 3 de la BD, 07/10/2026)
#  Cada partida tiene su CODIGO DE NUBE (24 hex, en su BD: "nube_id") y en la nube es su propia base de
#  datos (servidor/nube "partida:<id>"), con tu clave secreta de llave (Identidad.clave). No hay cerrojo:
#  cada subida lleva el rev del que parte, y si la nube ya no esta ahi se rechaza (rev_distinto).
#    - Mientras juegas, en disco cada 2 s (arriba) y a la nube cada SEG_NUBE, solo lo cambiado.
#    - Al salir (menu o cerrar la ventana) se sube lo que falte, con una foto para el historial.
#    - Al CARGAR desde el menu se mira la nube (preparar_carga): al dia / bajar lo cambiado / CONFLICTO
#      (jugaste en dos PCs sin subir: se te pregunta cual, y la otra va al historial o a respaldos).
#    - Sin internet se juega igual: queda apuntado y sube cuando vuelva (aviso discreto).
#  Las pruebas lo apagan (nube_activa = false, o "sin_nube" en la linea de ordenes).
# ------------------------------------------------------------
const SEG_NUBE := 30.0
const BORRAR_PENDIENTES := "user://bd/borrar_en_nube.json"
const RESPALDOS_CONFLICTO := "user://respaldos/conflictos"
var nube_activa: bool = not OS.get_cmdline_user_args().has("sin_nube")
var sin_conexion := false
signal conexion_cambiada(sin_red: bool)
var _t_nube := 0.0
var _subiendo := false
# Lo ultimo que dijo la nube de tus partidas: {nube_id: {meta, rev, fecha}}. Lo pide el menu al pintarse.
var en_nube: Dictionary = {}


## Las ranuras que hay (sin tope): las de su .tres y las de su BD, en orden.
func ranuras() -> Array:
	var vistas: Dictionary = {}
	for pareja in [[CARPETA, ".tres"], [PartidaBD.CARPETA, ".sqlite"]]:
		var d := DirAccess.open(pareja[0])
		if d == null:
			continue
		for f in d.get_files():
			if f.begins_with("slot_") and f.ends_with(pareja[1]):
				var n: int = int(f.trim_prefix("slot_").trim_suffix(pareja[1]))
				if n > 0:
					vistas[n] = true
	var l: Array = vistas.keys()
	l.sort()
	return l


## El primer numero de ranura libre (para una partida nueva o una bajada de la nube).
func ranura_libre() -> int:
	var n: int = 1
	while existe(n):
		n += 1
	return n


## El codigo de nube de una ranura con BD ("" si no tiene BD). Se crea la primera vez.
func nube_id(slot: int) -> String:
	if not usa_bd(slot):
		return ""
	var bd: PartidaBD = _bd_de(slot)
	var pid: String = _nube_id_de(bd)
	_soltar_bd(bd)
	return pid


func _nube_id_de(bd: PartidaBD) -> String:
	var pid: String = bd.meta_leer("nube_id", "")
	if pid == "":
		pid = Nube.nuevo_id()
		bd.meta_poner("nube_id", pid)
	return pid


# La BD de una ranura: la de la partida en juego si es esa, o una abierta para la ocasion (_soltar_bd).
func _bd_de(slot: int) -> PartidaBD:
	if _bd != null and _bd_slot == slot and _bd.abierta():
		return _bd
	var bd := PartidaBD.new()
	if not bd.abrir(ruta_bd(slot)):
		return null
	bd.rastrear = true
	return bd


func _soltar_bd(bd: PartidaBD) -> void:
	if bd != null and bd != _bd:
		bd.cerrar()


## ¿Le queda algo por subir a esta ranura? (El icono de "sin subir" de la lista.)
func sin_subir(slot: int) -> bool:
	if not usa_bd(slot):
		return false
	var bd: PartidaBD = _bd_de(slot)
	if bd == null:
		return false
	var r: bool = bd.hay_pendientes() or bd.meta_leer("conflicto", "") == "1"
	_soltar_bd(bd)
	return r


## Pide a la nube la lista de tus partidas (en_nube). false = sin conexion (se juega igual).
func mirar_nube() -> bool:
	if not nube_activa:
		return false
	var r: Dictionary = await Nube.cuenta_lista()
	_poner_conexion(r)
	if not r.get("ok", false):
		return false
	en_nube = r.get("partidas", {})
	await _borrar_pendientes_en_nube()
	return true


## Las partidas que estan en la nube y NO en este PC (para bajarlas): [{id, meta, rev}], la mas reciente arriba.
func solo_en_nube() -> Array:
	var aqui: Dictionary = {}
	for s in ranuras():
		var pid: String = nube_id(s)
		if pid != "":
			aqui[pid] = true
	var borradas: Array = _leer_borrar()
	var l: Array = []
	for pid in en_nube:
		if not aqui.has(pid) and not borradas.has(pid):
			var e: Dictionary = en_nube[pid]
			l.append({"id": pid, "meta": e.get("meta", {}), "rev": int(e.get("rev", 0))})
	l.sort_custom(func(a, b): return String(a["meta"].get("fecha", "")) > String(b["meta"].get("fecha", "")))
	return l


## Baja una partida que solo esta en la nube a una ranura nueva. Devuelve la ranura (0 = no se pudo).
func bajar_de_nube(pid: String) -> int:
	var b: Dictionary = await Nube.partida_bajar(pid, 0)
	_poner_conexion(b)
	if not b.get("ok", false) or (b.get("filas", []) as Array).is_empty():
		return 0
	var slot: int = ranura_libre()
	var bd := PartidaBD.new()
	if not bd.abrir(ruta_bd(slot)):
		return 0
	var ok: bool = bd.aplicar(b["filas"], true, int(b.get("rev", 0)))
	bd.meta_poner("nube_id", pid)
	bd.cerrar()
	if not ok or int(PartidaBD.inspeccionar_ruta(ruta_bd(slot), true)["estado"]) != SaveIO.OK:
		PartidaBD.borrar(ruta_bd(slot))
		return 0
	print("[perfil] partida %s bajada de la nube a la ranura %d (%d filas, rev %d)" % [pid, slot,
		(b["filas"] as Array).size(), int(b.get("rev", 0))])
	return slot


## ANTES DE CARGAR una ranura desde el menu: ponerla al dia con la nube.
## {"ok": true} = se puede cargar (al dia, bajado lo cambiado, o sin conexion);
## {"conflicto": true, "aqui": {...}, "nube": {...}} = cambiaron las dos: hay que preguntar (resolver_conflicto).
func preparar_carga(slot: int) -> Dictionary:
	if not nube_activa or not usa_bd(slot):
		return {"ok": true}
	var bd: PartidaBD = _bd_de(slot)
	if bd == null:
		return {"ok": true}
	var pid: String = _nube_id_de(bd)
	var mia: int = bd.rev_nube()
	var tocada: bool = bd.contar_sin_subir() > 0 or bd.meta_leer("conflicto", "") == "1"
	var cab_aqui: Dictionary = _cab_meta(bd)
	_soltar_bd(bd)
	if not await mirar_nube():
		return {"ok": true, "sin_conexion": true}
	if not en_nube.has(pid):
		# Nunca subida (subira entera)... o BORRADA desde otro PC: esta copia es lo unico que queda, asi
		# que vuelve a subir entera en vez de perderse.
		if mia >= 0 or tocada:
			bd = _bd_de(slot)
			bd.olvidar_nube()
			bd.meta_poner("conflicto", "0")
			_soltar_bd(bd)
		return {"ok": true}
	var suya: int = int(en_nube[pid].get("rev", 0))
	if mia == suya:
		return {"ok": true}
	if mia >= 0 and mia < suya and not tocada:
		return {"ok": await _bajar_a(slot, pid, mia)}
	return {"ok": false, "conflicto": true, "aqui": cab_aqui, "nube": en_nube[pid].get("meta", {}),
		"rev_nube": suya}


## Decide un conflicto. "aqui" = esta copia sube entera y la de la nube pasa a su historial; "nube" = se baja
## la de la nube y esta queda en respaldos/conflictos. true = resuelto.
func resolver_conflicto(slot: int, gana: String, rev_nube_: int) -> bool:
	var bd: PartidaBD = _bd_de(slot)
	if bd == null:
		return false
	var pid: String = _nube_id_de(bd)
	if gana == "aqui":
		bd.olvidar_nube()   # todo pendiente: sube entera
		var r: Dictionary = await _subir(bd, pid, false, rev_nube_, true)
		var ok: bool = r.get("ok", false)
		if ok:
			bd.meta_poner("conflicto", "0")
		_soltar_bd(bd)
		return ok
	_soltar_bd(bd)
	DirAccess.make_dir_recursive_absolute(RESPALDOS_CONFLICTO)
	var destino: String = "%s/slot_%d_%s.sqlite" % [RESPALDOS_CONFLICTO, slot,
		Time.get_datetime_string_from_system().replace(":", "-")]
	DirAccess.copy_absolute(ProjectSettings.globalize_path(ruta_bd(slot)), ProjectSettings.globalize_path(destino))
	print("[perfil] conflicto de la ranura %d: manda la nube; la copia de aqui queda en %s" % [slot, destino])
	return await _bajar_a(slot, pid, 0)


# Baja de la nube lo cambiado desde `desde` (0 = entera) encima de la ranura.
func _bajar_a(slot: int, pid: String, desde: int) -> bool:
	var b: Dictionary = await Nube.partida_bajar(pid, desde)
	_poner_conexion(b)
	if not b.get("ok", false):
		return false
	var bd: PartidaBD = _bd_de(slot)
	if bd == null:
		return false
	var ok: bool = bd.aplicar(b.get("filas", []), bool(b.get("completa", desde == 0)), int(b.get("rev", 0)))
	bd.meta_poner("conflicto", "0")
	_soltar_bd(bd)
	if bd == _bd:
		_ids = BDFilas.Ids.new()
	print("[perfil] ranura %d al dia con la nube (%d filas, rev %d)" % [slot, (b.get("filas", []) as Array).size(),
		int(b.get("rev", 0))])
	return ok


## Sube lo que falte de una ranura. Sin nada que subir no se habla con la nube (salvo foto).
func subir_nube(slot: int, foto := false) -> Dictionary:
	if not nube_activa or not usa_bd(slot):
		return {"ok": false, "error": "sin_nube"}
	var bd: PartidaBD = _bd_de(slot)
	if bd == null:
		return {"ok": false, "error": "sin_bd"}
	if bd.meta_leer("conflicto", "") == "1":
		_soltar_bd(bd)
		return {"ok": false, "error": "conflicto"}
	var r: Dictionary = await _subir(bd, _nube_id_de(bd), foto)
	_soltar_bd(bd)
	return r


func _subir(bd: PartidaBD, pid: String, foto: bool, base := -1, foto_antes := false) -> Dictionary:
	if _subiendo:
		return {"ok": false, "error": "ocupado"}
	var pen: Dictionary = bd.pendientes()
	if (pen["filas"] as Array).is_empty() and not pen["completa"]:
		return {"ok": true, "nada": true}
	if base < 0:
		base = maxi(bd.rev_nube(), 0)
	_subiendo = true
	var t0: int = Time.get_ticks_msec()
	var r: Dictionary = await Nube.partida_sync(pid, {"base": base, "completa": pen["completa"],
		"filas": pen["filas"], "foto": foto, "foto_antes": foto_antes}, _cab_meta(bd))
	_subiendo = false
	_poner_conexion(r)
	if r.get("ok", false):
		if bd.abierta():
			bd.marcar_subido(int(pen["marca"]), int(r.get("rev", 0)))
		r["subidas"] = (pen["filas"] as Array).size()
		print("[perfil] nube: %d filas%s en %d ms (rev %d)" % [(pen["filas"] as Array).size(),
			" (entera)" if pen["completa"] else "", Time.get_ticks_msec() - t0, int(r.get("rev", 0))])
	elif String(r.get("error", "")) == "rev_distinto":
		# Se jugo en otro PC mientras tanto: se deja de subir y se pregunta al volver a cargarla.
		bd.meta_poner("conflicto", "1")
		push_warning("[perfil] la partida cambio en otro PC: se resolvera al cargarla desde el menu")
	return r


# Lo que se apunta en tu cuenta de la nube para pintar la lista en otro PC.
func _cab_meta(bd: PartidaBD) -> Dictionary:
	var c: Dictionary = bd.leer_campos(["nombre", "cab_nivel", "cab_dinero", "cab_lugar", "fecha", "color"])
	if c.has("color"):
		c["color"] = (c["color"] as Color).to_html() if c["color"] is Color else str(c["color"])
	return c


func _poner_conexion(r: Dictionary) -> void:
	var sin_red: bool = String(r.get("error", "")) in ["sin_red", "respuesta_mala"]
	if r.get("ok", false):
		sin_red = false
	elif not sin_red:
		return   # otros fallos no dicen nada de la conexion
	if sin_red == sin_conexion:
		return
	sin_conexion = sin_red
	conexion_cambiada.emit(sin_red)
	if sin_red:
		_avisar_hud("Sin conexión: tu partida se subirá luego")


func _avisar_hud(texto: String) -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("mostrar_aviso_esquina"):
		hud.mostrar_aviso_esquina(texto)


## Al salir de la partida (menu o cerrar la ventana): sube lo que falte con foto, sin esperar de mas.
func subir_al_salir(plazo := 8.0) -> void:
	if ranura_actual <= 0 or not usa_bd(ranura_actual):
		return
	var hecho := [false]
	var tarea := func():
		await subir_nube(ranura_actual, true)
		hecho[0] = true
	tarea.call()
	var t := 0.0
	while not hecho[0] and t < plazo:
		await get_tree().create_timer(0.1, true, false, true).timeout
		t += 0.1


# Las partidas borradas cuyo borrado aun no llego a la nube (sin conexion al borrar).
func _leer_borrar() -> Array:
	if not FileAccess.file_exists(BORRAR_PENDIENTES):
		return []
	var d = JSON.parse_string(FileAccess.get_file_as_string(BORRAR_PENDIENTES))
	return d if d is Array else []


func _escribir_borrar(l: Array) -> void:
	DirAccess.make_dir_recursive_absolute(PartidaBD.CARPETA)
	var f := FileAccess.open(BORRAR_PENDIENTES, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(l))
		f.close()


func _borrar_pendientes_en_nube() -> void:
	var l: Array = _leer_borrar()
	if l.is_empty() or not nube_activa:
		return
	var quedan: Array = []
	for pid in l:
		var r: Dictionary = await Nube.partida_borrar(String(pid))
		if not r.get("ok", false) and String(r.get("error", "")) != "no_autorizado":
			quedan.append(pid)
		else:
			en_nube.erase(pid)
	_escribir_borrar(quedan)
