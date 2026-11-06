# ============================================================
#  equipo_armaduras.py  (06/11, el jefe: "quiero ver los otros tipos de armadura todos: tela, cuero, hierro, hierro
#  completo y placa")
#  LAMINA DE LOS CINCO TIPOS DE ARMADURA con sus cinco piezas (casco, pecho, manos, pantalones, botas), en pixel art
#  de verdad para la celda del inventario. Lo que separa un tipo de otro es LA SILUETA, como en el muñeco
#  (armadura_sprites.gd):
#    TELA     capucha con pico, tunica larga con mangas de campana y fajin, mitones, calzas lisas, zapatillas. Luz blanda.
#    CUERO    casco abierto de cuero, jubon con cintas, guantes, pantalon con rodilleras cosidas, botas.
#    HIERRO   lo ABIERTO del metal: bacinete con nasal, COTA DE MALLA, manoplas y calzas de malla, botas con puntera.
#    HIERRO COMPLETO  lo CERRADO sin adornos: gran yelmo, peto liso en cilindro, guanteletes de una pieza, grebas, escarpes.
#    PLACAS   lo elegido (tools/equipo_placas_juego.py): armet, peto de caballero, guanteletes articulados, grebas, escarpes.
#  El metal lleva los dos tonos nuevos (BRILLO y HONDO); la tela y el cuero no: su luz es blanda.
#    python tools/equipo_armaduras.py [salida.png]   (la lamina)
#    python tools/equipo_armaduras.py --hornear      (los 25 PNG del juego en assets/sprites/equipo/armadura)
# ============================================================
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import equipo_pixel as EP
import equipo_placas_versiones as V
import equipo_placas_juego as J
from equipo_placas_versiones import BRI, HON, rellenar_cilindro, rellenar_esfera, anillo_oscuro, torso
from equipo_pixel import MAT_S, MAT, MAT_L, OSC, ACE, volumen, punto
from PIL import Image, ImageDraw, ImageFont


# ---- utilidades ----
def blando(cv, m):
    volumen(cv, m, MAT, MAT_L, MAT_S)


def pliegues(cv, f, xs, y0, y1):
    # Los pliegues de la tela: rayas verticales de sombra.
    for fx in xs:
        cv.mancha(lambda x, y, fx=fx: f(x, y) and abs(x - fx) < 0.5 / cv.n and y0 <= y <= y1, MAT_S)


BAJA = {BRI: MAT_L, MAT_L: MAT, MAT: MAT_S, MAT_S: HON, HON: HON}


def malla(cv, m):
    # LA COTA DE MALLA: el cilindro de siempre y, a cuadros, cada otro pixel un tono mas oscuro (las anillas).
    rellenar_cilindro(cv, m)
    for (x, y) in m:
        if (x + y) % 2:
            cv.pon(x, y, BAJA.get(cv.get(x, y), cv.get(x, y)))


def piernas(cv, rellena, cx_l=0.34, cx_r=0.66, y0=0.20, y1=0.90, ancho=0.12, estrecha=0.03):
    for cx in (cx_l, cx_r):
        f = lambda x, y, cx=cx: abs(x - cx) <= ancho - (y - y0) * estrecha and y0 <= y <= y1
        m = cv.mascara(f)
        rellena(cv, m)
        yield cx, f


def cintura(cv, rellena, y0=0.12, y1=0.22, semi=0.30):
    m = cv.mascara(lambda x, y: abs(x - 0.5) <= semi and y0 <= y <= y1)
    rellena(cv, m)
    return m


