extends "res://tools/unitarias/caso.gd"
# Cubre: res://scripts/ui/menu_scaffold.gd (valor_es, el valor de las filas de las fichas)
# 06/11, pase de textos: coma decimal sin ceros de mas, espacio antes del %, "por turno"; y sin romper IPs ni versiones.


func test_decimales_con_coma_y_sin_ceros() -> void:
	igual(MenuScaffold.valor_es("×1.50"), "×1,5")
	igual(MenuScaffold.valor_es("×1.05"), "×1,05")
	igual(MenuScaffold.valor_es("3.00"), "3")
	igual(MenuScaffold.valor_es("12.4  (total 30.0)"), "12,4  (total 30)")


func test_porcentaje_con_espacio() -> void:
	igual(MenuScaffold.valor_es("+5%"), "+5 %")
	igual(MenuScaffold.valor_es("+4.5%"), "+4,5 %")
	igual(MenuScaffold.valor_es("25 %"), "25 %")


func test_por_turno() -> void:
	igual(MenuScaffold.valor_es("0.50/turno"), "0,5 por turno")


func test_no_toca_ips_ni_versiones() -> void:
	igual(MenuScaffold.valor_es("192.168.1.10"), "192.168.1.10")
	igual(MenuScaffold.valor_es("v0.15.6"), "v0.15.6")
	igual(MenuScaffold.valor_es("0:15"), "0:15")
