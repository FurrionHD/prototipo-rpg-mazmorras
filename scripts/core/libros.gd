# ============================================================
#  libros.gd  --  GENERADO por tools/generar_tochos.gd. NO EDITAR A MANO.
#
#  La lista de TODOS los libros que existen, para que la Biblioteca pueda enseñar los que
#  te faltan y no solo los que tienes. Va escrita y no escaneada porque DirAccess sobre
#  res:// no es de fiar en el .exe (mismo motivo que Game._MANIFIESTO_PLANTILLAS).
#
#  Para cambiarla: toca la tabla de tools/generar_tochos.gd y vuelve a pasar
#  herramientas/generar_tochos.bat.
# ============================================================

class_name Libros

# Todos los hechizos del juego. La fuente es la tabla RAREZAS de tools/generar_tochos.gd,
# que ya falla si un .tres de la carpeta no esta apuntado: por ahi no se puede quedar corta.
const HECHIZOS: Array[String] = [
	"res://resources/spells/bola_fuego.tres",
	"res://resources/spells/brasa.tres",
	"res://resources/spells/chorro_agua.tres",
	"res://resources/spells/debilidad.tres",
	"res://resources/spells/descarga.tres",
	"res://resources/spells/filo_ardiente.tres",
	"res://resources/spells/filo_fulgurante.tres",
	"res://resources/spells/filo_torrente.tres",
	"res://resources/spells/fortaleza.tres",
	"res://resources/spells/manto_brasas.tres",
	"res://resources/spells/manto_centellas.tres",
	"res://resources/spells/manto_marea.tres",
	"res://resources/spells/pulso_arcano.tres",
	"res://resources/spells/pulso_menor.tres",
	"res://resources/spells/rayo.tres",
	"res://resources/spells/rocio.tres",
	"res://resources/spells/shock_termico.tres",
	"res://resources/spells/tormenta.tres",
]

const TOCHOS: Array[String] = [
	"res://resources/consumables/tochos/actas_torre.tres",
	"res://resources/consumables/tochos/antorchas.tres",
	"res://resources/consumables/tochos/botas.tres",
	"res://resources/consumables/tochos/boticario.tres",
	"res://resources/consumables/tochos/cartas.tres",
	"res://resources/consumables/tochos/cortesia.tres",
	"res://resources/consumables/tochos/croquis.tres",
	"res://resources/consumables/tochos/cuentas_gremio.tres",
	"res://resources/consumables/tochos/errores_propios.tres",
	"res://resources/consumables/tochos/escaleras.tres",
	"res://resources/consumables/tochos/estoque_rodela.tres",
	"res://resources/consumables/tochos/goteras.tres",
	"res://resources/consumables/tochos/guardia.tres",
	"res://resources/consumables/tochos/guia_descenso.tres",
	"res://resources/consumables/tochos/humedad.tres",
	"res://resources/consumables/tochos/indice_biblioteca.tres",
	"res://resources/consumables/tochos/inventario_almacen.tres",
	"res://resources/consumables/tochos/nombrar_espada.tres",
	"res://resources/consumables/tochos/perro.tres",
	"res://resources/consumables/tochos/piedra_tacto.tres",
	"res://resources/consumables/tochos/precio_kebab.tres",
	"res://resources/consumables/tochos/puertas.tres",
	"res://resources/consumables/tochos/rata_comun.tres",
	"res://resources/consumables/tochos/rata_segundo.tres",
	"res://resources/consumables/tochos/respiracion.tres",
	"res://resources/consumables/tochos/setas.tres",
	"res://resources/consumables/tochos/silencio.tres",
	"res://resources/consumables/tochos/sopa.tres",
	"res://resources/consumables/tochos/suenos.tres",
	"res://resources/consumables/tochos/versos_pozo.tres",
]

const GRIMORIOS: Array[String] = [
	"res://resources/consumables/grimorio_bola_fuego.tres",
	"res://resources/consumables/grimorio_brasa.tres",
	"res://resources/consumables/grimorio_chorro_agua.tres",
	"res://resources/consumables/grimorio_debilidad.tres",
	"res://resources/consumables/grimorio_descarga.tres",
	"res://resources/consumables/grimorio_filo_ardiente.tres",
	"res://resources/consumables/grimorio_filo_fulgurante.tres",
	"res://resources/consumables/grimorio_filo_torrente.tres",
	"res://resources/consumables/grimorio_fortaleza.tres",
	"res://resources/consumables/grimorio_manto_brasas.tres",
	"res://resources/consumables/grimorio_manto_centellas.tres",
	"res://resources/consumables/grimorio_manto_marea.tres",
	"res://resources/consumables/grimorio_pulso_arcano.tres",
	"res://resources/consumables/grimorio_rayo.tres",
	"res://resources/consumables/grimorio_rocio.tres",
	"res://resources/consumables/grimorio_shock_termico.tres",
	"res://resources/consumables/grimorio_tormenta.tres",
]


# Los 46 de golpe, que es lo que recorre la Biblioteca.
static func todos() -> Array[String]:
	var out: Array[String] = []
	out.append_array(GRIMORIOS)
	out.append_array(TOCHOS)
	return out
