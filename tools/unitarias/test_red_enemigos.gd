extends "res://tools/unitarias/caso.gd"
# El tick de enemigos por la red (scripts/net/net_enemigos.gd, fase 3): empaquetado y solo con los que cambian.

const NE := preload("res://scripts/net/net_enemigos.gd")

# [id, pos, mirada, avisando, pelea, embestidas, embistiendo]
const FILAS := [
	[3, Vector2(100.5, -20.25), 1.5, false, 0, 0, false],
	[17, Vector2(-4.0, 9000.0), -3.0, true, 1000002, 41, true],
	[255, Vector2.ZERO, 0.0, false, 0, 65535, false],
]


func test_empaquetar_y_deshacer_da_las_mismas_filas() -> void:
	var vuelta: Array = NE.filas_de_tick(NE.empaquetar_tick(FILAS))
	igual(vuelta.size(), FILAS.size(), "los tres bichos")
	for i in FILAS.size():
		var a: Array = FILAS[i]
		var b: Array = vuelta[i]
		igual(int(b[0]), int(a[0]), "bicho %d: su id" % i)
		cierto((b[1] as Vector2).is_equal_approx(a[1]), "bicho %d: su sitio (%s)" % [i, b[1]])
		cerca(float(b[2]), float(a[2]), 0.0001, "bicho %d: su mirada" % i)
		igual(bool(b[3]), bool(a[3]), "bicho %d: si avisa el golpe" % i)
		igual(int(b[4]), int(a[4]), "bicho %d: de quien es su pelea" % i)
		igual(int(b[5]), int(a[5]), "bicho %d: su contador de embestidas" % i)
		igual(bool(b[6]), bool(a[6]), "bicho %d: si embiste" % i)


func test_empaquetado_pesa_menos_de_la_mitad() -> void:
	var muchos: Array = []
	for i in 20:
		muchos.append([i, Vector2(i * 31.0, i * 7.0), 0.1 * i, i % 3 == 0, 0, i, false])
	var antes: int = var_to_bytes(muchos).size()
	var ahora: int = var_to_bytes(NE.empaquetar_tick(muchos)).size()
	cierto(ahora * 2 < antes, "menos de la mitad (%d B frente a %d)" % [ahora, antes])


func test_paquete_vacio_o_cojo_no_rompe() -> void:
	igual(NE.filas_de_tick([]).size(), 0, "sin paquete")
	var cojo: Array = NE.empaquetar_tick(FILAS)
	cojo[2] = PackedByteArray([1])
	igual(NE.filas_de_tick(cojo).size(), 1, "con un array mas corto, solo los que estan enteros")


func test_quieto_no_cambia_y_lo_que_se_ve_si() -> void:
	var base: Array = FILAS[0]
	cierto(NE.fila_igual(base, base.duplicate()), "el mismo bicho quieto: igual")
	var poco: Array = base.duplicate()
	poco[1] = (base[1] as Vector2) + Vector2(0.2, 0.0)
	cierto(NE.fila_igual(base, poco), "un quinto de pixel no cuenta")
	var cambios := {1: Vector2(110.0, -20.25), 2: 1.7, 3: true, 4: 1000001, 5: 1, 6: true}
	for k in cambios:
		var otra: Array = base.duplicate()
		otra[k] = cambios[k]
		cierto(not NE.fila_igual(base, otra), "cambiar el campo %d si cuenta" % k)
	var vuelta: Array = base.duplicate()
	vuelta[2] = float(base[2]) + TAU
	cierto(NE.fila_igual(base, vuelta), "una vuelta entera de mirada es la misma mirada")
