# RED FALSA para la huella del combate en ESPEJO: hace de Net.peleas en la prueba y, en vez de mandar
# por la red, entrega cada mensaje del anfitrion directamente a la pantalla espejo. Asi se ejercita el
# codigo del espejo (roster, instantaneas, impactos, barra de accion) sin dos procesos.
#
# Con 'espejos' (peer -> pantalla) hace ademas de los HUMANOS de una pelea montada con fichas: el
# anfitrion les pide los turnos a ellos y lo que eligen vuelve como si llegara por la red.
extends "res://scripts/net/net_peleas.gd"

var espejo: Node = null
var anfitrion: Node = null
var espejos: Dictionary = {}        # peer -> pantalla espejo de ese humano
var pjs_por_hueco: Dictionary = {}  # hueco en la fila de aliados -> PersonajeData de su dueño


func _todos() -> Array:
	var out: Array = []
	if is_instance_valid(espejo):
		out.append(espejo)
	for p in espejos:
		if is_instance_valid(espejos[p]):
			out.append(espejos[p])
	return out


func difundir_instantanea(snap: Dictionary) -> void:
	for e in _todos():
		e.aplicar_instantanea(snap)


func difundir_atb(ratios: PackedFloat32Array) -> void:
	for e in _todos():
		e.aplicar_atb(ratios)


func difundir_impactos(datos: PackedInt32Array) -> void:
	for e in _todos():
		e.aplicar_impactos(datos)


func difundir_roster(roster: Dictionary) -> void:
	for e in _todos():
		e.aplicar_roster(roster)


func pedir_roster_pelea() -> void:
	if not is_instance_valid(anfitrion):
		return
	for e in _todos():
		e.aplicar_roster(anfitrion.roster_para_espejo())


func salir_del_espejo() -> void:
	pass


# --- TURNOS: anfitrion -> el espejo de ese humano ---

func pedir_accion(peer: int, idx: int, seq: int = 0, radio: float = 0.0) -> void:
	if is_instance_valid(espejos.get(peer)):
		espejos[peer].turno_mio(idx, seq, radio)


func pedir_frase(peer: int, idx: int, opciones: Array, nombre: String, largo: int, seq: int = 0) -> void:
	if is_instance_valid(espejos.get(peer)):
		espejos[peer].recitar_frase(idx, opciones, nombre, largo, seq)


func pedir_disparo(peer: int, nombre: String, seq: int = 0) -> void:
	if is_instance_valid(espejos.get(peer)):
		espejos[peer].lanzar_conjuro(nombre, seq)


func pedir_soltar(peer: int, nombre: String, seq: int = 0) -> void:
	if is_instance_valid(espejos.get(peer)):
		espejos[peer].soltar_carga(nombre, seq)


func esta_en_mi_pelea(peer: int) -> bool:
	return espejos.has(peer) or _pelea_participantes.has(peer)


func mi_pj_en_pelea(idx: int) -> PersonajeData:
	return pjs_por_hueco.get(idx)


# --- RESPUESTAS: espejo -> anfitrion. Quien contesta es el espejo al que se le pidio ESE numero (cada
# peticion lleva uno distinto y solo se le manda a un humano).
func enviar_accion(accion: Dictionary) -> void:
	if not is_instance_valid(anfitrion):
		return
	var seq: int = int(accion.get("seq", 0))
	for peer in espejos:
		var e: Node = espejos[peer]
		if is_instance_valid(e) and int(e.espejo._seq_contestada) == seq:
			anfitrion.aplicar_accion_remota(accion, peer)
			return
