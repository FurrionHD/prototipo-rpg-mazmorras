# PROTOTIPO: el minotauro como FORMAS QUE SE FUNDEN (SDF), pintado desde la camara del juego (45 grados), con tonos
# planos y contorno. Uso: python sdf_mino.py [dirs...]  -> sdf_<dir>.png (x1) y sdf_hoja.png (x4)
import sys, math
import numpy as np
from PIL import Image

OUT = 'tools/salida/sdf/'

# --- CAMARA (la del juego: pantalla_y = y*cos - z*sin) ---
CAM = math.radians(45.0)
C, S = math.cos(CAM), math.sin(CAM)
R_ = np.array([1.0, 0.0, 0.0])
U_ = np.array([0.0, -C, S])          # arriba en pantalla
F_ = np.array([0.0, -S, -C])         # hacia dentro de la pantalla
PPU = 2.8                            # pixeles por unidad
W, H = 144, 186                      # lienzo
OX, OY = W / 2, H - 16               # donde cae el origen (los pies)
ESTIRA = 1.18                        # las alturas, estiradas (si no, a 45 grados un humanoide sale achaparrado)

PIERNA_EXTRA = 1.8                   # todo lo que va de la cadera para arriba sube esto: piernas mas largas

def Z(x, y, z):
    if z >= 18.0:
        z += PIERNA_EXTRA
    return np.array([x, y, z * ESTIRA], dtype=float)

# --- PRIMITIVAS (P: N x 3) ---
def sd_esfera(P, c, r):
    return np.linalg.norm(P - c, axis=1) - r

def sd_elipsoide(P, c, rad):
    q = (P - c) / rad
    k0 = np.linalg.norm(q, axis=1)
    k1 = np.linalg.norm(q / rad, axis=1)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-6)

def sd_cono(P, a, b, ra, rb):
    """Capsula con radio que va de ra (en a) a rb (en b)."""
    pa = P - a; ba = b - a
    h = np.clip((pa @ ba) / max(ba @ ba, 1e-6), 0.0, 1.0)
    return np.linalg.norm(pa - np.outer(h, ba), axis=1) - (ra + (rb - ra) * h)

def sd_caja(P, c, ejes, medio, redondeo=0.2):
    """Caja orientada: 'ejes' = 3 vectores unitarios (filas), 'medio' = semilados."""
    q = (P - c) @ np.array(ejes).T
    d = np.abs(q) - (np.array(medio) - redondeo)
    return np.linalg.norm(np.maximum(d, 0.0), axis=1) + np.minimum(d.max(axis=1), 0.0) - redondeo

def smin(a, b, k):
    if k <= 0: return np.minimum(a, b)
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b + (a - b) * h - k * h * (1.0 - h)

# --- MATERIALES: tres tonos (sombra, base, luz) ---
MAT = {
    'piel':   [(0.50, 0.19, 0.11), (0.70, 0.30, 0.16), (0.87, 0.47, 0.24)],
    'pelo':   [(0.22, 0.12, 0.09), (0.32, 0.18, 0.13), (0.42, 0.25, 0.18)],
    'pezuna': [(0.15, 0.16, 0.23), (0.22, 0.24, 0.32), (0.32, 0.34, 0.43)],
    'cuero':  [(0.15, 0.10, 0.08), (0.23, 0.15, 0.12), (0.31, 0.21, 0.16)],
    'cuerno': [(0.70, 0.60, 0.46), (0.87, 0.78, 0.62), (0.96, 0.91, 0.79)],
    'morro':  [(0.66, 0.38, 0.34), (0.84, 0.54, 0.48), (0.93, 0.68, 0.62)],
    'ojo':    [(1.00, 0.78, 0.10), (1.00, 0.82, 0.15), (1.00, 0.90, 0.40)],
    'oro':    [(0.70, 0.50, 0.08), (0.94, 0.74, 0.16), (1.00, 0.90, 0.45)],
    'hierro': [(0.20, 0.21, 0.25), (0.31, 0.32, 0.37), (0.46, 0.47, 0.52)],
    'filo':   [(0.62, 0.62, 0.66), (0.80, 0.80, 0.83), (0.92, 0.92, 0.94)],
    'madera': [(0.30, 0.17, 0.10), (0.42, 0.25, 0.14), (0.52, 0.33, 0.19)],
}
NOMBRES = list(MAT.keys())
BORDE = (0.13, 0.06, 0.05)


