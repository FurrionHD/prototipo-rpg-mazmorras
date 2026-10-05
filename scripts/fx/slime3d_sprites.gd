# ============================================================
#  slime3d_sprites.gd  (class_name Slime3DSprites)
#  LOS SLIMES EN 3D (05/10/2026, su referencia: una gominola de GEL TRANSLUCIDO, los ojos solidos en el frente). Se
#  modelan en tools/sprites_sdf/slime_sdf.py, UNA HOJA POR TAMAÑO (el lienzo del viejo cambia con la escala) y por
#  forma: el de siempre (s100, s115, s150, s170), el de LAVA (lava160) y el REY (rey280, con su corona de gel). Aqui
#  solo se cargan (Sprites3D, con el tinte de cada piso). Los tiempos de cada gesto son los del viejo.
#  El viejo (SlimeSprites, por codigo) queda de referencia y presta su lienzo y su caja.
# ============================================================

extends RefCounted
class_name Slime3DSprites

const CARPETA := "res://assets/sprites/enemigos/slime_sdf_%s/"
# Las variantes horneadas: escala -> (carpeta, color en que estan pintadas).
const NORMALES := [[1.00, "s100", "ff2b2b"], [1.15, "s115", "47d552"], [1.50, "s150", "556a80"], [1.70, "s170", "556faa"]]
const LAVA := ["lava160", "ff862b", 1.60]
const REY := ["rey280", "55b8ff", 2.80]

const ANIMS := {
	"idle": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 4.0, "loop": true},
	"walk": {"hoja": "walk", "dirs": 8, "marcos": 8, "fps": 8.0, "loop": true},
	"embestida": {"hoja": "embestida", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"inflar": {"hoja": "inflar", "dirs": 8, "marcos": 8, "fps": 9.0, "loop": false},
	"hinchado": {"hoja": "hinchado", "dirs": 8, "marcos": 8, "fps": 8.0, "loop": true},
	"deshincharse": {"hoja": "deshincharse", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"encogido": {"hoja": "encogido", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": true},
	"aplaston": {"hoja": "aplaston", "dirs": 8, "marcos": 8, "fps": 14.0, "loop": false},
	"ignicion": {"hoja": "ignicion", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": false},
	"brote": {"hoja": "brote", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"escupir": {"hoja": "escupir", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": false},
	"nacer": {"hoja": "nacer", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"encaje": {"hoja": "encaje", "dirs": 8, "marcos": 4, "fps": 18.0, "loop": false},
	"muerte": {"hoja": "muerte", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"cadaver": {"hoja": "muerte", "dirs": 8, "marcos": 1, "desde": 7, "fps": 1.0, "loop": false},
}


# La variante horneada que le toca: [carpeta, color base, escala].
static func _variante(escala: float, corona: bool, lava: bool) -> Array:
	if corona:
		return REY
	if lava:
		return LAVA
	var mejor: Array = NORMALES[0]
	for v in NORMALES:
		if absf(float(v[0]) - escala) < absf(float(mejor[0]) - escala):
			mejor = v
	return [mejor[1], mejor[2], mejor[0]]


# --- Contrato de SpritesEnemigo ---
static func generar_de(ed: EnemyData, t: float) -> SpriteFrames:
	return generar(ed.color_visual(t), ed.corona_slime, ed.escala_visual, ed.lava_slime)


# 'slime3d_' y no 'slime_': con la clave vieja, SpritesEnemigo cargaria el horneado VIEJO de disco.
static func clave_de(ed: EnemyData, t: float) -> String:
	var v: Array = _variante(ed.escala_visual, ed.corona_slime, ed.lava_slime)
	return "slime3d_%s_%s" % [String(v[0]),
		SpriteLienzo.cuantizar_hsv(ed.color_visual(t), SlimeSprites.COLOR_PASOS).to_html(false)]


static func escala_base() -> float:
	return SlimeSprites.escala_base()


static func ancho_px(escala: float = 1.0) -> int:
	return SlimeSprites.ancho_px(escala)


static func dimensiona_por_escala() -> bool:
	return SlimeSprites.dimensiona_por_escala()


static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	return SlimeSprites.tam_cuerpo(escala)


static func generar(color: Color = Color(1.0, 0.2, 0.2), corona: bool = false, escala: float = 1.0,
		lava: bool = false) -> SpriteFrames:
	var v: Array = _variante(escala, corona, lava)
	var lienzo: Vector2i = SlimeSprites._lienzo(float(v[2]))
	return Sprites3D.montar(CARPETA % String(v[0]), ANIMS, lienzo, Color(String(v[1])),
		SpriteLienzo.cuantizar_hsv(color, SlimeSprites.COLOR_PASOS))
