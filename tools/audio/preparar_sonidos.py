# -*- coding: utf-8 -*-
"""
preparar_sonidos.py
Convierte los sonidos descargados a lo que el juego sabe leer.

QUE HACE
  1. SFX del jugador  Descargas/sonidos para los ataques de los personajes/  ->  audio/sfx/*.wav
     Estereo->mono, quita el silencio de los dos extremos, recorta y funde la salida.
  2. Ambiente         Descargas/Sonidos ambiente/                            ->  audio/ambiente/
     Los cortos como .wav mono; los bucles largos a .ogg.
  3. Musica           Descargas/Musicas/                                     ->  audio/musica/<contexto>/*.ogg

POR QUE NO SE TOCAN LOS ORIGINALES: el usuario los va a reeditar. Este guion es idempotente, o
sea que se vuelve a lanzar despues de cada reedicion y rehace la carpeta del juego entera.

EL NOMBRE DE SALIDA ES LA CLAVE. Una sola version se llama sfx_<clave>.wav; varias, sfx_<clave>_v1
.. _vN, y Sonido sortea una en cada disparo. Ver audio/sfx/LEEME.md.

DEPENDENCIAS: para el OGG hace falta ffmpeg. Se busca primero el del paquete `imageio-ffmpeg`
(pip install imageio-ffmpeg, no pide admin) y si no, el del PATH. Los WAV cortos van con `wave` +
`array` de la biblioteca estandar: en Python 3.14 ya NO existe `audioop`.
"""

import array
import math
import os
import shutil
import subprocess
import sys
import wave

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DESCARGAS = os.path.join(os.path.expanduser("~"), "Downloads")

ORIG_SFX = os.path.join(DESCARGAS, "sonidos para los ataques de los personajes")
ORIG_AMB = os.path.join(DESCARGAS, "Sonidos ambiente")
ORIG_MUS = os.path.join(DESCARGAS, "Musicas")
# Los de enemigos son de una tanda anterior y ya vienen recortados: de ahi la subcarpeta.
ORIG_ENE = os.path.join(DESCARGAS, "sonidos para los ataques de los enemigos", "recortados")

# COMO SE LLAMABAN Y COMO SE LLAMAN. Los sonidos de enemigos se generaron con el nombre del prompt
# ("pisoton atronador") y el juego los busca por la clave de la habilidad o del estilo
# ("minotauro_pisoton"). Lo que no esta aqui se copia con su nombre tal cual.
RENOMBRES = {
	"sfx_alarido.wav": "sfx_aberracion_alarido.wav",
	"sfx_mirada_vacio_v1.wav": "sfx_aberracion_mirada_v1.wav",
	"sfx_mirada_vacio_v2.wav": "sfx_aberracion_mirada_v2.wav",
	"sfx_mirada_vacio_v3.wav": "sfx_aberracion_mirada_v3.wav",
	"sfx_carga_acorazada.wav": "sfx_bestia_carga.wav",
	"sfx_pisoton_sismico.wav": "sfx_coloso_pisoton.wav",
	"sfx_mirada_petrea_v1.wav": "sfx_gargola_mirada_v1.wav",
	"sfx_mirada_petrea_v2.wav": "sfx_gargola_mirada_v2.wav",
	"sfx_picado.wav": "sfx_gargola_picado.wav",
	"sfx_machaca.wav": "sfx_golem_machaca.wav",
	"sfx_bramido.wav": "sfx_minotauro_bramido.wav",
	"sfx_cornada_minotauro.wav": "sfx_minotauro_cornada.wav",
	"sfx_pisoton_atronador_v1.wav": "sfx_minotauro_pisoton_v1.wav",
	"sfx_pisoton_atronador_v2.wav": "sfx_minotauro_pisoton_v2.wav",
	"sfx_aplastamiento_v1.wav": "sfx_rey_slime_aplastamiento_v1.wav",
	"sfx_aplastamiento_v2.wav": "sfx_rey_slime_aplastamiento_v2.wav",
	"sfx_aplastamiento_v3.wav": "sfx_rey_slime_aplastamiento_v3.wav",
	"sfx_aplastamiento_v4.wav": "sfx_rey_slime_aplastamiento_v4.wav",
	"sfx_ramazo_v1.wav": "sfx_trent_ramazo_v1.wav",
	"sfx_ramazo_v2.wav": "sfx_trent_ramazo_v2.wav",
	"sfx_savia.wav": "sfx_trent_savia_corrosiva.wav",
}

DEST_SFX = os.path.join(RAIZ, "audio", "sfx")
DEST_AMB = os.path.join(RAIZ, "audio", "ambiente")
DEST_MUS = os.path.join(RAIZ, "audio", "musica")

# ============================================================
#  EL MANIFIESTO
#
#  (carpeta de origen, principio del prompt) -> (clave, modo)
#
#  El "principio del prompt" es el nombre del fichero hasta el '#': asi lo dejo el generador y es
#  lo unico que queda para saber que era cada cosa. Varios ficheros con el mismo principio son
#  VERSIONES de la misma clave.
#
#  LA CLAVE es el CombatFX.Estilo en minusculas. Todas las habilidades del jugador tienen estilo
#  propio, asi que ninguna necesita entrar en Sonido.CLAVES (esa lista es solo para las enemigas
#  que comparten dibujo, y su orden viaja por red).
#
#  MODOS:
#    ""              recorta silencios y funde. Lo normal.
#    "primer_golpe"  la muestra trae 2-3 impactos y la habilidad ya suena una vez POR golpe: se
#                    corta justo antes del segundo, o sonarian nueve estocadas en vez de tres.
#    "largo"         no es un impacto sino un estado (cubrir el filo, echarse el manto): la
#                    muestra dura 20 s y se recorta a TOPE_LARGO.
#    (a, b)          ventana a mano, en segundos. El buscador automatico de golpes acierta en la
#                    mayoria, pero hay muestras donde los impactos estan FUNDIDOS (la carniceria
#                    del hacha es una masa sostenida, no tres hachazos) o donde el bueno es el
#                    SEGUNDO y no el primero. Ahi se dice el trozo y se acabo.
#
#  Las que se quedan ENTERAS a proposito aunque la habilidad sea de varios golpes van marcadas con
#  un comentario: son las que no tienen costura por donde cortar.
# ============================================================

