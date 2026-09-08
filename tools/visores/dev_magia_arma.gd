# ============================================================
#  dev_magia_arma.gd  --  HERRAMIENTA, no parte del juego.
#
#  Comprueba el HECHIZO DE SERIE del arma (WeaponData.hechizo_base): el baston y la varita prestan
#  el Pulso menor mientras los lleves puestos, pero no te lo enseñan.
#
#  Son cuatro invariantes y las cuatro se rompen por caminos distintos, asi que se prueban una a una:
#    1. equipar el arma  -> el hechizo aparece disponible Y puesto en la primera ranura libre
#    2. quitarlo A MANO  -> NO vuelve solo (si volviera, no se podria ordenar el kit)
#    3. soltar el arma   -> la ranura se vacia sola, sin codigo de desequipar
#    4. en NINGUN momento entra en 'sabidos', que es lo unico que se GUARDA -- si entrara, el
#       prestado se quedaria aprendido para siempre en el save y ya no se perderia nunca
#
#  Es logica pura, sin Control ni captura, asi que aqui SI vale --headless.
#
#    godot --headless --path . res://tools/visores/dev_magia_arma.tscn
#  Escribe el resultado por consola y devuelve codigo de salida != 0 si algo falla.
# ============================================================
extends Node

const BASTON := "res://resources/weapons/baston.tres"
const VARITA := "res://resources/wands/varita.tres"
const PULSO := "res://resources/spells/pulso_menor.tres"

var _fallos: int = 0


func _ready() -> void:
	var pulso: SpellData = load(PULSO)
	print("=== HECHIZO DE SERIE DEL ARMA ===")
	_probar_baston(pulso)
	_probar_varita(pulso)
	_probar_grimorio(pulso)
	if _fallos == 0:
		print("\nOK: las %d comprobaciones pasan." % _hechas)
	else:
		printerr("\nFALLAN %d comprobaciones." % _fallos)
	get_tree().quit(1 if _fallos > 0 else 0)


var _hechas: int = 0

func _ok(que: String, cond: bool) -> void:
	_hechas += 1
	if cond:
		print("  ok   %s" % que)
	else:
		_fallos += 1
		printerr("  FALLA %s" % que)


# El BASTON: es de dos manos y va en la principal.
func _probar_baston(pulso: SpellData) -> void:
	print("\n-- Baston (mano principal) --")
	var p := PersonajeData.new()
	_ok("de partida no puede lanzar nada", Game.hechizos_disponibles(p).is_empty())

	Game.equipar_arma(load(BASTON), p)
	_ok("con el baston, el pulso esta disponible", Game.hechizos_disponibles(p).has(pulso))
	_ok("y entra puesto en la ranura 1", Game.hechizos_con_huecos(p)[0] == pulso)
	_ok("pero NO se ha aprendido", not Game.hechizos_sabidos(p).has(pulso))

	# 2) Quitarlo a mano tiene que quedarse quitado. Se lee DOS veces a proposito: el saneado corre
	# en cada lectura, asi que un reinyectado tardio se veria en la segunda y no en la primera.
	Game.quitar_hechizo(pulso, p)
	_ok("quitado a mano: la ranura queda vacia", Game.hechizos_con_huecos(p)[0] == null)
	_ok("y sigue vacia al releer (no se reinyecta)", Game.hechizos_con_huecos(p)[0] == null)
	_ok("pero se puede volver a poner a mano", Game.equipar_hechizo(pulso, p))

	# 3) Soltar el arma: sin codigo de desequipar, lo hace el saneado.
	Game.equipar_arma(null, p)
	_ok("sin baston ya no esta disponible", not Game.hechizos_disponibles(p).has(pulso))
	_ok("y su ranura se ha vaciado sola", not Game.hechizos_con_huecos(p).has(pulso))

	Game.equipar_arma(load(BASTON), p)
	_ok("al reequiparlo vuelve", Game.hechizos_con_huecos(p).has(pulso))
	_ok("y sigue sin estar aprendido", Game.hechizos_sabidos(p).is_empty())


# La VARITA: va en la secundaria, con un arma ligera en la principal.
func _probar_varita(pulso: SpellData) -> void:
	print("\n-- Varita (mano secundaria) --")
	var p := PersonajeData.new()
	Game.equipar_arma(load("res://resources/weapons/daga.tres"), p)
	_ok("con solo la daga no puede lanzar nada", Game.hechizos_disponibles(p).is_empty())

	_ok("la varita se admite en la off", Game.equipar_secundaria(load(VARITA), p))
	_ok("con la varita, el pulso esta puesto", Game.hechizos_con_huecos(p).has(pulso))
	_ok("y no se ha aprendido", Game.hechizos_sabidos(p).is_empty())

	Game.equipar_secundaria(null, p)
	_ok("al soltarla, la ranura se vacia", not Game.hechizos_con_huecos(p).has(pulso))


# EL CASO FEO: leer el grimorio de un hechizo que YA te presta el arma. Tiene que aprenderse de
# verdad, porque es justo lo que hace que sobreviva a soltar el baston.
func _probar_grimorio(pulso: SpellData) -> void:
	print("\n-- Grimorio de lo que ya te presta el arma --")
	var p := PersonajeData.new()
	Game.equipar_arma(load(BASTON), p)
	_ok("prestado, pero no sabido", not Game.hechizos_sabidos(p).has(pulso))

	_ok("se puede aprender igualmente", Game.aprender_hechizo(pulso, p))
	_ok("ahora si esta aprendido", Game.hechizos_sabidos(p).has(pulso))
	_ok("y no se ha duplicado en el kit", _veces(Game.hechizos_con_huecos(p), pulso) == 1)

	Game.equipar_arma(null, p)
	_ok("y al soltar el baston AHORA se queda", Game.hechizos_con_huecos(p).has(pulso))


func _veces(a: Array, x) -> int:
	var n := 0
	for e in a:
		if e == x:
			n += 1
	return n
