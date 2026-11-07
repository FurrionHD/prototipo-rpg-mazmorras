extends "res://tools/unitarias/caso.gd"
# Cubre: res://scripts/ui/combat.gd (_n y _frase_estados, las piezas de las frases del registro de la pelea)
# 06/11, pase de textos del log: numeros con coma y sin ceros (lo eligio el jefe) y los estados en frases.

const Pantalla = preload("res://scripts/ui/combat.gd")


func test_numeros_con_coma_y_sin_ceros() -> void:
	igual(Pantalla._n(5.69), "5,69")
	igual(Pantalla._n(4.10), "4,1")
	igual(Pantalla._n(3.0), "3")
	igual(Pantalla._n(10.0), "10")
	igual(Pantalla._n(0.004), "0")
	igual(Pantalla._n(-0.001), "0")
	igual(Pantalla._n(12.345), "12,35")


func test_estados_causados_se_juntan() -> void:
	igual(Pantalla._frase_estados(["·Veneno", "·Pegajoso", "·Veneno"]), "  Causa Veneno ×2, Pegajoso.")


func test_buff_de_grupo_en_una_frase() -> void:
	igual(Pantalla._frase_estados(["Daniel recibe Furia", "Dasui recibe Furia", "Coco recibe Furia"]),
		"  Daniel, Dasui y Coco reciben Furia.")
	igual(Pantalla._frase_estados(["Daniel recibe Furia"]), "  Daniel recibe Furia.")


func test_mezcla_en_orden() -> void:
	igual(Pantalla._frase_estados(["·Lento", "en guardia: Daniel", "Dasui recibe Escudo", "Daniel recibe Escudo"]),
		"  Causa Lento.  En guardia: Daniel.  Dasui y Daniel reciben Escudo.")
