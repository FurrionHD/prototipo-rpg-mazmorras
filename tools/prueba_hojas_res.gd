# ============================================================
#  PRUEBA: LAS HOJAS HORNEADAS EN .res Y LAS HOJAS PEREZOSAS (optimizacion 1E, 19/10/2026)
#  1) Cada .json de hoja tiene su .res (DescripcionHoja) AL DIA: misma firma que el json. Si falla, pasar
#     tools/hojas_a_res (lo deja viejo tools/compactar_hojas.py, que reescribe los json).
#  2) Una hoja montada desde el .res -- entera, y perezosa animacion a animacion -- es IDENTICA a como se montaba
#     antes desde el json (el bucle de antes va copiado aqui abajo como referencia): mismas animaciones, bucle,
#     velocidad y, fotograma a fotograma, el mismo recorte y margen.
#  3) La perezosa nace vacia, monta solo lo que se pide, dice que no a lo que no tiene y completar() la llena.
#    godot --headless --path . res://tools/prueba_hojas_res.tscn
# ============================================================
extends Node

const HojasARes := preload("res://tools/hojas_a_res.gd")

var _mal: int = 0


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _ready() -> void:
	# 1) AL DIA
	var hojas: Array = HojasARes.hojas(HojasARes.RAIZ)
	var viejas: Array = []
	for js in hojas:
		var res: String = js.get_basename() + ".res"
		var d: DescripcionHoja = ResourceLoader.load(res, "", ResourceLoader.CACHE_MODE_IGNORE) as DescripcionHoja \
			if ResourceLoader.exists(res) else null
		if d == null or d.firma != FileAccess.get_file_as_string(js).hash():
			viejas.append(js.get_file())
	_ver(hojas.size() > 100, "hay hojas horneadas (%d)" % hojas.size())
	_ver(viejas.is_empty(), "todas con su .res al dia (viejas o sin .res: %s)" % [str(viejas.slice(0, 8))])

	# 2) IGUALES QUE ANTES, en unas cuantas: el cuerpo, una diminuta, una de equipo, una gris y una de enemigo.
	var muestra: Array = [
		[CapaJugador.CARPETA, "cuerpo_1.00"], [CapaJugador.CARPETA, "boca_recta_1.00"],
		[CapaJugador.CARPETA, "armadura_placas_casco_1.00"], [CapaJugador.CARPETA, "arma_mandoble_mano_der_1.00"],
	]
	for js in hojas:
		if String(js).begins_with(SpriteLienzo.CARPETA_HORNO):
			muestra.append([SpriteLienzo.CARPETA_HORNO, String(js).get_file().get_basename()])
			break
	for m in muestra:
		var carpeta: String = m[0]
		var clave: String = m[1]
		var antes: SpriteFrames = _como_antes(carpeta, clave)
		if antes == null:
			_ver(false, "%s: no se pudo montar como antes" % clave)
			continue
		var entera: SpriteFrames = SpriteLienzo.cargar_horneado(clave, carpeta)
		_ver(_iguales(antes, entera, clave + " entera"), "%s entera: igual que desde el json (%d animaciones)" % [
			clave, antes.get_animation_names().size()])
		var pere: SpriteFrames = SpriteLienzo.cargar_horneado(clave, carpeta, true)
		for a in antes.get_animation_names():
			SpriteLienzo.asegurar_anim(pere, a)
		_ver(_iguales(antes, pere, clave + " perezosa"), "%s perezosa, pedida animacion a animacion: igual" % clave)

	# 3) LA PEREZOSA
	var sf: SpriteFrames = SpriteLienzo.cargar_horneado("cuerpo_1.00", CapaJugador.CARPETA, true)
	_ver(sf != null and sf.get_animation_names().is_empty(), "la perezosa nace sin animaciones")
	_ver(SpriteLienzo.asegurar_anim(sf, &"idle_0") and sf.get_animation_names().size() == 1
		and sf.get_frame_count(&"idle_0") > 0, "pedir idle_0 monta esa y solo esa")
	_ver(SpriteLienzo.asegurar_anim(sf, &"idle_0") and sf.get_animation_names().size() == 1, "pedirla otra vez no monta nada")
	_ver(not SpriteLienzo.asegurar_anim(sf, &"no_existe_0"), "lo que la hoja no tiene: false")
	SpriteLienzo.completar(sf)
	var entera2: SpriteFrames = SpriteLienzo.cargar_horneado("cuerpo_1.00", CapaJugador.CARPETA)
	_ver(sf.get_animation_names().size() == entera2.get_animation_names().size() and not sf.has_meta(SpriteLienzo.META_PEREZOSA),
		"completar() la llena entera (%d) y deja de ser perezosa" % sf.get_animation_names().size())
	# Lo que se gana (solo informa: no es una comprobacion, el PC baila).
	var t0: int = Time.get_ticks_usec()
	SpriteLienzo.cargar_horneado("boca_recta_1.00", CapaJugador.CARPETA, true)
	var t1: int = Time.get_ticks_usec()
	_como_antes(CapaJugador.CARPETA, "boca_recta_1.00")
	var t2: int = Time.get_ticks_usec()
	print("  (la boca: perezosa desde .res %.2f ms, como antes desde el json %.2f ms)" % [(t1 - t0) / 1000.0, (t2 - t1) / 1000.0])

	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(0 if _mal == 0 else 1)


