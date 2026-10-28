extends "res://tools/unitarias/caso.gd"
# La foto del charco por la red (scripts/world/fishing_spot.gd, fase 3): empaquetada y solo a quien la ve.

const FS := preload("res://scripts/world/fishing_spot.gd")

const FILAS := [[7, Vector2(12.5, -3.0), 1.25, 0], [9, Vector2(40.0, 8.0), -2.5, 1218597964], [11, Vector2.ZERO, 0.0, 0]]


func test_empaquetar_y_deshacer_da_los_mismos_peces() -> void:
	var foto: Array = FS.empaquetar_peces(FILAS, 8, 5)
	igual(int(foto[0]), 8, "el stock")
	igual(int(foto[1]), 5, "el aforo")
	var vuelta: Array = FS.peces_de_red(foto)
	igual(vuelta.size(), FILAS.size(), "los tres peces")
	for i in FILAS.size():
		igual(int(vuelta[i][0]), int(FILAS[i][0]), "pez %d: su nonce" % i)
		cierto((vuelta[i][1] as Vector2).is_equal_approx(FILAS[i][1]), "pez %d: su sitio" % i)
		cerca(float(vuelta[i][2]), float(FILAS[i][2]), 0.0001, "pez %d: hacia donde mira" % i)
		igual(int(vuelta[i][3]), int(FILAS[i][3]), "pez %d: quien lo tiene enganchado" % i)


func test_empaquetada_pesa_menos_que_la_lista() -> void:
	var muchos: Array = []
	for i in 6:   # PECES_MAX
		muchos.append([100 + i, Vector2(i * 10.0, i * 3.0), 0.5 * i, 0])
	var antes: int = var_to_bytes({"peces": muchos, "stock": 10, "aforo": 6}).size()
	var ahora: int = var_to_bytes(FS.empaquetar_peces(muchos, 10, 6)).size()
	cierto(ahora * 2 < antes, "menos de la mitad (%d B frente a %d)" % [ahora, antes])


func test_foto_vacia_o_rota_no_rompe() -> void:
	igual(FS.peces_de_red([]).size(), 0, "sin peces")
	var cojo: Array = FS.empaquetar_peces(FILAS)
	cojo[3] = PackedFloat32Array([1.0, 2.0, 3.0, 4.0])
	igual(FS.peces_de_red(cojo).size(), 1, "con un array mas corto, solo los que estan enteros")


func test_solo_a_quien_lo_ve() -> void:
	var tam := Vector2(256, 192)
	cierto(FS.se_ve_desde(Vector2(500, 0), Vector2.ZERO, tam), "a 500 px lo ve")
	cierto(not FS.se_ve_desde(Vector2(3000, 0), Vector2.ZERO, tam), "a 3000 px no")
	cierto(FS.se_ve_desde(Vector2.INF, Vector2.ZERO, tam), "sin saber donde esta, se le manda")