TOPE_NORMAL = 2.0    # segundos: ningun golpe del jugador dura mas que esto
TOPE_LARGO = 1.8     # segundos: los estados, recortados a una pincelada
FUNDIDO_MS = 30      # el corte a pelo hace 'clic'

SFX = {
	"Daga": {
		"Quick_dagger_slash_t": ("daga_corte", ""),
		# El primer tajo casi no suena y el gordo es el SEGUNDO: se coge ese.
		"Two_dagger_slashes_b": ("daga_rafaga", (0.19, 0.36)),
		"Dagger_stab,_aimed_a": ("punalada", ""),
		"Coating_a_blade_by_h": ("imbuir_filo", "largo"),
		"Rogue_vanishes_in_sm": ("desvanecer", ""),
	},
	"Estoque": {
		"Rapier_point_punches": ("estoque_punzada", ""),
		"Rapier_lunge_held": ("estocada_penetrante", ""),
		"Two_light_feinting_p": ("fintas", "primer_golpe"),
		"Rapier_snaps_into": ("en_guardia", ""),
		"Light_nimble_footwor": ("paso_ligero", ""),
		"Precise_targeted_rap": ("punzada_nervio", ""),
		# Suena una sola estocada aunque el prompt pidiera tres: no hay nada que cortar.
		"Three_quick_rapier_t": ("danza_acero", ""),
	},
	"Espada Corta": {
		"Short-sword_slash_cl": ("espada_tajo", ""),
		"Heavier_wind-up_slas": ("cambio_ritmo", ""),
		"Two_crossing_sword_s": ("doble_tajo", "primer_golpe"),
		"Sword_slash_that_bre": ("tajo_quebrantador", ""),
		# Los dos cortes salen FUNDIDOS en una masa sostenida, sin valle: se deja entera.
		"Precise_thin_sword_s": ("senalar_hueco", ""),
		"Low_sweeping_sword_c": ("corte_tendones", ""),
	},
	"Espada Larga": {
		"Longsword_heavy_slas": ("espada_larga_tajo", ""),
		"Blade_raised_then_fa": ("tajo_pesado", ""),
		"Angled_longsword_sla": ("tajo_desarmante", ""),
		"Forceful_slash_break": ("guardia_rota", ""),
		"Longsword_planted_po": ("voto_guardia", ""),
		"Disciplined_longswor": ("estocada_marcial", ""),
		"Commanding_battle_sh": ("voz_mando", ""),
		"Shield_boss_slams_in": ("escudazo", ""),
	},
	"Mandoble": {
		"Wide_overhead_greatsword": ("mandoble_tajo", ""),
		"Massive_two-handed_g": ("tajo_devastador", ""),
		"Spinning_greatsword": ("molinete", ""),
		"Rousing_war_cry_that": ("grito_guerra", ""),
		"Greatsword_raised_hi": ("tajo_verdugo", ""),
		"Low_horizontal_scyth": ("segar", ""),
		"Greatsword_held_aloft_l": ("acero_en_alto", ""),
	},
	"Maza Pequeña": {
		"Small_mace_head_stri": ("maza_golpe", ""),
		"Heavy_overhead_mace": ("golpe_demoledor", ""),
		"Low_mace_strike_aime": ("rompepiernas", ""),
		"Two_blunt_impacts_cl": ("aplastamiento", "primer_golpe"),
		"Warm_encouraging_ral": ("grito_aliento", ""),
		"Shields_and_armor_pl": ("muro_aliados", ""),
		"Short_sharp_mace-haf": ("culatazo", ""),
	},
	"Hacha Grande": {
		"Big_axe_slash_into_f": ("hacha_tajo", ""),
		"Wide_cleaving_axe": ("hendedura", ""),
		"Massive_overhead_axe": ("hachazo_brutal", ""),
		# Igual que senalar_hueco: una rampa y una masa, los tres hachazos no se separan.
		"Three_rapid_uneven_a": ("carniceria", ""),
		"Axe_blade_dragged_th": ("desgarro", ""),
		"A_low_guttural_inhal": ("sed_sangre", ""),
	},
	"Martillo Grande": {
		"Huge_hammer_head_str": ("martillo_golpe", ""),
		"Hammer_slams_the_flo": ("golpe_sismico", ""),
		"Hammer_impact_sends": ("onda_expansiva", ""),
		"Sharp_precise_hammer": ("rompecorazas", ""),
		"Hammer_raised_high_o": ("martillo_guerra", ""),
		"Hammer_held_aloft_wi": ("martillo_en_alto", ""),
		"Repeated_ground_poun": ("temblor_suelo", ""),
	},
	"Baston": {
		"Light_wooden_staff_s": ("baston_golpe", ""),
		"Staff_swung_harder_d": ("bastonazo", ""),
		"Arcane_energy_gather": ("foco_arcano", ""),
		"A_glowing_rune_trace": ("sello_arcano", ""),
		"A_shadow_cloak_falls": ("velo_umbrio", "largo"),
		"A_clean_gust_sweeps": ("viento_limpio", ""),
	},
	"Puños": {
		"Bare-knuckle_punch_q": ("punos_golpe", ""),
	},
	"Escudo": {
		"Shield-first_charge": ("embestida_escudo", ""),
		"A_short_biting_taunt": ("provocacion_fx", ""),
		"A_shield_locks_into": ("guardia_carne_fx", ""),
		"A_shield_shifts_quic": ("cobertura", ""),
	},
	"Varita": {
		"A_soft_cleansing_chi": ("purificar", ""),
		"A_small_spark_of_lig": ("chispa_vinculada", ""),
		"A_faint_protective_w": ("egida_menor", ""),
	},
	# Los genericos que quedaban mudos: son los estilos que comparten TODOS los hechizos y armas
	# a distancia, y el MELEE del puñetazo pelado.
	"magias": {
		"Plain_unarmed_contac": ("melee", ""),
		"A_small_magic_bolt_l": ("proyectil", ""),
		"A_raw_arcane_bolt_tr": ("arcano", ""),
		"A_quick_lightning_bo": ("rayo", ""),
		"Lightning_strikes_do": ("caida_rayo", ""),
		"A_heavy_droplet_fall": ("caida_gota", ""),
		"An_arrow_is_loosed_a": ("arco", ""),
		"A_small_blast_bursts": ("explosion", ""),
	},
	# LA CAPA DEL ELEMENTO: no reemplaza al golpe, suena ENCIMA. Por eso su clave lleva 'elem_' y
	# no es ningun estilo. Ver Sonido.golpe.
	"Capas Elementales": {
		"Brief_ignition_layer": ("elem_fuego", ""),
		"Light_splash_layered": ("elem_agua", ""),
		"Sharp_electric_crack": ("elem_rayo", ""),
		"Toxic_hiss_layered_o": ("elem_veneno", ""),
	},
}

