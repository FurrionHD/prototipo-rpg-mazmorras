# ============================================================
#  poligono.gd  (class_name Poligono)
#  LOS RELLENOS DE POLIGONO DE LOS EFECTOS Y DE LA PELEA, pasando por aqui (08/10/2026).
#
#  En el playtest del 07/10 salieron 473 "ERROR: Invalid polygon data, triangulation failed." en los logs, cientos
#  seguidos en cada pelea (en un trabajador, desde que un Slime de fuego usaba la Ignicion hasta que moria). Godot solo
#  falla asi con un poligono que se CRUZA consigo mismo o que se APLASTA sobre una linea y vuelve (el caso de las
#  vedijas de la niebla del 15/09, ver CapaEstado._vedija). Ese poligono no se pinta, y ademas escupe dos lineas al
#  log en CADA fotograma. No se pudo reproducir (ni las 55 pruebas de tools/ ni las huellas de las 150 habilidades).
#
#  Asi que: antes de dibujar se mira si se puede triangular (Geometry2D.triangulate_polygon, el MISMO que usa el
#  motor). Si no, NO se dibuja -- que es lo que pasaba igual, sin el error -- y se avisa UNA sola vez por sitio con
#  quien lo pinta, para cazarlo en el proximo log ("[poligono]"). Los menus y el inventario no pasan por aqui: alli no
#  salia y la rejilla del baul va justa de rendimiento.
# ============================================================
extends RefCounted
class_name Poligono

static var _avisados: Dictionary = {}


## Igual que ci.draw_colored_polygon(pts, col).
static func relleno(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	if _se_puede(ci, pts):
		ci.draw_colored_polygon(pts, col)


## Igual que ci.draw_polygon(pts, cols, uvs, tex) (color por vertice).
static func colores(ci: CanvasItem, pts: PackedVector2Array, cols: PackedColorArray,
		uvs: PackedVector2Array = PackedVector2Array(), tex: Texture2D = null) -> void:
	if _se_puede(ci, pts):
		ci.draw_polygon(pts, cols, uvs, tex)


static func _se_puede(ci: CanvasItem, pts: PackedVector2Array) -> bool:
	if pts.size() >= 3 and not Geometry2D.triangulate_polygon(pts).is_empty():
		return true
	if pts.size() < 3:
		return false   # nada que pintar, y Godot tampoco se queja de esto
	# QUIEN: la linea que llamo (solo en las versiones con depuracion: en el .exe final get_stack() viene vacio) y si
	# no, el script del CanvasItem donde se pinta.
	var donde: String = ""
	var pila: Array = get_stack()
	if pila.size() >= 3:
		donde = "%s:%d (%s)" % [String(pila[2]["source"]).get_file(), int(pila[2]["line"]), String(pila[2]["function"])]
	else:
		var s: Script = ci.get_script() as Script if ci != null else null
		donde = s.resource_path.get_file() if s != null else (ci.get_class() if ci != null else "?")
	if _avisados.has(donde):
		return false
	_avisados[donde] = true
	var caja := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		caja = caja.expand(p)
	print("[poligono] %s pinta un poligono que no se puede triangular (%d puntos, caja %s): no se dibuja (Godot tampoco lo dibujaria). Aviso una vez por sitio." % [
		donde, pts.size(), caja])
	return false
