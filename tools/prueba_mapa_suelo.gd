# PRUEBA: el suelo del mapa (M) horneado en una imagen (optimizacion 1D, 16/10/2026; ver map_menu._textura_suelo).
#  1) La imagen tiene UN pixel de suelo por celda de la libreta, en su sitio, y nada mas.
#  2) Se recuerda: mismo piso y misma libreta = la misma textura.
#  3) Al cartografiar otra vez (Array nuevo, con mas celdas) se rehace.
extends Node

var fallos := 0

func _ok(c: bool, t: String) -> void:
	print(("[PASA] " if c else "[FALLA] ") + t)
	if not c:
		fallos += 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var men = load("res://scripts/ui/map_menu.gd").new()
	add_child.call_deferred(men)
	await get_tree().process_frame
	await get_tree().process_frame
	var suelo: Array = []
	for x in range(3, 40):
		for y in range(5, 9):
			suelo.append(Vector2i(x, y))
	suelo.append(Vector2i(0, 0))
	suelo.append(Vector2i(59, 44))
	var snap := {"ancho": 60, "alto": 45, "suelo": suelo, "vivos": [], "agotados": {}}
	var tex: Texture2D = men._textura_suelo(3, snap)
	var img: Image = tex.get_image()
	var llenos: int = 0
	var bien: bool = true
	for y in img.get_height():
		for x in img.get_width():
			var es: bool = img.get_pixel(x, y).a > 0.5
			if es:
				llenos += 1
			if es != suelo.has(Vector2i(x, y)):
				bien = false
	_ok(img.get_size() == Vector2i(60, 45), "un pixel por celda (60x45)")
	_ok(bien and llenos == suelo.size(), "suelo en su sitio: %d pixeles = %d celdas" % [llenos, suelo.size()])
	# A 8 bits por canal: el color se queda en el escalon de 1/255 mas cercano.
	var px: Color = img.get_pixel(3, 5)
	var c: Color = men.COLOR_SUELO
	_ok(absf(px.r - c.r) < 0.005 and absf(px.g - c.g) < 0.005 and absf(px.b - c.b) < 0.005 and px.a > 0.99,
		"con el color del suelo")
	_ok(men._textura_suelo(3, snap) == tex, "la misma libreta: la misma textura (recordada)")
	var nuevo: Array = suelo.duplicate()
	nuevo.append(Vector2i(50, 30))
	var snap2 := {"ancho": 60, "alto": 45, "suelo": nuevo, "vivos": [], "agotados": {}}
	var tex2: Texture2D = men._textura_suelo(3, snap2)
	_ok(tex2 != tex and tex2.get_image().get_pixel(50, 30).a > 0.5, "libreta nueva: textura rehecha con la celda nueva")
	print("[mapa] RESULTADO: ", "FIN: TODO BIEN" if fallos == 0 else "FALLAN %d" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)
