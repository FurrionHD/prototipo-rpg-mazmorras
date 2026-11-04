# ============================================================
#  slime_aire.gd
#  LOS EFECTOS DE LOS SLIMES en el mapa (28/09/2026; la lista la aprobo el usuario). Todo del COLOR DEL SLIME
#  que lo lanza, que viaja metido en los bits altos de la semilla (ver semilla_con_color): asi el espejo pinta
#  lo mismo sin mandar nada mas por red.
#  POR EL SUELO (SueloRoto.Tipo.SLIME_*, en el orden de Modo; el golpe le llega a cada uno cuando le alcanza):
#    SPLAT       Reventon: cae del salto y revienta en un CHARCO de gel con una corona de gotas que salen
#                disparadas; el nucleo mas denso.
#    APLASTA     Aplastamiento del Rey: lo mismo en grande, con la onda de choque y las losas del martillo.
#    MAREA       Marea corrosiva: tres anillos de baba que se abren desde el Rey (uno por tramo).
#    COMBUSTION  Combustion: una bola de fuego revienta sobre el slime y la onda de llamas llega al borde.
#    SALPICA     Salpicadura ardiente: se sacude y saltan gotas de lava en anillo; chisporrotean en el suelo.
#    ROCIADA     Rociada corrosiva: un abanico de gotas (cometas) por el cono que dejan manchas.
#    LLAMARADA   Llamarada: el aliento de la Brasa (MagiaAire.ALIENTO) estrechado a su linea.
#    PRESION     Presion del abismo: una ola de GARRAS NEGRAS en media luna (con su pincelada clara rota) que barre su
#                linea y deja tinta salpicada y sombra. El abisal es de OSCURIDAD, no de agua (lo dijo el usuario,
#                28/09), y con el lenguaje de NUESTRA oscuridad (la Voragine): nada de fuego negro.
#    PLACAJE     Placaje: el rastro de baba que deja al embestir y el salpicon al chocar.
#    EMBATE      Doble embate: los dos coletazos, la ida y vuelta del Segar (BarridoAire.SIEGA) en gel.
#  SOBRE UN CUERPO (CombatTactico._on_dibujo_mapa, CombatFX.Estilo.SLIME_*):
#    GOLPE       el basico: salpicon de gel sobre el que recibe, hacia atras de donde viene el golpe.
#    ESCUPE      el Escupitajo (y las gotas del Brote): una bola de baba en parabola con estela de gotas que
#                revienta en el pecho y deja un charquito.
#    TROMBA      Tromba abisal: un EMBUDO de medias lunas negras que gira y se estrecha cae sobre el (cabeza negra con
#                el ojo claro del eclipse) y a sus pies se abre un REMOLINO de brazos negros, una Voragine pequeña.
#    IGNICION    Ignicion: el slime de fuego SE PRENDE: llamas que le suben del cuerpo, calor en el suelo y ascuas.
#    TROZO       Escision: un trozo del Rey sale disparado hacia el, le revienta encima y vuelve.
#  NADA DE LINEAS peladas: gel = silueta llena con borde oscuro, cuerpo y brillo; gotas = cometas. Suelo sin
#  achatar; lo que va por el aire, a su altura por K. Coordenadas de MUNDO.
# ============================================================
extends RefCounted
class_name SlimeAire

# Los del suelo van en el orden de SueloRoto.Tipo.SLIME_*: no reordenar.
enum Modo { SPLAT, APLASTA, MAREA, COMBUSTION, SALPICA, ROCIADA, LLAMARADA, PRESION, PLACAJE, EMBATE,
	GOLPE, ESCUPE, TROMBA, TROZO, IGNICION, PUAS, CRIA }


const T_SPLAT := 0.16            # lo que tarda el charco en abrirse hasta el borde
const T_APLASTA := 0.3           # la onda del Aplastamiento hasta el borde
const T_MAREA := 0.75            # lo que tarda cada anillo de la marea en llegar al borde
const T_ENTRE_OLAS := 0.14
const T_COMBUSTION := 0.26       # la onda de llamas de la Combustion hasta el borde
const T_SALPICA := 0.34          # lo que vuela una gota de lava
const T_ROCIADA := 0.3           # lo que vuela una gota de la rociada hasta el fondo
const T_PLACAJE := 0.2           # = CombatTactico.T_EMBESTIDA_BICHO (el rastro va con el cuerpo)
const T_PUAS := 0.2              # lo que tardan las puas de Expandir puas en llegar al borde del circulo

