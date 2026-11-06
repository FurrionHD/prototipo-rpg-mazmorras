# ============================================================
#  equipo_pixel.py  (06/11, rework visual a pixel: "sprites de armas y armaduras y cualquier dibujo de objeto que no
#  sea pixel art de verdad", y "como armadura y asi en el inventario")
#  LAMINA DE PRUEBA del EQUIPO en pixel art de verdad, para la celda del inventario. Hoy esas celdas enseñan la capa del
#  muñeco ampliada (retrato_pieza.gd), que es "un dibujo con pixeles", no pixel art.
#
#  SE DIBUJA EN LOS INDICES DE TONO DEL JUEGO, no en colores: el mismo papel por tono que ArmaSprites.ROLES y
#  ArmaduraSprites.ROLES, asi que en el juego lo seguira tiñendo paleta_equipo.gdshader con su tier y su +N. Aqui se
#  tiñe con las paletas DE VERDAD, volcadas del juego a tools/salida/paletas_equipo.json.
#
#  Cada pieza es una funcion de coordenadas NORMALIZADAS (0..1), asi que sale a 32 y a 24 px con el mismo dibujo.
#  Las armas van en diagonal (pomo abajo a la izquierda, punta arriba a la derecha) y la luz viene de arriba a la
#  izquierda, como en los libros.
#    python tools/equipo_pixel.py [salida.png]
# ============================================================
import json
import math
import os
import sys
from PIL import Image, ImageDraw, ImageFont

AQUI = os.path.dirname(os.path.abspath(__file__))

# Tonos del ARMA (ArmaSprites.ROLES): 2 borde, 3/4 mango (cuero), 5/6/7 metal, 8/9/10 madera
B, MANGO_S, MANGO, MET_S, MET, MET_L, MAD_S, MAD, MAD_L = 2, 3, 4, 5, 6, 7, 8, 9, 10
# Tonos de la ARMADURA (ArmaduraSprites.ROLES): 2 borde, 3/4/5 material, 6 oscuro, 7 acento
MAT_S, MAT, MAT_L, OSC, ACE = 3, 4, 5, 6, 7


class Lienzo:
    def __init__(self, n):
        self.n = n
        self.p = [[0] * n for _ in range(n)]

    def pon(self, x, y, t):
        if 0 <= x < self.n and 0 <= y < self.n:
            self.p[y][x] = t

    def get(self, x, y):
        return self.p[y][x] if 0 <= x < self.n and 0 <= y < self.n else 0

    # Rellena con 't' los pixeles cuyo centro cumple 'f(fx, fy)' (coordenadas 0..1).
    def mancha(self, f, t):
        n = self.n
        for y in range(n):
            for x in range(n):
                if f((x + 0.5) / n, (y + 0.5) / n):
                    self.p[y][x] = t

    # La mascara de lo que cumple f, para biselarla despues.
    def mascara(self, f):
        n = self.n
        return {(x, y) for y in range(n) for x in range(n) if f((x + 0.5) / n, (y + 0.5) / n)}

    # BISEL: base en todo, luz en el borde de arriba/izquierda, sombra en el de abajo/derecha.
    def biselar(self, m, base, luz, sombra):
        for (x, y) in m:
            t = base
            if (x - 1, y) not in m or (x, y - 1) not in m:
                t = luz
            elif (x + 1, y) not in m or (x, y + 1) not in m:
                t = sombra
            self.pon(x, y, t)

    def contorno(self):
        n = self.n
        marcar = []
        for y in range(n):
            for x in range(n):
                if self.p[y][x] == 0:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        v = self.get(x + dx, y + dy)
                        if v not in (0, B):
                            marcar.append((x, y))
                            break
        for x, y in marcar:
            self.p[y][x] = B


# ---- LAS ARMAS, en diagonal ----
# s = a lo largo de la diagonal (pixeles de diagonal, 0 en el centro), p = filas de diagonal hacia abajo-derecha
# (p < 0 es el lado de la luz). Cada fila de diagonal es una escalera limpia de pixeles.
def diag(cv, fn):
    n = cv.n
    k = n - 1
    for y in range(n):
        for x in range(n):
            s = (x - y) / 2.0
            p = x + y - k
            t = fn(s, p, n / 32.0)
            if t:
                cv.pon(x, y, t)


def tono_hoja(p, acanalada=False):
    # Cuatro filas de diagonal (~3 px de ancho): el filo de arriba en luz, el de abajo en sombra.
    if p <= -2:
        return MET_L
    if p == -1:
        return MET
    if p == 0:
        return MET_S if acanalada else MET
    return MET_S