def par_botas(cv, cana_y0, rellena_cana, rellena_pie, extra=None):
    # Dos botas de perfil mirando a la izquierda (la de atras mas arriba), como las de cuero y los escarpes.
    for dx, dy in ((0.14, -0.04), (-0.06, 0.06)):
        cana = lambda x, y, dx=dx, dy=dy: 0.40 <= x - dx <= 0.62 and cana_y0 <= y - dy <= 0.66
        pie = lambda x, y, dx=dx, dy=dy: 0.62 <= y - dy <= 0.82 and \
            0.20 + max(0.0, 0.70 - (y - dy)) * 1.4 <= x - dx <= 0.64
        m = cv.mascara(cana)
        anillo_oscuro(cv, m)
        rellena_cana(cv, m)
        m = cv.mascara(pie)
        anillo_oscuro(cv, m)
        rellena_pie(cv, m)
        cv.mancha(lambda x, y: pie(x, y) and y - dy > 0.79, OSC)                       # la suela
        if extra:
            extra(cv, dx, dy, cana, pie)


def par_manos(cv, rellena_puno, rellena_mano, dedos=True, pulgar=True, largo_puno=0.34):
    # EL PAR DE MANOS, de frente y con los dedos hacia abajo. La silueta es lo que las lee como mano y no como un
    # ladrillo: puño ACAMPANADO, MUÑECA estrecha, palma redondeada, dedos con HUECO entre las puntas y el PULGAR
    # saliendo en diagonal hacia el centro.
    for cx, h in ((0.27, 1), (0.73, -1)):
        def mano(x, y, cx=cx):
            if largo_puno <= y < largo_puno + 0.06:                       # la muñeca
                return abs(x - cx) <= 0.08
            if largo_puno + 0.06 <= y <= 0.64:                            # la palma
                return abs(x - cx) <= 0.12 - max(0.0, largo_puno + 0.10 - y) * 0.5
            if 0.64 < y <= 0.86 and abs(x - cx) <= 0.12:                  # los dedos
                if not dedos:
                    return ((x - cx) / 0.12) ** 2 + ((y - 0.64) / 0.20) ** 2 <= 1.0
                u = (x - (cx - 0.12)) / 0.24
                k = min(3, int(u * 4))
                largo = 0.86 - (0.06 if k in (0, 3) else 0.0)
                hueco = abs(u - (k + 0.5) / 4) > 0.09 and y > 0.74        # el hueco entre las puntas
                return y <= largo and not hueco
            return False
        rellena_mano(cv, cv.mascara(mano))
        if dedos:
            for k in (1, 2, 3):
                fx = cx - 0.12 + 0.24 * k / 4
                cv.mancha(lambda x, y, fx=fx, mano=mano: mano(x, y) and abs(x - fx) < 0.5 / cv.n and y > 0.66, MAT_S)
        if pulgar:
            # el pulgar, en diagonal: de la palma hacia abajo y hacia el centro
            def pul(x, y, cx=cx, h=h):
                ax, ay = cx + h * 0.10, 0.46
                bx, by = cx + h * 0.19, 0.62
                t = max(0.0, min(1.0, ((x - ax) * (bx - ax) + (y - ay) * (by - ay)) / ((bx - ax) ** 2 + (by - ay) ** 2)))
                px, py = ax + (bx - ax) * t, ay + (by - ay) * t
                return ((x - px) ** 2 + (y - py) ** 2) ** 0.5 <= 0.05
            p = cv.mascara(pul)
            anillo_oscuro(cv, p)
            rellena_mano(cv, p)
        puno = lambda x, y, cx=cx: abs(x - cx) <= 0.08 + (largo_puno - y) * 0.30 and 0.14 <= y < largo_puno
        m = cv.mascara(puno)
        anillo_oscuro(cv, m)
        rellena_puno(cv, m)


