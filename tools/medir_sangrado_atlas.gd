# HERRAMIENTA (headless). PIXELES QUE SE CUELAN EN LOS MARCOS (20/11, el jefe: "al acechador base se le cuelan pixeles de la
# imagen de abajo en algunas animaciones, puede que pase en muchos mas enemigos, no es la primera vez que te lo digo").
# Para cada atlas de assets/sprites/enemigos: dentro de cada marco, los pixeles que en el PNG son TRANSPARENTES y en la
# grafica (la textura importada, BC7) se ven (alfa >= UMBRAL). Saca los peores.
#   godot --headless --path . res://tools/medir_sangrado_atlas.tscn        (MEDIR_FILTRO=acechador para unos pocos)
extends Node

const UMBRAL := 24
const CARPETA := "res://assets/sprites/enemigos/"


func _ready() -> void:
	var filtro: String = OS.get_environment("MEDIR_FILTRO")
	var total_hojas := 0
	var con_fallo := 0
	var peores: Array = []
	for f in DirAccess.get_files_at(CARPETA):
		if not f.ends_with(".json") or (filtro != "" and not f.contains(filtro)):
			continue
		var png: String = CARPETA + f.trim_suffix(".json") + ".png"
		if not ResourceLoader.exists(png):
			continue
		var src := Image.load_from_file(ProjectSettings.globalize_path(png))
		var tex: Texture2D = load(png)
		if src == null or tex == null:
			continue
		var gpu: Image = tex.get_image()
		if gpu.is_compressed():
			gpu.decompress()
		gpu.convert(Image.FORMAT_RGBA8)
		src.convert(Image.FORMAT_RGBA8)
		var d = JSON.parse_string(FileAccess.get_file_as_string(CARPETA + f))
		total_hojas += 1
		var malos := 0
		var marcos_malos := 0
		var vistos := {}
		for a in d["anims"]:
			for m in a["f"]:
				var r := Rect2i(int(m[0]), int(m[1]), int(m[2]), int(m[3]))
				if r.size.x <= 0 or vistos.has(r):
					continue
				vistos[r] = true
				var n := 0
				for y in range(r.position.y, r.end.y):
					for x in range(r.position.x, r.end.x):
						if src.get_pixel(x, y).a8 == 0 and gpu.get_pixel(x, y).a8 >= UMBRAL:
							n += 1
				# Y EL AIRE DE ALREDEDOR (el pixel de fuera que la grafica puede leer al pintar el borde del marco): en el PNG
				# esta vacio; si en la grafica se ve, es el vecino colandose
				var fuera := r.grow(1).intersection(Rect2i(Vector2i.ZERO, src.get_size()))
				for y in range(fuera.position.y, fuera.end.y):
					for x in range(fuera.position.x, fuera.end.x):
						if r.has_point(Vector2i(x, y)):
							continue
						if gpu.get_pixel(x, y).a8 >= UMBRAL:
							n += 1
				if n > 0:
					marcos_malos += 1
					malos += n
		if malos > 0:
			con_fallo += 1
			peores.append([malos, marcos_malos, f.trim_suffix(".json"), String(tex.get_class()), gpu.get_size()])
	peores.sort_custom(func(p, q): return p[0] > q[0])
	print("=== %d hojas, %d con pixeles colados (alfa >= %d donde el PNG es transparente) ===" % [total_hojas, con_fallo, UMBRAL])
	for p in peores.slice(0, 40):
		print("  %6d px en %4d marcos  %s" % [p[0], p[1], p[2]])
	get_tree().quit(0)
