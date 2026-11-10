# ============================================================
#  PRUEBA: LAS ANCLAS DE LAS SETAS AL DIA (10/11/2026, miconido-mutante)
#  Las setas de los florecidos se clavan en la silueta de cada fotograma con las anclas que mide tools/anclas_hongos.py
#  (AnclasHongos). Si se rehornea o compacta una hoja, sus recortes cambian y las anclas se quedan viejas: las setas
#  volverian a flotar. Aqui: cada hoja de enemigo y el cuerpo del personaje estan en el indice, y CADA recorte de su
#  .res (lo que el juego monta de verdad) tiene sus anclas, con al menos una de arriba. Si falla: python tools/anclas_hongos.py
#    godot --headless --path . res://tools/prueba_anclas_hongos.tscn
# ============================================================
extends Node

const HojasARes := preload("res://tools/hojas_a_res.gd")

var _mal: int = 0


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _ready() -> void:
	var hojas: Array = []
	for js in HojasARes.hojas(SpriteLienzo.CARPETA_HORNO):
		if String(js).contains("_parpado"):   # la capa del ojo, no un cuerpo
			continue
		hojas.append(String(js).get_basename())
	hojas.append(CapaJugador.CARPETA + "cuerpo_1.00")
	var sin: Array = []
	var viejas: Array = []
	var recortes: int = 0
	for ruta in hojas:
		var tabla: AnclasHongos = AnclasHongos.de(ruta)
		if tabla == null:
			sin.append(String(ruta).get_file())
			continue
		var d: DescripcionHoja = SpriteLienzo.descripcion(String(ruta).get_file(), String(ruta).get_base_dir() + "/")
		if d == null:
			continue
		for k in range(0, d.marcos.size(), 6):
			if d.marcos[k + 2] <= 0 or d.marcos[k + 3] <= 0:
				continue
			recortes += 1
			var reg := Vector2i(d.marcos[k], d.marcos[k + 1])
			var alguna: bool = false
			for r in 6:
				if tabla.ancla(reg, r).x >= 0:
					alguna = true
					break
			if not alguna:
				viejas.append("%s %s" % [String(ruta).get_file(), str(reg)])
				break
	_ver(hojas.size() > 100, "hay hojas que medir (%d)" % hojas.size())
	_ver(sin.is_empty(), "todas en el indice de anclas (sin: %s)" % str(sin.slice(0, 8)))
	_ver(viejas.is_empty() and recortes > 10000, "cada recorte de cada hoja con sus anclas (%d recortes; viejas: %s)" % [
		recortes, str(viejas.slice(0, 8))])
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(1 if _mal > 0 else 0)