const T_OSCURO := 0.45           # lo que tarda el frente de la Presion en recorrer su linea
const TOCA_TROMBA := 3.0 / 14.0
const T_TROZO_ESPERA := 0.12
const T_TROZO_VUELVE := 0.35
const T_CRECE := 0.4             # lo que tarda en hacerse opaca la cria (su hoja cria_nace lo mismo)
const PIES_EN_DIBUJO := 1.12 / 1.52   # a que altura de su dibujo tiene los pies un slime (como slime_efectos_pixel.pies)

# ------------------------------------------------------------
#  EL COLOR EN LA SEMILLA
# ------------------------------------------------------------
# 12 bits de color (4 por canal) en los bits 18-29; los 18 de abajo son el azar (impar). Cabe en los 30 bits
# de siempre, asi que viaja por el paquete del suelo (MARCA_SUELO) sin cambiar nada.
static func semilla_con_color(azar: int, col: Color) -> int:
	var rgb: int = (clampi(roundi(col.r * 15.0), 0, 15) << 8) | (clampi(roundi(col.g * 15.0), 0, 15) << 4) \
		| clampi(roundi(col.b * 15.0), 0, 15)
	return (rgb << 18) | (azar & 0x3FFFF) | 1


static func color_de_semilla(semilla: int) -> Color:
	var rgb: int = (semilla >> 18) & 0xFFF
	if rgb == 0:
		return Color(0.35, 0.7, 0.95)
	return Color(float((rgb >> 8) & 15) / 15.0, float((rgb >> 4) & 15) / 15.0, float(rgb & 15) / 15.0)


# ------------------------------------------------------------
#  EN EL SUELO
# ------------------------------------------------------------
static func area(padre: Node, f: CombatFormas.Forma, m: int, semilla: int, espera: float) -> Node2D:
	if padre == null or f == null:
		return null
	var col: Color = color_de_semilla(semilla)
	return _area_pixel(padre, f, m, col, espera)


# LOS EFECTOS EN PIXEL ART (04/11/2026, memoria efectos-a-pixel-art), con el color de quien lo lanza. La forma manda que hoja le
# toca: el mismo numero en todas las maquinas.
static func _area_pixel(padre: Node, f: CombatFormas.Forma, m: int, col: Color, espera: float) -> EfectoPixel:
	var nombre: String = ""
	match m:
		Modo.APLASTA:
			nombre = "aplasta"
		Modo.MAREA:
			nombre = "marea_rey"
		Modo.SPLAT:
			if f.radio <= 47.0:
				nombre = "splat_46" if f.radio > 40.0 else "splat_35"
			else:
				nombre = "nube_ceniza"
		Modo.PLACAJE:
			if f.ancho <= 50.0:
				nombre = "placaje_g" if f.largo > 55.0 else "placaje_c"
			else:
				nombre = "emb_cortante"
		Modo.LLAMARADA:
			nombre = "llamarada"
		Modo.SALPICA:
			nombre = "salpica_ceniza" if f.radio > 37.0 else "salpica"
		Modo.COMBUSTION:
			nombre = "combustion"
		Modo.EMBATE:
			nombre = "embate_3" if f.apertura > 110.0 else "embate_2"
		Modo.PRESION:
			nombre = "presion"
		Modo.PUAS:
			nombre = "puas_obs" if col.get_luminance() < 0.25 else "puas"
		Modo.ROCIADA:
			# (las Esquirlas de la obsidiana van por aqui: la ficha las hace una Rociada oscura)
			nombre = "esquirlas_obs" if f.radio >= 58.0 else ("rociada_55" if f.radio > 50.0 else "rociada_45")
	if nombre == "":
		return null
	var dir: int = SpriteLienzo.dir8(f.dir) if f.dir.length_squared() > 0.0001 else 0
	return EfectoPixel.lanzar(padre, "slime", nombre, SueloRoto.origen_de(f), dir, null, espera, -1.0,
		maxf(BarridoAire.ritmo, 0.05), paleta_pixel(col))


# LO QUE SE QUEDA de los slimes, en pixel art (PiezaPixel): la baba de los mutantes (3 y 4), la nube de miasma (5) y la burbuja (6).
static func baba_pixel(padre: Node, f: CombatFormas.Forma, col: Color, pinchos: bool) -> PiezaPixel:
	var linea: bool = f.tipo == CombatFormas.Tipo.LINEA
	var base: String = ("baba_l" if linea else "baba_c") + ("_p" if pinchos else "")
	var pos: Vector2 = f.origen if linea else f.centro   # (la hoja del rastro tiene su origen donde empieza)
	var dir: int = SpriteLienzo.dir8(f.dir) if linea and f.dir.length_squared() > 0.0001 else 0
	return PiezaPixel.crear(padre, "slime", base + "_sale", base + "_dura", base + "_vete", pos, dir, paleta_pixel(col), 0.0, BarridoAire.ritmo)


