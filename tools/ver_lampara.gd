# ============================================================
#  ver_lampara.gd  --  HERRAMIENTA, no parte del juego.
#  Saca la tabla de RADIOS del farolillo: que se ve con cada pieza en cada piso. Es la curva que
#  hay que mirar para calibrar, no un numero suelto.
#  godot --headless --path . --script res://tools/ver_lampara.gd
# ============================================================
extends SceneTree

const PISOS := [1, 3, 6, 7, 9, 12, 13, 16]

func _initialize() -> void:
	print("RADIO DE VISION, en celdas (suelo duro %.1f, tope %.1f)"
		% [Vision.RADIO_MINIMO, Lampara.RADIO_TOPE])
	print("")
	var cab: String = "%-42s" % "farolillo"
	for p in PISOS:
		cab += "%7s" % ("p%d" % p)
	print(cab)
	print("-".repeat(cab.length()))
	_fila("SIN FAROLILLO (o sin carbon)", 0.0)
	print("")
	_pieza("T1 comun, cobre bruto, sin mejoras", 1, Upgrades.Rareza.COMUN, 0, 0)
	_pieza("T1 comun, cobre bruto, +3 (tope comun)", 1, Upgrades.Rareza.COMUN, 0, 3)
	_pieza("T1 raro, cobre veteado, +5", 1, Upgrades.Rareza.RARO, 3, 5)
	_pieza("T1 legendario, cobre profundo, +8", 1, Upgrades.Rareza.LEGENDARIO, 9, 8)
	_pieza("T1 pristino, cobre profundo, +15", 1, Upgrades.Rareza.PRISTINO, 9, 15)
	print("")
	_pieza("T2 comun, hierro, sin mejoras", 2, Upgrades.Rareza.COMUN, 0, 0)
	_pieza("T2 legendario, hierro negro, +8", 2, Upgrades.Rareza.LEGENDARIO, 9, 8)
	_pieza("T2 pristino, hierro negro, +15", 2, Upgrades.Rareza.PRISTINO, 9, 15)
	print("")
	_pieza("T3 comun, acero, sin mejoras", 3, Upgrades.Rareza.COMUN, 0, 0)
	_pieza("T3 pristino, acero, +15", 3, Upgrades.Rareza.PRISTINO, 9, 15)

	print("")
	print("DURACION DE LA LLAMA (minutos, calidad NORMAL):")
	for id in Lampara.DURACION:
		print("  %-18s %.0f min" % [id, float(Lampara.DURACION[id]) / 60.0 * 1.25])
	quit()


func _pieza(que: String, tier: int, rareza: int, banda: int, mejoras: int) -> void:
	_fila(que, Lampara.potencia(tier, rareza, banda, mejoras))


func _fila(que: String, pot: float) -> void:
	var s: String = "%-42s" % que
	for p in PISOS:
		s += "%7.1f" % Lampara.radio(pot, p)
	print(s)