# ============================================================
#  TELA
# ============================================================
def tela_casco(cv):
    # LA CAPUCHA: de frente, con la cara en sombra dentro, el PICO que cae por un lado y la tela sobre los hombros.
    hombros = cv.mascara(lambda x, y: abs(x - 0.5) <= 0.38 - max(0.0, 0.80 - y) * 0.8 and 0.66 <= y <= 0.88)
    blando(cv, hombros)
    cap = lambda x, y: ((x - 0.5) / 0.30) ** 2 + ((y - 0.46) / 0.36) ** 2 <= 1.0 and y <= 0.78
    blando(cv, cv.mascara(cap))
    pico = cv.mascara(lambda x, y: 0.62 <= x <= 0.84 and 0.10 <= y <= 0.30 and (x - 0.62) * 1.1 <= 0.30 - y + 0.02)
    blando(cv, pico)
    cara = lambda x, y: ((x - 0.5) / 0.17) ** 2 + ((y - 0.54) / 0.21) ** 2 <= 1.0
    cv.mancha(cara, OSC)
    cv.mancha(lambda x, y: cara(x, y) and y > 0.62, MAT_S)                                        # la barbilla en penumbra
    pliegues(cv, cap, (0.30, 0.70), 0.40, 0.74)
    for fx in (0.44, 0.56):
        punto(cv, fx, 0.50, ACE, 0.5)                                                              # los ojos que brillan


def tela_pecho(cv):
    # LA TUNICA larga, con las MANGAS DE CAMPANA abiertas abajo y el FAJIN.
    def tunica(x, y):
        if y < 0.14 or y > 0.92:
            return False
        if ((x - 0.5) / 0.11) ** 2 + ((y - 0.12) / 0.09) ** 2 <= 1.0:
            return False
        semi = 0.20 + max(0.0, y - 0.50) * 0.30
        return abs(x - 0.5) <= semi
    def manga(x, y, l):
        cx = 0.5 + l * (0.27 + (y - 0.18) * 0.22)
        return 0.18 <= y <= 0.62 and abs(x - cx) <= 0.06 + (y - 0.18) * 0.18
    for l in (-1, 1):
        m = cv.mascara(lambda x, y, l=l: manga(x, y, l))
        blando(cv, m)
        cv.mancha(lambda x, y, l=l: manga(x, y, l) and y > 0.58, OSC)                             # el hueco de la manga
    blando(cv, cv.mascara(tunica))
    pliegues(cv, tunica, (0.40, 0.60), 0.56, 0.90)
    cv.mancha(lambda x, y: tunica(x, y) and abs(x - 0.5) < 0.5 / cv.n and 0.20 <= y <= 0.44, MAT_S)  # el cuello en pico
    cv.mancha(lambda x, y: tunica(x, y) and 0.46 <= y <= 0.52, ACE)                               # el fajin
    cv.mancha(lambda x, y: 0.52 <= x <= 0.56 and 0.52 <= y <= 0.66, ACE)                          # su caida


def tela_manos(cv):
    # MITONES: puño vuelto, la mano sin dedos marcados y el pulgar.
    def puno(cv, m):
        blando(cv, m)
    par_manos(cv, puno, blando, dedos=False, pulgar=True, largo_puno=0.32)
    for cx in (0.27, 0.73):
        cv.mancha(lambda x, y, cx=cx: abs(x - cx) <= 0.13 and abs(y - 0.33) < 0.5 / cv.n, ACE)    # la costura del puño


def tela_pantalones(cv):
    # CALZAS lisas: la cinturilla y las dos piernas, sin rodillera.
    cintura(cv, blando, 0.10, 0.20, 0.28)
    cv.mancha(lambda x, y: abs(x - 0.5) <= 0.28 and abs(y - 0.20) < 0.5 / cv.n, ACE)
    for cx, f in piernas(cv, blando, 0.36, 0.64, 0.20, 0.90, 0.12, 0.05):
        pliegues(cv, f, (cx - 0.03,), 0.30, 0.84)


def tela_botas(cv):
    # ZAPATILLAS: caña muy baja y la punta un poco levantada.
    def extra(cv, dx, dy, cana, pie):
        cv.mancha(lambda x, y: cana(x, y) and y - dy < 0.52, 0)                                   # sin caña alta
        punto(cv, 0.22 + dx, 0.66 + dy, MAT)                                                       # la punta que sube
        cv.mancha(lambda x, y: cana(x, y) and abs(y - dy - 0.54) < 0.5 / cv.n, ACE)
    par_botas(cv, 0.52, blando, blando, extra)


