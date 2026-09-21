# PRUEBA: la REGLA DE DAÑO de las magias (decision del usuario, 21/09/2026) y las frases del examen.
#   DAÑO TOTAL contra 3 enemigos en fila = UNIDAD × (1 + 0,75 × (frases − 1)) × (1 + 0,05 × rareza)
# Cada frase de mas suma un 75 % de la primera, no un 100 % (1 frase ×1, 2 ×1,75, 3 ×2,5, 4 ×3,25).
# El total cuenta TODO lo que hace el hechizo: el principal, los de al lado, los rebotes y las bolas
# que salpican. Apuntando al del medio, que es lo que haria cualquiera con un hechizo de area.
# Una primera version comparaba solo el golpe al principal y dejaba el Estallido haciendo dos veces y
# media lo que las demas en cuanto habia enemigos a los lados.
# Las comunes de 1 frase no se miden: estan bien y por TURNO ya empatan con las de 2.
# Frases: ninguna puede ser "la misma" que otra distinta quitando tildes y mayusculas (asi se colaba
# "restaurame" junto a "restáurame" en el examen).
#   godot --headless --path . res://tools/prueba_magias_regla.tscn
extends Node

const CARPETA := "res://resources/spells/"
# LA UNIDAD, fija: es la media que daban Andanada, Rayo y Torrente (35 / 35,6 / 39 de total) antes de
# pasarles tambien a ellas la regla (decision del usuario). Desde entonces las tres la cumplen, asi que
# ya no se puede sacar de ellas: se escribe.
const UNIDAD := 19.89
const NO_SE_MIDEN := ["brasa", "descarga", "rocio", "pulso_menor"]
const TOLERANCIA := 0.02
const ENEMIGOS := 3


func _ready() -> void:
	await get_tree().process_frame
	var fallos: int = 0
	var unidad: float = UNIDAD
	print("[regla] unidad por frase: %.2f (total contra %d enemigos)" % [unidad, ENEMIGOS])
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
				or NO_SE_MIDEN.has(id):
			continue
		var esperado: float = _por_frases(s) * unidad * (1.0 + 0.05 * float(s.rareza))
		var real: float = _total(s)
		var ok: bool = absf(real - esperado) <= esperado * TOLERANCIA
		if not ok:
			fallos += 1
		print("[regla] %-26s %s  %d frases, rareza %d  total %.1f (regla %.1f)" % [
			s.nombre, "ok " if ok else "MAL", s.longitud(), s.rareza, real, esperado])
	fallos += _curas()
	print("[regla] RESULTADO: ", "TODO CUADRA" if fallos == 0 else "FALLAN %d" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)


# Lo que multiplican las frases: la primera cuenta 1 y cada una de mas, 0,75.
func _por_frases(s: SpellData) -> float:
	return 1.0 + 0.75 * float(s.longitud() - 1)


# TODO LO QUE HACE el hechizo contra ENEMIGOS en fila, apuntando al del medio (sin poder magico).
#  - A LOS LADOS: el principal y sus dos vecinos. A TODOS: cada uno.
#  - REBOTES: cada uno cae en alguien, asi que suman enteros.
#  - DISPERSOS: cada bola cae en uno al azar; si salpica, en una fila de 3 tiene de media 4/3 vecinos, y
#    solo salpican las del elemento de identidad (la lluvia de la Tormenta cae suelta).
func _total(s: SpellData) -> float:
	var vecinos: float = 0.0
	if s.salpica():
		vecinos = float(ENEMIGOS - 1) if (s.alcance == SpellData.Alcance.TODOS or not s.dispersa) else 4.0 / 3.0
		if s.alcance == SpellData.Alcance.ADYACENTES and not s.dispersa:
			vecinos = 2.0
	var salp: float = s.dano_salpicon * vecinos
	if s.dispersa:
		salp *= s.peso_elemento(s.elemento)
	return s.dano_base * (s.dano_objetivo + salp + float(s.rebotes_n()) * s.dano_rebote)


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


