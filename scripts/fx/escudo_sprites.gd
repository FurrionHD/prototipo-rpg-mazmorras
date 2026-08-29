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

# GEOMETRIA por tamaño, en unidades de mundo (PoseJugador.ALTO_MUNDO = 60). 'largo' es de punta a
# punta a lo largo del eje del agarre; 'r_arriba'/'r_abajo' son el radio en cada extremo -- variar
# los dos es lo que saca las tres siluetas sin mas piezas: casi iguales = redondo (rodela); muy
# distintos = con punta (heater); largo grande y radios parecidos = alto y recto (torre).
const GEO := {
	"pequeno": {"largo": 9.0,  "r_arriba": 4.2, "r_abajo": 4.0, "remache": 1.5},
	"normal":  {"largo": 13.0, "r_arriba": 4.6, "r_abajo": 1.7, "remache": 1.2},
	"grande":  {"largo": 17.5, "r_arriba": 3.7, "r_abajo": 3.3, "remache": 1.1},
}

# En que animaciones dibuja cada capa (nombre BASE, sin direccion). Mismo criterio que ArmaSprites,
# sin golpe_izq/golpe_2m: ver la cabecera.
const _ANIM_ENVAINADA := ["idle", "walk", "correr", "sigilo", "encaje", "muerte", "cadaver", "desenvainar"]
const _ANIM_MANO := ["guardia", "guardia_and", "guardia_cor", "golpe"]


# --- Contrato de capa (ver CapaJugador y el registro de JugadorSprites) ---
static func frames(clave: String, esc: float = 1.0) -> SpriteFrames:
	return CapaJugador.frames(clave, pintar.bind(clave), colores(), esc)


static func generar(clave: String, esc: float = 1.0) -> SpriteFrames:
	return CapaJugador.generar(clave, pintar.bind(clave), colores(), esc)


static func colores() -> Array:
	return [
		Color(0, 0, 0, 0),                # VACIO
		Color(0, 0, 0, 0.20),              # SOMBRA_SUELO
		Color(0.09, 0.09, 0.11),           # BORDE
		Color(0.32, 0.20, 0.12),           # MADERA_S
		Color(0.46, 0.30, 0.17),           # MADERA
		Color(0.62, 0.44, 0.27),           # MADERA_L
		Color(0.62, 0.65, 0.70),           # METAL
		Color(0.88, 0.91, 0.95),           # METAL_L
	]


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
	return _ANIM_ENVAINADA.has(anim)


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

	# ENVAINADO: solo se dibuja de espaldas (el resto de direcciones lo tapa el cuerpo, y un escudo
	# es demasiado ancho para "mandarlo detras" y que cuele -- asoma por los lados igual que una
	# hoja larga). Durante 'desenvainar' se dibuja siempre: esta viajando a la mano.
	if estado != "mano" and sac < 0.0 and not _DIRS_ESPALDA.has(int(esq.get("dir", 0))):
		return

	var ag: Dictionary = PoseJugador.agarre_escudo(esq, estado)
	var grip: Vector3 = ag["empunadura"]
	var eje: Vector3 = ag["eje"]

	if sac >= 0.0 and estado != "mano":
		var agm: Dictionary = PoseJugador.agarre_escudo(esq, "mano")
		grip = grip.lerp(agm["empunadura"], sac)
		eje = eje.lerp(agm["eje"], sac)
		if eje.length() > 0.01:
			eje = eje.normalized()

	_dibujar(piezas, esq, grip, eje, g)


static func _dibujar(piezas: Array, esq: Dictionary, grip: Vector3, eje: Vector3,
		g: Dictionary) -> void:
	var largo: float = float(g.get("largo", 10.0))
	var r_arriba: float = float(g.get("r_arriba", 4.0))
	var r_abajo: float = float(g.get("r_abajo", 4.0))
	# El agarre cae a un tercio desde abajo (como se lleva un escudo de verdad: el antebrazo pasa
	# por la correa central-baja, no por el medio exacto), no en el centro geometrico.
	var arriba: Vector3 = grip + eje * (largo * 0.62)
	var abajo: Vector3 = grip - eje * (largo * 0.38)

	# El aro metalico: el perfil MAS ANCHO, para que asome como borde alrededor de la madera.
	PoseJugador.cadena(piezas, esq, abajo, arriba, r_abajo, r_arriba, Tono.METAL)

	# El cuerpo (madera/cuero), un pelo mas estrecho que el aro -- deja el aro asomando alrededor
	# entero, como el reborde metalico de un escudo de verdad.
	var m: float = 0.82
	PoseJugador.cadena(piezas, esq, abajo, arriba, r_abajo * m, r_arriba * m, Tono.MADERA)
	# El realce de luz: mas estrecho todavia y SOLO sobre la madera (no se sale de su silueta), la
	# misma idea que el filo de una hoja.
	PoseJugador.cadena(piezas, esq, abajo, arriba, r_abajo * m * 0.55, r_arriba * m * 0.55,
		Tono.MADERA_L, {"solo_sobre": [Tono.MADERA]})

	# El remache central, sobre el propio agarre.
	var remache: float = float(g.get("remache", 1.2))
	PoseJugador.poner(piezas, esq, grip, Vector3(remache, remache, remache), Tono.METAL_L)
