# ============================================================
#  luz_de_arriba.gd  (class_name LuzDeArriba)
#  LA LUZ QUE ENTRA POR LA CARACOL que sube al pueblo (EscaleraSprites). Antes iba pintada en el dibujo,
#  siempre de sol, y el usuario lo vio: "si es de noche no tiene sentido que esto brille tanto".
#
#  Sigue la hora del pueblo (CicloDia): de dia la luz calida de siempre; al atardecer se tiñe con el
#  cielo; de noche queda una claridad de luna, floja y azulada.
# ============================================================
extends Sprite2D
class_name LuzDeArriba

const COLOR_DIA := Color(1.00, 0.88, 0.58)
const COLOR_NOCHE := Color(0.55, 0.66, 1.00)
const FUERZA_DIA := 0.55
const FUERZA_NOCHE := 0.14


static func crear(tex: Texture2D) -> LuzDeArriba:
	var s := LuzDeArriba.new()
	s.name = "LuzDeArriba"
	s.texture = tex
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return s


func _ready() -> void:
	# Con un menu abierto el arbol se para; la luz no cobra nada por seguir la hora.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_process(0.0)


func _process(_delta: float) -> void:
	var s: float = CicloDia.segundo()
	var noche: float = CicloDia.noche(s)
	# De dia, el color de siempre; en el paso, teñido con el cielo del pueblo.
	var c: Color = COLOR_DIA.lerp(COLOR_NOCHE, noche) * CicloDia.tinte(s).lerp(Color.WHITE, 0.5)
	c.a = lerpf(FUERZA_DIA, FUERZA_NOCHE, noche)
	modulate = c
