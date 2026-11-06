# ============================================================
#  equipo_herramientas.py  (06/11, rework visual a pixel) LAS HERRAMIENTAS DE FAENA en pixel art de verdad, con el mismo
#  lenguaje que las armas (tools/equipo_armas.py): en diagonal, el metal con BRILLO y HONDO, mango de madera.
#    pico, hacha de talar, hoz, caña y cuchillo de desollar.
#  Hoy salen de las facetas de sprites_objeto.gd (poligonos rasterizados a partir de UN color). Lamina de prueba: no toca
#  el juego hasta su visto bueno.
#    python tools/equipo_herramientas.py [salida.png]
# ============================================================
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import equipo_pixel as EP
import equipo_armas as A
from equipo_armas import diag, puno, BRI, HON, CUERDA
from equipo_pixel import MANGO_S, MANGO, MET_S, MET, MET_L, MAD_S, MAD, MAD_L
from PIL import Image, ImageDraw, ImageFont


def asta(s, p, s0, s1):
    if s0 <= s <= s1 and -1 <= p <= 0:
        return MAD_L if p == -1 else MAD_S
    return 0


def _pico(cv, curva, largo_izq, largo_der, cara_der=False):
    # EL PICO: la cabeza ATRAVESADA arriba, casi recta (un arco suave hacia la punta del mango) y solo las PUNTAS caen.
    # Con mucha curva los dos brazos hacian una V y se leia como una punta de flecha (el jefe, 06/11).
    #   curva       cuanto se arquea la cabeza
    #   largo_*     lo que mide cada brazo (filas de diagonal)
    #   cara_der    el brazo derecho acaba en CARA PLANA (pico y martillo) en vez de en punta
    def f(s, p, e):
        c = 10.5 * e
        lado = -1 if p < 0 else 1
        largo = largo_izq if p < 0 else largo_der
        if abs(p) <= largo:
            k = abs(p) / max(1.0, largo)
            centro = c - curva * p * p - (2.2 * k ** 4 if not (cara_der and p > 0) else 0.0)   # la punta cae al final
            grueso = 1.7 * (1.0 - k * 0.65) if not (cara_der and p > 0) else 1.8
            if abs(s - centro) <= grueso:
                if abs(p) >= largo - 0.5:
                    return MET_L if not (cara_der and p > 0) else MET
                if s > centro:                                               # el canto de arriba, a la luz
                    return BRI if (p < 0 and k < 0.7) else MET_L
                if s < centro - grueso + 0.7:
                    return HON
                return MET
        if abs(s - c) <= 2.4 and -2 <= p <= 1:
            return MET_L if p == -2 else (MET_S if p < 1 else HON)           # el ojo
        return primero(puno(s, p, -15 * e, -11 * e, -1, 0), asta(s, p, -11 * e, c))
    diag(cv, f)


def pico_arco(cv, grueso_max=2.6):
    # EL PICO EN ARCO GRANDE: la cabeza es una media luna que recorre TODO el borde de arriba y el de la derecha, y el
    # mango llega a su centro. Encajada en la esquina y pequeña, la cabeza se leia como una punta de flecha.
    n = cv.n
    cx, cy, R = 0.36, 0.64, 0.56                 # el centro del arco, abajo a la izquierda (hacia el mango)
    for y in range(n):
        for x in range(n):
            fx, fy = (x + 0.5) / n, (y + 0.5) / n
            d = math.hypot(fx - cx, fy - cy)
            ang = math.atan2(-(fy - cy), fx - cx)          # 0 = derecha, pi/2 = arriba
            if not (-0.30 <= ang <= 1.90):
                continue
            mitad = (1.90 - 0.30) / 2
            k = abs(ang - (1.90 - 0.30) / 2 - (-0.30 + 0.30)) / mitad   # 0 en el centro del arco, 1 en las puntas
            k = min(1.0, abs((ang - 0.80) / 1.10))
            g = grueso_max * (1.0 - k ** 1.6 * 0.80) / n
            if abs(d - R) <= g:
                fuera = d > R
                if k > 0.92:
                    t = MET_L                                      # las puntas
                elif fuera:
                    t = BRI if ang > 0.9 else MET_L                # el canto de fuera, a la luz arriba
                elif d < R - g * 0.5:
                    t = HON
                else:
                    t = MET
                cv.pon(x, y, t)
    # el ojo donde entra el mango
    ex, ey = cx + R * math.cos(0.80), cy - R * math.sin(0.80)
    for y in range(n):
        for x in range(n):
            fx, fy = (x + 0.5) / n, (y + 0.5) / n
            if abs(fx - ex) <= 2.2 / n and abs(fy - ey) <= 2.2 / n:
                cv.pon(x, y, MET_S if fx + fy < ex + ey + 1.0 / n else HON)
    # el mango, de abajo a la izquierda al ojo
    def f(s, p, e):
        if s > -11 * e * A.LARGO and s < 5.5 and -1 <= p <= 0:
            return MAD_L if p == -1 else MAD_S
        return puno(s, p, -15 * e, -11 * e, -1, 0) if s <= -11 * e * A.LARGO else 0
    EP.diag(cv, lambda s, p, e: f(s, p, e) if cv.get(int((s * 2 + p + n - 1) / 2), int((p + n - 1 - s * 2) / 2)) == 0 else 0)


