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
# ============================================================

extends Node

const CARPETA := "user://saves"
const RANURAS := 3   # cuantas partidas en paralelo

# En que ranura se esta jugando ahora (1..RANURAS). 0 = ninguna (estamos en el menu).
var ranura_actual: int = 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CARPETA)


func ruta(slot: int) -> String:
	return "%s/slot_%d.tres" % [CARPETA, slot]


func existe(slot: int) -> bool:
	return FileAccess.file_exists(ruta(slot))


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
	return SaveIO.inspeccionar_ruta(ruta(slot))


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
	var err: int = ResourceSaver.save(datos, ruta(slot))
	if err != Error.OK:   # Error.OK, NO el OK de arriba: ver la nota de las constantes
		push_warning("[perfil] no se pudo guardar la ranura %d (error %d)" % [slot, err])
		return false
	ranura_actual = slot
	print("[perfil] partida guardada en la ranura ", slot, ": ", datos.resumen())
	return true


# Carga la ranura EN MEMORIA (deja a Game listo). Quien llama decide a que escena ir.
func cargar(slot: int) -> bool:
	var datos: SaveData = cabecera(slot)
	if datos == null:
		return false
	Game.importar_partida(datos)
	ranura_actual = slot
	print("[perfil] partida cargada de la ranura ", slot, ": ", datos.resumen())
	return true


func borrar(slot: int) -> void:
	if existe(slot):
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
	var err: int = ResourceSaver.save(datos, ruta(ranura_actual))
	if err != Error.OK:   # Error.OK, NO el OK de arriba: ver la nota de las constantes
		push_warning("[perfil] no se pudo guardar la ranura %d (error %d)" % [ranura_actual, err])
		return false
	print("[perfil] partida guardada en la ranura ", ranura_actual, ": ", datos.resumen())
	return true
