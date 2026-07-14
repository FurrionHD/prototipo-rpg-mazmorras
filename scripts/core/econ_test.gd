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
		 "res://resources/materials/acero.tres"],
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

	_forjable()
	_fundido()
	_rareza()
	quit()


# RAREZA: la obra maestra tiene que ganar en TODO (raw, crit, evasion, aturdir, bloqueo, vel) y
# cada mejora tiene que rendir mas. Se prueba contra Upgrades (class_name, estatico).
func _rareza() -> void:
	print("\n=========== LA RAREZA SE NOTA (comun vs obra maestra) ===========")
	var daga: WeaponData = load("res://resources/weapons/daga.tres") as WeaponData
	var maza: WeaponData = load("res://resources/weapons/martillo_grande.tres") as WeaponData
	for arma in [daga, maza]:
		print("\n  --- %s (base: crit %.2f, evasion %.2f, aturdir %.2f, bloqueo %.2f) ---" % [
			arma.nombre, arma.crit_bonus, arma.evasion_bonus, arma.aturdir_base, arma.bloqueo])
		# COMUN sin mejoras, COMUN a tope de mejoras, OBRA MAESTRA a tope. tmult=1 (tier 1).
		var full_comun: Dictionary = _mejoras_full(Upgrades.RAREZA_SLOTS[0])
		var full_om: Dictionary = _mejoras_full(Upgrades.RAREZA_SLOTS[6])
		_fila_arma("Comun +0        ", arma, 0, {})
		_fila_arma("Comun +max      ", arma, 0, full_comun)
		_fila_arma("Obra maestra +0 ", arma, 6, {})
		_fila_arma("Obra maestra max", arma, 6, full_om)


# Reparte 'huecos' mejoras entre Agudeza, Precision, Peso y Rapidez (para ver todos los efectos).
func _mejoras_full(huecos: int) -> Dictionary:
	var cats: Array = [Upgrades.AGUDEZA, Upgrades.PRECISION, Upgrades.PESO, Upgrades.RAPIDEZ]
	var out: Dictionary = {}
	for i in range(huecos):
		var c: String = cats[i % cats.size()]
		out[c] = int(out.get(c, 0)) + 1
	return out


func _fila_arma(etq: String, w: WeaponData, rareza: int, mejoras: Dictionary) -> void:
	var m: Dictionary = Upgrades.weapon_mods(w, 1.0, rareza, mejoras)
	print("    %s  raw %5.2f  crit %+.3f  evasion %+.3f  aturdir %.3f  bloqueo %.2f  vel ×%.3f" % [
		etq, float(m["raw"]), float(m["crit"]), float(m["evasion"]),
		float(m["aturdir"]), float(m["bloqueo"]), float(m["vel_mult"])])


# FUNDIR: lo que cuesta hacer una pieza contra lo que devuelve deshacerla, y el AVISO que deje
# escrito en el plan: si el material que sale vale mas que el precio de compra en la tienda,
# comprar-y-fundir es una imprenta de dinero.
func _fundido() -> void:
	print("\n=========== FUNDIR EQUIPO (mitad de lo que costo) ===========")
	var piezas: Array[String] = [
		"res://resources/weapons/daga.tres",
		"res://resources/weapons/espada_larga.tres",
		"res://resources/weapons/martillo_grande.tres",
		"res://resources/armor/cuero_pecho.tres",
	]
	for ruta in piezas:
		var base: Resource = load(ruta)
		if base == null:
			continue
		var c: Dictionary = Forge.coste(base)
		print("\n  %s  (precio %d)" % [str(base.get("nombre")), int(base.get("valor_base"))])
		print("    forjar: %d uds de metal + %d de fibra" % [int(c["metal"]), int(c["fibra"])])
		for mejoras in [0, 3, 7]:
			var f: Dictionary = Forge.fundir_material(base, mejoras)
			var esc: Array = ARMADURA if base is ArmorData else ARMA
			var nuc: Dictionary = Forge.fundir_nucleos(_cargar(esc), mejoras)
			var txt: String = ""
			for n in nuc:
				txt += "%d x %s  " % [int(nuc[n]), (n as MaterialData).nombre]
			print("    fundir +%d -> %d metal + %d fibra   %s" % [
				mejoras, int(f["metal"]), int(f["fibra"]), txt if txt != "" else "(sin núcleos)"])


func _cargar(rutas: Array) -> Array:
	var out: Array = []
	for r in rutas:
		var m: MaterialData = load(r) as MaterialData
		if m != null:
			out.append(m)
	out.sort_custom(func(a: MaterialData, b: MaterialData): return a.mejora_min < b.mejora_min)
	return out


# QUE se puede forjar con cada metal. Lo que se comprueba aqui es el FRENO: la armadura T2/T3
# tiene que salir BLOQUEADA (no hay cuero que no sea el de rata), y el arma T2/T3 NO.
#
# Se prueba contra Forge, que es donde vive la regla y es ESTATICO. Game no vale aqui: en modo
# --script los autoloads no se instancian.
const METALES: Array[String] = [
	"res://resources/materials/lingote_cobre.tres",
	"res://resources/materials/lingote_hierro.tres",
	"res://resources/materials/lingote_acero.tres",
]
const MADERAS: Array[String] = [
	"res://resources/materials/madera_comun.tres",
	"res://resources/materials/madera_dura.tres",
	"res://resources/materials/madera_negra.tres",
]
const CUERO := "res://resources/materials/cuero_curtido.tres"

func _forjable() -> void:
	print("\n=========== QUE SE PUEDE FORJAR CON CADA METAL ===========")
	var cuero: MaterialData = load(CUERO) as MaterialData
	for ruta in METALES:
		var metal: MaterialData = load(ruta) as MaterialData
		# El ARMA necesita una madera de la altura del metal.
		var mango: String = "BLOQUEADA"
		for rm in MADERAS:
			var mad: MaterialData = load(rm) as MaterialData
			if Forge.madera_vale_para(mad, metal):
				mango = mad.nombre
				break
		var piel: String = cuero.nombre if Forge.cuero_vale_para(cuero, metal) \
			else "BLOQUEADA (no hay cuero a su altura)"
		print("  T%d %-8s  arma -> %-16s   armadura -> %s" % [
			metal.tier, metal.nombre.replace("Lingote de ", ""), mango, piel])


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