def pico_d(cv):
    pico_arco(cv, 2.6)


def pico(cv):        # A: cabeza casi recta, las dos puntas caen al final
    _pico(cv, 0.012, 11, 11)


def pico_b(cv):      # B: algo mas arqueada, la del minero clasico
    _pico(cv, 0.028, 10, 10)


def pico_c(cv):      # C: pico por un lado y CARA PLANA de martillo por el otro
    _pico(cv, 0.012, 11, 5, cara_der=True)


def primero(*v):
    for x in v:
        if x:
            return x
    return 0


def hacha_talar(cv):
    # HACHA DE TALAR: la de una mano, cabeza de un solo filo, mas pequeña que la de guerra, asta larga
    def f(s, p, e):
        eh = e / A.LARGO * 1.0
        c, r = 9.5 * e, 4.6 * eh
        q = -p
        if q >= 1:
            hw = 1.4 * eh if q <= 2 else min(r, 1.4 * eh + (q - 2) * 1.1 * eh)
            borde = 2 + 4.2 * eh + 1.2 * eh * math.sqrt(max(0.0, 1.0 - ((s - c) / r) ** 2))
            if abs(s - c) <= hw and q <= borde:
                if q >= borde - 1.2:
                    return BRI if s < c else MET_L
                if abs(s - c) >= hw - 0.6:
                    return HON if s > c else MET_S
                return MET
        if 1 <= p <= 2 and abs(s - c) <= 1.6 * eh:
            return MET_S if p == 1 else HON                                   # el talon
        if abs(s - c) <= 1.6 * eh and -1 <= p <= 0:
            return MET
        return primero(puno(s, p, -15 * e, -11 * e, -1, 0), asta(s, p, -11 * e, c + 1.5))
    diag(cv, f)


def hoz(cv):
    # HOZ: el mango corto de madera y la hoja en MEDIA LUNA que se abre hacia la luz, con el filo por dentro
    def f(s, p, e):
        cs, cp, R = 4.0 * e, -6.0, 8.0 * e
        d = math.hypot((s - cs) * 1.0, (p - cp) * 0.72)
        ang = math.atan2(p - cp, s - cs)
        if R - 2.2 <= d <= R and -2.2 <= ang <= 1.2:
            if d < R - 1.4:
                return BRI if ang < -0.4 else MET_L                          # el filo, por dentro
            return HON if ang > 0.4 else (MET if d < R - 0.6 else MET_S)
        return primero(puno(s, p, -14 * e, -6 * e, -1, 0), asta(s, p, -6 * e, cs + R * 0.98 - 1))
    diag(cv, f)