# ============================================================
#  CUERO
# ============================================================
def cuero_manos(cv):
    def puno(cv, m):
        blando(cv, m)
    par_manos(cv, puno, blando, dedos=True, pulgar=True)
    for cx in (0.27, 0.73):
        for fy in (0.22, 0.28):
            punto(cv, cx, fy, OSC, 0.5)                                                            # la cinta del puño
        punto(cv, cx, 0.46, ACE)


def cuero_pantalones(cv):
    m = cintura(cv, blando, 0.10, 0.20, 0.30)
    cv.mancha(lambda x, y: abs(x - 0.5) <= 0.30 and abs(y - 0.15) < 0.5 / cv.n, MAT_S)
    punto(cv, 0.5, 0.15, ACE)                                                                     # la hebilla
    for cx, f in piernas(cv, blando, 0.35, 0.65, 0.20, 0.90, 0.13, 0.04):
        rod = cv.mascara(lambda x, y, cx=cx: abs(x - cx) <= 0.08 and 0.50 <= y <= 0.62)
        volumen(cv, rod, MAT_L, MAT_L, MAT_S)                                                       # la rodillera cosida
        for fx in (cx - 0.08, cx + 0.08):
            cv.mancha(lambda x, y, fx=fx: abs(x - fx) < 0.5 / cv.n and 0.50 <= y <= 0.62 and (int(y * cv.n) % 2 == 0), OSC)


# ============================================================
#  HIERRO (abierto, con malla)
# ============================================================
def hierro_casco(cv):
    # BACINETE con NASAL y la cofia de malla debajo (de las versiones: yelmo C).
    V.yelmo_c(cv)


def hierro_pecho(cv):
    # COTA DE MALLA: la camisa de anillas con mangas cortas y un cinto de cuero.
    def cota(x, y):
        if y < 0.18 or y > 0.86:
            return False
        if ((x - 0.5) / 0.12) ** 2 + ((y - 0.16) / 0.10) ** 2 <= 1.0:
            return False
        if y < 0.44:
            return abs(x - 0.5) <= 0.40 - max(0.0, 0.26 - y) * 0.9 and not (y > 0.34 and abs(x - 0.5) > 0.30)
        return abs(x - 0.5) <= 0.30 + (y - 0.44) * 0.06
    malla(cv, cv.mascara(cota))
    cv.mancha(lambda x, y: cota(x, y) and 0.58 <= y <= 0.63, OSC)                                 # el cinto
    punto(cv, 0.5, 0.605, ACE)
    cv.mancha(lambda x, y: cota(x, y) and y > 0.84, MAT_S)                                        # el bajo


def hierro_manos(cv):
    # MANOPLAS de malla con el puño de cuero (OSC).
    par_manos(cv, malla, malla, dedos=False, pulgar=True)
    for cx in (0.27, 0.73):
        cv.mancha(lambda x, y, cx=cx: abs(x - cx) <= 0.10 and abs(y - 0.30) < 0.5 / cv.n, OSC)     # la correa
        punto(cv, cx, 0.30, ACE)


def hierro_pantalones(cv):
    # CALZAS DE MALLA con una rodillera de chapa.
    cintura(cv, lambda cv, m: volumen(cv, m, OSC, MAT_S, OSC), 0.10, 0.18, 0.30)
    for cx, f in piernas(cv, malla, 0.35, 0.65, 0.18, 0.90, 0.12, 0.03):
        r = 0.07
        rod = cv.mascara(lambda x, y, cx=cx: ((x - cx) / r) ** 2 + ((y - 0.54) / (r * 0.9)) ** 2 <= 1.0)
        anillo_oscuro(cv, rod)
        rellenar_esfera(cv, rod, cx, 0.54, r)


