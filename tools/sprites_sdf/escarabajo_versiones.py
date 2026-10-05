# ============================================================
#  escarabajo_versiones.py -- TRES VERSIONES del escarabajo de hierro en quieto (05/10/2026), de sus referencias. El de
#  escarabajo_sdf.py "parece un culo": los dos elitros eran dos bultos redondos. Lo comun a las tres (sus fotos):
#    - los ELITROS son UN ovalo liso con solo la COSTURA fina por el medio (y unas estrias), no dos bolas;
#    - el PRONOTO es un ESCUDO grande, casi tan ancho como los elitros, separado de ellos por una raya;
#    - las PATAS son largas, en tres tramos, con PINCHOS en la tibia, y se ven bien por los lados.
#  Lo que cambia es la cabeza (y en la C, el caparazon):
#    A RINOCERONTE  un cuerno que sale de la cabeza y sube curvado hacia delante (empuja con el, como la pala).
#    B CIERVO       dos MANDIBULAS grandes curvadas hacia dentro, con un diente.
#    C CRISTAL      el caparazon son CRISTALES de facetas que salen del lomo, translucidos, y dos antenas-garfio.
#  Uso: python tools/sprites_sdf/escarabajo_versiones.py  -> tools/salida/sdf/escarabajo_versiones.png
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
from PIL import Image

V = np.array
MAT = {
    'caparazon': [(0.22, 0.31, 0.20), (0.36, 0.50, 0.33), (0.48, 0.63, 0.44), (0.86, 0.94, 0.82)],
    'costura':   [(0.10, 0.14, 0.09), (0.14, 0.20, 0.13), (0.18, 0.25, 0.16)],
    'oscuro':    [(0.12, 0.17, 0.11), (0.18, 0.25, 0.16), (0.26, 0.34, 0.22), (0.62, 0.72, 0.58)],
    'cara':      [(0.05, 0.07, 0.05), (0.09, 0.12, 0.08), (0.15, 0.20, 0.13), (0.50, 0.58, 0.46)],
    'pata':      [(0.11, 0.15, 0.10), (0.18, 0.25, 0.16), (0.26, 0.34, 0.22)],
    'cuerno':    [(0.16, 0.22, 0.14), (0.26, 0.36, 0.24), (0.38, 0.50, 0.34), (0.80, 0.90, 0.76)],
    'cristal':   [(0.30, 0.42, 0.28), (0.48, 0.64, 0.46), (0.66, 0.82, 0.62), (0.92, 0.98, 0.90)],
    'ojo':       [(1.0, 0.80, 0.30)] * 3,
}


def modelo(translucido=False):
    return Modelo(2.1, (80, 80), (40, 40), MAT, (0.06, 0.09, 0.05), suaves=('cuerpo',), brillan=('ojo',), corta_suelo=True,
                  especular=('caparazon', 'cuerno', 'cristal', 'oscuro', 'cara'), umbral_especular=0.96,
                  translucidos=('cristal',) if translucido else (), alfa=0.8)


def _cono(add, a, b, ra, rb, mat, g):
    add(lambda P, a=V(a, dtype=float), b=V(b, dtype=float): sd_cono(P, a, b, ra, rb), mat, 0, g)


def _elip(add, c, r, mat, g):
    add(lambda P, c=V(c, dtype=float), r=V(r, dtype=float): sd_elipsoide(P, c, r), mat, 0, g)


def _curva(add, pts, r0, r1, mat, g):
    n = len(pts) - 1
    for i in range(n):
        _cono(add, pts[i], pts[i + 1], r0 + (r1 - r0) * i / n, r0 + (r1 - r0) * (i + 1) / n, mat, g)


ELI_C = V((0.0, -3.4, 3.4)); ELI_R = V((5.3, 5.6, 3.3))


def cuerpo_comun(add, elitros=True, boca=True):
    if elitros:
        # LOS ELITROS: UN ovalo, liso y brillante...
        _elip(add, ELI_C, ELI_R, 'caparazon', 'elitros')
        # ...la COSTURA: una tira oscura que asoma un pelo por el medio, de punta a punta.
        _elip(add, ELI_C, (0.28, ELI_R[1] + 0.12, ELI_R[2] + 0.12), 'costura', 'costura')
        # (Las ESTRIAS sobraban: a este tamaño, rayas de sandia.)
    # El vientre, oscuro, que asoma por debajo.
    _elip(add, (0, -1.0, 2.0), (4.6, 6.4, 1.8), 'oscuro', 'vientre')
    # PIEZAS SEPARADAS ("parece que es una sola pieza"): entre el escudo y los elitros, una CINTURA oscura y estrecha
    # que se ve; los dos se tocan solo por la punta.
    _elip(add, (0, 2.2, 2.9), (2.8, 1.4, 1.9), 'oscuro', 'cintura')
    # EL PRONOTO: el escudo, ancho y abombado.
    _elip(add, (0, 4.7, 3.3), (4.6, 2.5, 2.6), 'caparazon', 'pronoto')
    # LA CABEZA, FUERA del escudo y oscura ("no tiene cara"), con OJOS GRANDES que asoman a los lados...
    _elip(add, (0, 7.8, 2.7), (2.5, 1.9, 1.7), 'cara', 'cabeza')
    for s in (-1, 1):
        _elip(add, (2.0 * s, 8.4, 3.2), (0.95, 0.9, 0.9), 'ojo', 'ojo')
        # ...y la BOCA: dos mandibulas cortas que se cierran delante.
        if boca:
            _cono(add, (1.1 * s, 9.3, 2.1), (1.5 * s, 10.4, 2.0), 0.5, 0.35, 'cuerno', 'boca%d' % s)
            _cono(add, (1.5 * s, 10.4, 2.0), (0.4 * s, 11.0, 2.0), 0.35, 0.12, 'cuerno', 'boca%d' % s)
    # LAS PATAS: coxa bajo el cuerpo, FEMUR hacia fuera y arriba, TIBIA abajo con PINCHOS, y el tarso hasta el suelo.
    for s in (-1, 1):
        for k, (y0, ang) in enumerate(((4.4, 0.75), (0.6, -0.15), (-3.0, -0.75))):
            d = V((math.cos(ang) * s, math.sin(ang), 0.0))
            base = V((2.6 * s, y0, 1.8))
            rod = base + d * 4.6 + V((0, 0, 1.6))
            tob = base + d * 7.4 + V((0, 0, -0.6))
            pie = base + d * 9.0 + V((0, 0, -1.7))
            g = 'pata%d%d' % (s, k)
            _cono(add, base, rod, 0.7, 0.55, 'pata', g)
            _cono(add, rod, tob, 0.55, 0.45, 'pata', g)
            _cono(add, tob, pie, 0.35, 0.22, 'pata', g)
            # los pinchos de la tibia, hacia fuera
            for f in (0.35, 0.7):
                p = rod + (tob - rod) * f
                _cono(add, p, p + d * 0.9 + V((0, 0, 0.5)), 0.28, 0.08, 'pata', g)


