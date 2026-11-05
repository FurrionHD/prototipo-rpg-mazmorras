# ============================================================
#  escarabajo3d_sprites.gd  (class_name Escarabajo3DSprites)
#  EL ESCARABAJO DE HIERRO EN 3D (05/10/2026): el domo con su brillo de metal; se hace BOLA y RUEDA, y muere panza arriba.
#  Se modela en tools/sprites_sdf/escarabajo_sdf.py y aqui solo se cargan sus hojas (Sprites3D, con el tinte de cada piso).
#  Los tiempos de cada gesto son los del viejo, asi que sus efectos caen igual. El viejo (EscarabajoSprites, por codigo) queda
#  de referencia.
# ============================================================

extends RefCounted
class_name Escarabajo3DSprites

const CARPETA := "res://assets/sprites/enemigos/escarabajo_sdf/"
# El lienzo del generador viejo a su escala (y el del script de python): el juego lo coloca igual.
const LIENZO := Vector2i(80, 80)
# El color en que estan pintadas las hojas (el de su ficha).
const BASE := Color("5c8055")

const ANIMS := {
	"idle": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 3.0, "loop": true},
	"walk": {"hoja": "walk", "dirs": 8, "marcos": 8, "fps": 7.0, "loop": true},
	"embestida": {"hoja": "embestida", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	# EL PALAZO: empuja con la pala en la mitad.
	"basico": {"hoja": "basico", "dirs": 8, "marcos": 6, "fps": 16.0, "loop": false},
	# Se aplasta del todo en el 0,571 (sale el reflejo del efecto).
	"caparazon": {"hoja": "caparazon", "dirs": 8, "marcos": 8, "fps": 9.0, "loop": false},
	"hacerse_bola": {"hoja": "hacerse_bola", "dirs": 8, "marcos": 6, "fps": 12.0, "loop": false},
	"bola": {"hoja": "bola", "dirs": 8, "marcos": 8, "fps": 8.0, "loop": true},
	# Dos vueltas a 90 grados por marco y se desenrosca (= InsectoAire.T_RODADA).
	"rodar": {"hoja": "rodar", "dirs": 8, "marcos": 12, "fps": 18.0, "loop": false},
	"desenroscarse": {"hoja": "desenroscarse", "dirs": 8, "marcos": 5, "fps": 12.0, "loop": false},
	"encaje": {"hoja": "encaje", "dirs": 8, "marcos": 4, "fps": 18.0, "loop": false},
	"muerte": {"hoja": "muerte", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"cadaver": {"hoja": "muerte", "dirs": 8, "marcos": 1, "desde": 7, "fps": 1.0, "loop": false},
	# COMER UN CRISTAL (04/11, sus mutantes).
	"comer": {"hoja": "comer", "dirs": 8, "marcos": 10, "fps": 10.0, "loop": false, "opcional": true},
}

# LOS MUTANTES DEL ESCARABAJO (04/11, escarabajo-mutante): su carpeta y sus animaciones (tools/sprites_sdf/escarabajo_mut_sdf.py).
# Ya vienen a su tamaño y con SU color (sin el tinte del piso). Su 'embestida' de siempre es su basico.
const LIENZO_MUT := Vector2i(136, 224)
const _MUT_COMUN := {
	"basico": {"hoja": "basico", "dirs": 8, "marcos": 6, "fps": 16.0, "loop": false},
	"embestida": {"hoja": "basico", "dirs": 8, "marcos": 6, "fps": 16.0, "loop": false},
	"encaje": {"hoja": "encaje", "dirs": 8, "marcos": 4, "fps": 18.0, "loop": false},
	"muerte": {"hoja": "muerte", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"cadaver": {"hoja": "muerte", "dirs": 8, "marcos": 1, "desde": 7, "fps": 1.0, "loop": false},
	"comer": {"hoja": "comer", "dirs": 8, "marcos": 10, "fps": 10.0, "loop": false},
	"evolucion": {"hoja": "evolucion", "dirs": 8, "marcos": 18, "fps": 10.0, "loop": false},
}
const _MUT_VUELO := {
	"idle": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": true},
	"walk": {"hoja": "walk", "dirs": 8, "marcos": 6, "fps": 18.0, "loop": true},
	"pasada": {"hoja": "pasada", "dirs": 8, "marcos": 6, "fps": 18.0, "loop": true},
	"subir": {"hoja": "subir", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": false},
	"aire": {"hoja": "aire", "dirs": 8, "marcos": 6, "fps": 14.0, "loop": true},
	"picado": {"hoja": "picado", "dirs": 8, "marcos": 8, "fps": 14.0, "loop": false},
	# DERRIBADO: aturdido o bajado del aire cae, se queda panza arriba y se recoloca.
	"caer": {"hoja": "caer", "dirs": 8, "marcos": 8, "fps": 14.0, "loop": false},
	"volteado": {"hoja": "volteado", "dirs": 8, "marcos": 6, "fps": 10.0, "loop": true},
	"recolocarse": {"hoja": "recolocarse", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": false},
}
const _MUT_PULSO := {
	"pulso_carga": {"hoja": "pulso_carga", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": true},
	"pulso": {"hoja": "pulso", "dirs": 8, "marcos": 6, "fps": 14.0, "loop": false},
}
const _MUT_IMAN := {
	"idle": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 3.0, "loop": true},
	"walk": {"hoja": "walk", "dirs": 8, "marcos": 8, "fps": 6.0, "loop": true},
	"caparazon": {"hoja": "caparazon", "dirs": 8, "marcos": 8, "fps": 9.0, "loop": false},
	"embestir_carga": {"hoja": "embestir_carga", "dirs": 8, "marcos": 8, "fps": 8.0, "loop": true},
	"embestir": {"hoja": "embestir", "dirs": 8, "marcos": 8, "fps": 18.0, "loop": true},
}
const _MUT_SAETA := {
	"elitros": {"hoja": "elitros", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": false},
}
const _MUT_ERRANTE := {
	"evolucion_saeta": {"hoja": "evolucion_saeta", "dirs": 8, "marcos": 18, "fps": 10.0, "loop": false},
}


static func _anims_mutante(sprite: StringName) -> Dictionary:
	var a: Dictionary = _MUT_COMUN.duplicate()
	match sprite:
		&"iman":
			a.merge(_MUT_IMAN)
			a.merge(_MUT_PULSO)
		&"saeta":
			a.merge(_MUT_VUELO)
			a.merge(_MUT_SAETA)
		&"errante":
			a.merge(_MUT_VUELO)
			a.merge(_MUT_PULSO)
			a.merge(_MUT_ERRANTE)
	return a


static func _sprite_mutante(ed: EnemyData, mutacion: StringName) -> StringName:
	var m: MutacionData = ed.mutacion_de(mutacion) if ed != null else null
	return m.sprite if m != null and m.sprite in [&"iman", &"saeta", &"errante"] else &""


# --- EL SPRITE DE MUTANTE (contrato de SpritesEnemigo, como Jabali3DSprites) ---
static func tiene_mutante(ed: EnemyData, mutacion: StringName = &"") -> bool:
	return _sprite_mutante(ed, mutacion) != &""


static func clave_mutante_de(ed: EnemyData, _t: float, mutacion: StringName = &"") -> String:
	var s: StringName = _sprite_mutante(ed, mutacion)
	return "" if s == &"" else "escarabajo3d_escarabajo_sdf_%s" % String(s)


static func generar_mutante_de(ed: EnemyData, _t: float, mutacion: StringName = &"") -> SpriteFrames:
	var s: StringName = _sprite_mutante(ed, mutacion)
	if s == &"":
		return null
	return Sprites3D.montar("res://assets/sprites/enemigos/escarabajo_sdf_%s/" % String(s), _anims_mutante(s), LIENZO_MUT, BASE, BASE)


# --- Contrato de SpritesEnemigo ---
static func generar_de(ed: EnemyData, t: float) -> SpriteFrames:
	return generar(ed.color_visual(t))


# 'escarabajo3d_' y no 'escarabajo_': con la clave vieja, SpritesEnemigo cargaria el horneado VIEJO de disco.
static func clave_de(ed: EnemyData, t: float) -> String:
	return "escarabajo3d_%s" % SpriteLienzo.cuantizar_hsv(ed.color_visual(t), EscarabajoSprites.COLOR_PASOS).to_html(false)


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(_escala: float = 1.0) -> int:
	return LIENZO.x


static func dimensiona_por_escala() -> bool:
	return true


static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	return EscarabajoSprites.tam_cuerpo(escala)


static func generar(color: Color = BASE) -> SpriteFrames:
	return Sprites3D.montar(CARPETA, ANIMS, LIENZO, BASE, SpriteLienzo.cuantizar_hsv(color, EscarabajoSprites.COLOR_PASOS))