def hacha_grande_talar(cv):
    # EL HACHA DE TALAR A LO GRANDE: una CUÑA ancha que sale del asta hacia la luz (arriba a la izquierda) y se abre EN
    # CURVA hasta el FILO, con su talon detras. La primera, encajada en la esquina, salia "escuchimizada"; la segunda
    # se salia por arriba del lienzo y se cortaba (el jefe, 06/11): la cabeza va mas abajo y todo cabe dentro.
    n = cv.n
    hx, hy = 0.60, 0.42                                   # donde va la cabeza, en lo alto del asta
    fin_asta = ((hx - hy) * n / 2.0) + 2.2                # el asta asoma solo un poco por encima de la cabeza
    def asta_f(s, p, e):
        if -15 * e <= s < -11 * e:
            return puno(s, p, -15 * e, -11 * e, -1, 0)
        if -11 * e <= s <= fin_asta and -1 <= p <= 0:
            return MAD_L if p == -1 else MAD_S
        return 0
    EP.diag(cv, asta_f)
    d = (0.7071, -0.7071)                                 # a lo largo del asta, hacia la punta
    nn = (-0.7071, -0.7071)                               # hacia la luz: alli va el filo
    E = 0.86                                              # el tamaño de la cabeza
    for y in range(n):
        for x in range(n):
            rx, ry = (x + 0.5) / n - hx, (y + 0.5) / n - hy
            u = rx * d[0] + ry * d[1]
            v = rx * nn[0] + ry * nn[1]
            if 0.0 <= v <= 0.40 * E:
                semi = (0.065 + 0.165 * min(1.0, max(0.0, (v / E - 0.05) / 0.27)) ** 1.8) * E
                borde = (0.32 + 0.07 * math.sqrt(max(0.0, 1.0 - (u / (0.22 * E)) ** 2))) * E
                if abs(u) <= semi and v <= borde:
                    if v >= borde - 0.045:
                        t = BRI if u > -0.05 else MET_L            # el FILO
                    elif u < -semi + 0.04:
                        t = HON                                     # el canto de abajo, en sombra
                    elif u > semi - 0.04:
                        t = MET_L                                   # el de arriba, a la luz
                    elif u < -0.02:
                        t = MET_S
                    else:
                        t = MET
                    cv.pon(x, y, t)
            elif -0.08 <= v < 0.0 and abs(u) <= 0.055:             # el TALON, del otro lado del asta
                cv.pon(x, y, MET_S if u > 0 else HON)


def hoz_abierta(cv, R=0.27, fin=-0.15):
    # LA HOZ ABIERTA: la hoja sale de lo alto del mango, sube por encima en arco y acaba con la PUNTA LEJOS del palo,
    # a la derecha. Cerrada sobre el mango (la primera) se leia como un gancho (el jefe, 06/11).
    n = cv.n
    hx, hy = 0.40, 0.56                          # lo alto del mango: donde arranca la hoja
    cx, cy = hx + R, hy                          # el centro del arco, a la derecha del mango
    ini = math.pi                                # empieza a la izquierda del centro (en el mango)
    for y in range(n):
        for x in range(n):
            fx, fy = (x + 0.5) / n, (y + 0.5) / n
            d = math.hypot(fx - cx, fy - cy)
            ang = math.atan2(-(fy - cy), fx - cx)
            if ang < -math.pi / 2:
                ang += 2 * math.pi
            if not (fin <= ang <= ini):
                continue
            k = (ini - ang) / (ini - fin)                       # 0 en el mango, 1 en la punta
            g = (3.4 * math.sin(math.pi * min(1.0, 0.15 + k * 0.85)) ** 0.7 + 0.6) / n
            if R - g <= d <= R + 0.6 / n:
                if d < R - g + 1.2 / n:
                    t = BRI if k < 0.75 else MET_L              # el FILO, por dentro
                elif d > R - 0.4 / n:
                    t = HON if ang < 1.2 else MET_S             # el lomo
                else:
                    t = MET_L if ang > 1.8 else MET
                cv.pon(x, y, t)
    def f(s, p, e):
        if -15 * e <= s < -10 * e:
            return puno(s, p, -15 * e, -10 * e, -1, 0)
        if -10 * e <= s <= -2.2 and -1 <= p <= 0:
            return MAD_L if p == -1 else MAD_S
        return 0
    EP.diag(cv, f)
    cv.pon(int(hx * n), int(hy * n), MET_S)                     # la virola


