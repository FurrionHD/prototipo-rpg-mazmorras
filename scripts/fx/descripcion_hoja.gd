# ============================================================
#  LA DESCRIPCION DE UNA HOJA HORNEADA, en binario (optimizacion 1E, 19/10/2026)
#  Lo mismo que el .json que escribe SpriteLienzo.hornear (nombre, bucle y velocidad de cada animacion y el
#  recorte de cada fotograma), pero en arrays empaquetados dentro de un .res: se lee en nada, cuando el json de
#  una capa del jugador (1.654 animaciones, 14.596 fotogramas) eran ~9 ms SOLO de leer, y una hoja diminuta como
#  la boca tardaba lo mismo que el cuerpo. Lo genera tools/hojas_a_res desde el json, y 'firma' es el hash de ese
#  json: tools/prueba_hojas_res comprueba que ninguno se ha quedado viejo.
#  Los nombres van ORDENADOS (describir los ordena), asi que se buscan con bsearch.
# ============================================================
class_name DescripcionHoja
extends Resource

@export var w: int = 0
@export var h: int = 0
@export var gris: bool = false
@export var firma: int = 0
@export var nombres: PackedStringArray = PackedStringArray()
@export var bucle: PackedByteArray = PackedByteArray()
@export var fps: PackedFloat32Array = PackedFloat32Array()
# Donde empieza cada animacion en 'marcos' (en FOTOGRAMAS, no en enteros) y cuantos tiene.
@export var inicio: PackedInt32Array = PackedInt32Array()
@export var cuantos: PackedInt32Array = PackedInt32Array()
# Seis enteros por fotograma: x, y, ancho y alto del recorte y los dos margenes (ver SpriteLienzo.describir).
@export var marcos: PackedInt32Array = PackedInt32Array()
# EL PUNTO DEL SUELO (16/11, SombraSuelo): donde cae el suelo respecto al CENTRO del lienzo, en pixeles de la hoja. Lo
# apunta el horno SDF en su hojas.json ('pies') y Sprites3D lo cuelga del SpriteFrames; tiene_pies = false si no hay.
@export var pies: Vector2 = Vector2.ZERO
@export var tiene_pies: bool = false


# El numero de la animacion 'nombre', o -1 si esta hoja no la tiene.
func indice(nombre: String) -> int:
	var i: int = nombres.bsearch(nombre)
	return i if i < nombres.size() and nombres[i] == nombre else -1


# Desde el diccionario del json ('d'); 'firma' = hash del texto del json.
static func desde_json(d: Dictionary, firma_json: int) -> DescripcionHoja:
	var r := DescripcionHoja.new()
	r.w = int(d.get("w", 0))
	r.h = int(d.get("h", 0))
	r.gris = bool(d.get("gris", false))
	r.firma = firma_json
	var p = d.get("pies", null)
	if p is Array and (p as Array).size() == 2:
		r.pies = Vector2(float(p[0]), float(p[1]))
		r.tiene_pies = true
	var anims: Array = d.get("anims", [])
	# Ordenadas por nombre: el json ya viene asi, pero bsearch no perdona.
	anims = anims.duplicate()
	anims.sort_custom(func(a, b): return String(a["n"]) < String(b["n"]))
	var total: int = 0
	for a in anims:
		r.nombres.append(String(a["n"]))
		r.bucle.append(1 if bool(a["loop"]) else 0)
		r.fps.append(float(a["fps"]))
		r.inicio.append(total)
		r.cuantos.append((a["f"] as Array).size())
		total += (a["f"] as Array).size()
	r.marcos.resize(total * 6)
	var k: int = 0
	for a in anims:
		for m in a["f"]:
			for j in 6:
				r.marcos[k] = int(m[j])
				k += 1
	return r
