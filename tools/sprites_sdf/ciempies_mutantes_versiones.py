# ============================================================
#  ciempies_mutantes_versiones.py -- LOS MUTANTES DEL CIEMPIES CARMESI, propuestas en QUIETO (05/11/2026). Cada una con SU
#  cuerpo (silueta y postura propias). Nada en el suelo. Arbol en linea: Ciempies -> BICEFALO -> CONSTRICTOR de dos cabezas.
#    BICEFALO (una cabeza en cada punta; las cabezas de dos colores, porque cada una lleva su contador de aturdir)
#      A herradura  en U abierta, las dos cabezas delante: ya se ve de donde sale su basico en U
#      B escorpion  la mitad de atras sube y se arquea por encima del lomo: la segunda cabeza ataca desde arriba
#      C ese        tumbado en S, cada cabeza mirando a un lado: la culebra de dos puntas de la leyenda
#    CONSTRICTOR (enorme y gordo, anillos anchos de piton, sigue con dos cabezas; el Enrosque atrapa a dos)
#      A monton     enrollado sobre si mismo en una pila, una cabeza en lo alto y otra a ras de suelo
#      B piton      U enorme y baja, de anillos gordos con bandas; patas cortas
#      C aro        un anillo casi cerrado con las dos cabezas alzadas hacia dentro: el hueco es donde cabe la presa
#  Uso: python tools/sprites_sdf/ciempies_mutantes_versiones.py -> tools/salida/sdf/ciempies_mutantes_versiones.png
#  (y al escritorio, en ataques_mapa/enemigos/prueba_3d/mutantes)
# ============================================================
import sys, os, math
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import sdf_comun
import ciempies_sdf as base

V = np.array
_cono = base._cono
_elip = base._elip
_marco = base._marco

MAT = dict(base.MAT)
MAT.update({
    'cuerpo': [(0.22, 0.07, 0.17), (0.38, 0.12, 0.26), (0.56, 0.22, 0.36)],
    'placa':  [(0.13, 0.05, 0.12), (0.24, 0.08, 0.20), (0.40, 0.16, 0.32)],
    'banda':  [(0.36, 0.20, 0.10), (0.54, 0.32, 0.13), (0.72, 0.48, 0.20)],
    'pata':   [(0.62, 0.58, 0.46), (0.82, 0.78, 0.62), (0.96, 0.93, 0.78)],
    'cabA':   [(0.62, 0.20, 0.06), (0.86, 0.38, 0.10), (1.00, 0.66, 0.26)],
    'cabB':   [(0.05, 0.34, 0.36), (0.12, 0.56, 0.54), (0.40, 0.82, 0.74)],
})


def modelo():
    return Modelo(2.3, (150, 150), (75, 88), MAT, (0.07, 0.02, 0.06), suaves=('cuerpo',), brillan=('ojo',), corta_suelo=True)


def _catmull(ctrl, n=240):
    """Curva suave que pasa por los puntos de control; 'n' muestras."""
    c = [V(p, dtype=float) for p in ctrl]
    c = [c[0] * 2 - c[1]] + c + [c[-1] * 2 - c[-2]]
    tramos_ = len(c) - 3
    sal = []
    for k in range(n):
        t = k / (n - 1) * tramos_
        i = min(int(t), tramos_ - 1)
        u = t - i
        a, b, d, e = c[i], c[i + 1], c[i + 2], c[i + 3]
        sal.append(0.5 * ((2 * b) + (d - a) * u + (2 * a - 5 * b + 4 * d - e) * u * u + (3 * b - a - 3 * d + e) * u * u * u))
    return sal


def _repartir(ctrl, paso):
    """Anillos a distancia 'paso' sobre la curva: el numero sale del largo, asi no quedan separados ni pisados."""
    m = _catmull(ctrl)
    dist = [0.0]
    for i in range(1, len(m)):
        dist.append(dist[-1] + np.linalg.norm(m[i] - m[i - 1]))
    total = dist[-1]
    n = max(3, int(round(total / paso)) + 1)
    pts = []
    j = 0
    for i in range(n):
        obj = total * i / (n - 1)
        while j < len(m) - 2 and dist[j + 1] < obj:
            j += 1
        pts.append(m[j])
    return pts


