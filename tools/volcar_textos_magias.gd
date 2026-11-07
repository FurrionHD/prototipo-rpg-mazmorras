extends Node
# Vuelca a la consola lo que lee el jugador de cada hechizo (pase de textos 06/11): la linea compacta (resumen), la
# ficha mecanica (descripcion_mecanica) y la descripcion de sabor. Sin ventana:
#   godot --headless --path . res://tools/volcar_textos_magias.tscn
# REF = el daño al 100 % de un lector de ejemplo y CURA = su parte de la cura (solo cambian los numeros entre parentesis).

const REF := 40.0
const CURA := 12.0


func _ready() -> void:
	await get_tree().process_frame   # los autoloads (el catalogo de estados) tienen que estar listos
	var dir := DirAccess.open("res://resources/spells")
	var nombres: Array = []
	for f in dir.get_files():
		if f.ends_with(".tres"):
			nombres.append(f)
	nombres.sort()
	for f in nombres:
		var s = load("res://resources/spells/" + f)
		if s == null or not (s is SpellData):
			continue
		var sp: SpellData = s
		print("=== %s  [%s]" % [sp.nombre, f])
		print("  Resumen: " + sp.resumen())
		print("  " + sp.descripcion_mecanica(REF * sp.dano_mostrado() / maxf(1.0, sp.dano_mostrado()), CURA).replace("\n", "\n  "))
		if sp.descripcion != "":
			print("  Sabor: " + sp.descripcion.replace("\n", " "))
	get_tree().quit()
