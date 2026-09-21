# ============================================================
#  arena_foto.gd  (sin class_name: Game la usa por preload)
#  LA ARENA NO DEJA HUELLA. Al entrar se saca una FOTO de todo lo tuyo y al salir se vuelve a ella:
#  lo que comas, bebas o gastes alli, la excelia, los contadores, las pasivas, la vida, el desgaste del
#  equipo... nada sale de la arena. Lo pidio el usuario: "uso una comida pero al salir no puedo seguir
#  con el buff, porque solo la uso para las pruebas".
#
#  POR QUE UNA FOTO Y NO CORTAR CADA GANANCIA: la excelia entra por una docena de sitios (golpes,
#  esquivas, recitar, extraer, huir...) y los consumos por otros tantos. Tapar uno a uno es la receta
#  de que se escape el que no se tapo; la foto cubre tambien lo que se añada mañana a la ficha.
#
#  LA FICHA SE COPIA ENTERA, campo a campo (get_property_list), en vez de con una lista escrita a mano:
#  un campo nuevo de PersonajeData queda cubierto sin tocar esto. Se RESTAURA EN SITIO, sobre los mismos
#  objetos: los PersonajeData y las metas del equipo los referencian el grupo, la plantilla, el baul y
#  los encargos, y cambiarlos por copias los desataria (ver equip_meta / item_meta, que son ALIAS).
# ============================================================
extends RefCounted

# Lo que no puede cambiar en la arena y no se toca: quien es y como se ve.
const _NO_SE_TOCA := ["nombre", "color", "metalico", "imagen", "color_alpha", "aspecto", "uid",
	"dueno", "rol", "es_original", "equip_meta", "script", "resource_path", "resource_name",
	"resource_local_to_scene", "resource_scene_unique_id"]


static func sacar(g) -> Dictionary:
	var pjs: Dictionary = {}
	for pj in g.plantilla:
		pjs[pj] = _ficha(pj)
	# Las metas de TODO el equipo (durabilidad, cargas...). Son pocos cientos de diccionarios pequeños.
	var metas: Dictionary = {}
	for item in g.item_meta:
		var m = g.item_meta[item]
		if m is Dictionary:
			metas[item] = (m as Dictionary).duplicate(true)
	return {
		"pjs": pjs, "metas": metas,
		"plantilla": g.plantilla.duplicate(), "party": g.party.duplicate(), "lider_idx": g.lider_idx,
		"money": g.money, "crystals": g.crystals.duplicate(), "materiales": g.materiales.duplicate(),
		"carbon": g.carbon.duplicate(), "consumables": g.consumables.duplicate(),
		"cebo": g.cebo_activo, "llama": g.lampara_llama, "llama_total": g.lampara_llama_total,
		"registro_pesca": g.registro_pesca.duplicate(true),
	}


static func aplicar(g, foto: Dictionary) -> void:
	if foto.is_empty():
		return
	var pjs: Dictionary = foto.get("pjs", {})
	for pj in pjs:
		if is_instance_valid(pj):
			_devolver(pj, pjs[pj])
	var metas: Dictionary = foto.get("metas", {})
	for item in metas:
		var viva = g.item_meta.get(item)
		if viva is Dictionary:
			(viva as Dictionary).clear()
			(viva as Dictionary).merge((metas[item] as Dictionary).duplicate(true))
	g.plantilla.assign(foto["plantilla"])
	g.party.assign(foto["party"])
	g.lider_idx = int(foto["lider_idx"])
	g.money = int(foto["money"])
	g.crystals.assign(foto["crystals"])
	g.materiales.assign(foto["materiales"])
	g.carbon.assign(foto["carbon"])
	g.consumables = (foto["consumables"] as Dictionary).duplicate()
	g.cebo_activo = foto["cebo"]
	g.lampara_llama = float(foto["llama"])
	g.lampara_llama_total = float(foto["llama_total"])
	g.registro_pesca = (foto["registro_pesca"] as Dictionary).duplicate(true)
	for pj in g.plantilla:
		g.refrescar_cache_estados(pj)


static func _ficha(pj: Object) -> Dictionary:
	var d: Dictionary = {}
	for p in pj.get_property_list():
		if not (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var nombre: String = String(p["name"])
		if _NO_SE_TOCA.has(nombre):
			continue
		d[nombre] = _copia(pj.get(nombre))
	return d


static func _devolver(pj: Object, d: Dictionary) -> void:
	for nombre in d:
		pj.set(nombre, _copia(d[nombre]))   # copia otra vez: la foto puede aplicarse mas de una vez


# Diccionarios y arrays, a fondo (los objetos de dentro se quedan: son el MISMO equipo, no copias).
static func _copia(v):
	if v is Dictionary:
		return (v as Dictionary).duplicate(true)
	if v is Array:
		return (v as Array).duplicate(true)
	return v