func _iguales(a: SpriteFrames, b: SpriteFrames, que: String) -> bool:
	if b == null:
		print("    %s: no hay hoja" % que)
		return false
	var na: PackedStringArray = a.get_animation_names()
	var nb: PackedStringArray = b.get_animation_names()
	na.sort()
	nb.sort()
	if na != nb:
		print("    %s: animaciones distintas (%d / %d)" % [que, na.size(), nb.size()])
		return false
	for n in na:
		if a.get_animation_loop(n) != b.get_animation_loop(n) or not is_equal_approx(a.get_animation_speed(n), b.get_animation_speed(n)) \
				or a.get_frame_count(n) != b.get_frame_count(n):
			print("    %s: %s cambia de bucle, velocidad o numero de fotogramas" % [que, n])
			return false
		for i in a.get_frame_count(n):
			var ta: Texture2D = a.get_frame_texture(n, i)
			var tb: Texture2D = b.get_frame_texture(n, i)
			if (ta is AtlasTexture) != (tb is AtlasTexture):
				print("    %s: %s fotograma %d: uno vacio y el otro no" % [que, n, i])
				return false
			if ta is AtlasTexture and ((ta as AtlasTexture).region != (tb as AtlasTexture).region
					or (ta as AtlasTexture).margin != (tb as AtlasTexture).margin):
				print("    %s: %s fotograma %d: recorte distinto" % [que, n, i])
				return false
	return true


# EL MONTAJE DE ANTES (SpriteLienzo.cargar_horneado hasta el 19/10/2026), copiado tal cual: la referencia.
func _como_antes(carpeta: String, clave: String) -> SpriteFrames:
	var png: String = carpeta + clave + ".png"
	var js: String = carpeta + clave + ".json"
	if not FileAccess.file_exists(js):
		return null
	var d = JSON.parse_string(FileAccess.get_file_as_string(js))
	if typeof(d) != TYPE_DICTIONARY:
		return null
	var hoja: Texture2D = SpriteLienzo._hoja_gris(png) if bool(d.get("gris", false)) else \
		(load(png) as Texture2D if ResourceLoader.exists(png) else null)
	if hoja == null:
		return null
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var recortes: Dictionary = {}
	for a in d["anims"]:
		sf.add_animation(a["n"])
		sf.set_animation_loop(a["n"], bool(a["loop"]))
		sf.set_animation_speed(a["n"], float(a["fps"]))
		for m in a["f"]:
			if int(m[2]) <= 0 or int(m[3]) <= 0:
				sf.add_frame(a["n"], SpriteLienzo.vacia())
				continue
			var k := Vector4i(int(m[0]), int(m[1]), int(m[2]) * 4096 + int(m[3]), int(m[4]) * 4096 + int(m[5]))
			var at: AtlasTexture = recortes.get(k)
			if at == null:
				at = AtlasTexture.new()
				at.atlas = hoja
				at.region = Rect2(m[0], m[1], m[2], m[3])
				at.margin = Rect2(m[4], m[5], int(d["w"]) - int(m[2]), int(d["h"]) - int(m[3]))
				at.filter_clip = true
				recortes[k] = at
			sf.add_frame(a["n"], at)
	return sf
