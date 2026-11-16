# ============================================================
#  aberracion3d_sprites.gd  (class_name Aberracion3DSprites)
#  LA ABERRACION EN 3D (05/10/2026). Se modela en tools/sprites_sdf/aberracion_sdf.py.
#  Aqui solo se cargan sus hojas (Sprites3D, con el tinte de cada piso). Los tiempos de cada gesto son los
#  del viejo, asi que sus efectos caen igual. El viejo (AberracionSprites, por codigo) queda de referencia y le presta
#  la caja y los pasos de color.
# ============================================================

extends RefCounted
class_name Aberracion3DSprites

const CARPETA := "res://assets/sprites/enemigos/aberracion_sdf/"
# El lienzo del generador viejo (y el del script de python): el juego lo coloca igual.
const LIENZO := Vector2i(102, 102)
# El color de la variante en que estan pintadas las hojas (la del horneado con el que se comparo).
const BASE := Color("754080")

const ANIMS := {
	"idle": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 4.0, "loop": true},
	"walk": {"hoja": "walk", "dirs": 8, "marcos": 8, "fps": 6.0, "loop": true},
	"alarido": {"hoja": "alarido", "dirs": 8, "marcos": 8, "fps": 9.0, "loop": false},
	"basico": {"hoja": "basico", "dirs": 8, "marcos": 8, "fps": 16.0, "loop": false},
	"embestida": {"hoja": "embestida", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": false},
	"mirada": {"hoja": "mirada", "dirs": 8, "marcos": 8, "fps": 9.0, "loop": false},
	"encaje": {"hoja": "encaje", "dirs": 8, "marcos": 4, "fps": 18.0, "loop": false},
	"muerte": {"hoja": "muerte", "dirs": 8, "marcos": 8, "fps": 9.0, "loop": false},
	"cadaver": {"hoja": "muerte", "dirs": 8, "marcos": 1, "desde": 7, "fps": 1.0, "loop": false},
}


# --- Contrato de SpritesEnemigo ---
static func generar_de(ed: EnemyData, t: float) -> SpriteFrames:
	return generar(ed.color_visual(t))


# 'aberracion3d_' y no 'aberracion_': con la clave vieja, SpritesEnemigo cargaria el horneado VIEJO de disco.
static func clave_de(ed: EnemyData, t: float) -> String:
	return "aberracion3d_%s" % SpriteLienzo.cuantizar_hsv(ed.color_visual(t), AberracionSprites.COLOR_PASOS).to_html(false)


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(_escala: float = 1.0) -> int:
	return LIENZO.x


static func dimensiona_por_escala() -> bool:
	return true


static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	return AberracionSprites.tam_cuerpo(escala)


static func generar(color: Color = BASE) -> SpriteFrames:
	return Sprites3D.montar(CARPETA, ANIMS, LIENZO, BASE, SpriteLienzo.cuantizar_hsv(color, AberracionSprites.COLOR_PASOS))


# LOS MUTANTES DE LA ABERRACION (13/11, memoria aberracion-mutante): su carpeta y sus animaciones
# (tools/sprites_sdf/aberracion_mut_sdf.py). Ya vienen a su tamaño (x1,2 la Masa) y con SU color (sin el tinte del piso).
# La MASA GALVANICA tiene las mismas anims que la base con el mismo nombre: 'alarido' es su Descarga y 'mirada' su Mirada
# chispeante (sus habilidades piden esos gestos), asi que sus efectos caen igual.
const LIENZOS_MUT := {&"galvanica": Vector2i(122, 122), &"tormenta": Vector2i(190, 190)}
# EL OJO DE LA TORMENTA (13/11): VUELA, y sus anims son todas nuevas ("la forma se parece pero no es igual"): late como una
# medusa, avanza a latidos, el Chispazo (basico), el Rayo del ojo (rayo), El ojo se abre (ojo_carga en bucle y ojo, el
# estallido), los Tentaculos que cuelgan (tentaculos), el encaje en el aire, la muerte que cae y la evolucion desde la Masa.
# 'embestida' es su Chispazo (por si algo pide el gesto de siempre).
const _MUT_TORMENTA := {
	"idle": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 6.0, "loop": true},
	"walk": {"hoja": "walk", "dirs": 8, "marcos": 8, "fps": 8.0, "loop": true},
	"basico": {"hoja": "basico", "dirs": 8, "marcos": 8, "fps": 14.0, "loop": false},
	"embestida": {"hoja": "basico", "dirs": 8, "marcos": 8, "fps": 14.0, "loop": false},
	"rayo": {"hoja": "rayo", "dirs": 8, "marcos": 10, "fps": 12.0, "loop": false},
	"ojo_carga": {"hoja": "ojo_carga", "dirs": 8, "marcos": 8, "fps": 8.0, "loop": true},
	"ojo": {"hoja": "ojo", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": false},
	"tentaculos": {"hoja": "tentaculos", "dirs": 8, "marcos": 8, "fps": 14.0, "loop": false},
	"encaje": {"hoja": "encaje", "dirs": 8, "marcos": 4, "fps": 18.0, "loop": false},
	"muerte": {"hoja": "muerte", "dirs": 8, "marcos": 12, "fps": 9.0, "loop": false},
	"cadaver": {"hoja": "muerte", "dirs": 8, "marcos": 1, "desde": 11, "fps": 1.0, "loop": false},
	"evolucion": {"hoja": "evolucion", "dirs": 8, "marcos": 20, "fps": 10.0, "loop": false},
}