# La nube que deja la Nube de ceniza (estilo 7).
static func nube_ceniza_pixel(padre: Node, f: CombatFormas.Forma, espera: float) -> PiezaPixel:
	return PiezaPixel.crear(padre, "slime", "nubec_50_sale", "nubec_50_dura", "nubec_50_vete", f.centro, 0, PackedColorArray(), espera, BarridoAire.ritmo)


static func nube_pixel(padre: Node, f: CombatFormas.Forma, col: Color, espera: float) -> PiezaPixel:
	var base: String = "nube_65" if f.radio > 57.0 else "nube_50"
	return PiezaPixel.crear(padre, "slime", base + "_sale", base + "_dura", base + "_vete", f.centro, 0, paleta_pixel(col), espera, BarridoAire.ritmo)


const T_VUELO_BURBUJA := 0.4


static func burbuja_pixel(padre: Node, f: CombatFormas.Forma, col: Color) -> PiezaPixel:
	var p: PiezaPixel = PiezaPixel.crear(padre, "slime", "burbuja_sale", "burbuja_dura", "burbuja_vete", f.centro, 0, paleta_pixel(col), T_VUELO_BURBUJA, BarridoAire.ritmo)
	if p != null:
		p.tiembla = true
		p.poner_vuelo("burbuja_vuela", f.origen if f.origen != Vector2.ZERO else f.centro, 22.0, T_VUELO_BURBUJA)
	return p


# Los cinco colores de sus hojas (ver EfectoPixel): los cuatro tonos del gel y el borde, sacados de SU color.
static func paleta_pixel(col: Color) -> PackedColorArray:
	return PackedColorArray([col.darkened(0.62), col.darkened(0.2), col.lightened(0.32), col.lightened(0.78), col.darkened(0.82)])


# La LLAMARADA es una linea en la ficha (su huella) y el aliento es un cono: el mismo largo, abierto lo justo.
static func _cono_de_linea(f: CombatFormas.Forma) -> CombatFormas.Forma:
	var largo: float = f.largo if f.largo > 0.0 else f.radio
	var abre: float = clampf(rad_to_deg(atan2(maxf(f.ancho, 8.0), largo)) * 2.0, 14.0, 40.0)
	return CombatFormas.cono(f.origen, f.dir, largo, abre)


# CUANDO LE LLEGA a 'p', en segundos desde que se lanza (la misma cuenta que el dibujo).
static func retraso(m: int, f: CombatFormas.Forma, p: Vector2) -> float:
	if f == null:
		return 0.0
	var o: Vector2 = SueloRoto.origen_de(f)
	var u: float = clampf(p.distance_to(o) / maxf(f.radio, 1.0), 0.0, 1.0)
	match m:
		Modo.SPLAT: return u * T_SPLAT
		Modo.APLASTA: return u * T_APLASTA
		Modo.MAREA: return u * T_MAREA
		Modo.COMBUSTION: return u * T_COMBUSTION
		Modo.SALPICA: return u * T_SALPICA
		Modo.ROCIADA: return u * T_ROCIADA
		Modo.PLACAJE:
			return clampf((p - f.origen).dot(f.dir) / maxf(f.largo, 1.0), 0.0, 1.0) * T_PLACAJE
		Modo.LLAMARADA:
			return MagiaAire.retraso(MagiaAire.Modo.ALIENTO, _cono_de_linea(f), p)
		Modo.PRESION:
			return clampf((p - f.origen).dot(f.dir) / maxf(f.largo, 1.0), 0.0, 1.0) * T_OSCURO
		Modo.EMBATE:
			return BarridoAire.retraso_px(BarridoAire.Modo.SIEGA, p.distance_to(o), f.radio)
		Modo.PUAS: return u * T_PUAS
	return 0.0


static func t_salir(m: int) -> float:
	match m:
		Modo.SPLAT: return T_SPLAT
		Modo.APLASTA: return T_APLASTA
		Modo.MAREA: return T_MAREA + T_ENTRE_OLAS * 2.0
		Modo.COMBUSTION: return T_COMBUSTION
		Modo.SALPICA: return T_SALPICA
		Modo.ROCIADA: return T_ROCIADA
		Modo.PLACAJE: return T_PLACAJE
		Modo.LLAMARADA: return MagiaAire.t_salir(MagiaAire.Modo.ALIENTO)
		Modo.PRESION: return T_OSCURO
		Modo.EMBATE: return BarridoAire.T_ENTRE * 2.0
		Modo.PUAS: return T_PUAS
	return 0.3