def escena():
    """Lista de (sdf_fn, material, grupo, k). Los del grupo 'cuerpo' se FUNDEN entre si con su k; el resto es union dura."""
    L = []
    def add(fn, mat, k=0.0, grupo='cuerpo'):
        L.append((fn, mat, grupo, k))

    # TORSO EN V
    add(lambda P: sd_elipsoide(P, Z(0, -0.4, 21.4), np.array([4.9, 4.2, 3.2 * ESTIRA])), 'piel', 0)
    add(lambda P: sd_elipsoide(P, Z(0, 0.8, 24.8), np.array([5.4, 4.4, 3.8 * ESTIRA])), 'piel', 2.0)
    add(lambda P: sd_elipsoide(P, Z(0, 1.0, 29.4), np.array([9.2, 5.8, 5.4 * ESTIRA])), 'piel', 2.0)
    for s in (-1, 1):
        add(lambda P, s=s: sd_elipsoide(P, Z(4.4 * s, 3.8, 29.0), np.array([4.2, 2.8, 3.2 * ESTIRA])), 'piel', 1.2)
    add(lambda P: sd_elipsoide(P, Z(0, -1.2, 33.4), np.array([6.2, 3.6, 2.8 * ESTIRA])), 'piel', 2.0)   # trapecio
    add(lambda P: sd_cono(P, Z(0, -0.2, 32.0), Z(0, 1.0, 36.4), 3.6, 3.2), 'piel', 1.5)                 # cuello

    # BRAZOS: deltoide, brazo, antebrazo gordo, puño; el brazalete por encima (union dura)
    for s in (-1, 1):
        # EL CODO UN POCO DOBLADO (va hacia atras y el antebrazo sale hacia delante): un brazo recto es un espagueti.
        hom = Z(9.6 * s, 0.4, 31.4); codo = Z(11.2 * s, -1.0, 23.6); mun = Z(12.4 * s, 2.0, 16.8)
        add(lambda P, c=hom: sd_elipsoide(P, c - Z(0, 0, 0.6), np.array([2.9, 3.0, 3.2 * ESTIRA])), 'piel', 2.2)
        # El brazo: hueso fino (se estrecha en el codo) y encima los MUSCULOS, fundidos poco para que se marquen.
        add(lambda P, a=hom, b=codo: sd_cono(P, a, b, 2.4, 1.8), 'piel', 1.0)
        bi = hom + (codo - hom) * 0.5
        add(lambda P, c=bi + np.array([0.3 * s, 1.3, 0.0]): sd_elipsoide(P, c, np.array([2.3, 2.1, 3.0 * ESTIRA])), 'piel', 0.7)   # biceps
        add(lambda P, c=bi + np.array([0.5 * s, -1.1, 0.4]): sd_elipsoide(P, c, np.array([2.2, 2.0, 3.2 * ESTIRA])), 'piel', 0.7)  # triceps
        add(lambda P, a=codo, b=mun: sd_cono(P, a, b, 1.9, 1.7), 'piel', 0.8)
        # EL ANTEBRAZO, gordo junto al codo y afinando hacia la muñeca, con el bulto hacia fuera y delante.
        ab = codo + (mun - codo) * 0.3
        add(lambda P, c=ab + np.array([0.4 * s, 0.5, 0.0]): sd_elipsoide(P, c, np.array([2.6, 2.4, 3.2 * ESTIRA])), 'piel', 0.8)
        add(lambda P, a=codo, b=mun: sd_cono(P, a + (b - a) * 0.45, a + (b - a) * 0.95, 2.95, 2.7), 'cuero', 0, 'brazalete')
        puno = mun + Z(0.2 * s, 0.4, -2.2)
        add(lambda P, c=puno: sd_elipsoide(P, c, np.array([2.6, 2.6, 2.6 * ESTIRA])), 'piel', 0.8)

    # PIERNAS digitigradas: muslo, rodilla adelante, corvejon atras, pezuña
    for s in (-1, 1):
        cad = Z(4.2 * s, 0.0, 20.0); rod = Z(4.8 * s, 1.4, 11.8); cor = Z(4.6 * s, -1.2, 5.6); pie = Z(4.7 * s, 0.6, 1.3)
        add(lambda P, a=cad, b=rod: sd_cono(P, a, b, 3.7, 2.8), 'piel', 1.5)
        add(lambda P, a=rod, b=cor: sd_cono(P, a, b, 2.6, 1.9), 'pelo', 1.0)
        add(lambda P, a=cor, b=pie: sd_cono(P, a, b, 1.9, 1.7), 'pelo', 0.8)
        add(lambda P, c=Z(4.7 * s, 1.0, 1.0): sd_elipsoide(P, c, np.array([2.1, 2.6, 1.2 * ESTIRA])), 'pezuna', 0.4)

    # CABEZA: craneo, cara larga hacia abajo, morro claro, cejas, orejas, ojos, anilla
    add(lambda P: sd_elipsoide(P, Z(0, 0.8, 39.0), np.array([3.8, 3.8, 3.4 * ESTIRA])), 'piel', 1.5)
    add(lambda P: sd_cono(P, Z(0, 2.0, 38.6), Z(0, 6.4, 36.2), 3.3, 2.8), 'piel', 1.2)
    add(lambda P: sd_elipsoide(P, Z(0, 7.3, 35.6), np.array([2.9, 2.1, 1.9 * ESTIRA])), 'morro', 0, 'morro')
    for s in (-1, 1):
        add(lambda P, s=s: sd_elipsoide(P, Z(2.1 * s, 3.8, 40.0), np.array([1.5, 1.2, 0.7 * ESTIRA])), 'piel', 0.6)   # ceja
        add(lambda P, s=s: sd_elipsoide(P, Z(4.3 * s, 0.2, 39.4), np.array([2.0, 0.9, 0.9 * ESTIRA])), 'piel', 0.5)   # oreja
        add(lambda P, s=s: sd_esfera(P, Z(2.3 * s, 5.0, 38.9), 0.85), 'ojo', 0, 'ojo')
        add(lambda P, s=s: sd_esfera(P, Z(1.1 * s, 9.2, 35.9), 0.5), 'pelo', 0, 'narina')
    # La anilla: un toro de oro colgando del morro.
    def anilla(P):
        q = P - Z(0, 8.8, 34.3)
        d2 = np.sqrt(q[:, 0] ** 2 + (q[:, 2] / ESTIRA) ** 2) - 1.2
        return np.sqrt(d2 ** 2 + q[:, 1] ** 2) - 0.38
    add(anilla, 'oro', 0, 'anilla')

    # CUERNOS EN U: cadena de conos, hacia fuera, arriba y un poco adelante
    for s in (-1, 1):
        p = Z(3.2 * s, 0.6, 41.2); th = 0.30; r = 1.8
        for k in range(7):
            d = np.array([math.cos(th) * s, 0.12 + 0.06 * k, math.sin(th) * ESTIRA]); d /= np.linalg.norm(d)
            q = p + d * 1.7; r2 = max(0.5, r - 0.2)
            add(lambda P, a=p, b=q, ra=r, rb=r2: sd_cono(P, a, b, ra, rb), 'cuerno', 0, 'cuerno')
            p = q; r = r2; th += 0.26

    # TAPARRABOS: el cinto (un aro algo mas ancho que la cadera) y las dos tiras de cuero
    add(lambda P: sd_elipsoide(P, Z(0, -0.3, 22.2), np.array([5.5, 4.7, 1.2 * ESTIRA])), 'cuero', 0, 'ropa')
    for s in (1, -1):
        ejes = [np.array([1.0, 0, 0]), np.array([0, 1.0, 0]), np.array([0, 0, 1.0])]
        add(lambda P, s=s, e=ejes: sd_caja(P, Z(0, 4.9 * s, 18.2), e, [2.0, 0.35, 5.0 * ESTIRA], 0.3), 'cuero', 0, 'ropa')

    # COLA con borla
    p = Z(0, -4.6, 21.4)
    for k in range(8):
        f = k / 7.0
        q = p + Z(0.5 * f, -0.7 + 0.4 * f, -1.05)
        add(lambda P, a=p, b=q: sd_cono(P, a, b, 0.7, 0.65), 'piel', 0.3, 'cola')
        p = q
    add(lambda P, c=p: sd_elipsoide(P, c, np.array([1.3, 1.3, 2.0 * ESTIRA])), 'pelo', 0.5, 'cola')

    # EL HACHA en el puño derecho (x negativa): cabeza colgando bajo el puño, mango subiendo por detras del antebrazo
    puno = Z(-12.4, 2.0, 16.8) + Z(-0.2, 0.4, -2.2)
    abajo = np.array([-0.18, 0.1, -1.0]); abajo /= np.linalg.norm(abajo)
    add(lambda P: sd_cono(P, puno - abajo * 6.0, puno + abajo * 5.5, 0.55, 0.55), 'madera', 0, 'hacha')
    cab = puno + abajo * 5.6
    afuera = np.array([-0.35, 1.0, 0.0]); afuera /= np.linalg.norm(afuera)
    normal = np.cross(afuera, abajo); normal /= np.linalg.norm(normal)
    for sg in (1, -1):
        def hoja(P, sg=sg):
            q = P - cab
            t = q @ abajo; dd = q @ afuera * sg; n = q @ normal
            # media luna: elipse centrada fuera del mango, cortada junto al mango
            e = np.sqrt(((dd - 3.4) / 3.6) ** 2 + (t / (1.4 + 0.75 * np.clip(dd, 0, 6))) ** 2) - 1.0
            d2 = np.maximum(e * 2.0, 0.6 - dd)
            return np.maximum(d2, np.abs(n) - 0.35)
        add(hoja, 'hierro', 0, 'hacha')
        def filo(P, sg=sg):
            q = P - cab
            t = q @ abajo; dd = q @ afuera * sg; n = q @ normal
            e = np.sqrt(((dd - 3.4) / 3.6) ** 2 + (t / (1.4 + 0.75 * np.clip(dd, 0, 6))) ** 2) - 1.0
            d2 = np.maximum(np.abs(e * 2.0 + 0.5) - 0.5, 4.2 - dd)
            return np.maximum(d2, np.abs(n) - 0.4)
        add(filo, 'filo', 0, 'hacha')
    add(lambda P: sd_cono(P, cab - abajo * 1.2, cab + abajo * 1.2, 0.95, 0.95), 'hierro', 0, 'hacha')
    return L