def hierro_botas(cv):
    # BOTAS DE CUERO (en OSC/MAT_S) con PUNTERA y espinillera de hierro.
    def cana(cv, m):
        volumen(cv, m, MAT_S, MAT, HON)
    def extra(cv, dx, dy, cana_f, pie_f):
        esp = cv.mascara(lambda x, y: cana_f(x, y) and 0.48 <= x - dx <= 0.58 and 0.24 <= y - dy <= 0.62)
        rellenar_cilindro(cv, esp)                                                                  # la espinillera
        punta = cv.mascara(lambda x, y: pie_f(x, y) and x - dx < 0.38 and y - dy < 0.80)
        rellenar_cilindro(cv, punta)                                                                # la puntera
    par_botas(cv, 0.20, cana, cana, extra)


# ============================================================
#  HIERRO COMPLETO (cerrado, liso)
# ============================================================
def completo_casco(cv):
    # GRAN YELMO sin cresta (la cresta es de las placas).
    V.yelmo_a(cv)
    cv.mancha(lambda x, y: abs(x - 0.5) < 0.5 / cv.n and 0.10 <= y <= 0.42, 0)
    m = cv.mascara(lambda x, y: abs(x - 0.5) < 0.5 / cv.n and 0.16 <= y <= 0.42)
    for (x, y) in m:
        cv.pon(x, y, MAT_L)


def completo_pecho(cv):
    # PETO LISO en cilindro con hombreras y escarcelas (de las versiones: peto A).
    V.peto_a(cv)


def completo_manos(cv):
    # GUANTELETES DE UNA PIEZA: puño y mano lisos en cilindro, los dedos solo marcados.
    par_manos(cv, rellenar_cilindro, rellenar_cilindro, dedos=True, pulgar=True)
    for cx in (0.27, 0.73):
        cv.mancha(lambda x, y, cx=cx: abs(x - cx) <= 0.11 and abs(y - 0.64) < 0.5 / cv.n, HON)     # los nudillos
        cv.mancha(lambda x, y, cx=cx: abs(x - cx) <= 0.09 and abs(y - 0.61) < 0.5 / cv.n, BRI)


def completo_pantalones(cv):
    # GREBAS lisas: quijotes, rodillera y espinillera, sin la falda de lamas.
    cintura(cv, rellenar_cilindro, 0.12, 0.22, 0.30)
    cv.mancha(lambda x, y: abs(x - 0.5) <= 0.30 and abs(y - 0.22) < 0.5 / cv.n, HON)
    for cx in (0.34, 0.66):
        muslo = cv.mascara(lambda x, y, cx=cx: abs(x - cx) <= 0.12 and 0.24 <= y <= 0.50)
        anillo_oscuro(cv, muslo)
        rellenar_cilindro(cv, muslo)
        greba = cv.mascara(lambda x, y, cx=cx: abs(x - cx) <= 0.10 and 0.58 <= y <= 0.90)
        anillo_oscuro(cv, greba)
        rellenar_cilindro(cv, greba)
        r = 0.085
        rod = cv.mascara(lambda x, y, cx=cx: ((x - cx) / r) ** 2 + ((y - 0.54) / (r * 0.9)) ** 2 <= 1.0)
        anillo_oscuro(cv, rod)
        rellenar_esfera(cv, rod, cx, 0.54, r)


def completo_botas(cv):
    # ESCARPES LISOS: caña y pie en cilindro, sin lamas.
    def extra(cv, dx, dy, cana, pie):
        cv.mancha(lambda x, y: cana(x, y) and abs(x - dx - 0.51) < 0.5 / cv.n, MAT_L)
    par_botas(cv, 0.18, rellenar_cilindro, rellenar_cilindro, extra)


TIPOS = [
    ("Tela", "tela", False, [tela_casco, tela_pecho, tela_manos, tela_pantalones, tela_botas]),
    ("Cuero", "cuero", False, [EP.casco_cuero, EP.pecho_cuero, cuero_manos, cuero_pantalones, EP.botas]),
    ("Hierro", "metal", True, [hierro_casco, hierro_pecho, hierro_manos, hierro_pantalones, hierro_botas]),
    ("Hierro completo", "metal", True, [completo_casco, completo_pecho, completo_manos, completo_pantalones, completo_botas]),
    ("Placas", "metal", True, [V.yelmo_b, V.peto_c, J.guanteletes, J.grebas, J.escarpes]),
]
SLOTS = ["Casco", "Pecho", "Manos", "Pantalones", "Botas"]
TIERS = [1, 2, 3]


