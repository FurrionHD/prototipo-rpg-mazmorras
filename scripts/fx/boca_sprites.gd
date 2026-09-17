# ============================================================
#  boca_sprites.gd
#  LA BOCA, aparte de los ojos (se eligen por separado: lo pidio el usuario, con una hoja de emojis en
#  pixel art de referencia). Misma tecnica que CaraSprites: un SELLO de pixeles estampado donde cae la
#  boca en este fotograma, y la misma paleta (no se tiñe).
#
#  Se carga por preload desde JugadorSprites y no lleva class_name: un class_name nuevo no existe para
#  las herramientas de linea de comandos hasta pasar --import (ver hornear_sprites.bat).
# ============================================================
extends RefCounted

const PIEZA := "boca"

const R := PoseJugador.CABEZA_R

# Los dibujos, de arriba abajo. Letras de CaraSprites.LETRAS: B raya · D por dentro · T lengua.
const BOCAS := {
	"recta": ["BBB"],
	"sonrisa": ["B..B", ".BB."],
	"abierta": ["BBBB", "BDDB", ".BB."],
	"o": ["BB", "BB"],   # con hueco dentro (".B./BDB/.B.") se leia como una cruz
	"lengua": ["BBBB", ".TT."],
	"media": ["...B", "BBB."],
	"triste": [".BB.", "B..B"],
}


static func frames(modelo: String, esc: float = 1.0) -> SpriteFrames:
	return CapaJugador.frames(clave(modelo), pintar.bind(modelo), CaraSprites.colores(), esc)


static func generar(modelo: String, esc: float = 1.0) -> SpriteFrames:
	return CapaJugador.generar(clave(modelo), pintar.bind(modelo), CaraSprites.colores(), esc)


static func clave(modelo: String) -> String:
	return "%s_%s" % [PIEZA, modelo]


static func pintar(esq: Dictionary, piezas: Array, modelo: String) -> void:
	var d: int = int(esq.get("dir", 0))
	if d == 3 or d == 4 or d == 5:
		return
	var dibujo: Array = BOCAS.get(modelo, [])
	if dibujo.is_empty():
		return
	var cab: Vector3 = esq["puntos"][PoseJugador.P_CABEZA]
	var de_perfil: bool = d == 2 or d == 6
	# De perfil la boca se corre hacia el lado al que mira (el mismo que el unico ojo que se dibuja).
	var dx: float = 0.0
	if de_perfil:
		# El signo es el de CaraSprites de antes (-lados[0]); al reves la boca subia por encima del ojo.
		dx = (1.0 if d == 6 else -1.0) * R * CaraSprites.BOCA_PERFIL
	var pos: Vector2 = PoseJugador.proyectar(esq,
		cab + Vector3(dx, R * CaraSprites.OJO_FONDO, R * CaraSprites.BOCA_ALTO),
		Vector3(R * 0.1, R * 0.1, R * 0.1))["pos"]
	# En DIAGONAL y DE PERFIL la boca caia en la fila de abajo del ojo: un pixel mas abajo.
	if d == 1 or d == 7 or de_perfil:
		pos.y += 1.0
	var centro0: Vector2 = PoseJugador.proyectar(esq, cab, Vector3(R, R, R))["pos"]
	pos = CaraSprites.hacia_dentro(pos, centro0, String(dibujo[0]).length(), d)
	# DE PERFIL, SOLO LA MITAD DE DELANTE: una sonrisa entera de lado se lee como un bigote cruzando la
	# mejilla. Se quedan las columnas del lado hacia el que queda la cara.
	var columnas: Array = []
	if de_perfil:
		var centro: Vector2 = PoseJugador.proyectar(esq, cab, Vector3(R, R, R))["pos"]
		var ancho: int = String(dibujo[0]).length()
		var delante_derecha: bool = pos.x >= centro.x
		for i in ancho:
			if (i >= ancho / 2) == delante_derecha:
				columnas.append(i)
	CaraSprites.sello(piezas, pos, dibujo, false, false, columnas)