def puno(s, p):
    # El puño de cuero con sus vueltas: una fila de cada tres en sombra.
    return MANGO_S if (p == 1 or int((s + 20) * 1.4) % 3 == 0) else MANGO


def daga(cv):
    def f(s, p, e):
        if -13.0 * e <= s < -10.5 * e and -2 <= p <= 1:                # el pomo
            return MET_L if p < 0 else MET_S
        if -10.5 * e <= s < -5.0 * e and -1 <= p <= 1:                 # el puño
            return puno(s, p)
        if -5.0 * e <= s < -3.0 * e and abs(p) <= 4:                    # la guarda
            return MET_L if p < 0 else (MET if p == 0 else MET_S)
        if -3.0 * e <= s <= 12.5 * e:                                   # la hoja, ancha y en punta
            arriba = -2 if s < 7.0 * e else (-1 if s < 10.0 * e else 0)
            abajo = 1 if s < 10.0 * e else 0
            if arriba <= p <= abajo:
                return tono_hoja(p)
        return 0
    diag(cv, f)


def espada_larga(cv):
    def f(s, p, e):
        if -15.0 * e <= s < -13.0 * e and -2 <= p <= 1:
            return MET_L if p < 0 else MET_S
        if -13.0 * e <= s < -8.0 * e and -1 <= p <= 1:
            return puno(s, p)
        if -8.0 * e <= s < -6.0 * e and abs(p) <= 5:
            return MET_L if p < 0 else (MET if p == 0 else MET_S)
        if -6.0 * e <= s <= 15.0 * e:
            if s > 13.0 * e:
                return tono_hoja(p) if -1 <= p <= 0 else 0
            if -2 <= p <= 1:
                return tono_hoja(p, acanalada=s < 9.0 * e)
        return 0
    diag(cv, f)


def hacha(cv):
    def f(s, p, e):
        c, r = 8.5 * e, 6.0 * e
        q = -p                                                          # lo que se aleja del asta, hacia la luz
        if q >= 1:
            # el cuello estrecho junto al asta y la hoja que se abre en abanico, con el filo curvo
            hw = 1.6 * e if q <= 3 else min(r, 1.6 * e + (q - 3) * 1.25 * e)
            borde = 3 + 5.5 * e + 1.6 * e * math.sqrt(max(0.0, 1.0 - ((s - c) / r) ** 2))
            if abs(s - c) <= hw and q <= borde:
                if q >= borde - 1.5:
                    return MET_L                                        # el filo
                if abs(s - c) >= hw - 0.6:
                    return MET_S
                return MET
        if 2 <= p <= 4 and abs(s - c) <= (2.2 - (p - 2) * 0.6) * e:     # el contrafilo
            return MET_S if p > 2 else MET
        if -14.5 * e <= s <= 13.0 * e and -1 <= p <= 1:                 # el asta, de madera
            if abs(s - c) <= 2.2 * e:
                return MET_S if p == 1 else MET
            if s < -11.0 * e:
                return MANGO if p < 1 else MANGO_S                        # el puño forrado
            return MAD_L if p == -1 else (MAD if p == 0 else MAD_S)
        return 0
    diag(cv, f)


# ---- LAS ARMADURAS, de frente y simetricas ----
# VOLUMEN: ademas del bisel, la parte de abajo a la derecha en sombra y una mancha de luz arriba a la izquierda,
# segun la posicion dentro de su caja. Sin esto todo salia plano por dentro.
def volumen(cv, m, base, luz, sombra):
    if not m:
        return
    xs = [x for x, _ in m]
    ys = [y for _, y in m]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    for (x, y) in m:
        u = (x - x0) / max(1, x1 - x0)
        v = (y - y0) / max(1, y1 - y0)
        t = base
        if u + v * 0.6 > 1.15:
            t = sombra
        elif u + v < 0.55:
            t = luz
        cv.pon(x, y, t)
    for (x, y) in m:                                                     # y el bisel por encima
        if (x - 1, y) not in m or (x, y - 1) not in m:
            cv.pon(x, y, luz)
        elif (x + 1, y) not in m or (x, y + 1) not in m:
            cv.pon(x, y, sombra)


def punto(cv, fx, fy, t, r=0.6):
    cv.mancha(lambda x, y: abs(x - fx) < r / cv.n and abs(y - fy) < r / cv.n, t)