static func _anims_mutante(sprite: StringName) -> Dictionary:
	return _MUT_TORMENTA.duplicate() if sprite == &"tormenta" else ANIMS.duplicate()


static func _sprite_mutante(ed: EnemyData, mutacion: StringName) -> StringName:
	var m: MutacionData = ed.mutacion_de(mutacion) if ed != null else null
	return m.sprite if m != null and LIENZOS_MUT.has(m.sprite) else &""


# LAS PUNTAS (13/11, el jefe: "los latigazos tienen que salir del tentaculo que usa para atacar"): donde esta en su sprite,
# en cada una de las 8 direcciones, el tentaculo de DELANTE en el golpe (base y Masa, fotograma 3 de 'basico') y el OJO del
# Ojo de la tormenta; y donde acaban sus tentaculos colgando. En pixeles del lienzo desde su centro, medidos en el modelo
# (tools/sprites_sdf/aberracion_efectos_horno.py, puntas()).
const PUNTAS := {
	&"": [Vector2(-13.2, 6.7), Vector2(20.6, -3.6), Vector2(16.7, 3.5), Vector2(20.6, -7.7), Vector2(12.2, -17.6),
		Vector2(-21.6, -7.2), Vector2(-17.3, 3.9), Vector2(-21.6, -3.2)],
	&"galvanica": [Vector2(-15.7, 8.1), Vector2(24.9, -4.2), Vector2(20.1, 4.4), Vector2(24.8, -9.1), Vector2(14.7, -21.0),
		Vector2(-25.9, -8.6), Vector2(-20.6, 4.8), Vector2(-25.8, -3.7)],
	&"ojo": [Vector2(0.0, -34.9), Vector2(10.6, -37.4), Vector2(12.8, -43.7), Vector2(10.3, -52.7), Vector2(-1.0, -57.5),
		Vector2(-11.6, -52.3), Vector2(-13.8, -42.7), Vector2(-11.3, -35.1)],
}
const CUELGAN := Vector2(0.0, -8.0)


# El punto del mundo donde esta esa punta en el sprite de 'cuerpo' ahora (la direccion, la de su animacion: "<anim>_<dir>").
# 'si_no' si no tiene sprite.
static func punta(cuerpo: Node2D, si_no: Vector2, clave: StringName) -> Vector2:
	if cuerpo == null:
		return si_no
	for hijo in cuerpo.get_children():
		if hijo is AnimatedSprite2D and (hijo as CanvasItem).visible and (hijo as AnimatedSprite2D).sprite_frames != null:
			var spr: AnimatedSprite2D = hijo
			var trozos: PackedStringArray = String(spr.animation).rsplit("_", true, 1)
			var d: int = clampi(trozos[1].to_int() if trozos.size() == 2 and trozos[1].is_valid_int() else 0, 0, 7)
			var q: Vector2 = CUELGAN if clave == &"cuelgan" else (PUNTAS.get(clave, PUNTAS[&""]) as Array)[d]
			var local: Vector2 = spr.offset + q
			if not spr.centered:
				var tex: Texture2D = spr.sprite_frames.get_frame_texture(spr.animation, spr.frame)
				if tex != null:
					local += tex.get_size() * 0.5
			return spr.to_global(local)
	return si_no


# --- EL SPRITE DE MUTANTE (contrato de SpritesEnemigo, como Polilla3DSprites) ---
static func tiene_mutante(ed: EnemyData, mutacion: StringName = &"") -> bool:
	return _sprite_mutante(ed, mutacion) != &""


static func clave_mutante_de(ed: EnemyData, _t: float, mutacion: StringName = &"") -> String:
	var s: StringName = _sprite_mutante(ed, mutacion)
	return "" if s == &"" else "aberracion3d_aberracion_sdf_%s" % String(s)


static func generar_mutante_de(ed: EnemyData, _t: float, mutacion: StringName = &"") -> SpriteFrames:
	var s: StringName = _sprite_mutante(ed, mutacion)
	if s == &"":
		return null
	return Sprites3D.montar("res://assets/sprites/enemigos/aberracion_sdf_%s/" % String(s), _anims_mutante(s), LIENZOS_MUT[s],
		BASE, BASE)
