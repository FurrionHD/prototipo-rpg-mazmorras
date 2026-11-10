# ============================================================
#  anclas_hongos.gd  (class_name AnclasHongos)
#  DONDE BROTAN LAS SETAS DE UN FLORECIDO EN CADA FOTOGRAMA (10/11/2026, miconido-mutante). Lo mide offline
#  tools/anclas_hongos.py sobre la silueta de cada recorte de cada hoja horneada (ver alli las 10 ranuras: 6 arriba,
#  2 lados, 2 frente). Aqui solo se leen: AnclasHongos.de(hoja) -> la tabla de esa hoja (o null si no esta medida).
# ============================================================
class_name AnclasHongos
extends Resource

const INDICE := "res://assets/sprites/hongos/indice.tres"
const RANURAS := 10
const NADA := -1

@export var regiones: PackedInt32Array = PackedInt32Array()   # x*65536 + y del recorte, ordenadas
@export var puntos: PackedInt32Array = PackedInt32Array()     # RANURAS por recorte, x*65536 + y o NADA

static var _indice: Dictionary = {}
static var _cargadas: Dictionary = {}   # fichero -> AnclasHongos


# La tabla de la hoja 'ruta' (sin .png: la meta HOJA_RUTA que le pone SpriteLienzo.cargar_horneado).
static func de(ruta: String) -> AnclasHongos:
	if _indice.is_empty() and ResourceLoader.exists(INDICE):
		var r: Resource = load(INDICE)
		if r != null and r.has_meta(&"hojas"):
			_indice = r.get_meta(&"hojas")
	var f: String = String(_indice.get(ruta, ""))
	if f == "":
		return null
	if not _cargadas.has(f):
		_cargadas[f] = load(f) as AnclasHongos if ResourceLoader.exists(f) else null
	return _cargadas[f]


# La ranura 'k' del recorte que empieza en 'region' (pixel de la hoja relativo al recorte), o Vector2i(-1, -1).
func ancla(region: Vector2i, k: int) -> Vector2i:
	var i: int = regiones.bsearch(region.x * 65536 + region.y)
	if i >= regiones.size() or regiones[i] != region.x * 65536 + region.y:
		return Vector2i(-1, -1)
	var p: int = puntos[i * RANURAS + k]
	if p == NADA:
		return Vector2i(-1, -1)
	return Vector2i(p >> 16, p & 0xffff)