def evalua(P, L):
    """Distancia y material: el cuerpo se funde (smin), lo demas se une duro."""
    cuerpo = None
    d_min = np.full(len(P), 1e9); mat = np.zeros(len(P), dtype=int); mat_d = np.full(len(P), 1e9)
    dur = np.full(len(P), 1e9); dur_mat = np.zeros(len(P), dtype=int)
    for fn, m, g, k in L:
        d = fn(P)
        mi = NOMBRES.index(m)
        if g == 'cuerpo':
            cuerpo = d if cuerpo is None else smin(cuerpo, d, k)
            mejor = d < mat_d
            mat = np.where(mejor, mi, mat); mat_d = np.where(mejor, d, mat_d)
        else:
            mejor = d < dur
            dur_mat = np.where(mejor, mi, dur_mat); dur = np.minimum(dur, d)
    usa_dur = dur < cuerpo
    return np.where(usa_dur, dur, cuerpo), np.where(usa_dur, dur_mat, mat)


def render(dir_i, L):
    vecs = [(0, 1), (0.7, 0.7), (1, 0), (0.7, -0.7), (0, -1), (-0.7, -0.7), (-1, 0), (-0.7, 0.7)]
    v = vecs[dir_i]
    ang = math.atan2(v[1], v[0]) - math.atan2(1, 0)
    ca, sa = math.cos(-ang), math.sin(-ang)
    jj, ii = np.mgrid[0:H, 0:W]
    u = (ii.ravel() + 0.5 - OX) / PPU
    vv = (OY - (jj.ravel() + 0.5)) / PPU
    O = np.outer(u, R_) + np.outer(vv, U_) - F_ * 80.0
    def a_local(P):
        x = P[:, 0] * ca - P[:, 1] * sa; y = P[:, 0] * sa + P[:, 1] * ca
        return np.stack([x, y, P[:, 2]], axis=1)
    t = np.zeros(len(O)); vivo = np.ones(len(O), dtype=bool); toca = np.zeros(len(O), dtype=bool)
    for _ in range(140):
        idx = np.where(vivo)[0]
        if len(idx) == 0: break
        P = a_local(O[idx] + np.outer(t[idx], F_))
        d, _m = evalua(P, L)
        hit = d < 0.02
        toca[idx[hit]] = True; vivo[idx[hit]] = False
        t[idx[~hit]] += np.maximum(d[~hit] * 0.8, 0.02)
        lejos = t > 170
        vivo &= ~lejos
    hi = np.where(toca)[0]
    P = a_local(O[hi] + np.outer(t[hi], F_))
    _d, mats = evalua(P, L)
    e = 0.05
    n = np.zeros_like(P)
    for a in range(3):
        dv = np.zeros(3); dv[a] = e
        n[:, a] = evalua(P + dv, L)[0] - evalua(P - dv, L)[0]
    n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-6)
    # La luz viene de arriba a la izquierda y algo de delante, FIJA EN PANTALLA: se gira con el bicho al reves.
    luz_mundo = np.array([-0.75, 0.35, 0.6]); luz_mundo /= np.linalg.norm(luz_mundo)
    lx = luz_mundo[0] * ca - luz_mundo[1] * sa; ly = luz_mundo[0] * sa + luz_mundo[1] * ca
    luz = np.array([lx, ly, luz_mundo[2]])
    ndl = n @ luz
    # Oclusion barata: en los recovecos (axilas, entre piernas) baja un tono.
    ao = np.clip(evalua(P + n * 1.2, L)[0] / 1.2, 0, 1)
    banda = np.where(ndl > 0.62, 2, np.where(ndl > 0.22, 1, 0))
    banda = np.where(ao < 0.55, np.maximum(banda - 1, 0), banda)
    img = np.zeros((H * W, 4))
    for i, nom in enumerate(NOMBRES):
        sel = mats == i
        if nom == 'ojo':
            bb = np.full(sel.sum(), 2)
        else:
            bb = banda[sel]
        cols = np.array(MAT[nom])[bb]
        img[hi[sel], :3] = cols
    img[hi, 3] = 1.0
    prof = np.full(H * W, np.inf); prof[hi] = t[hi]
    matmap = np.full(H * W, -1); matmap[hi] = mats; matmap = matmap.reshape(H, W)
    img = img.reshape(H, W, 4); prof = prof.reshape(H, W)
    OJO_I = NOMBRES.index('ojo')
    # CONTORNO de fuera y LINEAS DE DENTRO donde hay salto de profundidad (lo de delante va suelto).
    sal = img.copy()
    for y in range(H):
        for x in range(W):
            if img[y, x, 3] == 0: continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                fuera = nx < 0 or ny < 0 or nx >= W or ny >= H or img[ny, nx, 3] == 0
                if fuera or (matmap[y, x] != OJO_I and prof[ny, nx] - prof[y, x] > 2.6):
                    sal[y, x, :3] = BORDE; break
    return Image.fromarray((sal * 255).astype(np.uint8), 'RGBA')


if __name__ == '__main__':
    dirs = [int(a) for a in sys.argv[1:]] or [0, 1, 2, 3, 4]
    L = escena()
    ims = []
    for d in dirs:
        im = render(d, L); im.save(OUT + 'sdf_%d.png' % d); ims.append(im); print('dir', d)
    Zm = 4
    hoja = Image.new('RGB', (W * Zm * len(ims), H * Zm), (28, 30, 38))
    for i, im in enumerate(ims):
        g = im.resize((W * Zm, H * Zm), Image.NEAREST); hoja.paste(g, (i * W * Zm, 0), g)
    hoja.thumbnail((1700, 1700)); hoja.save(OUT + 'sdf_hoja.png')
