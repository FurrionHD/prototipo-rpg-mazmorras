# PRUEBA: la REGLA DE DAÑO de las magias (decision del usuario, 21/09/2026) y las frases del examen.
#   Daño al objetivo en 1 contra 1 = frases × unidad de su forma × (1 + 0,05 × rareza)
# La unidad sale de la comun de 1 frase con la misma forma (se lee de su .tres, no va escrita aqui):
# a los lados = Brasa, a todos = Rocio, rebotes = Descarga, a uno = Pulso menor.
# Frases: ninguna puede ser "la misma" que otra distinta quitando tildes y mayusculas (asi se colaba
# "restaurame" junto a "restáurame" en el examen).
#   godot --headless --path . res://tools/prueba_magias_regla.tscn
extends Node

const CARPETA := "res://resources/spells/"
# Las de referencia (de ahi sale la regla, el usuario dice que estan bien) y las de forma unica.
const NO_SE_MIDEN := ["brasa", "descarga", "rocio", "pulso_menor", "bola_fuego", "rayo", "chorro_agua",
	"tormenta"]
const TOLERANCIA := 0.02


func _ready() -> void:
	await get_tree().process_frame
	var fallos: int = 0
	var unidades := {
		"lados": _valor(load(CARPETA + "brasa.tres")),
		"todos": _valor(load(CARPETA + "rocio.tres")),
		"rebotes": _valor(load(CARPETA + "descarga.tres")),
		"uno": _valor(load(CARPETA + "pulso_menor.tres")),
	}
	print("[regla] unidades: ", unidades)
	var frases: Dictionary = {}   # clave normalizada -> texto
	for f in SpellBook.REPOSITORIO:
		frases[SpellBook.normalizar(f)] = f
	for archivo in ResourceLoader.list_directory(CARPETA):
		if not archivo.ends_with(".tres"):
			continue
		var s := load(CARPETA + archivo) as SpellData
		if s == null:
			continue
		# FRASES: la misma clave con distinto texto = la misma frase escrita de dos formas.
		for f in s.frases:
			var k: String = SpellBook.normalizar(f)
			if frases.has(k) and frases[k] != f:
				fallos += 1
				print("[frases] %s: «%s» es casi igual que «%s»" % [s.nombre, f, frases[k]])
			frases[k] = f
		var id: String = archivo.get_basename()
		if s.tipo != SpellData.TipoEfecto.ATAQUE or s.dano_base <= 0.0 or s.es_imbuicion() \
				or NO_SE_MIDEN.has(id) or s.dispersa:
			continue
		var forma: String = _forma(s)
		var esperado: float = float(s.longitud()) * float(unidades[forma]) * (1.0 + 0.05 * float(s.rareza))
		var real: float = _valor(s)
		var ok: bool = absf(real - esperado) <= esperado * TOLERANCIA
		if not ok:
			fallos += 1
		print("[regla] %-26s %s  %d frases, rareza %d, forma %-7s  %.1f (regla %.1f)" % [
			s.nombre, "ok " if ok else "MAL", s.longitud(), s.rareza, forma, real, esperado])
	fallos += _curas()
	print("[regla] RESULTADO: ", "TODO CUADRA" if fallos == 0 else "FALLAN %d" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)


# Lo que le cae al objetivo en un 1 contra 1: el golpe principal y, si rebota, todos los rebotes
# (con un solo enemigo caen todos sobre el).
func _valor(s: SpellData) -> float:
	return s.dano_base * (s.dano_objetivo + float(s.rebotes_n()) * s.dano_rebote)


# LAS CURAS contra la tabla que aprobo el usuario el 21/09/2026 (Magia y baston al 50 %; nivel 1, 199 de
# vida, las mejoras son de Potencia). Vendaje = a uno; Luz = el TOTAL, que luego se reparte.
func _curas() -> int:
	var vendaje := load(CARPETA + "vendaje_de_luz.tres") as SpellData
	var luz := load(CARPETA + "luz_restauradora.tres") as SpellData
	# [tier, rareza, mejoras, magia, vendaje esperado, luz total esperada]
	var casos: Array = [
		[1, 0, 0, 0, 42, 144], [1, 0, 0, 800, 80, 275], [1, 5, 3, 400, 86, 293],
		[2, 3, 0, 200, 79, 270], [2, 5, 3, 800, 133, 456],
	]
	var fallos: int = 0
	for c in casos:
		var ab := Abilities.new()
		ab.magia = int(c[3])
		var lanzador := Combatant.new("prueba", 1, ab, 199.0, 0.0, 0.0, 0.0)
		lanzador.magic_amp = float(Upgrades.magic_mods(1.7, Game.tier_mult(int(c[0])), int(c[1]),
			{Upgrades.POTENCIA: int(c[2])})["magic_amp"])
		var v: float = vendaje.cura_de(199.0, StatsMath.resolve_heal(lanzador, vendaje))
		var l: float = luz.cura_de(199.0, StatsMath.resolve_heal(lanzador, luz))
		var ok: bool = absf(v - float(c[4])) <= 1.0 and absf(l - float(c[5])) <= 2.0
		if not ok:
			fallos += 1
		print("[curas] T%d rareza %d +%d Magia %d: Vendaje %.0f (tabla %d) · Luz %.0f = %.0f c/u con 4 (tabla %d)  %s" % [
			c[0], c[1], c[2], c[3], v, c[4], l, l / 4.0, c[5], "ok" if ok else "MAL"])
	return fallos


func _forma(s: SpellData) -> String:
	if s.rebotes_n() > 0:
		return "rebotes"
	if s.alcance == SpellData.Alcance.TODOS and s.salpica():
		return "todos"
	if s.alcance == SpellData.Alcance.ADYACENTES and s.salpica():
		return "lados"
	return "uno"