# ------------------------------------------------------------
#  SOBRE UN CUERPO
# ------------------------------------------------------------
# 'desde' = de donde viene (el pecho o la boca de quien lo lanza), 'caja' = el cuerpo que lo recibe, 'espera' =
# lo que falta para el golpe (lo que viaja ocupa ese tiempo).
static func sobre_cuerpo(padre: Node, m: int, desde: Vector2, caja: Rect2, col: Color, semilla: int,
		espera: float, ritmo: float, trozo_vuelve: bool = true) -> Node2D:
	if padre == null:
		return null
	if m == Modo.GOLPE:
		# EN PIXEL ART (04/11): el salpicon, a los pies del que lo recibe, hacia atras de donde viene el golpe.
		var hacia: Vector2 = caja.get_center() - desde
		var d8: int = SpriteLienzo.dir8(hacia) if hacia.length_squared() > 1.0 else 0
		return EfectoPixel.lanzar(padre, "slime", "golpe", Vector2(caja.get_center().x, caja.end.y), d8, null, maxf(espera, 0.08), -1.0,
			maxf(ritmo, 0.05), paleta_pixel(col))
	if m == Modo.IGNICION:
		# EN PIXEL ART: el fuego le sube del cuerpo. (El de Ceniza y brasa, mas grande: sus brasas, mas ascuas que llama.)
		# Sale de SUS PIES dentro del dibujo (la misma cuenta que la lamina), no del borde de abajo de la caja.
		return EfectoPixel.lanzar(padre, "slime", "ignicion_brasas" if caja.size.x > 56.0 else "ignicion",
			Vector2(caja.get_center().x, caja.position.y + caja.size.y * PIES_EN_DIBUJO), 0, null, 0.0, -1.0, maxf(ritmo, 0.05))
	if m == Modo.TROZO:
		# EN PIXEL ART: un trozo suyo vuela hasta el cuerpo, le revienta encima (el salpicon del basico) y lo que queda le vuelve.
		var r_tr: float = maxf(ritmo, 0.05)
		var v_tr: float = maxf(espera, 0.08)
		var pal_tr: PackedColorArray = paleta_pixel(col)
		var centro_tr: Vector2 = caja.get_center()
		var hacia_tr: Vector2 = centro_tr - desde
		var ida: EfectoPixel = EfectoPixel.lanzar(padre, "slime", "golpe", Vector2(centro_tr.x, caja.end.y), SpriteLienzo.dir8(hacia_tr) if hacia_tr.length_squared() > 1.0 else 0,
			null, v_tr, -1.0, r_tr, pal_tr)
		if ida != null:
			ida.poner_vuelo("slime", "trozo_bola", desde, centro_tr, 22.0, v_tr)
		if trozo_vuelve:
			var vuelta: EfectoPixel = EfectoPixel.lanzar(padre, "slime", "trozo_junta", desde, 0, null, v_tr + T_TROZO_ESPERA + T_TROZO_VUELVE, -1.0, r_tr, pal_tr)
			if vuelta != null:
				vuelta.poner_vuelo("slime", "trozo_gota", centro_tr, desde, 26.0, T_TROZO_VUELVE)
		return ida
	if m == Modo.CRIA:
		# EN PIXEL ART: la bola vuela en arco y al caer sale el gel del que nace la cria (ella se va haciendo opaca, ver CombatTactico).
		var pies_c := Vector2(caja.get_center().x, caja.end.y)
		var v_c: float = maxf(espera, 0.08)
		var cr: EfectoPixel = EfectoPixel.lanzar(padre, "slime", "cria_nace", pies_c, 0, null, v_c, -1.0, maxf(ritmo, 0.05), paleta_pixel(col))
		if cr != null:
			cr.poner_vuelo("slime", "trozo_bola", desde, pies_c, maxf(24.0, desde.distance_to(pies_c) * 0.3), v_c)
		return cr
	if m == Modo.TROMBA:
		# EN PIXEL ART: la columna cae sobre sus pies; en el marco 3 de la hoja toca el suelo, y eso ha de ser el golpe.
		var r_t: float = maxf(ritmo, 0.05)
		return EfectoPixel.lanzar(padre, "slime", "tromba", Vector2(caja.get_center().x, caja.end.y), 0, null, maxf(espera - TOCA_TROMBA / r_t, 0.0), -1.0, r_t)
	if m == Modo.ESCUPE:
		# EN PIXEL ART: la bola viaja la distancia que toque (por codigo) y revienta en los pies del que lo recibe.
		var pies_e := Vector2(caja.get_center().x, caja.end.y)
		var viaje: float = maxf(espera, 0.08)
		var ep: EfectoPixel = EfectoPixel.lanzar(padre, "slime", "escupe", pies_e, 0, null, viaje, -1.0, maxf(ritmo, 0.05), paleta_pixel(col))
		if ep != null:
			ep.poner_vuelo("slime", "bola", desde, caja.get_center(), 18.0, viaje)
		return ep
	return null
