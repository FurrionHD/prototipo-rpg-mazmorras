# ============================================================
#  escudo_sprites.gd  (class_name EscudoSprites)
#  LA CAPA DEL ESCUDO: calco de ArmaSprites, recortado a lo que un escudo necesita de verdad.
#
#  Por que es un archivo aparte y no una rama mas de ArmaSprites: un escudo NUNCA va en la mano
#  principal ni al costado (cadera) -- solo tiene DOS sitios, "espalda" (envainado) y "mano"
#  (el antebrazo izquierdo, siempre). Meterlo en ArmaSprites hubiera significado que la mitad de
#  sus ramas (mano_der, cadera_*, DOS_MANOS...) tuvieran que aprender a decir "esto no aplica aqui".
#
#  QUE DIBUJA CADA CAPA SEGUN LA ANIMACION -- mismo criterio que el arma: la envainada (espalda)
#  sale en idle/walk/correr/sigilo/encaje/muerte/cadaver y en 'desenvainar' (viajando a la mano);
#  la de mano sale en guardia*/golpe. NO en golpe_izq (esa es del arma mala del dual, y dual+escudo
#  son excluyentes por construccion: los dos comparten el mismo campo PersonajeData.equipped_off) ni
#  en golpe_2m (un arma a dos manos tambien exige equipped_off = null -- nunca hay escudo con ella).
#
#  DONDE SE AGARRA: PoseJugador.agarre_escudo, igual que el arma cuelga de PoseJugador.agarre_arma.
#  Envainado comparte el punto P_ESPALDA con las armas a dos manos -- nunca chocan, por el mismo
#  motivo de arriba (equipped_off es null si el arma principal ocupa las dos manos).
#
#  NO SE TIÑE: el ShieldData no trae color propio (a diferencia del personaje), asi que va con
#  colores de verdad (madera/cuero + metal) como el arma, "tinte": false en el registro.
# ============================================================

extends RefCounted
class_name EscudoSprites

enum Tono {
	VACIO = 0, SOMBRA_SUELO = 1, BORDE = 2,
	MADERA_S,   # el cuerpo, en penumbra
	MADERA,     # el cuerpo (madera/cuero)
	MADERA_L,   # el cuerpo, realce de luz
	METAL,      # el aro que lo bordea
	METAL_L,    # el remache central
}

# Nombre de cada ShieldData.Tamano, para las claves de capa. El indice es el valor del enum.
const TAMANO_NOMBRE := ["pequeno", "normal", "grande"]

# LAS TRES SILUETAS (rehechas el 24/09, lo pidio el: "el pequeño y el grande son basicamente del mismo
# tamaño y forma"). Antes eran una cadena de circulos (una salchicha) y solo cambiaba el largo. Ahora
# cada una es una LAMINA PLANA con su silueta, en unidades de mundo (PoseJugador.ALTO_MUNDO = 60),
# medida en el plano del escudo: 'u' hacia arriba (su eje) y 'v' de lado; el agarre en (0, 0).
#   pequeno  LA RODELA de parry: un disco pequeño, casi todo aro y un umbo gordo en el centro.
#   normal   EL DE CABALLERO (el tipico "escudo de plata"): arriba recto, los lados bajan y se cierran
#            en punta; aro y una franja de metal por el medio.
#   grande   LA PUERTA (el de los caballeros de Lothric): alto del hombro a la rodilla, casi recto, la
#            parte de arriba en arco; aro gordo, dos bandas y una arista por el medio.
# OJO CON LA ESCALA: una unidad sale a ~0,83 px (la primera version, a ojo, salio la MITAD de lo que se
# queria: la rodela 7x5 px, tapada entera por el puño). El paso del relleno, del orden de un pixel.
const GEO := {
	"pequeno": {"arriba": 7.0, "abajo": 7.0, "ancho": 7.0, "aro": 1.6, "umbo": 2.6, "paso": 0.9},
	"normal":  {"arriba": 11.0, "abajo": 15.0, "ancho": 10.0, "aro": 1.6, "franja": 1.6, "paso": 1.0},
	"grande":  {"arriba": 21.0, "abajo": 19.0, "ancho": 12.0, "aro": 1.9, "bandas": [10.0, -12.0],
		"franja": 1.6, "paso": 1.1},
}
# Cuanto va la lamina por DELANTE del antebrazo (el brazo la lleva por detras, por las correas).
const SEPARA_DEL_BRAZO := 1.2
# De P_ESPALDA (corrido a la derecha y alto, para la empuñadura de un arma cruzada) al MEDIO de la espalda.
const CENTRO_ESPALDA := Vector3(4.0, -1.5, -4.0)