def version_a():
    # RINOCERONTE: un cuerno largo que sale de la cabeza y sube curvado hacia delante; y un cuernecillo en el escudo.
    e = Escena({}); add = e.add
    cuerpo_comun(add)
    pts = [V((0, 8.0, 3.6)), V((0, 9.4, 4.8)), V((0, 10.6, 6.6)), V((0, 11.2, 8.8)), V((0, 10.9, 10.8)), V((0, 10.1, 11.9))]
    _curva(add, pts, 1.7, 0.3, 'cuerno', 'cuerno')
    _cono(add, (0, 5.2, 5.6), (0, 6.6, 7.4), 1.3, 0.3, 'cuerno', 'cuernecillo')
    return e.L


def version_b():
    # CIERVO VOLANTE: dos mandibulas grandes que salen hacia delante y se curvan hacia dentro, con un diente.
    e = Escena({}); add = e.add
    cuerpo_comun(add, boca=False)
    for s in (-1, 1):
        pts = [V((1.3 * s, 8.8, 2.8)), V((3.0 * s, 9.6, 3.8)), V((4.0 * s, 11.8, 4.8)), V((3.6 * s, 13.8, 5.6)),
               V((1.8 * s, 15.0, 5.8))]
        _curva(add, pts, 1.35, 0.3, 'cuerno', 'mandibula%d' % s)
        _cono(add, (3.7 * s, 11.0, 4.5), (2.0 * s, 11.8, 4.8), 0.6, 0.15, 'cuerno', 'mandibula%d' % s)
    return e.L


def version_c():
    # CRISTAL: el lomo son CRISTALES de facetas (cajas giradas, poco redondeadas) que salen hacia atras y arriba,
    # translucidos; el cuerpo de debajo, oscuro; dos antenas largas en garfio.
    e = Escena({}); add = e.add
    cuerpo_comun(add, elitros=False)
    _elip(add, (0, -2.0, 2.8), (4.6, 6.0, 2.4), 'oscuro', 'lomo')
    for (c, ang, inc, med) in (((0.0, -2.6, 6.8), 0.0, 1.05, (2.4, 5.2, 2.0)), ((-3.0, -1.6, 5.0), -0.45, 0.85, (1.8, 4.0, 1.6)),
                               ((3.0, -1.6, 5.0), 0.45, 0.85, (1.8, 4.0, 1.6))):
        # el cristal: su largo apunta hacia atras y arriba ('inc') y se abre de lado ('ang')
        lar = V((math.sin(ang), -math.cos(inc), math.sin(inc))); lar /= np.linalg.norm(lar)
        anc = np.cross(lar, V((0, 0, 1.0))); anc /= np.linalg.norm(anc)
        alt = np.cross(anc, lar)
        # girado 45 grados sobre su largo: asi enseña una ARISTA arriba (la faceta), no una cara plana
        a1 = (anc + alt) / math.sqrt(2); a2 = (alt - anc) / math.sqrt(2)
        add(lambda P, c=V(c), ej=[a1, lar, a2], m=med: sd_caja(P, c, ej, m, 0.15), 'cristal', 0, 'cristal%d' % int(c[0]))
    for s in (-1, 1):
        pts = [V((0.8 * s, 7.6, 2.8)), V((2.2 * s, 9.4, 4.8)), V((3.6 * s, 10.6, 7.2)), V((3.2 * s, 11.6, 8.2))]
        _curva(add, pts, 0.45, 0.2, 'cuerno', 'antena%d' % s)
        _cono(add, (3.6 * s, 10.6, 7.2), (4.6 * s, 10.4, 6.6), 0.3, 0.1, 'cuerno', 'antena%d' % s)
    return e.L


if __name__ == '__main__':
    filas = [('A', version_a(), modelo()), ('B', version_b(), modelo()), ('C', version_c(), modelo(True))]
    W = H = 80
    hoja = Image.new('RGB', (W * 5, H * 3), (40, 42, 50))
    for f, (_n, L, mo) in enumerate(filas):
        for d in range(5):
            im = render(mo, L, d)
            hoja.paste(im, (d * W, f * H), im)
    hoja = hoja.resize((hoja.width * 3, hoja.height * 3), Image.NEAREST)
    os.makedirs('tools/salida/sdf', exist_ok=True)
    hoja.save('tools/salida/sdf/escarabajo_versiones.png')
    print('ok')
