# ============================================================
#  econ_test.gd  (TEMPORAL - para llevar la curva al Excel)
#  Imprime, sin jugar, las dos curvas que se acaban de retocar:
#    1) lo que cuesta subir un arma / una armadura de +0 a su tope, nucleo a nucleo;
#    2) la dificultad de los tres minijuegos contra la curva de stats esperada.
#  Se corre en headless:
#    godot --headless --script scripts/core/econ_test.gd
# ============================================================

extends SceneTree


# La escalera de nucleos, en el orden en que te los vas encontrando.
const ARMA: Array[String] = [
	"res://resources/materials/nucleo_slime.tres",
	"res://resources/materials/nucleo_venenoso.tres",
	"res://resources/materials/nucleo_fuego.tres",
	"res://resources/materials/nucleo_rey_slime.tres",
]
const ARMADURA: Array[String] = [
	"res://resources/materials/nucleo_rata.tres",
	"res://resources/materials/nucleo_rey_rata.tres",
	"res://resources/materials/nucleo_jabali.tres",
	"res://resources/materials/nucleo_rey_slime.tres",
]

# La curva que nos dio el usuario: al piso 5 rondas los 300 de stat.
const STAT_POR_PISO := 60.0


func _init() -> void:
	print("\n=========== COSTE DE MEJORA (nucleos por +1) ===========")
	_curva_nucleos("ARMA", ARMA)
	_curva_nucleos("ARMADURA", ARMADURA)

	print("\n=========== DIFICULTAD DE LOS MINIJUEGOS ===========")
	print("(stat esperada = %d x piso; el reto sale de exigencia / (stat + suelo))" % int(STAT_POR_PISO))
	_curva_material("PLANTAS  (Destreza, suelo %d)" % int(Game.HERB_DESTREZA_FLOOR),
		["res://resources/materials/hierba_palida.tres",
		 "res://resources/materials/raiz_amarga.tres"],
		Game.HERB_DESTREZA_FLOOR)
	_curva_material("VETAS    (Fuerza, suelo %d)" % int(Game.MINERIA_FUERZA_FLOOR),
		["res://resources/materials/cobre.tres",
		 "res://resources/materials/hierro.tres",
		 "res://resources/materials/adamante.tres"],
		Game.MINERIA_FUERZA_FLOOR)

	_curva_material("MADERAS  (Agilidad, suelo %d)" % int(Game.TALA_AGILIDAD_FLOOR),
		["res://resources/materials/madera_comun.tres",
		 "res://resources/materials/madera_dura.tres",
		 "res://resources/materials/madera_negra.tres"],
		Game.TALA_AGILIDAD_FLOOR)

	print("\n=========== QUE SALE EN CADA PISO ===========")
	_reparto("PLANTAS", "res://resources/world/plantas.tres")
	_reparto("VETAS", "res://resources/world/vetas.tres")
	_reparto("MADERAS", "res://resources/world/maderas.tres")
	quit()


# El reparto REAL de la tabla piso a piso (lo deriva de los pesos, no se escribe a mano).
func _reparto(titulo: String, ruta: String) -> void:
	var tabla: MaterialTable = load(ruta) as MaterialTable
	if tabla == null:
		return
	print("\n--- %s ---" % titulo)
	for piso in [1, 2, 3, 4, 6, 11]:
		print("  piso %-2d : %s" % [piso, tabla.resumen(piso)])


func _curva_nucleos(titulo: String, rutas: Array[String]) -> void:
	print("\n--- %s ---" % titulo)
	var total: Dictionary = {}
	var nivel: int = 0
	for ruta in rutas:
		var n: MaterialData = load(ruta) as MaterialData
		if n == null:
			continue
		# Este nucleo cubre de su mejora_min a su mejora_max.
		while nivel < n.mejora_max:
			var cuesta: int = Forge.nucleos_para_mejora(nivel, n)
			nivel += 1
			total[n.nombre] = int(total.get(n.nombre, 0)) + cuesta
			print("  +%d  <- %-22s  %d nucleo(s)" % [nivel, n.nombre, cuesta])
	print("  TOTAL para llegar a +%d:" % nivel)
	for k in total:
		print("      %-22s x%d" % [k, total[k]])


func _curva_material(titulo: String, rutas: Array, suelo: float) -> void:
	print("\n--- %s ---" % titulo)
	for ruta in rutas:
		var m: MaterialData = load(ruta) as MaterialData
		if m == null:
			continue
		var linea: String = "  %-18s (piso %2d+, exigencia %4.0f): " % [m.nombre, m.piso_min, m.exigencia]
		# El reto en el piso donde aparece, y en los dos siguientes multiplos de 5.
		for piso in [m.piso_min, m.piso_min + 4, m.piso_min + 8]:
			var exig: float = m.exigencia * pow(Game.RECOLECCION_PISO_FACTOR, float(piso - 1))
			var stat: float = STAT_POR_PISO * float(piso)
			var reto: float = exig / (stat + suelo)
			linea += "p%-2d reto %.2f   " % [piso, reto]
		print(linea)
