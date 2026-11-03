# ============================================================
#  arana3d_sprites.gd  (class_name Arana3DSprites)
#  LA ARAÑA DE LAS SIMAS EN 3D (05/10/2026): ocho patas en el mundo (anda a tetrapodo, se alza, se enrosca al morir).
#  Se modela en tools/sprites_sdf/arana_sdf.py y aqui solo se cargan sus hojas (Sprites3D, con el tinte de cada piso).
#  Los tiempos de cada gesto son los del viejo, asi que sus efectos caen igual. El viejo (AranaSprites, por codigo) queda
#  de referencia.
# ============================================================

extends RefCounted
class_name Arana3DSprites

const CARPETA := "res://assets/sprites/enemigos/arana_sdf/"
# El lienzo del generador viejo a su escala (y el del script de python): el juego lo coloca igual.
const LIENZO := Vector2i(90, 90)
# El color en que estan pintadas las hojas (el de su ficha).
const BASE := Color("635580")

const ANIMS := {
	"idle": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 3.0, "loop": true},
	"walk": {"hoja": "walk", "dirs": 8, "marcos": 8, "fps": 11.0, "loop": true},
	# SE ALZA y se deja caer encima: el avance llega en el 0,72.
	"embestida": {"hoja": "embestida", "dirs": 8, "marcos": 8, "fps": 11.0, "loop": false},
	"muerte": {"hoja": "muerte", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	# LA TELARAÑA: baja la cabeza, sube el abdomen y dispara en el 0,45.
	"telarana": {"hoja": "telarana", "dirs": 8, "marcos": 10, "fps": 12.0, "loop": false},
	# EL PONZOÑOSO: clava en el 0,44 y se queda apretando.
	"mordisco": {"hoja": "mordisco", "dirs": 8, "marcos": 10, "fps": 14.0, "loop": false},
	# PICA (cierra los queliceros) en el 0,45.
	"basico": {"hoja": "basico", "dirs": 8, "marcos": 8, "fps": 16.0, "loop": false},
	"encaje": {"hoja": "encaje", "dirs": 8, "marcos": 4, "fps": 18.0, "loop": false},
	"cadaver": {"hoja": "muerte", "dirs": 8, "marcos": 1, "desde": 7, "fps": 1.0, "loop": false},
	# COMER UN CRISTAL y LA EVOLUCION (03/11, los mutantes de la araña).
	"comer": {"hoja": "comer", "dirs": 8, "marcos": 10, "fps": 10.0, "loop": false, "opcional": true},
	"evolucion": {"hoja": "evolucion", "dirs": 8, "marcos": 18, "fps": 10.0, "loop": false, "opcional": true},
	# LA TEJEDORA: el Hilo al rojo (dispara en el 0,4, tira en el 0,6), el Capullo (tejiendo en bucle y soltando en el
	# 0,35) y la Explosion (revienta en el 0,3).
	"hilo": {"hoja": "hilo", "dirs": 8, "marcos": 10, "fps": 12.0, "loop": false, "opcional": true},
	"capullo_carga": {"hoja": "capullo_carga", "dirs": 8, "marcos": 8, "fps": 8.0, "loop": true, "opcional": true},
	"capullo": {"hoja": "capullo", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false, "opcional": true},
	"explosion": {"hoja": "explosion", "dirs": 8, "marcos": 8, "fps": 14.0, "loop": false, "opcional": true},
	# LA TORMENTOSA: el Pisoton (cae en el 0,5), el Salto (despega en el 0,25, cae en el 0,72) y la Descarga (0,3).
	"pisoton": {"hoja": "pisoton", "dirs": 8, "marcos": 10, "fps": 12.0, "loop": false, "opcional": true},
	"salto": {"hoja": "salto", "dirs": 8, "marcos": 10, "fps": 12.0, "loop": false, "opcional": true},
	"descarga": {"hoja": "descarga", "dirs": 8, "marcos": 8, "fps": 14.0, "loop": false, "opcional": true},
}

