extends "res://tools/unitarias/caso.gd"
# Cubre: res://scripts/net/net_jugadores.gd res://scripts/ui/combat_espejo.gd res://scripts/net/net_pisos.gd
# LO QUE VIAJA MUCHAS VECES POR SEGUNDO, EMPAQUETADO (29/10, PROTOCOLO 56): la posicion de cada jugador (con su mirada,
# su pose y sus acompañantes) y las barras de ATB de una pelea. Ida y vuelta, lo que pesan, y que un paquete mal formado
# no se lee.

const NetJugadores = preload("res://scripts/net/net_jugadores.gd")
const Espejo = preload("res://scripts/ui/combat_espejo.gd")


func test_la_posicion_va_y_vuelve() -> void:
	var comps: Array = [Vector2(10.4, -20.6), Vector2(3000, 4000)]
	var paq: PackedByteArray = NetJugadores.empaquetar_estado(Vector2(1234.4, -567.6), Vector2(0.6, 0.8), comps, 0x123456)
	igual(paq.size(), 13 + 2 * 8, "13 bytes y 8 por acompañante")
	var e: Array = NetJugadores.desempaquetar_estado(paq)
	igual(e[0], Vector2(1234, -568), "la posicion, en pixeles enteros")
	cierto((e[1] as Vector2).angle_to(Vector2(0.6, 0.8)) < 0.03, "la mirada, a menos de dos grados")
	igual(e[2], [Vector2(10, -21), Vector2(3000, 4000)], "los acompañantes")
	igual(e[3], 0x123456, "la pose entera")
	var antes: int = var_to_bytes([Vector2(1234.4, -567.6), Vector2(0.6, 0.8), comps, 0x123456]).size()
	cierto(var_to_bytes(paq).size() < antes, "pesa menos (%d -> %d bytes)" % [antes, var_to_bytes(paq).size()])


func test_sin_mirada_y_mal_formado() -> void:
	var e: Array = NetJugadores.desempaquetar_estado(NetJugadores.empaquetar_estado(Vector2.ZERO, Vector2.ZERO))
	igual(e[1], Vector2.ZERO, "sin mirada sigue sin mirada")
	igual(NetJugadores.desempaquetar_estado(PackedByteArray([1, 2, 3])), [], "corto: nada")
	var paq: PackedByteArray = NetJugadores.empaquetar_estado(Vector2.ONE, Vector2.RIGHT)
	paq.append(7)
	igual(NetJugadores.desempaquetar_estado(paq), [], "con bytes de mas: nada")


func test_el_atb_va_y_vuelve() -> void:
	var barras := PackedFloat32Array([0.0, 0.5, 1.0, 1.7])
	var cola := PackedFloat32Array([3.0, 1520.5, -88.25, 96.0])
	var paq: PackedByteArray = Espejo.empaquetar_atb(barras, cola)
	igual(paq.size(), 1 + 4 * 2 + 4 * 4, "un byte, dos por barra y la cola en float")
	var d: Array = Espejo.desempaquetar_atb(paq)
	for i in barras.size():
		cerca(d[0][i], barras[i], 0.0001, "barra %d" % i)
	igual(d[1], cola, "el circulo del tactico, exacto")
	var sin_cola: Array = Espejo.desempaquetar_atb(Espejo.empaquetar_atb(barras, PackedFloat32Array()))
	igual((sin_cola[1] as PackedFloat32Array).size(), 0, "fuera del tactico, sin cola")
	igual(Espejo.desempaquetar_atb(PackedByteArray([5, 0])), [], "mal formado: nada")
