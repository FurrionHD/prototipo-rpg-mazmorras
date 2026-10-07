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
const RANURAS := 3   # cuantas partidas en paralelo

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
	for i in range(1, RANURAS + 1):
		if not usa_bd(i) and not _no_migradas.has(i) and FileAccess.file_exists(ruta(i)):
			return true
	return false


## Migra todas las ranuras viejas de una vez (ver _asegurar_migrada).
func migrar_todas() -> void:
	for i in range(1, RANURAS + 1):
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


# Lo mismo que SaveIO.inspeccionar_ruta, pero leyendo de la BD. `ids` se queda con los objetos leidos.
func _inspeccionar_bd(slot: int, ids: BDFilas.Ids) -> Dictionary:
	var bd := _bd if (_bd != null and _bd_slot == slot) else PartidaBD.new()
	if not bd.abierta() and not bd.abrir(ruta_bd(slot)):
		return {"estado": SaveIO.ILEGIBLE, "version": 0, "version_mundo": 0, "datos": null}
	var cab: Dictionary = bd.leer_campos(["version", "version_mundo"])
	var info := {"estado": SaveIO.OK, "version": int(cab.get("version", 0)),
		"version_mundo": int(cab.get("version_mundo", 0)), "datos": null}
	if not cab.has("version"):
		info["estado"] = SaveIO.ILEGIBLE
	elif info["version"] < SaveData.VERSION_ACTUAL:
		info["estado"] = SaveIO.MAS_VIEJA
	elif info["version"] > SaveData.VERSION_ACTUAL or info["version_mundo"] > SaveData.VERSION_MUNDO:
		info["estado"] = SaveIO.MAS_NUEVA
	if info["estado"] == SaveIO.OK:
		info["datos"] = BDFilas.de_filas(bd.leer(), ids)
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
	for i in range(1, RANURAS + 1):
		var c: SaveData = cabecera(i)
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
	_bd_slot = slot
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
	if Game.hay_pelea_en_pantalla() or not Mundos.en_partida():
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