# LOS MUTANTES DE LA ARAÑA (03/11, arana-mutante): UNA LINEA. La TEJEDORA DE BRASAS (1a: el abdomen es una jaula de carbon
# con ascuas) y la ARAÑA TORMENTOSA (2a: un globo de hilos de luz). Cada una CON SU CUERPO, de
# tools/sprites_sdf/arana_mutantes_sdf.py: [carpeta, lienzo, sus animaciones, grupos de hilos]. Ya vienen a su tamaño y
# con su color (sin el tinte del piso). LOS HILOS de la Tormentosa van como los ojos del slime de mil ojos: una hoja
# de capa por grupo (<anim>_parpado<N>.png), y el juego los enciende cada uno a su aire.
const _COMUNES_MUT := ["idle", "walk", "embestida", "telarana", "basico", "encaje", "muerte", "cadaver", "comer", "evolucion"]
const GRUPOS_HILOS := 4
const MUTANTES := {
	&"tejedora": ["arana_sdf_tejedora", Vector2i(160, 150), _COMUNES_MUT + ["hilo", "capullo_carga", "capullo", "explosion"], 0],
	&"tormentosa": ["arana_sdf_tormentosa", Vector2i(180, 190), _COMUNES_MUT + ["mordisco", "pisoton", "salto", "descarga"], 4],
}


# --- Contrato de SpritesEnemigo ---
static func generar_de(ed: EnemyData, t: float) -> SpriteFrames:
	return generar(ed.color_visual(t))


# 'arana3d_' y no 'arana_': con la clave vieja, SpritesEnemigo cargaria el horneado VIEJO de disco.
static func clave_de(ed: EnemyData, t: float) -> String:
	return "arana3d_%s" % SpriteLienzo.cuantizar_hsv(ed.color_visual(t), AranaSprites.COLOR_PASOS).to_html(false)


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(_escala: float = 1.0) -> int:
	return LIENZO.x


static func dimensiona_por_escala() -> bool:
	return true


static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	return AranaSprites.tam_cuerpo(escala)


static func generar(color: Color = BASE) -> SpriteFrames:
	return Sprites3D.montar(CARPETA, ANIMS, LIENZO, BASE, SpriteLienzo.cuantizar_hsv(color, AranaSprites.COLOR_PASOS))


# --- EL SPRITE DE MUTANTE (contrato de SpritesEnemigo, como Trent3DSprites) ---
static func _variante_mutante(ed: EnemyData, mutacion: StringName) -> Array:
	var m: MutacionData = ed.mutacion_de(mutacion) if ed != null else null
	if m == null or not MUTANTES.has(m.sprite):
		return []
	return MUTANTES[m.sprite]


static func _anims_de(lista: Array) -> Dictionary:
	var anims := {}
	for k in lista:
		anims[k] = ANIMS[k].duplicate()
	return anims


static func tiene_mutante(ed: EnemyData, mutacion: StringName = &"") -> bool:
	return not _variante_mutante(ed, mutacion).is_empty()


# Sin tinte: la clave no lleva color (es siempre el mismo).
static func clave_mutante_de(ed: EnemyData, _t: float, mutacion: StringName = &"") -> String:
	var v: Array = _variante_mutante(ed, mutacion)
	return "" if v.is_empty() else "arana3d_%s" % String(v[0])


static func generar_mutante_de(ed: EnemyData, _t: float, mutacion: StringName = &"") -> SpriteFrames:
	var v: Array = _variante_mutante(ed, mutacion)
	if v.is_empty():
		return null
	return Sprites3D.montar("res://assets/sprites/enemigos/%s/" % String(v[0]), _anims_de(v[2]), v[1], BASE, BASE)


# --- LOS HILOS DE LA TORMENTOSA (contrato de SpritesEnemigo: van por los parpados, como los ojos del de mil ojos) ---
static func _hilos(ed: EnemyData, mutacion: StringName, grupo: int) -> SpriteFrames:
	var v: Array = _variante_mutante(ed, mutacion)
	if v.is_empty() or int(v[3]) < grupo:
		return null
	var sufijo: String = "_parpado" if grupo <= 1 else "_parpado%d" % grupo
	return Sprites3D.montar("res://assets/sprites/enemigos/%s/" % String(v[0]), _anims_de(v[2]), v[1], BASE, BASE, sufijo)


static func parpados_de(ed: EnemyData, _t: float, mutante: bool = false, mutacion: StringName = &"") -> SpriteFrames:
	return _hilos(ed, mutacion, 1) if mutante else null


static func parpados_extra_de(ed: EnemyData, _t: float, mutante: bool = false, mutacion: StringName = &"") -> Array:
	var out: Array = []
	if mutante:
		for g in range(2, GRUPOS_HILOS + 1):
			var f: SpriteFrames = _hilos(ed, mutacion, g)
			if f != null:
				out.append(f)
	return out


# Los hilos sin cargas (TacticoArana.HILOS, el primero): en la pelea el ritmo sube con ellas.
static func ritmo_parpados() -> Array:
	return [0.5, 1.2, 3.0]
