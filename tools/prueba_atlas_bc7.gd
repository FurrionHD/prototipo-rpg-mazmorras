# ============================================================
#  PRUEBA: LOS ATLAS DE ENEMIGOS EN BC7 (02/11/2026, el Espantajo eran 65 MB de grafica)
#  1) Cada hoja de assets/sprites/enemigos se importa como dice tools/compactar_hojas.py: comprimida en la grafica
#     (compress/mode=2 + high_quality) salvo las SIN_PERDIDA (minotauro3d*, rata3d*: sus shaders buscan el color exacto
#     del ojo). Si falla: pasar el compactador (lo escribe el) y --import.
#  2) Todos los fotogramas van recortados JUSTO al dibujo: es lo que da por hecho SpriteLienzo.caja_pintada para no
#     leer pixeles de un atlas comprimido. Se mira en el PNG de disco (sin perdida).
#  3) Por el camino del juego, una hoja BC7 (la del Espantajo): llega comprimida a la grafica, lleva la marca de
#     recortada y caja_pintada da el recorte entero de cada fotograma sin tocar sus pixeles.
#    godot --headless --path . res://tools/prueba_atlas_bc7.tscn
# ============================================================
extends Node

const CARPETA := "res://assets/sprites/enemigos/"
const SIN_PERDIDA := ["minotauro3d", "rata3d"]

var _mal: int = 0


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _ready() -> void:
	var pngs: Array = []
	for f in DirAccess.get_files_at(CARPETA):
		if f.ends_with(".png") and FileAccess.file_exists(CARPETA + f.get_basename() + ".json"):
			pngs.append(f)
	_ver(pngs.size() > 150, "hay hojas de enemigos (%d)" % pngs.size())

	# 1) LA IMPORTACION
	var mal_import: Array = []
	for f in pngs:
		var cfg := ConfigFile.new()
		if cfg.load(CARPETA + f + ".import") != OK:
			mal_import.append(f + " (sin .import)")
			continue
		var sin_perdida: bool = SIN_PERDIDA.any(func(p: String) -> bool: return String(f).begins_with(p))
		var modo: int = int(cfg.get_value("params", "compress/mode", -1))
		var hq: bool = bool(cfg.get_value("params", "compress/high_quality", false))
		if sin_perdida and modo != 0:
			mal_import.append(f + " (deberia ir sin perdida)")
		elif not sin_perdida and (modo != 2 or not hq):
			mal_import.append(f + " (modo %d, high_quality %s)" % [modo, hq])
	_ver(mal_import.is_empty(), "todas importadas como toca (mal: %s)" % [str(mal_import.slice(0, 6))])

	# 2) RECORTADOS JUSTO
	var flojos: Array = []
	var n_fot: int = 0
	for f in pngs:
		var img := Image.load_from_file(ProjectSettings.globalize_path(CARPETA + f))
		var d = JSON.parse_string(FileAccess.get_file_as_string(CARPETA + f.get_basename() + ".json"))
		if img == null or typeof(d) != TYPE_DICTIONARY:
			flojos.append(f + " (no se lee)")
			continue
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		var vistos: Dictionary = {}
		for a in d["anims"]:
			for m in a["f"]:
				var r := Rect2i(int(m[0]), int(m[1]), int(m[2]), int(m[3]))
				if r.size.x <= 0 or r.size.y <= 0 or vistos.has(r):
					continue
				vistos[r] = true
				n_fot += 1
				if img.get_region(r).get_used_rect().size != r.size:
					flojos.append("%s %s %s" % [f, a["n"], r])
					break
	_ver(n_fot > 10000 and flojos.is_empty(), "%d recortes, todos justos al dibujo (flojos: %s)" % [n_fot,
		str(flojos.slice(0, 4))])

	# 3) EL CAMINO DEL JUEGO sobre una hoja BC7
	var clave := "trent3d_trent_sdf_espantajo"
	var sf: SpriteFrames = SpriteLienzo.cargar_horneado(clave)
	_ver(sf != null, "la hoja del Espantajo se monta")
	if sf != null:
		var at := sf.get_frame_texture(sf.get_animation_names()[0], 0) as AtlasTexture
		var hoja_img: Image = at.atlas.get_image() if at != null else null
		_ver(hoja_img != null and hoja_img.is_compressed(), "llega comprimida a la grafica (formato %s)" % [
			hoja_img.get_format() if hoja_img != null else "-"])
		_ver(at != null and at.atlas.has_meta(SpriteLienzo.META_RECORTADA), "lleva la marca de recortada")
		var malas: int = 0
		var total: int = 0
		for anim in sf.get_animation_names():
			for i in sf.get_frame_count(anim):
				var t := sf.get_frame_texture(anim, i) as AtlasTexture
				if t == null or t.region.size.x <= 0:
					continue
				total += 1
				var c: Dictionary = SpriteLienzo.caja_pintada(t)
				if c["caja"] != Rect2i(Vector2i.ZERO, Vector2i(t.region.size)) or c["tam"] != Vector2i(t.region.size):
					malas += 1
		_ver(total > 100 and malas == 0, "caja_pintada = el recorte en sus %d fotogramas (mal: %d)" % [total, malas])
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(0 if _mal == 0 else 1)