def hoz_ref(cv):
    # LA HOZ DE LA REFERENCIA DEL JEFE (06/11, foto de una hoz de verdad), en espejo para que el mango vaya abajo a la
    # izquierda como el resto: mango corto de madera torneada con sus RAYAS y la VIROLA de metal; la hoja arranca ANCHA
    # junto al mango, da la vuelta en MEDIA LUNA por abajo y por la derecha y acaba en una PUNTA FINA arriba, lejos del
    # palo. El FILO va por dentro (la parte concava).
    n = cv.n
    C, R = (0.56, 0.44), 0.38                      # el circulo de fuera
    # (06/11) la hoja FINA: el jefe prefirio esta a la engordada ("asi mejor")
    C2, R2 = (0.47, 0.35), 0.33                    # el de dentro, corrido hacia la boca: la hoja adelgaza hacia la punta
    ini, fin = math.radians(-152), math.radians(96)   # de junto al mango (abajo-izquierda) hasta la punta (arriba)
    for y in range(n):
        for x in range(n):
            fx, fy = (x + 0.5) / n, (y + 0.5) / n
            d1 = math.hypot(fx - C[0], fy - C[1])
            d2 = math.hypot(fx - C2[0], fy - C2[1])
            if d1 > R or d2 < R2:
                continue
            ang = math.atan2(-(fy - C[1]), fx - C[0])
            if not (ini <= ang <= fin):
                continue
            k = (ang - ini) / (fin - ini)                   # 0 junto al mango, 1 en la punta
            if d2 < R2 + 1.3 / n:
                t = BRI if 0.15 < k < 0.85 else MET_L       # el FILO, por dentro
            elif d1 > R - 1.2 / n:
                t = HON if ang < math.radians(30) else MET_S   # el lomo de fuera; abajo en sombra
            else:
                luz = -(fx - C[0]) * 0.6 - (fy - C[1]) * 0.8
                t = MET_L if luz > 0.12 else (MET if luz > -0.15 else MET_S)
            cv.pon(x, y, t)
    # el mango: de abajo a la izquierda hasta el arranque de la hoja, con la virola y las rayas torneadas
    ax = C[0] + R * math.cos(ini) + 0.02
    ay = C[1] - R * math.sin(ini) - 0.01
    bx, by = 0.06, 0.88
    largo = math.hypot(ax - bx, ay - by)
    for y in range(n):
        for x in range(n):
            fx, fy = (x + 0.5) / n, (y + 0.5) / n
            t_ = ((fx - bx) * (ax - bx) + (fy - by) * (ay - by)) / (largo * largo)
            if not (0.0 <= t_ <= 1.0):
                continue
            px_, py_ = bx + (ax - bx) * t_, by + (ay - by) * t_
            dd = math.hypot(fx - px_, fy - py_)
            grueso = 0.045 if t_ > 0.08 else 0.06        # el remate del final, mas gordo
            if dd <= grueso and cv.get(x, y) == 0:
                lado = (fx - px_) * (ay - by) - (fy - py_) * (ax - bx)
                if t_ > 0.86:
                    t = MET_L if lado < 0 else MET_S        # la VIROLA
                elif abs(t_ - 0.30) < 0.03 or abs(t_ - 0.38) < 0.03 or abs(t_ - 0.70) < 0.03:
                    t = MAD_S                                # las rayas del torneado
                else:
                    t = MAD_L if lado < 0 else MAD
                cv.pon(x, y, t)


def hoz_b(cv):
    hoz_abierta(cv, 0.27, -0.15)


def hoz_c(cv):
    hoz_abierta(cv, 0.31, 0.25)


