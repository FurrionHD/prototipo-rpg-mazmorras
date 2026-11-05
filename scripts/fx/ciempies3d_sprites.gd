# ============================================================
#  ciempies3d_sprites.gd  (class_name Ciempies3DSprites)
#  EL CIEMPIES CARMESI EN 3D (05/10/2026): cada anillo un hueso; espiral al morir y la HELICE del enroscado en dos mitades.
#  Se modela en tools/sprites_sdf/ciempies_sdf.py y aqui solo se cargan sus hojas (Sprites3D, con el tinte de cada piso).
#  Los tiempos de cada gesto son los del viejo, asi que sus efectos caen igual. El viejo (CiempiesSprites, por codigo) queda
#  de referencia.
# ============================================================

extends RefCounted
class_name Ciempies3DSprites

const CARPETA := "res://assets/sprites/enemigos/ciempies_sdf/"
# El lienzo del generador viejo a su escala (y el del script de python): el juego lo coloca igual.
const LIENZO := Vector2i(104, 104)
# El color en que estan pintadas las hojas (el de su ficha).
const BASE := Color("aa251c")

const ANIMS := {
	"idle": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 4.0, "loop": true},
	"walk": {"hoja": "walk", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": true},
	"embestida": {"hoja": "embestida", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": false},
	# UNA direccion (combate, de frente).
	"enrosque": {"hoja": "enrosque", "dirs": 1, "marcos": 8, "fps": 11.0, "loop": false},
	# PICA en la mitad.
	"basico": {"hoja": "basico", "dirs": 8, "marcos": 6, "fps": 16.0, "loop": false},
	# Una sacudida por picotazo, en la mitad.
	"oleada": {"hoja": "oleada", "dirs": 8, "marcos": 6, "fps": 18.0, "loop": false},
	"encaje": {"hoja": "encaje", "dirs": 8, "marcos": 4, "fps": 18.0, "loop": false},
	"muerte": {"hoja": "muerte", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"enroscarse_detras": {"hoja": "enroscarse_detras", "dirs": 1, "marcos": 6, "fps": 12.0, "loop": false},
	"enroscado_detras": {"hoja": "enroscado_detras", "dirs": 1, "marcos": 8, "fps": 8.0, "loop": true},
	"apreton_detras": {"hoja": "apreton_detras", "dirs": 1, "marcos": 5, "fps": 14.0, "loop": false},
	"desenroscarse_detras": {"hoja": "desenroscarse_detras", "dirs": 1, "marcos": 6, "fps": 12.0, "loop": false},
	"enroscarse_delante": {"hoja": "enroscarse_delante", "dirs": 1, "marcos": 6, "fps": 12.0, "loop": false},
	"enroscado_delante": {"hoja": "enroscado_delante", "dirs": 1, "marcos": 8, "fps": 8.0, "loop": true},
	"apreton_delante": {"hoja": "apreton_delante", "dirs": 1, "marcos": 5, "fps": 14.0, "loop": false},
	"desenroscarse_delante": {"hoja": "desenroscarse_delante", "dirs": 1, "marcos": 6, "fps": 12.0, "loop": false},
	"cadaver": {"hoja": "muerte", "dirs": 8, "marcos": 1, "desde": 7, "fps": 1.0, "loop": false},
	# COMER UN CRISTAL (05/11, sus mutantes).
	"comer": {"hoja": "comer", "dirs": 8, "marcos": 10, "fps": 10.0, "loop": false, "opcional": true},
}

# LOS MUTANTES DEL CIEMPIES (05/11, ciempies-mutante): su carpeta y sus animaciones (tools/sprites_sdf/ciempies_mut_sdf.py).
# Ya vienen a su tamaño y con SU color (sin el tinte del piso). Su 'embestida' de siempre es su basico.
const LIENZOS_MUT := {&"bicefalo": Vector2i(136, 136), &"nudo": Vector2i(184, 216)}
const _MUT_COMUN := {
	"idle": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 4.0, "loop": true},
	"basico": {"hoja": "basico", "dirs": 8, "marcos": 8, "fps": 14.0, "loop": false},
	"basico_u": {"hoja": "basico", "dirs": 8, "marcos": 8, "fps": 14.0, "loop": false},
	"embestida": {"hoja": "basico", "dirs": 8, "marcos": 8, "fps": 14.0, "loop": false},
	"pinza": {"hoja": "pinza", "dirs": 8, "marcos": 7, "fps": 14.0, "loop": false},
	"oleada": {"hoja": "oleada", "dirs": 8, "marcos": 6, "fps": 18.0, "loop": false},
	"enrosque": {"hoja": "enrosque", "dirs": 8, "marcos": 8, "fps": 11.0, "loop": false},
	"libre_idle": {"hoja": "libre_idle", "dirs": 8, "marcos": 6, "fps": 8.0, "loop": true},
	"libre_muerde": {"hoja": "libre_muerde", "dirs": 8, "marcos": 6, "fps": 14.0, "loop": false},
	"encaje": {"hoja": "encaje", "dirs": 8, "marcos": 4, "fps": 18.0, "loop": false},
	"muerte": {"hoja": "muerte", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"cadaver": {"hoja": "muerte", "dirs": 8, "marcos": 1, "desde": 7, "fps": 1.0, "loop": false},
	"comer": {"hoja": "comer", "dirs": 8, "marcos": 10, "fps": 10.0, "loop": false},
	"evolucion": {"hoja": "evolucion", "dirs": 8, "marcos": 18, "fps": 10.0, "loop": false},
}
const _MUT_NUDO := {
	"derrumbe_carga": {"hoja": "derrumbe_carga", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": true},
	"derrumbe": {"hoja": "derrumbe", "dirs": 8, "marcos": 7, "fps": 12.0, "loop": false},
}


# Las piezas del enrosque, 'suf' = "" (la cabeza A) o "_b" (la B, la segunda presa del Nudo).
static func _piezas(suf: String) -> Dictionary:
	var a: Dictionary = {}
	for lado in ["_detras", "_delante"]:
		for t in [["enroscarse", 6, 12.0, false], ["enroscado", 8, 8.0, true], ["apreton", 5, 14.0, false], ["desenroscarse", 6, 12.0, false]]:
			var nom: String = "%s%s%s" % [t[0], suf, lado]
			a[nom] = {"hoja": nom, "dirs": 1, "marcos": t[1], "fps": t[2], "loop": t[3]}
	return a


static func _anims_mutante(sprite: StringName) -> Dictionary:
	var a: Dictionary = _MUT_COMUN.duplicate()
	a["walk"] = {"hoja": "walk", "dirs": 8, "marcos": 8, "fps": 10.0 if sprite == &"bicefalo" else 7.0, "loop": true}
	a.merge(_piezas(""))
	if sprite == &"nudo":
		a.merge(_MUT_NUDO)
		a.merge(_piezas("_b"))
	return a


static func _sprite_mutante(ed: EnemyData, mutacion: StringName) -> StringName:
	var m: MutacionData = ed.mutacion_de(mutacion) if ed != null else null
	return m.sprite if m != null and LIENZOS_MUT.has(m.sprite) else &""


# --- EL SPRITE DE MUTANTE (contrato de SpritesEnemigo, como Jabali3DSprites) ---
static func tiene_mutante(ed: EnemyData, mutacion: StringName = &"") -> bool:
	return _sprite_mutante(ed, mutacion) != &""


static func clave_mutante_de(ed: EnemyData, _t: float, mutacion: StringName = &"") -> String:
	var s: StringName = _sprite_mutante(ed, mutacion)
	return "" if s == &"" else "ciempies3d_ciempies_sdf_%s" % String(s)


static func generar_mutante_de(ed: EnemyData, _t: float, mutacion: StringName = &"") -> SpriteFrames:
	var s: StringName = _sprite_mutante(ed, mutacion)
	if s == &"":
		return null
	return Sprites3D.montar("res://assets/sprites/enemigos/ciempies_sdf_%s/" % String(s), _anims_mutante(s), LIENZOS_MUT[s], BASE, BASE)


# --- Contrato de SpritesEnemigo ---
static func generar_de(ed: EnemyData, t: float) -> SpriteFrames:
	return generar(ed.color_visual(t))


# 'ciempies3d_' y no 'ciempies_': con la clave vieja, SpritesEnemigo cargaria el horneado VIEJO de disco.
static func clave_de(ed: EnemyData, t: float) -> String:
	return "ciempies3d_%s" % SpriteLienzo.cuantizar_hsv(ed.color_visual(t), CiempiesSprites.COLOR_PASOS).to_html(false)


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(_escala: float = 1.0) -> int:
	return LIENZO.x


static func dimensiona_por_escala() -> bool:
	return true


static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	return CiempiesSprites.tam_cuerpo(escala)


static func generar(color: Color = BASE) -> SpriteFrames:
	return Sprites3D.montar(CARPETA, ANIMS, LIENZO, BASE, SpriteLienzo.cuantizar_hsv(color, CiempiesSprites.COLOR_PASOS))