def _cabeza(add, h, mat, tam, forc=1.0):
    """La cabeza: mira a la 'y' local del hueso h. Las forcipulas abiertas y grandes, antenas cortas."""
    _elip(add, (0, 0.5 * tam, 0.1 * tam), (2.2 * tam, 2.4 * tam, 1.5 * tam), mat, 0, 'cabeza', h)
    for s in (-1, 1):
        _cono(add, (0.8 * s * tam, 1.5 * tam, 0.7 * tam), (2.4 * s * tam, 4.0 * tam, 1.8 * tam), 0.5, 0.38, 'pata', 0, 'antena', h)
        _cono(add, (2.4 * s * tam, 4.0 * tam, 1.8 * tam), (3.6 * s * tam, 5.8 * tam, 1.2 * tam), 0.38, 0.28, 'pata', 0, 'antena', h)
        _cono(add, (1.3 * s * tam, 2.0 * tam, -0.3), (2.3 * s * tam * forc, 3.7 * tam, -0.3), 0.75 * tam, 0.5 * tam, 'garra', 0, 'garra', h)
        _cono(add, (2.3 * s * tam * forc, 3.7 * tam, -0.3), (0.5 * s * tam, 4.9 * tam, -0.3), 0.5 * tam, 0.18, 'garra', 0, 'garra', h)
        _elip(add, (1.1 * s * tam, 1.7 * tam, 0.95 * tam), (0.5 * tam, 0.45 * tam, 0.4 * tam), 'ojo', 0, 'ojo', h)


ESTILO_CABEZA = None   # None = la cabeza de la primera lamina; 'escudo', 'cuna', 'fauces' = las de la lamina de cabezas


def _ojos_cab(add, h, y, x, z, r):
    for s in (-1, 1):
        _elip(add, (x * s, y, z), (r, r * 0.9, r * 0.8), 'ojo', 0, 'ojo', h)


def _antenas(add, h, y, t):
    for s in (-1, 1):
        _cono(add, (0.8 * s * t, y, 0.8 * t), (2.6 * s * t, y + 2.4 * t, 2.0 * t), 0.5, 0.36, 'pata', 0, 'antena', h)
        _cono(add, (2.6 * s * t, y + 2.4 * t, 2.0 * t), (3.8 * s * t, y + 4.4 * t, 1.4 * t), 0.36, 0.26, 'pata', 0, 'antena', h)


def _hoz(add, h, s, base, codo, punta, r0):
    """Una forcipula: hueso claro con la punta oscura, curvada hacia dentro."""
    _cono(add, (base[0] * s, base[1], base[2]), (codo[0] * s, codo[1], codo[2]), r0, r0 * 0.72, 'pata', 0, 'forc', h)
    _cono(add, (codo[0] * s, codo[1], codo[2]), (punta[0] * s, punta[1], punta[2]), r0 * 0.72, 0.2, 'garra', 0, 'forc', h)


def _cabeza_estilo(add, h, mat, t, estilo):
    if estilo == 'escudo':
        # ANCHA Y PLANA, como la de una escolopendra de verdad, con su placa encima y hoces cortas.
        _elip(add, (0, 1.5 * t, 0.0), (2.5 * t, 2.8 * t, 1.25 * t), mat, 0, 'cabeza', h)
        _elip(add, (0, 1.0 * t, 0.75 * t), (1.5 * t, 1.7 * t, 0.65 * t), 'placa', 0, 'cabplaca', h)
        _ojos_cab(add, h, 3.1 * t, 1.25 * t, 0.65 * t, 0.46 * t)
        _antenas(add, h, 3.4 * t, t)
        for s in (-1, 1):
            _hoz(add, h, s, (1.6 * t, 3.4 * t, -0.2), (2.6 * t, 5.0 * t, -0.2), (0.7 * t, 6.2 * t, -0.2), 0.8 * t)
    elif estilo == 'cuna':
        # EN PUNTA: se estrecha hacia delante, mas de serpiente; hoces largas y finas pegadas al morro.
        _cono(add, (0, 0.4 * t, 0.2), (0, 4.4 * t, 0.0), 2.3 * t, 0.85 * t, mat, 0, 'cabeza', h)
        _cono(add, (0, 0.4 * t, 1.25 * t), (0, 3.2 * t, 0.55 * t), 1.0 * t, 0.35 * t, 'placa', 0, 'cabplaca', h)
        _ojos_cab(add, h, 2.3 * t, 1.25 * t, 0.75 * t, 0.42 * t)
        _antenas(add, h, 2.8 * t, t)
        for s in (-1, 1):
            _hoz(add, h, s, (1.2 * t, 2.8 * t, -0.3), (2.5 * t, 5.0 * t, -0.3), (0.5 * t, 7.0 * t, -0.3), 0.6 * t)
    else:
        # FAUCES: cabeza corta y unas hoces ENORMES abiertas en arco: lo que se ve primero es la tenaza.
        _elip(add, (0, 1.0 * t, 0.1), (2.2 * t, 2.1 * t, 1.35 * t), mat, 0, 'cabeza', h)
        _elip(add, (0, 0.8 * t, 0.85 * t), (1.2 * t, 1.2 * t, 0.55 * t), 'placa', 0, 'cabplaca', h)
        _ojos_cab(add, h, 2.3 * t, 0.95 * t, 0.8 * t, 0.42 * t)
        _antenas(add, h, 2.2 * t, t * 0.8)
        for s in (-1, 1):
            _hoz(add, h, s, (1.5 * t, 2.0 * t, -0.2), (4.4 * t, 4.4 * t, -0.2), (1.0 * t, 7.6 * t, -0.2), 1.0 * t)