def casco_cuero(cv):
    cupula = lambda x, y: ((x - 0.5) / 0.36) ** 2 + ((y - 0.60) / 0.44) ** 2 <= 1.0 and y <= 0.64
    volumen(cv, cv.mascara(cupula), MAT, MAT_L, MAT_S)
    cv.mancha(lambda x, y: abs(x - 0.5) < 0.5 / cv.n and 0.20 <= y <= 0.62, MAT_S)            # la costura
    for fy in (0.30, 0.40, 0.50):
        punto(cv, 0.5 - 1.0 / cv.n, fy, OSC, 0.5)
    ala = cv.mascara(lambda x, y: 0.10 <= x <= 0.90 and 0.62 <= y <= 0.72)
    volumen(cv, ala, MAT_S, MAT, OSC)
    for fx in (0.22, 0.5, 0.78):
        punto(cv, fx, 0.67, ACE)                                                                # los remaches del ala


def casco_placas(cv):
    def yelmo(x, y):
        if not (0.22 <= x <= 0.78 and 0.16 <= y <= 0.86):
            return False
        return not (y < 0.34 and ((x - 0.5) / 0.28) ** 2 + ((y - 0.34) / 0.18) ** 2 > 1.0)
    volumen(cv, cv.mascara(yelmo), MAT, MAT_L, MAT_S)
    cv.mancha(lambda x, y: 0.28 <= x <= 0.72 and 0.44 <= y <= 0.51, OSC)                       # la mirilla
    cv.mancha(lambda x, y: abs(x - 0.5) < 0.5 / cv.n and 0.12 <= y <= 0.43, ACE)               # la cresta
    cv.mancha(lambda x, y: abs(x - 0.5) < 0.5 / cv.n and 0.53 <= y <= 0.86, MAT_L)             # la arista
    for fy in (0.64, 0.74):                                                                       # los respiraderos
        for fx in (0.34, 0.42, 0.58, 0.66):
            punto(cv, fx, fy, OSC, 0.5)


def _torso(x, y):
    if y < 0.16 or y > 0.86:
        return False
    if ((x - 0.5) / 0.13) ** 2 + ((y - 0.14) / 0.13) ** 2 <= 1.0:      # el hueco del cuello
        return False
    if y < 0.40:                                       # los hombros, redondeados por fuera
        semi = 0.42 - max(0.0, 0.26 - y) * 0.9
    else:                                              # se estrecha hacia la cintura
        semi = 0.30 - (y - 0.40) * 0.10
    if abs(x - 0.5) > semi:
        return False
    if 0.34 < y < 0.46 and abs(x - 0.5) > 0.30:        # bajo el hombro, la sisa
        return False
    return True


def pecho_cuero(cv):
    volumen(cv, cv.mascara(_torso), MAT, MAT_L, MAT_S)
    cv.mancha(lambda x, y: abs(x - 0.5) < 0.5 / cv.n and 0.27 <= y <= 0.74 and _torso(x, y), OSC)     # el cierre
    for fy in (0.36, 0.48, 0.60):                                                                         # las cintas
        cv.mancha(lambda x, y, fy=fy: abs(x - 0.5) < 1.6 / cv.n and abs(y - fy) < 0.5 / cv.n, MAT_L)
    for fx in (0.16, 0.84):                                                                                # costura del hombro
        cv.mancha(lambda x, y, fx=fx: _torso(x, y) and abs(x - fx) < 0.5 / cv.n and y < 0.36, MAT_S)
    volumen(cv, cv.mascara(lambda x, y: _torso(x, y) and 0.74 <= y <= 0.81), MAT_S, MAT, OSC)           # el cinto
    cv.mancha(lambda x, y: abs(x - 0.5) < 1.2 / cv.n and 0.74 <= y <= 0.81, ACE)                         # la hebilla


def pecho_placas(cv):
    volumen(cv, cv.mascara(_torso), MAT, MAT_L, MAT_S)
    for fy in (0.52, 0.63, 0.74):                                                                          # las lamas
        cv.mancha(lambda x, y, fy=fy: _torso(x, y) and abs(y - fy) < 0.5 / cv.n, MAT_S)
    cv.mancha(lambda x, y: _torso(x, y) and abs(x - 0.5) < 0.5 / cv.n and 0.24 <= y <= 0.50, MAT_L)      # la arista
    for fx in (0.17, 0.83):                                                                                # las hombreras
        cv.mancha(lambda x, y, fx=fx: _torso(x, y) and abs(y - 0.34) < 0.5 / cv.n and abs(x - fx) < 0.12, MAT_S)
        punto(cv, fx, 0.26, ACE)


