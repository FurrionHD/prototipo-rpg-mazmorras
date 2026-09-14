# RED FALSA para la huella del combate en ESPEJO: hace de Net.peleas en la prueba y, en vez de mandar
# por la red, entrega cada mensaje del anfitrion directamente a la pantalla espejo. Asi se ejercita el
# codigo del espejo (roster, instantaneas, impactos, barra de accion) sin dos procesos.
extends "res://scripts/net/net_peleas.gd"

var espejo: Node = null
var anfitrion: Node = null


func difundir_instantanea(snap: Dictionary) -> void:
	if is_instance_valid(espejo):
		espejo.aplicar_instantanea(snap)


func difundir_atb(ratios: PackedFloat32Array) -> void:
	if is_instance_valid(espejo):
		espejo.aplicar_atb(ratios)


func difundir_impactos(datos: PackedInt32Array) -> void:
	if is_instance_valid(espejo):
		espejo.aplicar_impactos(datos)


func difundir_roster(roster: Dictionary) -> void:
	if is_instance_valid(espejo):
		espejo.aplicar_roster(roster)


func pedir_roster_pelea() -> void:
	if is_instance_valid(espejo) and is_instance_valid(anfitrion):
		espejo.aplicar_roster(anfitrion.roster_para_espejo())


func salir_del_espejo() -> void:
	pass