def cadena(ctrl, radio, paso, tam_cab=1.35, bandas=0, largo_pata=2.7, grosor_pata=1.0, fino=None):
    """Toda la cadena: 'ctrl' = puntos (x, y, z), de la cabeza A a la cabeza B. 'fino': radio en las puntas (cuello)."""
    pts = _repartir(ctrl, paso)
    n = len(pts)
    X = {}
    for i in range(n):
        d = pts[max(i - 1, 0)] - pts[min(i + 1, n - 1)]
        X['a%d' % i] = (_marco(d), pts[i])
    X['cabA'] = (_marco(pts[0] - pts[1]), pts[0])
    X['cabB'] = (_marco(pts[-1] - pts[-2]), pts[-1])
    e = Escena(X)
    add = e.add
    for i in range(n):
        h = 'a%d' % i
        punta = min(i, n - 1 - i)
        r = radio
        if fino is not None and punta < 4:
            r = fino + (radio - fino) * punta / 4.0
        _elip(add, (0, 0, 0), (r * 1.15, paso * 0.66, r * 0.85), 'cuerpo', 0.6, hueso=h)
        mat = 'banda' if bandas and i % bandas == 0 else 'placa'
        # (Con las cabezas nuevas el color se queda en el anillo pegado a la cabeza: dos anillos hacian un bloque.)
        cuello = 1 if ESTILO_CABEZA is None else 0
        if i <= cuello:
            mat = 'cabA'
        elif i >= n - 1 - cuello:
            mat = 'cabB'
        ancho_placa = 0.3 if mat == 'banda' else 0.5
        _elip(add, (0, 0, r * 0.45), (r * 1.2, paso * ancho_placa, r * 0.45), mat, 0, 'placa%d' % (i % 2), h)
        if 1 < i < n - 2 and i % 2 == 1:
            # Las patas van al suelo aunque el anillo gire: solo en los anillos que tocan abajo; los de arriba, recogidas.
            en_suelo = pts[i][2] < radio + 1.5
            lp = largo_pata if en_suelo else largo_pata * 0.55
            for s in (-1, 1):
                rod = V((s * (r + lp * 0.48), 0, 0.6))
                pie = V((s * (r + lp), 0, -1.5 if en_suelo else -0.5))
                _cono(add, V((s * r * 0.8, 0, 0)), rod, 0.78 * grosor_pata, 0.66 * grosor_pata, 'pata', 0, 'pata', h)
                _cono(add, rod, pie, 0.66 * grosor_pata, 0.35, 'pata', 0, 'pata', h)
    if ESTILO_CABEZA is None:
        _cabeza(add, 'cabA', 'cabA', tam_cab)
        _cabeza(add, 'cabB', 'cabB', tam_cab)
    else:
        _cabeza_estilo(add, 'cabA', 'cabA', tam_cab * 0.85, ESTILO_CABEZA)
        _cabeza_estilo(add, 'cabB', 'cabB', tam_cab * 0.85, ESTILO_CABEZA)
    return e.L


# ---------- BICEFALO ----------
def bicefalo_a():
    z = 1.5
    return cadena([(-6.2, 7.0, z), (-6.2, 2.0, z), (-5.2, -3.0, z), (-2.4, -6.0, z), (2.4, -6.0, z), (5.2, -3.0, z),
                   (6.2, 2.0, z), (6.2, 7.0, z)], 2.15, 1.75)


def bicefalo_b():
    z = 1.5
    return cadena([(0.0, 9.5, z), (0.8, 5.0, z), (-0.8, 0.5, z), (0.4, -4.0, z), (0.0, -7.6, 3.6), (0.0, -7.8, 8.0),
                   (0.0, -4.0, 11.2), (0.0, 0.8, 11.6)], 2.15, 1.75)


def bicefalo_c():
    z = 1.5
    return cadena([(-3.0, 11.0, z), (2.6, 7.0, z), (2.6, 2.4, z), (-1.6, -0.6, z), (-2.8, -4.6, z), (1.2, -8.0, z),
                   (3.4, -12.0, z)], 2.15, 1.75)


# ---------- CONSTRICTOR ----------
R_GORDO = 3.7
PASO_GORDO = 2.5