def botas(cv):
    # Dos botas DE PERFIL, mirando a la izquierda, la de atras un poco mas arriba y a la derecha.
    def bota(x, y, dx, dy):
        x, y = x - dx, y - dy
        cana = 0.40 <= x <= 0.62 and 0.14 <= y <= 0.70
        pie = 0.62 <= y <= 0.80 and 0.22 <= x <= 0.62 and not (y < 0.68 and x < 0.30)
        return cana or pie
    for dx, dy in ((0.14, -0.04), (-0.06, 0.06)):                       # primero la de atras
        m = cv.mascara(lambda x, y, dx=dx, dy=dy: bota(x, y, dx, dy))
        volumen(cv, m, MAT, MAT_L, MAT_S)
        cv.mancha(lambda x, y, dx=dx, dy=dy: 0.40 <= x - dx <= 0.62 and 0.14 <= y - dy <= 0.21, MAT_L)  # la vuelta
        cv.mancha(lambda x, y, dx=dx, dy=dy: bota(x, y, dx, dy) and y - dy >= 0.76, OSC)                 # la suela
        punto(cv, 0.51 + dx, 0.36 + dy, ACE)


PIEZAS = [
    ("Daga", daga, "arma", "metal"),
    ("Espada larga", espada_larga, "arma", "metal"),
    ("Hacha grande", hacha, "arma", "metal"),
    ("Casco de cuero", casco_cuero, "armadura", "cuero"),
    ("Yelmo de placas", casco_placas, "armadura", "metal"),
    ("Peto de cuero", pecho_cuero, "armadura", "cuero"),
    ("Peto de placas", pecho_placas, "armadura", "metal"),
    ("Botas de cuero", botas, "armadura", "cuero"),
]
# Las columnas: tier y mejoras (la banda de color salta en +3 y +9)
COLUMNAS = [(1, 0, "T1"), (2, 0, "T2"), (3, 0, "T3"), (3, 12, "T3 +12")]


def dibujar(fn, n):
    cv = Lienzo(n)
    fn(cv)
    cv.contorno()
    return cv


def teñir(cv, paleta):
    im = Image.new("RGBA", (cv.n, cv.n), (0, 0, 0, 0))
    for y in range(cv.n):
        for x in range(cv.n):
            t = cv.p[y][x]
            if t:
                c = paleta[t]
                im.putpixel((x, y), tuple(int(round(v * 255)) for v in c[:3]) + (255,))
    return im


def main():
    salida = sys.argv[1] if len(sys.argv) > 1 else "equipo_lamina.png"
    with open(os.path.join(AQUI, "salida", "paletas_equipo.json"), encoding="utf-8") as f:
        PAL = json.load(f)
    try:
        f1 = ImageFont.truetype("arial.ttf", 20)
        f2 = ImageFont.truetype("arial.ttf", 13)
    except OSError:
        f1 = f2 = None
    ESC = 3
    cw32 = 32 * ESC + 44
    cw24 = 24 * ESC + 40
    x0 = 170
    x24 = x0 + cw32 * len(COLUMNAS) + 30
    fila = 32 * ESC + 18
    w = x24 + cw24 * 3 + 20
    h = 90 + fila * len(PIEZAS)
    lam = Image.new("RGBA", (w, h), (16, 16, 20, 255))
    d = ImageDraw.Draw(lam)
    d.text((16, 12), "EQUIPO EN PIXEL ART (prueba): a 32 px y a 24 px, x3 y a tamano real", fill=(240, 190, 100), font=f1)
    d.text((x0, 50), "32 x 32", fill=(240, 190, 100), font=f2)
    d.text((x24, 50), "24 x 24", fill=(240, 190, 100), font=f2)
    for i, (_t, _m, nom) in enumerate(COLUMNAS):
        d.text((x0 + i * cw32, 68), nom, fill=(200, 200, 210), font=f2)
    for i, (_t, _m, nom) in enumerate(COLUMNAS[:3]):
        d.text((x24 + i * cw24, 68), nom, fill=(200, 200, 210), font=f2)
    for j, (nombre, fn, grupo, fam) in enumerate(PIEZAS):
        y = 90 + j * fila
        d.text((16, y + 40), nombre, fill=(220, 220, 228), font=f2)
        for n, xb, cols, cw in ((32, x0, COLUMNAS, cw32), (24, x24, COLUMNAS[:3], cw24)):
            cv = dibujar(fn, n)
            for i, (t, m, _nom) in enumerate(cols):
                im = teñir(cv, PAL["%s|%s|%d|%d" % (grupo, fam, t, m)])
                g = im.resize((n * ESC, n * ESC), Image.NEAREST)
                x = xb + i * cw
                lam.paste(g, (x, y + (32 - n) * ESC // 2), g)
                lam.paste(im, (x + n * ESC + 4, y + 32 * ESC - n), im)
    lam.save(salida)
    print(salida)


if __name__ == "__main__":
    main()