# En que animaciones dibuja cada capa (nombre BASE, sin direccion). Mismo criterio que ArmaSprites,
# sin golpe_izq/golpe_2m: ver la cabecera.
const _ANIM_ENVAINADA := ["idle", "walk", "correr", "sigilo", "encaje", "muerte", "cadaver", "desenvainar",
	"desenvainar_daga", "desenvainar_estoque", "desenvainar_estoque_esc", "desenvainar_espada_esc"]
# En mano: las de siempre y las de las armas de una mano con guardia propia (daga, estoque; 24/09: con
# ellas el escudo NO salia). El estoque con escudo va por sus variantes '_esc' (el escudo delante).
const _ANIM_MANO := ["guardia", "guardia_and", "guardia_cor", "golpe",
	"guardia_daga", "guardia_daga_and", "guardia_daga_cor", "tajo_daga", "tajo_daga_solo", "punalada_daga",
	"lanzar_humo", "afilar_veneno",
	"guardia_estoque_esc", "guardia_estoque_and_esc", "guardia_estoque_cor_esc", "guardia_estoque_def_esc",
	"estocada_estoque_esc", "estocada_honda_esc", "finta_estoque_esc", "pinchazo_estoque_esc",
	"ponerse_en_guardia_esc", "defensa_escudo",
	"guardia_espada_esc", "guardia_espada_and_esc", "guardia_espada_cor_esc", "tajo_espada_esc", "reves_espada_esc", "barrido_espada_esc", "tajo_bajo_espada_esc", "tajo_paso_espada_esc",
	# La espada larga con escudo (25/09): el escudo en la mano TAMBIEN al desenvainar (acaba en su guardia).
	"guardia_larga_esc", "guardia_larga_and_esc", "guardia_larga_cor_esc", "tajo_larga_esc", "rota_larga_esc", "pesado_larga_esc", "desarme_larga_esc", "estocada_larga_esc", "voto_larga_esc", "voz_larga_esc", "desenvainar_larga_esc",
	"golpe_escudo", "embestida_escudo", "provoca_escudo", "amparo_escudo", "rodela_escudo", "carne_escudo", "escolta_escudo"]


# --- Contrato de capa (ver CapaJugador y el registro de JugadorSprites) ---
static func frames(clave: String, esc: float = 1.0) -> SpriteFrames:
	return CapaJugador.frames(clave, pintar.bind(clave), colores(), esc)


static func generar(clave: String, esc: float = 1.0) -> SpriteFrames:
	return CapaJugador.generar(clave, pintar.bind(clave), colores(), esc)


static func colores() -> Array:
	return CapaJugador.rampa_indices(ROLES.size())


# QUE PAPEL HACE CADA TONO. Un escudo es lo mas claro de todo esto: el cuerpo es MADERA y el aro que
# lo bordea es METAL, y cada uno sigue su propia escala de tier y mejora. Un escudo de tier 2 muy
# mejorado sale de madera petrificada con el aro de hierro negro.
#
# El indice de este array ES el numero de tono, asi que su orden sigue al del enum Tono.
const ROLES := [
	PaletaEquipo.Rol.BORDE,        # 0 VACIO
	PaletaEquipo.Rol.SOMBRA,       # 1 SOMBRA_SUELO
	PaletaEquipo.Rol.BORDE,        # 2 BORDE
	PaletaEquipo.Rol.MADERA_S,     # 3 MADERA_S
	PaletaEquipo.Rol.MADERA,       # 4 MADERA
	PaletaEquipo.Rol.MADERA_L,     # 5 MADERA_L
	PaletaEquipo.Rol.MATERIAL,     # 6 METAL
	PaletaEquipo.Rol.MATERIAL_L,   # 7 METAL_L
]