def constrictor_a():
    # La pila: dos vueltas que suben, y las dos puntas salen de ella.
    ctrl = [(1.5, 15.0, 3.0), (5.5, 9.0, 3.0)]
    for k in range(10):
        a = math.radians(70) - k * math.radians(68)
        ctrl.append((8.0 * math.cos(a), 8.0 * math.sin(a), 3.0 + k * 0.62))
    ctrl += [(1.0, -5.0, 9.8), (-0.5, 0.5, 13.0), (0.0, 5.5, 15.5)]
    return cadena(ctrl, R_GORDO, PASO_GORDO, 1.9, bandas=3, largo_pata=3.0, grosor_pata=1.2, fino=2.6)


def constrictor_b():
    z = 3.0
    return cadena([(-6.0, 13.0, z), (-9.5, 5.0, z), (-9.5, -4.5, z), (-5.0, -10.5, z), (5.0, -10.5, z), (9.5, -4.5, z),
                   (9.5, 5.0, z), (6.0, 13.0, z)], R_GORDO, PASO_GORDO, 1.9, bandas=3, largo_pata=3.0, grosor_pata=1.2, fino=2.8)


def constrictor_c():
    ctrl = [(-7.5, 3.0, 9.0), (-6.5, 11.0, 6.0)]
    for k in range(1, 11):
        a = math.radians(115) + k * math.radians(31)
        ctrl.append((12.5 * math.cos(a), 12.5 * math.sin(a), 3.0))
    ctrl += [(6.5, 11.0, 6.0), (7.5, 3.0, 9.0)]
    return cadena(ctrl, R_GORDO, PASO_GORDO, 1.9, bandas=3, largo_pata=3.0, grosor_pata=1.2, fino=2.6)


if __name__ == '__main__':
    getattr(sdf_comun, '_prioridad_baja', lambda: None)()   # (si esta: lo que use el jefe pasa por delante)
    mo = modelo()
    cabezas = sys.argv[1:] == ['cabezas']
    filas = [
        ('NORMAL (hoy)', None),
        ('BICEFALO A herradura', bicefalo_a()),
        ('BICEFALO B escorpion', bicefalo_b()),
        ('BICEFALO C ese', bicefalo_c()),
        ('CONSTRICTOR A monton', constrictor_a()),
        ('CONSTRICTOR B piton', constrictor_b()),
        ('CONSTRICTOR C aro', constrictor_c()),
    ]
    salida_nombre = 'ciempies_mutantes_versiones.png'
    if cabezas:
        # python ... cabezas -> ciempies_mutantes_cabezas.png: las tres formas de cabeza sobre los cuerpos ELEGIDOS.
        salida_nombre = 'ciempies_mutantes_cabezas.png'
        filas = []
        for est in ('escudo', 'cuna', 'fauces'):
            ESTILO_CABEZA = est
            filas.append(('BICEFALO cabeza ' + est, bicefalo_a()))
            filas.append(('CONSTRICTOR cabeza ' + est, constrictor_a()))
    W = H = 150
    ESC = 4
    MARGEN = 190
    tiras = []
    for nombre, L in filas:
        fotos = []
        for d in range(5):
            if L is None:
                im0 = render(base.MODELO, base.escena(base.POSE()), d)
                im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
                im.paste(im0, (75 - base.MODELO.OX, 88 - base.MODELO.OY), im0)
            else:
                im = render(mo, L, d)
            fotos.append(im)
        cajas = [f.getbbox() for f in fotos]
        y0 = max(0, min(c[1] for c in cajas) - 3)
        y1 = min(H, max(c[3] for c in cajas) + 3)
        tiras.append((nombre, fotos, y0, y1))
        print(nombre, flush=True)
    x0 = min(f.getbbox()[0] for t in tiras for f in t[1]) - 3
    x1 = max(f.getbbox()[2] for t in tiras for f in t[1]) + 3
    ancho = x1 - x0
    alto_total = sum((t[3] - t[2]) * ESC for t in tiras)
    hoja = Image.new('RGB', (MARGEN + ancho * 5 * ESC, alto_total), (40, 42, 50))
    dib = ImageDraw.Draw(hoja)
    y = 0
    for nombre, fotos, y0, y1 in tiras:
        dib.text((10, y + (y1 - y0) * ESC // 2), nombre, fill=(235, 235, 235))
        for d, im in enumerate(fotos):
            c = im.crop((x0, y0, x1, y1)).resize((ancho * ESC, (y1 - y0) * ESC), Image.NEAREST)
            hoja.paste(c, (MARGEN + d * ancho * ESC, y), c)
        y += (y1 - y0) * ESC
    os.makedirs('tools/salida/sdf', exist_ok=True)
    hoja.save('tools/salida/sdf/' + salida_nombre)
    esc = os.path.join(os.path.expanduser('~'), 'Desktop', 'ataques_mapa', 'enemigos', 'prueba_3d', 'mutantes')
    os.makedirs(esc, exist_ok=True)
    hoja.save(os.path.join(esc, salida_nombre))
    print('ok', hoja.size)