# Los cortos del ambiente: se sueltan de vez en cuando, como un golpe mas.
AMB_CORTOS = {
	"aleteo": "aleteo",
	"burbujeo": "burbujeo",
	"chillido": "chillido",           # no choca con el estilo de la rata: lleva prefijo amb_
	"crujido madera": "crujido_madera",
	"crujido roca": "crujido_roca",
	"gota": "gota",
	"hueso": "hueso",
	"metal lejano": "metal_lejano",
	"piedrecillas": "piedrecillas",
	"respiracion": "respiracion",
	"viento": "viento",
}

# Los bucles del ambiente: largos, van a OGG.
AMB_BUCLES = {
	"Sonidos ambiente mazmorra": "mazmorra",
	"Sonidos ambiente pueblo": "pueblo",
	"Sonidos ambiente antorcha": "antorcha",
	"Sonidos ambiente charco": "charco",
}

# Contextos de musica. La carpeta de destino ES el contexto que pide Musica.poner().
MUSICA = {
	"menu": "menu",
	"pueblo": "pueblo",
	"calma": "calma",
	"mazmorra": "mazmorra",
	"combate": "combate",
	"combate jefe": "jefe",
	"victoria": "victoria",
	"derrota": "derrota",
	"piso nuevo": "piso",
}


# ============================================================
#  ffmpeg
# ============================================================

def buscar_ffmpeg():
	try:
		import imageio_ffmpeg
		return imageio_ffmpeg.get_ffmpeg_exe()
	except Exception:
		pass
	ruta = shutil.which("ffmpeg")
	if ruta:
		return ruta
	return None


FFMPEG = buscar_ffmpeg()


def a_ogg(origen, destino, calidad, mono, lufs):
	"""A OGG y de paso IGUALADO. `lufs` es la sonoridad objetivo (norma EBU R128).

	Aqui la sonoridad la mide ffmpeg y no la funcion `igualar` de mas abajo: en pistas de dos
	minutos lo que cuenta es la sonoridad MEDIA de todo, no el trozo mas fuerte, y loudnorm es
	justo eso. Con esto ninguna cancion entra a bocajarro despues de la anterior.
	"""
	if FFMPEG is None:
		raise RuntimeError("no hay ffmpeg: pip install imageio-ffmpeg")
	cmd = [FFMPEG, "-y", "-loglevel", "error", "-i", origen,
		   "-af", "loudnorm=I=%d:TP=-1.5:LRA=11" % lufs,
		   "-c:a", "libvorbis", "-q:a", str(calidad)]
	if mono:
		cmd += ["-ac", "1", "-ar", "32000"]
	cmd.append(destino)
	subprocess.run(cmd, check=True)


# ============================================================
#  WAV: leer, pasar a mono, recortar, fundir
# ============================================================