const CLAVE_ROLES := "escudo"


# ============================================================
#  QUE CLAVES EXISTEN
# ============================================================
static func claves_de(tn: String) -> Array:
	return ["escudo_%s_mano_izq" % tn, "escudo_%s_espalda" % tn]


static func todas_las_claves() -> Array:
	var out: Array = []
	for tn in TAMANO_NOMBRE:
		out.append_array(claves_de(tn))
	return out


# ============================================================
#  EL PARSEO DE LA CLAVE
# ============================================================
static func _parse(clave: String) -> Dictionary:
	var s: String = clave.trim_prefix("escudo_")
	if s.ends_with("_mano_izq"):
		return {"tamano": s.trim_suffix("_mano_izq"), "estado": "mano"}
	return {"tamano": s.trim_suffix("_espalda"), "estado": "espalda"}


static func _dibuja_en(anim: String, estado: String) -> bool:
	if estado == "mano":
		return _ANIM_MANO.has(anim)
	return _ANIM_ENVAINADA.has(anim) or PoseJugador.FAENAS.has(anim)


# Direcciones en las que se ve el escudo ENVAINADO (en la espalda). En el resto el cuerpo lo tapa
# entero -- mismo criterio y mismos 3 huecos que ArmaSprites._DIRS_ESPALDA (dir: 0=S 1=SE 2=E 3=NE
# 4=N 5=NW 6=W 7=SW).
const _DIRS_ESPALDA := [3, 4, 5]


# ============================================================
#  EL PINTOR
# ============================================================
static func pintar(esq: Dictionary, piezas: Array, clave: String) -> void:
	var info: Dictionary = _parse(clave)
	var tamano: String = info["tamano"]
	var estado: String = info["estado"]
	var g: Dictionary = GEO.get(tamano, {})
	if g.is_empty():
		return
	var anim: String = String(esq.get("anim", ""))
	if not _dibuja_en(anim, estado):
		return

	# 'sacando' (0..1): durante el gesto de desenvainar la capa envainada viaja de la espalda a la
	# mano. -1 = no se esta desenvainando. Mismo mecanismo que ArmaSprites.pintar.
	var sac: float = float((esq.get("pose", {}) as Dictionary).get("sacando", -1.0))

	# ENVAINADO SE DIBUJA EN TODAS LAS DIRECCIONES (25/09): de frente va DETRAS del cuerpo (su capa lleva
	# z_atras, ver JugadorSprites._escudo_de) y lo que sea mas ancho que el asoma por los lados. Antes solo
	# salia de espaldas y un escudo puerta no se veia de frente por ningun lado.

	var ag: Dictionary = PoseJugador.agarre_escudo(esq, estado)
	var grip: Vector3 = ag["empunadura"]
	var eje: Vector3 = ag["eje"]
	# A LA ESPALDA va DERECHO (colgado de las correas), no cruzado como la hoja de un mandoble, y CENTRADO
	# (P_ESPALDA esta corrido a un lado, donde asoma la empuñadura de un arma cruzada).
	if estado != "mano":
		eje = Vector3(0.0, -0.1, 1.0).normalized()
		grip += CENTRO_ESPALDA

	if sac >= 0.0 and estado != "mano":
		var agm: Dictionary = PoseJugador.agarre_escudo(esq, "mano")
		grip = grip.lerp(agm["empunadura"], sac)
		eje = eje.lerp(agm["eje"], sac)
		if eje.length() > 0.01:
			eje = eje.normalized()

	# La lamina se separa del brazo hacia DELANTE en la mano, y de la espalda hacia ATRAS envainada.
	var atras: float = 1.0 - clampf(sac, 0.0, 1.0) if estado != "mano" else 0.0
	_dibujar(piezas, esq, grip, eje, g, tamano, 1.0 - 2.0 * atras)