def cana(cv):
    # CAÑA: la vara larga y fina, el puño de corcho, el CARRETE de metal y el sedal que cae desde la punta
    n = cv.n
    def f(s, p, e):
        if -15 * e <= s < -9 * e and -1 <= p <= 0:
            return puno(s, p, -15 * e, -9 * e, -1, 0)
        if math.hypot(s + 7.5 * e, (p - 2.5) * 0.9) <= 2.2:                  # el carrete
            return BRI if p < 2 and s < -7.5 * e else (MET if p < 3.5 else HON)
        if -9 * e <= s <= 15 * e and p == 0:
            return MAD_L if s < 4 * e else MAD
        if -9 * e <= s <= 6 * e and p == 1:
            return MAD_S
        return 0
    diag(cv, f)
    # el sedal: de la punta hacia abajo, en curva
    for k in range(int(n * 0.55)):
        x = int(n * 0.92 - k * 0.12)
        y = int(n * 0.10 + k)
        if 0 <= x < n and 0 <= y < n and cv.p[y][x] == 0:
            cv.pon(x, y, CUERDA)


def cuchillo(cv):
    # CUCHILLO DE DESOLLAR: hoja ancha de un solo filo que se curva a la punta y mango de madera con dos remaches
    def f(s, p, e):
        if -13 * e <= s < -2 * e and -1 <= p <= 1:
            if abs(s + 10 * e) < 0.6 or abs(s + 5 * e) < 0.6:
                return MET_L if p <= 0 else MET_S                           # los remaches
            return MAD_L if p == -1 else (MAD if p == 0 else MAD_S)
        if -2 * e <= s < -1 * e and -2 <= p <= 1:
            return MET_S                                                     # el tope
        if -1 * e <= s <= 9 * e:
            falta = 9 * e - s
            arriba = -5 if falta > 5 else (-4 if falta > 3.5 else (-3 if falta > 2 else -2))
            abajo = 0 if falta > 1.5 else -1
            if arriba <= p <= abajo:
                if p == arriba:
                    return BRI if s < 5 * e else MET_L                      # el filo
                if p == abajo:
                    return HON                                               # el lomo
                return MET
        return 0
    diag(cv, f)


# (06/11) EL PICO: el de ARCO GRANDE (lo eligio el jefe; los otros se leian como punta de flecha). LA HOZ: abierta, con
# la punta lejos del palo (cerrada sobre el mango "es muy cerrado hacia el palo"): la de SU FOTO, con la hoja fina.
HERRAMIENTAS = [("Pico (arco grande)", pico_d), ("Hacha de talar", hacha_grande_talar), ("Hoz", hoz_ref), ("Caña", cana), ("Cuchillo", cuchillo)]


def main():
    salida = sys.argv[1] if len(sys.argv) > 1 else "herramientas_lamina.png"
    with open(os.path.join(EP.AQUI, "paletas_equipo.json"), encoding="utf-8") as f:
        PAL = json.load(f)
    try:
        f1 = ImageFont.truetype("arial.ttf", 20)
        f2 = ImageFont.truetype("arial.ttf", 13)
    except OSError:
        f1 = f2 = None
    ESC, N = 4, 32
    COLS = EP.COLUMNAS[:3]
    cw = N * ESC + 12
    x0 = 160
    fila = N * ESC + 16
    w = x0 + cw * len(COLS) + N + 30
    h = 66 + fila * len(HERRAMIENTAS)
    lam = Image.new("RGBA", (w, h), (16, 16, 20, 255))
    d = ImageDraw.Draw(lam)
    d.text((16, 12), "HERRAMIENTAS EN PIXEL (32 px): T1, T2 y T3 a x4, y T2 a tamano real", fill=(240, 190, 100), font=f1)
    for i, (_t, _m, nom) in enumerate(COLS):
        d.text((x0 + i * cw, 42), nom, fill=(200, 200, 210), font=f2)
    for j, (nombre, fn) in enumerate(HERRAMIENTAS):
        y = 62 + j * fila
        d.text((16, y + 56), nombre, fill=(220, 220, 228), font=f2)
        cv = EP.dibujar(fn, N)
        for k, (t, m, _n) in enumerate(COLS):
            im = EP.teñir(cv, A.paleta(PAL["arma|metal|%d|%d" % (t, m)]))
            g = im.resize((N * ESC, N * ESC), Image.NEAREST)
            lam.paste(g, (x0 + k * cw, y), g)
            if t == 2:
                lam.paste(im, (x0 + len(COLS) * cw + 6, y + N * ESC - N), im)
    lam.save(salida)
    print(salida)


if __name__ == "__main__":
    main()