def leer_mono(ruta):
	"""Devuelve (muestras como array('h'), frecuencia). Estereo -> media de los dos canales."""
	with wave.open(ruta, "rb") as w:
		if w.getsampwidth() != 2:
			raise RuntimeError("%s no es de 16 bits" % ruta)
		canales = w.getnchannels()
		fr = w.getframerate()
		crudo = w.readframes(w.getnframes())
	m = array.array("h")
	m.frombytes(crudo)
	if sys.byteorder == "big":
		m.byteswap()
	if canales == 1:
		return m, fr
	mono = array.array("h", bytes(len(m) // canales * 2))
	for i in range(len(mono)):
		s = 0
		for c in range(canales):
			s += m[i * canales + c]
		mono[i] = int(s / canales)
	return mono, fr


def escribir_mono(ruta, muestras, fr):
	with wave.open(ruta, "wb") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(fr)
		datos = array.array("h", muestras)
		if sys.byteorder == "big":
			datos.byteswap()
		w.writeframes(datos.tobytes())


def envolvente(muestras, fr, ventana_ms=5):
	"""Pico absoluto por ventana. Es lo que se mira para todo: silencios y golpes."""
	n = max(1, int(fr * ventana_ms / 1000))
	env = []
	for i in range(0, len(muestras), n):
		env.append(max((abs(x) for x in muestras[i:i + n]), default=0))
	return env, n


def recortar(muestras, fr, modo):
	"""Devuelve las muestras ya recortadas. Aqui pasa TODO lo interesante."""
	if isinstance(modo, (tuple, list)):
		a = max(0, int(modo[0] * fr))
		b = min(len(muestras), int(modo[1] * fr))
		return _fundir(array.array("h", muestras[a:b]), fr), "ventana a mano %.2f-%.2fs" % tuple(modo)

	env, n = envolvente(muestras, fr)
	pico = max(env) if env else 0
	if pico == 0:
		return muestras, ""

	# El silencio de cabeza: el generador deja hasta segundo y medio de nada delante, y con el el
	# golpe llegaria tarde respecto al dibujo.
	#
	# EL UMBRAL VA EN PROPORCION AL PICO Y NO EN VALOR ABSOLUTO, y ademas alto (5%): estas muestras
	# vienen SATURADAS y con una cola de reverberacion que baja despacio. Con un umbral bajo, un
	# tajo de espada de 250 ms de contenido se llevaba dos segundos enteros de cola.
	umbral_silencio = max(64, int(pico * 0.05))
	ini = 0
	while ini < len(env) and env[ini] < umbral_silencio:
		ini += 1
	fin = len(env) - 1
	while fin > ini and env[fin] < umbral_silencio:
		fin -= 1

	nota = ""
	if modo == "primer_golpe":
		corte = _segundo_golpe(env, ini, fin, pico)
		if corte > 0:
			nota = "corte en el 2o golpe @ %.2fs" % (corte * n / fr)
			fin = corte
		else:
			nota = "NO se encontro 2o golpe"

	a = max(0, ini * n - int(fr * 0.005))
	b = min(len(muestras), (fin + 1) * n + int(fr * 0.04))
	tope = int(fr * (TOPE_LARGO if modo == "largo" else TOPE_NORMAL))
	if b - a > tope:
		b = a + tope
	return _fundir(array.array("h", muestras[a:b]), fr), nota


# ============================================================
#  IGUALAR EL VOLUMEN
#
#  Cada muestra viene generada por su lado y salen unas mucho mas fuertes que otras: un punetazo
#  reventaba y un mandoble apenas se oia. Y eso PISA el sistema de volumen del juego, que ya sube y
#  baja cada golpe segun su peso y si es critico (ver Sonido._db): si la muestra de base ya viene
#  10 dB mas alta, ese trabajo no sirve de nada.
#
#  SE MIDE LA SONORIDAD, NO EL PICO. Normalizar por pico deja igual de "alto" un chasquido seco y
#  un grito sostenido, y al oido el grito suena el triple. Se mide la VENTANA MAS FUERTE (el cuerpo
#  del golpe, no la cola) y se lleva a un mismo objetivo.
#
#  Y SE MIDE PONDERADO, NO EN RMS PELADO. Esto no es un detalle fino: con RMS a secas, el martillo
#  grande y el Golpe sismico salian medidos EXACTAMENTE al mismo nivel que un espadazo y aun asi se
#  oian a la mitad. El motivo es que son graves, y el oido es mucho menos sensible a los graves a
#  igual energia. La ponderacion K de la norma EBU R128 / ITU-R BS.1770 es justo la correccion de
#  eso: un filtro paso-alto y una repisa de agudos ANTES de medir. Es lo mismo que hace el
#  `loudnorm` de ffmpeg con la musica; aqui va a mano porque estos ficheros duran decimas de
#  segundo y loudnorm necesita bloques de 400 ms para dar un numero fiable.
#
#  Con dos frenos:
#    - un TECHO DE PICO, para que subir el volumen no sature.
#    - un TOPE A LA GANANCIA, para no levantar 30 dB el siseo de fondo de una muestra casi vacia.
# ============================================================

RMS_OBJETIVO = 0.16     # nivel ponderado K objetivo. El punto donde ninguno se come a los demas
PICO_TECHO = 0.89       # ~ -1 dBFS. Margen para que el tono aleatorio del juego no rompa
GANANCIA_TOPE = 6.0     # los graves necesitan mas recorrido que el x4 de antes (ver K_BIQUADS)
VENTANA_RMS = 0.2       # segundos: el cuerpo del golpe

# LA PONDERACION K, tal cual la define ITU-R BS.1770, para 48 kHz (todos los ficheros del juego lo
# son: lo comprueba `igualar`). Dos biquads en serie:
#   1. repisa de agudos (+4 dB por encima de ~1.5 kHz), que es la "cabeza" del oyente
#   2. paso-alto a ~38 Hz, que quita el retumbe que no se oye pero si se mide
# Los coeficientes NO se pueden reescalar a otra frecuencia de muestreo a ojo: si algun dia entra un
# fichero que no sea de 48 kHz, `igualar` lo mide sin ponderar y lo dice.
# ============================================================
#  LA MEZCLA A MANO
#
#  dB que se le SUMAN a una clave despues de igualarla. Igualar deja todo al mismo nivel, que es lo
#  correcto de partida, pero "al mismo nivel" no es lo que se quiere para todo: un pisoton de jefe
#  TIENE que pesar mas que un mordisco de rata. Esto es la mezcla, y son decisiones de oido del
#  usuario, no una medida.
#
#  Se aplica con LIMITADOR (ver `_limitar`), asi que subir 7 dB no satura: lo que se lleva el
#  limitador son las puntas, y en un golpe grave -- que tiene mucho pico y poco cuerpo -- eso es
#  justo lo que hace que se OIGA mas sin sonar mas alto.
#
#  La clave es la del fichero sin 'sfx_' ni '_vN': vale para todas las versiones de una vez.
GANANCIAS = {
	# Los golpes de suelo. Son los que mas sufren la igualacion: al oido pesan por el retumbe, y el
	# retumbe es justo lo que la ponderacion K descuenta.
	"golpe_sismico": 6.0,
	"martillo_golpe": 6.0,        # el basico del martillo grande
	"temblor_suelo": 3.0,
	"coloso_pisoton": 7.0,
	"minotauro_pisoton": 7.0,     # el Pisoton atronador: no se oia
	# El Endurecerse del golem suena por el generico de ESCUDO.
	"escudo": 3.0,
}

# El limitador empieza a apretar a partir de esta fraccion del techo. Por debajo no toca nada.
RODILLA = 0.6

# ============================================================
#  REALCE DE GRAVES  (cuanto armonico se le añade a una clave, 0..1)
#
#  EL PROBLEMA. Medidos, estos golpes tienen el 97-100% de su energia POR DEBAJO DE 500 Hz: son
#  retumbe puro. Un altavoz de portatil o de monitor no baja de ~150 Hz, asi que ahi literalmente
#  no suenan -- y subirles el volumen no arregla nada, porque lo que falta no es nivel, es una
#  frecuencia que el altavoz no sabe dar. Es exactamente el sintoma que se describio como "el
#  Pisoton atronador no se escucha nada".
#
#  LA SOLUCION es la de siempre en audio: si no puedes dar el fundamental, da sus ARMONICOS. El
#  oido reconstruye el tono grave a partir de ellos (el "fundamental ausente"), asi que el golpe se
#  oye grave en un altavoz que no puede reproducir ni una nota de esa zona. Se saca el grave, se
#  rectifica -- que es lo que fabrica el armonico -- y se mezcla por encima.
#
#  NO ES SUBIR EL VOLUMEN: el nivel lo sigue poniendo `igualar` despues, sobre el resultado.
REALCE = {
	"minotauro_pisoton": 0.30,
	"coloso_pisoton": 0.28,
	"golpe_sismico": 0.25,
	"martillo_golpe": 0.22,
	"temblor_suelo": 0.20,
	"golem_machaca": 0.12,
	"pisoton": 0.15,          # el generico de PISOTON (el del jabali)
}


K_BIQUADS = [
	([1.53512485958697, -2.69169618940638, 1.19839281085285],
	 [1.0, -1.69065929318241, 0.73248077421585]),
	([1.0, -2.0, 1.0],
	 [1.0, -1.99004745483398, 0.99007225036621]),
]

# Para lo largo (musica y bucles) la sonoridad la mide ffmpeg en LUFS. El ambiente va mas bajo a
# proposito: es fondo, no tiene que competir con nada.
LUFS_MUSICA = -16
LUFS_AMBIENTE = -22


def _biquad(x, b, a):
	"""Un biquad de forma directa I. Sencillo a proposito: se pasa una vez por fichero corto."""
	y = [0.0] * len(x)
	x1 = x2 = y1 = y2 = 0.0
	for i in range(len(x)):
		xi = x[i]
		yi = b[0] * xi + b[1] * x1 + b[2] * x2 - a[1] * y1 - a[2] * y2
		y[i] = yi
		x2, x1 = x1, xi
		y2, y1 = y1, yi
	return y


def ponderar_k(muestras, fr):
	"""Las muestras pasadas por el filtro K de BS.1770, en float. Sin 48 kHz devuelve None."""
	if fr != 48000:
		return None
	y = [m / 32768.0 for m in muestras]
	for b, a in K_BIQUADS:
		y = _biquad(y, b, a)
	return y


def _un_polo(x, fr, hz, paso_alto=False):
	"""Filtro de un polo. Basta y sobra aqui: no hace falta corte fino, hace falta separar bandas."""
	a = 1.0 - math.exp(-2.0 * math.pi * hz / fr)
	y = 0.0
	fuera = [0.0] * len(x)
	for i in range(len(x)):
		y += a * (x[i] - y)
		fuera[i] = (x[i] - y) if paso_alto else y
	return fuera


def realzar_graves(muestras, fr, cantidad):
	"""Le añade a un golpe grave los armonicos que le faltan para oirse. Ver REALCE.

	`cantidad` es la fraccion de ENERGIA del original que va a aportar el armonico: 0.30 significa
	que se le suma un 30% de energia nueva, toda ella en la zona que el altavoz si reproduce.

	TRES PASOS Y LOS TRES IMPORTAN:
	  1. paso-bajo a 150 Hz para quedarse con el retumbe SOLO;
	  2. un tanh que lo satura: saturar una onda le fabrica armonicos (3f, 5f...), que es de donde
	     va a salir lo que se oye;
	  3. paso-alto EMPINADO -- seis polos -- para quedarse unicamente con esos armonicos.

	El paso 3 es el que costo. Con UN polo (6 dB/octava) el fundamental de 60 Hz salia solo 12 dB
	por debajo y seguia mandando: el realce sonaba a "mas grave" en vez de a "mas claro", y medido
	no movia nada (1,7% -> 2,1% de energia por encima de 400 Hz). Con seis polos sube al 12%.

	No se normaliza el resultado a lo que era: de eso se encarga `igualar` justo despues, que es
	quien decide el nivel final. Aqui solo se baja si se ha salido del techo.
	"""
	if cantidad <= 0.0 or not muestras:
		return muestras
	x = [m / 32768.0 for m in muestras]
	energia = sum(v * v for v in x)
	if energia <= 0.0:
		return muestras
	bajo = _un_polo(x, fr, 150.0)
	pb = max((abs(v) for v in bajo), default=0.0)
	if pb <= 0.0:
		return muestras
	arm = [math.tanh(8.0 * v / pb) for v in bajo]
	for _ in range(6):
		arm = _un_polo(arm, fr, 300.0, True)
	ea = sum(v * v for v in arm)
	if ea <= 0.0:
		return muestras
	g = math.sqrt(cantidad * energia / ea)
	y = [x[i] + arm[i] * g for i in range(len(x))]
	pico = max((abs(v) for v in y), default=0.0)
	if pico > PICO_TECHO:
		k = PICO_TECHO / pico
		y = [v * k for v in y]
	for i in range(len(muestras)):
		muestras[i] = max(-32768, min(32767, int(y[i] * 32768.0)))
	return muestras


def _limitar(a, techo):
	"""Aprieta lo que pasa de la rodilla en vez de recortarlo. `a` es el valor absoluto, 0..N."""
	rodilla = techo * RODILLA
	if a <= rodilla:
		return a
	return rodilla + (techo - rodilla) * math.tanh((a - rodilla) / (techo - rodilla))


def igualar(muestras, fr, extra_db=0.0):
	"""Escala las muestras para que TODAS suenen igual de fuertes. Devuelve (muestras, dB movidos).

	`extra_db` es el retoque de mezcla de GANANCIAS: se suma DESPUES de igualar, que es lo que hace
	que sea una decision legible ("el pisoton del coloso, 7 dB por encima de la media") y no un
	numero perdido dentro de un fichero de audio.
	"""
	n = max(1, int(fr * VENTANA_RMS))
	if len(muestras) == 0:
		return muestras, 0.0
	# SE MIDE SOBRE LA SENAL PONDERADA y se aplica la ganancia sobre la ORIGINAL: el filtro es para
	# medir como oye una persona, no para cambiar el sonido.
	medir = ponderar_k(muestras, fr)
	if medir is None:
		print("  !! %d Hz: no es 48 kHz, se mide sin ponderar (ver K_BIQUADS)" % fr)
		medir = [m / 32768.0 for m in muestras]
	# El nivel de la ventana mas fuerte, recorrida a saltos de media ventana.
	mejor = 0.0
	paso = max(1, n // 2)
	for i in range(0, max(1, len(medir) - 1), paso):
		trozo = medir[i:i + n]
		if not trozo:
			break
		suma = 0.0
		for x in trozo:
			suma += x * x
		mejor = max(mejor, math.sqrt(suma / len(trozo)))
	if mejor <= 0.0:
		return muestras, 0.0
	g = RMS_OBJETIVO / mejor
	g = max(1.0 / GANANCIA_TOPE, min(GANANCIA_TOPE, g))
	# Y encima, el retoque de mezcla. Este NO se recorta contra el techo de pico: para eso esta el
	# limitador. Bajar la ganancia hasta que el pico quepa era justo lo que impedia subir estos
	# golpes -- les quedaba 1 dB de margen y el +6 se quedaba en +1.
	g *= pow(10.0, extra_db / 20.0)
	if abs(g - 1.0) < 0.02:
		return muestras, 0.0
	for i in range(len(muestras)):
		v = muestras[i] * g / 32768.0
		v = math.copysign(_limitar(abs(v), PICO_TECHO), v)
		muestras[i] = max(-32768, min(32767, int(v * 32768.0)))
	return muestras, 20.0 * math.log10(g)


def _fundir(fuera, fr):
	"""El corte a pelo hace 'clic'. Un fundido corto de salida y no se nota."""
	f = min(len(fuera), int(fr * FUNDIDO_MS / 1000))
	for i in range(f):
		k = 1.0 - (i / float(f))
		fuera[len(fuera) - f + i] = int(fuera[len(fuera) - f + i] * k)
	return fuera


def _segundo_golpe(env, ini, fin, pico):
	"""Indice de ventana donde empieza el SEGUNDO impacto, o -1 si la muestra trae uno solo.

	SE BUSCA EL VALLE, NO EL SILENCIO. Dos tajos seguidos no dejan silencio en medio: la cola del
	primero sigue sonando cuando entra el segundo. Lo que si hay es una BAJADA y una subida nueva.
	Asi que se sigue la cima del primer golpe, se apunta el minimo por el que pasa despues, y en
	cuanto algo vuelve a subir con fuerza sobre ese minimo, ese minimo es la costura: ahi se corta.

	Un umbral de silencio absoluto no encontraba ninguno -- son muestras saturadas donde el valle
	entre dos espadazos sigue al 30% del pico.
	"""
	ataque = int(pico * 0.45)     # por debajo de esto no es un golpe, es la cola del anterior
	i = ini
	while i <= fin and env[i] < ataque:
		i += 1
	if i > fin:
		return -1
	while i < fin and env[i + 1] >= env[i]:   # sube hasta la cima del primero
		i += 1
	valle = env[i]
	i_valle = i
	i += 1
	while i <= fin:
		if env[i] < valle:
			valle = env[i]
			i_valle = i
		elif env[i] >= ataque and env[i] >= valle * 1.4 and valle <= pico * 0.65:
			return i_valle
		i += 1
	return -1


# ============================================================
#  El trabajo
# ============================================================

def clave_de_fichero(nombre):
	"""El principio del prompt: lo que hay antes del '#' que metio el generador."""
	base = os.path.splitext(nombre)[0]
	return base.split("#")[0].rstrip("_")


def agrupar(carpeta, tabla):
	"""{clave destino: [rutas ordenadas]} y la lista de lo que sobro."""
	grupos = {}
	huerfanos = []
	for f in sorted(os.listdir(carpeta)):
		if not f.lower().endswith(".wav"):
			continue
		p = clave_de_fichero(f)
		if p not in tabla:
			huerfanos.append(os.path.join(carpeta, f))
			continue
		grupos.setdefault(p, []).append(os.path.join(carpeta, f))
	return grupos, huerfanos


def nombres_de_salida(clave, cuantos, prefijo, ext):
	if cuantos == 1:
		return ["%s%s.%s" % (prefijo, clave, ext)]
	return ["%s%s_v%d.%s" % (prefijo, clave, i + 1, ext) for i in range(cuantos)]


def hacer_sfx(informe):
	os.makedirs(DEST_SFX, exist_ok=True)
	for sub, tabla in SFX.items():
		carpeta = os.path.join(ORIG_SFX, sub)
		if not os.path.isdir(carpeta):
			informe.append("  !! falta la carpeta %s" % carpeta)
			continue
		grupos, huerfanos = agrupar(carpeta, tabla)
		for h in huerfanos:
			informe.append("  !! sin sitio en el manifiesto: %s" % os.path.basename(h))
		for prefijo, rutas in sorted(grupos.items()):
			clave, modo = tabla[prefijo]
			salidas = nombres_de_salida(clave, len(rutas), "sfx_", "wav")
			for ruta, nombre in zip(rutas, salidas):
				m, fr = leer_mono(ruta)
				m, nota = recortar(m, fr, modo)
				# Aqui NO se iguala el volumen: de eso se encarga una sola pasada al final, sobre
				# audio/sfx entero. Haciendolo en los dos sitios, estos ficheros pasaban dos veces
				# y se saltaban el tope de ganancia.
				escribir_mono(os.path.join(DEST_SFX, nombre), m, fr)
				informe.append("  %-28s %5.2fs  %s%s" % (
					nombre, len(m) / float(fr), os.path.basename(ruta)[:34],
					("   <- " + nota) if nota else ""))
		for prefijo in tabla:
			if prefijo not in grupos:
				informe.append("  !! el manifiesto pide '%s' y no hay fichero" % prefijo)


def hacer_ambiente(informe, solo_cortos=False):
	os.makedirs(DEST_AMB, exist_ok=True)
	for sub, clave in sorted(AMB_CORTOS.items()):
		carpeta = os.path.join(ORIG_AMB, sub)
		if not os.path.isdir(carpeta):
			informe.append("  !! falta %s" % carpeta)
			continue
		rutas = [os.path.join(carpeta, f) for f in sorted(os.listdir(carpeta))
				 if f.lower().endswith(".wav")]
		salidas = nombres_de_salida(clave, len(rutas), "amb_", "wav")
		for ruta, nombre in zip(rutas, salidas):
			m, fr = leer_mono(ruta)
			m, _ = recortar(m, fr, "")
			m, db = igualar(m, fr)
			escribir_mono(os.path.join(DEST_AMB, nombre), m, fr)
			informe.append("  %-28s %5.2fs %+5.1fdB  %s" % (nombre, len(m) / float(fr), db, sub))

	if solo_cortos:
		return
	for sub, clave in sorted(AMB_BUCLES.items()):
		carpeta = os.path.join(ORIG_AMB, sub)
		if not os.path.isdir(carpeta):
			informe.append("  !! falta %s" % carpeta)
			continue
		rutas = [os.path.join(carpeta, f) for f in sorted(os.listdir(carpeta))
				 if f.lower().endswith(".wav")]
		salidas = nombres_de_salida(clave, len(rutas), "bucle_", "ogg")
		for ruta, nombre in zip(rutas, salidas):
			dest = os.path.join(DEST_AMB, nombre)
			a_ogg(ruta, dest, 3, True, LUFS_AMBIENTE)
			informe.append("  %-28s %6.1f KB  %s" % (nombre, os.path.getsize(dest) / 1024.0, sub))


def hacer_enemigos(informe):
	"""Vuelve a traer los 61 sonidos de enemigos desde su carpeta de originales.

	POR QUE HACE FALTA. Estos ya venian recortados de antes de que existiera este guion, asi que
	estaban solo en audio/sfx y no se regeneraban: cada pasada les aplicaba el realce de graves
	OTRA VEZ sobre el resultado de la anterior, y eso no converge -- el armonico se iba acumulando.
	Trayendolos del original en cada pasada, todo audio/sfx sale siempre del mismo sitio y relanzar
	el guion mil veces da mil veces lo mismo, que es lo que promete el LEEME.

	No se recortan: los originales de `recortados/` ya lo estan. Solo se pasan a mono y se renombran.
	"""
	if not os.path.isdir(ORIG_ENE):
		informe.append("  !! falta %s (los de enemigos se quedan como esten)" % ORIG_ENE)
		return
	n = 0
	for dp, _, fs in os.walk(ORIG_ENE):
		for f in sorted(fs):
			if not f.lower().endswith(".wav"):
				continue
			destino = RENOMBRES.get(f, f)
			m, fr = leer_mono(os.path.join(dp, f))
			escribir_mono(os.path.join(DEST_SFX, destino), m, fr)
			n += 1
			if destino != f:
				informe.append("  %-34s -> %s" % (f, destino))
	# El aura no tiene sonido propio todavia: es una copia del arrastre. Se rehace aqui para que no
	# se quede atras cuando el arrastre cambie.
	copia = os.path.join(DEST_SFX, "sfx_arrastre_v1.wav")
	if os.path.isfile(copia):
		shutil.copyfile(copia, os.path.join(DEST_SFX, "sfx_aura.wav"))
	informe.append("  %d ficheros traidos de %s" % (n, os.path.basename(ORIG_ENE)))


def igualar_todo(informe):
	"""Iguala audio/sfx ENTERO, incluidos los sonidos de enemigos que se prepararon antes.

	Va en una pasada aparte y no dentro de hacer_sfx por dos motivos. Uno: los 61 de los bichos no
	pasan por hacer_sfx y sin esto se quedarian como estaban -- media plantilla a un volumen y
	media a otro, que es peor que no igualar nada. Y dos: asi cada fichero se iguala UNA vez, o el
	tope de ganancia se saltaria a base de pasadas.

	Se puede lanzar mil veces: `igualar` lleva a un OBJETIVO, asi que un fichero ya igualado se
	queda como esta (y por eso aqui solo se reescribe el que se movio).
	"""
	for f in sorted(os.listdir(DEST_SFX)):
		if not f.endswith(".wav"):
			continue
		ruta = os.path.join(DEST_SFX, f)
		# La clave, para buscarle su retoque de mezcla: sfx_X.wav y sfx_X_v3.wav son los dos "X".
		clave = f[4:-4] if f.startswith("sfx_") else f[:-4]
		if "_v" in clave and clave.rsplit("_v", 1)[1].isdigit():
			clave = clave.rsplit("_v", 1)[0]
		extra = float(GANANCIAS.get(clave, 0.0))
		realce = float(REALCE.get(clave, 0.0))
		m, fr = leer_mono(ruta)
		# EL REALCE VA ANTES DE IGUALAR: añade armonicos, o sea que cambia la sonoridad medida. Al
		# reves, el nivel saldria del sonido de antes de retocarlo.
		if realce > 0.0:
			m = realzar_graves(m, fr, realce)
		m, db = igualar(m, fr, extra)
		if db == 0.0 and realce <= 0.0:
			continue
		escribir_mono(ruta, m, fr)
		informe.append("  %-28s %+5.1f dB%s%s" % (f, db,
			"   mezcla %+.0f" % extra if extra != 0.0 else "",
			"   realce %.2f" % realce if realce > 0.0 else ""))


def hacer_musica(informe):
	for sub, contexto in sorted(MUSICA.items()):
		carpeta = os.path.join(ORIG_MUS, sub)
		if not os.path.isdir(carpeta):
			informe.append("  !! falta %s" % carpeta)
			continue
		destino = os.path.join(DEST_MUS, contexto)
		os.makedirs(destino, exist_ok=True)
		rutas = [os.path.join(carpeta, f) for f in sorted(os.listdir(carpeta))
				 if f.lower().endswith(".wav")]
		# La musica se numera 1..N y Musica.poner() las busca probando numeros: asi anadir una
		# pista es soltar el fichero, sin tocar ni una linea de codigo.
		for i, ruta in enumerate(rutas):
			nombre = "%d.ogg" % (i + 1)
			dest = os.path.join(destino, nombre)
			a_ogg(ruta, dest, 4, False, LUFS_MUSICA)
			informe.append("  %-12s %-8s %6.1f KB  %s" % (
				contexto, nombre, os.path.getsize(dest) / 1024.0, os.path.basename(ruta)[:38]))


def main():
	if FFMPEG is None:
		print("ffmpeg no encontrado. pip install imageio-ffmpeg")
		return 1
	print("ffmpeg: %s\n" % FFMPEG)

	# Los WAV cortos se rehacen en segundos; los OGG tardan minutos. Con --solo-sfx se retocan los
	# umbrales de recorte sin volver a codificar media hora de musica que no ha cambiado.
	solo_sfx = "--solo-sfx" in sys.argv

	informe = []
	print("== SFX del jugador ==")
	hacer_sfx(informe)
	print("\n".join(informe))

	informe = []
	print("\n== Igualando el volumen de audio/sfx entero ==")
	igualar_todo(informe)
	print("\n".join(informe) if informe else "  (nada que mover: ya estaban igualados)")

	informe = []
	print("\n== Ambiente ==")
	hacer_ambiente(informe, solo_sfx)
	print("\n".join(informe))

	if not solo_sfx:
		informe = []
		print("\n== Musica ==")
		hacer_musica(informe)
		print("\n".join(informe))

	total = 0
	for base in (DEST_SFX, DEST_AMB, DEST_MUS):
		for dp, _, fs in os.walk(base):
			for f in fs:
				if not f.endswith(".import"):
					total += os.path.getsize(os.path.join(dp, f))
	print("\naudio/ ocupa %.1f MB" % (total / 1048576.0))
	return 0


if __name__ == "__main__":
	sys.exit(main())