# LA LAMINA: se rellena su silueta con piezas pequeñas colocadas EN SU PLANO (eje hacia arriba y el
# lateral del cuerpo de lado), asi que se escorza sola al girar: de frente se ve entera y de perfil se
# queda en el canto, como un escudo de verdad. El pixel sale de la proyeccion de siempre (poner).
static func _dibujar(piezas: Array, esq: Dictionary, grip: Vector3, eje: Vector3,
		g: Dictionary, tamano: String, hacia: float = 1.0) -> void:
	var arriba_v: Vector3 = eje.normalized()
	var lado: Vector3 = Vector3.RIGHT - arriba_v * arriba_v.dot(Vector3.RIGHT)
	lado = lado.normalized() if lado.length() > 0.01 else Vector3.RIGHT
	var frente: Vector3 = arriba_v.cross(lado).normalized()
	if frente.y < 0.0:
		frente = -frente
	var centro: Vector3 = grip + frente * SEPARA_DEL_BRAZO * hacia
	var paso: float = float(g.get("paso", 0.7))
	var r: float = paso * 0.78
	# Toda la lamina gira ENTERA con la torsion de la mano (como el arma en la mano, ver 'z_torsion').
	var opts := {"z_torsion": grip.z}
	var ancho: float = float(g["ancho"])
	var u := -float(g["abajo"])
	while u <= float(g["arriba"]) + 0.001:
		var v := -ancho
		while v <= ancho + 0.001:
			var zona: int = _zona(tamano, g, u, v)
			if zona >= 0:
				var p: Vector3 = centro + arriba_v * u + lado * v
				PoseJugador.poner(piezas, esq, p, Vector3(r, r * 0.6, r), _tono(zona, g, u, v), opts)
			v += paso
		u += paso


# QUE HAY en (u, v) de la lamina: -1 fuera; 0 el aro; 1 el cuerpo; 2 el metal de encima (umbo, franja,
# bandas).
static func _zona(tamano: String, g: Dictionary, u: float, v: float) -> int:
	var aro: float = float(g["aro"])
	var borde: float = _hasta_el_borde(tamano, g, u, v)
	if borde < 0.0:
		return -1
	if borde < aro:
		return 0
	match tamano:
		"pequeno":
			if Vector2(u, v).length() < float(g["umbo"]):
				return 2
		"normal":
			if absf(v) < float(g["franja"]) * 0.5:
				return 2
		"grande":
			if absf(v) < float(g["franja"]) * 0.5:
				return 2
			for b in g["bandas"]:
				if absf(u - float(b)) < aro * 0.6:
					return 2
	return 1


# Cuanto le falta a (u, v) para salirse de la silueta (negativo = fuera). Es lo que da el grosor del aro
# igual en todo el borde.
static func _hasta_el_borde(tamano: String, g: Dictionary, u: float, v: float) -> float:
	var ancho: float = float(g["ancho"])
	var arriba: float = float(g["arriba"])
	var abajo: float = float(g["abajo"])
	match tamano:
		"pequeno":
			return ancho - Vector2(u, v).length()
		"normal":
			# Recto arriba y por los lados hasta la mitad; de ahi los lados se cierran en punta (un arco).
			var lat: float = ancho
			if u < 0.0:
				var k: float = clampf(-u / abajo, 0.0, 1.0)
				lat = ancho * sqrt(maxf(0.0, 1.0 - k * k))
			return minf(arriba - u, lat - absf(v))
		"grande":
			# Casi un rectangulo (un pelo mas estrecho abajo), con la parte de arriba en ARCO.
			var k2: float = clampf((u + abajo) / (arriba + abajo), 0.0, 1.0)
			var lat2: float = lerpf(ancho * 0.9, ancho, k2)
			var techo: float = arriba - 2.2 * (v / ancho) * (v / ancho)
			return minf(minf(techo - u, u + abajo), lat2 - absf(v))
	return -1.0


# El tono de cada zona. El cuerpo lleva LUZ arriba a la izquierda y sombra abajo a la derecha (el mismo
# lado de luz que el resto del personaje), y el metal de encima brilla.
static func _tono(zona: int, g: Dictionary, u: float, v: float) -> int:
	match zona:
		0:
			return Tono.METAL
		2:
			return Tono.METAL_L
	var luz: float = u / maxf(float(g["arriba"]), 1.0) - v / maxf(float(g["ancho"]), 1.0)
	if luz > 0.55:
		return Tono.MADERA_L
	if luz < -0.6:
		return Tono.MADERA_S
	return Tono.MADERA
