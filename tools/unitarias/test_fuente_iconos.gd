extends "res://tools/unitarias/caso.gd"
# Cubre: res://scripts/ui/fuente_iconos.gd, res://scripts/ui/fuente_iconos_tabla.gd
# TODO EN PIXEL (05/11, el jefe: "todo tiene que ir con pixel art"). La fuente de iconos va delante de la letra del juego
# y sin las fuentes del sistema: cada emoji o signo que escribe el codigo tiene que tener SU dibujo o estar en la letra;
# si no, saldria como un hueco (y antes, como el emoji de Windows).


func test_la_fuente_de_iconos_es_la_de_todos_los_textos() -> void:
	cierto(FuenteIconos.fuente != null, "la fuente de iconos esta montada")
	igual(ThemeDB.get_default_theme().default_font, FuenteIconos.fuente, "es la letra por defecto de los controles")
	cierto(not FuenteIconos.fuente.allow_system_fallback, "sin las fuentes del sistema (los emojis de colores)")


func test_cada_emoji_de_la_tabla_tiene_su_dibujo() -> void:
	var tam := Vector2i(FuenteIconos.TAM, 0)
	var faltan: Array = []
	for e in FuenteIconos.TABLA_SCRIPT.TABLA:
		if FuenteIconos.fuente.get_glyph_texture_idx(0, tam, String(e).unicode_at(0)) < 0:
			faltan.append(FuenteIconos.TABLA_SCRIPT.TABLA[e])
	igual(faltan, [], "emojis de la tabla sin dibujo (tools/iconos_estados_pixel.py --hornear)")


func test_ningun_caracter_del_codigo_se_queda_sin_dibujar() -> void:
	var f: FontFile = FuenteIconos.fuente
	var base: Font = f.fallbacks[0]
	var vistos: Dictionary = {}
	var faltan: Array = []
	var pila: Array = ["res://scripts"]
	while not pila.is_empty():
		var d: String = pila.pop_back()
		for sub in DirAccess.get_directories_at(d):
			pila.append(d + "/" + sub)
		for a in DirAccess.get_files_at(d):
			if not a.ends_with(".gd"):
				continue
			for linea in FileAccess.get_file_as_string(d + "/" + a).split("\n"):
				var codigo: String = linea.split("#")[0]
				for i in codigo.length():
					var cp: int = codigo.unicode_at(i)
					if cp < 128 or vistos.has(cp):
						continue
					vistos[cp] = true
					if not f.has_char(cp) and not base.has_char(cp):
						faltan.append("%s U+%X (%s)" % [String.chr(cp), cp, a])
	igual(faltan, [], "caracteres que escribe el codigo y que ninguna fuente pinta")
