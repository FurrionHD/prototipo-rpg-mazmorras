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


# Carga solo para LEER la cabecera (pintar la lista del menu). null si la ranura esta vacia
# o el fichero es de una version que ya no entendemos.
func cabecera(slot: int) -> SaveData:
	if not existe(slot):
		return null
	var d = ResourceLoader.load(ruta(slot), "", ResourceLoader.CACHE_MODE_IGNORE)
	if d == null or not (d is SaveData):
		push_warning("[perfil] la ranura %d no se puede leer" % slot)
		return null
	var s := d as SaveData
	if s.version != SaveData.VERSION_ACTUAL:
		# Una partida de una version vieja: mejor ignorarla entera que cargarla a medias y
		# dejar el juego en un estado imposible.
		push_warning("[perfil] la ranura %d es de una version antigua (%d): se ignora" % [slot, s.version])
		return null
	return s


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
	if err != OK:
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
	if err != OK:
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