TIPO_JUEGO = {"Tela": "tela", "Cuero": "cuero", "Hierro": "hierro", "Hierro completo": "hierro_completo",
              "Placas": "placas"}   # ArmaduraSprites.TIPO_NOMBRE
SLOT_JUEGO = ["casco", "pecho", "manos", "pantalones", "botas"]   # ArmaduraSprites.SLOT_NOMBRE
RAMPA_TONOS = 16   # CapaJugador.RAMPA_TONOS: el gris del tono t es t / 15


def hornear(carpeta):
    # LOS PNG DEL JUEGO, uno por tipo y pieza, EN GRISES DE INDICE (como las capas del muñeco): el color lo pone
    # paleta_equipo.gdshader con ArmaduraSprites.ROLES_ICONO segun el tier y el +N de cada pieza.
    os.makedirs(carpeta, exist_ok=True)
    n = 0
    for nombre, _fam, _amp, piezas in TIPOS:
        for slot, fn in zip(SLOT_JUEGO, piezas):
            cv = EP.dibujar(fn, 32)
            im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
            for y in range(32):
                for x in range(32):
                    t = cv.p[y][x]
                    if t:
                        g = int(round(t / (RAMPA_TONOS - 1) * 255))
                        im.putpixel((x, y), (g, g, g, 255))
            im.save(os.path.join(carpeta, "%s_%s.png" % (TIPO_JUEGO[nombre], slot)))
            n += 1
    print("%d armaduras en %s" % (n, carpeta))


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--hornear":
        hornear(sys.argv[2] if len(sys.argv) > 2 else "assets/sprites/equipo/armadura")
        return
    salida = sys.argv[1] if len(sys.argv) > 1 else "armaduras_lamina.png"
    with open(os.path.join(EP.AQUI, "paletas_equipo.json"), encoding="utf-8") as f:
        PAL = json.load(f)
    try:
        f1 = ImageFont.truetype("arial.ttf", 20)
        f2 = ImageFont.truetype("arial.ttf", 13)
    except OSError:
        f1 = f2 = None
    ESC, N = 3, 32
    celda = N * ESC + 4
    grupo = celda * len(TIERS) + N + 30
    x0 = 150
    fila = N * ESC + 28
    w = x0 + grupo * len(SLOTS) + 10
    h = 84 + fila * len(TIPOS)
    lam = Image.new("RGBA", (w, h), (16, 16, 20, 255))
    d = ImageDraw.Draw(lam)
    d.text((16, 12), "LOS CINCO TIPOS DE ARMADURA (32 px): T1, T2 y T3 a x3, y T2 a tamano real",
           fill=(240, 190, 100), font=f1)
    for i, s in enumerate(SLOTS):
        d.text((x0 + i * grupo, 52), s, fill=(240, 190, 100), font=f2)
    for j, (nombre, fam, ampliada, piezas) in enumerate(TIPOS):
        y = 80 + j * fila
        d.text((16, y + 40), nombre, fill=(220, 220, 228), font=f2)
        for i, fn in enumerate(piezas):
            cv = EP.dibujar(fn, N)
            for k, t in enumerate(TIERS):
                pal = PAL["armadura|%s|%d|0" % (fam, t)]
                im = EP.teñir(cv, V.paleta_ampliada(pal) if ampliada else pal)
                g = im.resize((N * ESC, N * ESC), Image.NEAREST)
                lam.paste(g, (x0 + i * grupo + k * celda, y), g)
                if t == 2:
                    lam.paste(im, (x0 + i * grupo + len(TIERS) * celda + 4, y + N * ESC - N), im)
    lam.save(salida)
    print(salida)


if __name__ == "__main__":
    main()
