# ============================================================
#  jabali_versiones.py -- LOS MUTANTES DEL JABALI, propuestas en QUIETO (31/10/2026). El jefe eligio UNA LINEA en la que
#  los dos llevan COLMILLOS DE CRISTAL y MUSGO, a distinta escala: la 1a con los colmillos pequeños, algo de musgo y poca
#  chepa; la 2a con los colmillos grandes, mucho musgo y una CHEPA muy pronunciada (muy grande). Dos versiones de cada,
#  sobre el jabali de siempre (jabali_sdf.py), a su tamaño de mutante (x1,2 la 1a, x1,32 la 2a) y al MISMO zoom:
#    1a A  lanzas     colmillos de cristal RECTOS (una lanza y dos esquirlas al pie), parches de musgo por el lomo y
#                     una chepa leve.
#    1a B  curvos     los colmillos de marfil hechos CRISTAL (curvos, algo mas largos), la crin cambiada por MUSGO y una
#                     chepa leve.
#    2a A  (sobre A)  lanzas grandes con mas esquirlas, un manto de musgo con SETAS y raices colgando, chepa enorme.
#    2a B  (sobre B)  colmillos curvos enormes con drusas en el morro, musgo hasta los flancos con helechos y setas,
#                     chepa enorme.
#  Uso: python tools/sprites_sdf/jabali_versiones.py -> tools/salida/sdf/jabali_versiones.png (y al escritorio)
# ============================================================
import sys, os, math, random
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import jabali_sdf as js

Z = js.Z
E = js.ESTIRA
ESC = 1.7
ESC_1 = 1.7 * 1.2
ESC_2 = 1.7 * 1.32

CRISTAL = [(0.30, 0.72, 0.85), (0.55, 0.95, 1.0), (0.85, 1.0, 1.0), (1.0, 1.0, 1.0)]
MUSGO = [(0.14, 0.24, 0.09), (0.24, 0.40, 0.15), (0.38, 0.55, 0.22)]
MUSGO_CLARO = [(0.30, 0.44, 0.16), (0.45, 0.60, 0.24), (0.60, 0.74, 0.34)]
SETA = [(0.42, 0.16, 0.10), (0.62, 0.26, 0.16), (0.78, 0.40, 0.26)]
PIE_SETA = [(0.70, 0.66, 0.56), (0.86, 0.82, 0.70), (0.95, 0.92, 0.82)]
RAIZ = [(0.18, 0.12, 0.08), (0.28, 0.19, 0.12), (0.38, 0.27, 0.18)]
QUEMADO = [(0.10, 0.08, 0.07), (0.18, 0.14, 0.11), (0.28, 0.22, 0.17)]   # el musgo quemado de la chepa pelada
BRASA = [(0.70, 0.22, 0.06), (0.95, 0.45, 0.12), (1.0, 0.75, 0.30)]        # el musgo ardiendo, en el frente del fuego


def _mat():
    m = dict(js.MAT)
    m.update(cristal=CRISTAL, musgo=MUSGO, musgo_claro=MUSGO_CLARO, seta=SETA, pie_seta=PIE_SETA, raiz=RAIZ,
             quemado=QUEMADO, brasa=BRASA)
    return m


class _Piezas:
    """El jabali de siempre, sin sus colmillos de marfil (y sin la crin si se la cambiamos por musgo)."""
    def __init__(self, pose, sin=()):
        self.X = js.huesos(pose)
        self.L = [t for t in js._escena_base(pose) if t[2] not in sin]   # (con JABALI_VAR, js.escena es la del mutante)

    def add(self, fn, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
        self.L.append((fn, mat, grupo, k, self.X.get(hueso, IDENT), hueso))


# EL LOMO de verdad: el punto de la PIEL (el barril, la cruz y la chepa de r_chepa) en el corte 'y', a 'ang' grados
# desde arriba (+-90 = los flancos), y 'fuera' mas alla. Se busca la superficie lanzando un rayo desde el espinazo contra
# los elipsoides del cuerpo (el mas lejano): asi el musgo y las setas quedan ENCIMA de la chepa, no enterrados en ella.
def _cuerpo_elipses(chepa):
    L = [(Z(0, -1.0, 7.8), np.array([6.4, 9.6, 5.2 * E])), (Z(0, 4.4, 9.4), np.array([6.8, 5.8, 6.0 * E])),
         (Z(0, -7.6, 7.4), np.array([5.8, 4.8, 4.8 * E]))]
    if chepa > 0.0:
        L.append(_chepa_elipse(chepa))
    return L


def _chepa_elipse(alto):
    return (Z(0, 3.0, 9.4 + alto * 0.55), np.array([6.0 + alto * 0.25, 6.5 + alto * 0.3, (4.8 + alto * 0.6) * E]))


def _lomo(y, ang, fuera=0.0, chepa=0.0):
    a = math.radians(ang)
    o = Z(0, y, 8.0)
    d = np.array([math.sin(a), 0.0, math.cos(a)])
    t_max = 0.0
    for c, r in _cuerpo_elipses(chepa):
        oc = (o - c) / r
        dd = d / r
        A = dd @ dd; B = 2 * (oc @ dd); C = oc @ oc - 1.0
        disc = B * B - 4 * A * C
        if disc >= 0.0:
            t = (-B + math.sqrt(disc)) / (2 * A)
            t_max = max(t_max, t)
    return o + d * (t_max + fuera)


# ------------------------------------------------------------
#  LOS RASGOS
# ------------------------------------------------------------
def r_chepa(e, alto):
    # LA CHEPA: una joroba sobre la cruz, fundida con el cuerpo (la del musgoso; alto = cuanto sube).
    c, r = _chepa_elipse(alto)
    e.add(lambda P: sd_elipsoide(P, c, r), 'piel', 2.8)


def _esquirla(e, base, d, largo, r, hueso='cabeza'):
    d = np.array(d, dtype=float)
    d = d / np.linalg.norm(d)
    e.add(lambda P, a=base - d * 0.4, b=base + d * largo, ra=r: sd_cono(P, a, b, ra, ra * 0.1), 'cristal', 0, 'colmillo',
          hueso)


def r_lanzas(e, escala=1.0, esquirlas=2):
    # COLMILLOS RECTOS DE CRISTAL: una lanza de cada lado del morro, hacia delante y arriba, con esquirlas al pie.
    for s in (-1, 1):
        base = Z(2.4 * s, 15.0, 4.0)
        _esquirla(e, base, [0.45 * s, 0.55, 0.7], 5.0 * escala, 1.1 * escala ** 0.5)
        for j in range(esquirlas):
            ang = 0.6 + 0.5 * j
            _esquirla(e, base + np.array([0.3 * s, -0.4 * j, -0.2]), [math.cos(ang) * s, 0.25, math.sin(ang)],
                      (1.8 + 0.6 * (j % 2)) * escala, 0.55 * escala ** 0.5)


def r_curvos(e, escala=1.0, rotos=False, mat='cristal'):
    # LOS COLMILLOS DE SIEMPRE HECHOS CRISTAL: gordos, salen del morro y se curvan arriba y atras (mas largos cuanto mas).
    # ROTOS (tras la Cornada de cristal): solo los dos primeros tramos, acabados en un MUÑON astillado (tres esquirlas
    # cortas). 'mat': 'marfil' mientras aun son los de siempre (la evolucion).
    for s in (-1, 1):
        p = Z(2.4 * s, 15.0, 4.0); d = np.array([0.55 * s, 0.4, 0.75]); r = 1.25 * escala ** 0.6
        tramos_ = int(5 + 2 * (escala - 1.0) * 2)
        for k in range(2 if rotos else tramos_):
            dd = d / np.linalg.norm(d); q = p + dd * 1.35 * escala ** 0.5
            e.add(lambda P, a=p, b=q, ra=r, rb=max(0.2, r - 0.16): sd_cono(P, a, b, ra, rb), mat, 0, 'colmillo',
                  'cabeza')
            p = q; r = max(0.22, r - 0.21 / escala ** 0.5); d = d + np.array([0.05 * s, -0.28 / escala ** 0.4, 0.0])
        if rotos:
            dd = d / np.linalg.norm(d)
            for k, giro in enumerate((-0.5, 0.1, 0.6)):
                dk = dd + np.array([giro * 0.6, 0.0, 0.25 * k - 0.2])
                _esquirla(e, p - dd * 0.2, dk, (0.6 + 0.25 * k) * escala ** 0.5, r * 0.9)


def r_drusas_morro(e, crece=1.0):
    # DRUSAS en el morro y la frente (la 2a B): racimos de cristal pequeños. 'crece' (la evolucion): de 0 a 1.
    if crece <= 0.0:
        return
    rnd = random.Random(3)
    for (x, y, z) in ((0.0, 13.6, 8.8), (1.4, 12.6, 9.8), (-1.5, 12.8, 9.6), (0.6, 14.8, 7.4)):
        for _ in range(3):
            d = [rnd.uniform(-0.5, 0.5), rnd.uniform(-0.2, 0.5), 1.0]
            _esquirla(e, Z(x, y, z), d, rnd.uniform(1.2, 2.2) * crece, 0.45 * max(crece, 0.3))


def r_musgo_parches(e, n=7, chepa=0.0):
    # PARCHES DE MUSGO por el lomo: bultos blandos sueltos.
    rnd = random.Random(7)
    for i in range(n):
        y = 6.0 - i * 2.2 + rnd.uniform(-0.6, 0.6)
        ang = rnd.uniform(-45, 45)
        c = _lomo(y, ang, -0.4, chepa)
        for j in range(3):
            off = np.array([rnd.uniform(-1.2, 1.2), rnd.uniform(-1.2, 1.2), rnd.uniform(0.0, 0.6)])
            e.add(lambda P, cc=c + off, r=rnd.uniform(1.0, 1.6): sd_esfera(P, cc, r),
                  'musgo' if (i + j) % 3 else 'musgo_claro', 0, 'musgo')


def r_musgo_crin(e, chepa=0.0, crece=1.0):
    # LA CRIN HECHA MUSGO: una cresta de musgo por el espinazo, de la nuca a media espalda. 'crece' (la evolucion): le
    # brota de la nuca hacia atras, mata a mata.
    rnd = random.Random(11)
    for i in range(16):
        y = 10.0 - i * 1.2
        c = _lomo(y, rnd.uniform(-12, 12), -0.2, chepa)
        r = rnd.uniform(1.3, 1.9)
        g = min(1.0, max(0.0, crece * 16.0 - i))
        if g > 0.0:
            e.add(lambda P, cc=c, r=r * (0.4 + 0.6 * g): sd_esfera(P, cc, r), 'musgo' if i % 3 else 'musgo_claro', 0, 'musgo')


# EL FRENTE DEL FUEGO cuando le queman el musgo (la animacion 'quemandose'): de la cabeza (y alta) a la grupa. Lo que
# queda por delante del frente (y mayor) ya ha ardido; en el frente, BRASA; detras, musgo aun.
FRENTE_DESDE, FRENTE_HASTA, FRENTE_ANCHO = 11.0, -12.0, 1.6


def frente_quema(q):
    return FRENTE_DESDE + (FRENTE_HASTA - FRENTE_DESDE) * q


def r_manto_musgo(e, chepa, flancos=60, crece=1.0, quema_y=None):
    # EL MANTO DE MUSGO de la 2a: todo el lomo y la chepa cubiertos, bajando por los flancos hasta 'flancos' grados.
    # 'crece' (la evolucion): se extiende del espinazo hacia los flancos. 'quema_y' (quemandose): el frente del fuego.
    rnd = random.Random(5)
    for i in range(14):
        y = 9.0 - i * 1.45
        for ang in range(-flancos, flancos + 1, 20):
            c = _lomo(y, ang + rnd.uniform(-6, 6), -0.5, chepa)
            r = rnd.uniform(1.4, 2.0)
            mat = 'musgo' if rnd.random() < 0.7 else 'musgo_claro'
            if quema_y is not None:
                if y > quema_y + FRENTE_ANCHO:
                    continue                      # ya ha ardido
                if y > quema_y - FRENTE_ANCHO:
                    mat = 'brasa'
                    r *= 0.8
            if abs(ang) <= flancos * crece + 0.01:
                e.add(lambda P, cc=c, r=r: sd_esfera(P, cc, r), mat, 0, 'musgo')


def r_quemado(e, chepa, quema_y=None):
    # LA CHEPA PELADA (le han quemado el musgo con fuego): costras negras de musgo quemado por el lomo, la piel a la vista.
    # 'quema_y' (quemandose): solo por donde ya ha pasado el fuego.
    rnd = random.Random(17)
    for i in range(10):
        y = 8.0 - i * 1.9 + rnd.uniform(-0.5, 0.5)
        c = _lomo(y, rnd.uniform(-55, 55), -0.9, chepa)
        r = rnd.uniform(0.9, 1.4)
        if quema_y is not None and y <= quema_y + FRENTE_ANCHO:
            continue
        e.add(lambda P, cc=c, r=r: sd_esfera(P, cc, r), 'quemado', 0, 'musgo')


def r_setas(e, chepa, n=4, crece=1.0, quema_y=None):
    # SETAS en la chepa: pie claro y sombrero rojizo. 'crece' (la evolucion): de 0 a 1. 'quema_y': arden al pasar el fuego.
    if crece <= 0.0:
        return
    rnd = random.Random(9)
    for i in range(n):
        ys = 4.5 - i * 2.4 + rnd.uniform(-0.5, 0.5)
        c = _lomo(ys, rnd.uniform(-35, 35), 0.8, chepa)
        alto = rnd.uniform(1.4, 2.4) * crece
        if quema_y is not None and ys > quema_y - FRENTE_ANCHO:
            rnd.uniform(1.1, 1.6)   # (la misma tirada que si se pintara: las demas no cambian de sitio)
            continue
        e.add(lambda P, a=c, b=c + np.array([0, 0, alto]): sd_cono(P, a, b, 0.45, 0.35), 'pie_seta', 0, 'seta')
        e.add(lambda P, cc=c + np.array([0, 0, alto + 0.3]), r=rnd.uniform(1.1, 1.6) * max(crece, 0.3):
              np.maximum(sd_elipsoide(P, cc, np.array([r, r, r * 0.55])), cc[2] - 0.15 - P[:, 2]), 'seta', 0, 'seta')


def r_raices(e, n=8):
    # RAICES que le cuelgan de la tripa y los flancos.
    rnd = random.Random(13)
    for i in range(n):
        s = -1 if i % 2 else 1
        y = 6.0 - i * 1.8
        a = Z(5.4 * s, y, 5.6)
        b = a + np.array([0.6 * s, rnd.uniform(-0.8, 0.8), -rnd.uniform(2.2, 3.6)])
        e.add(lambda P, aa=a, bb=b: sd_cono(P, aa, bb, 0.55, 0.15), 'raiz', 0, 'raiz')


def r_helechos(e, chepa, crece=1.0, quema_y=None):
    # HELECHOS: hojas finas que salen del musgo de la chepa, abiertas. 'crece' (la evolucion): de 0 a 1. 'quema_y': arden.
    if crece <= 0.0:
        return
    for (y, ang, s) in ((5.0, 30, 1), (2.0, -30, -1), (-1.5, 25, 1)):
        if quema_y is not None and y > quema_y - FRENTE_ANCHO:
            continue
        base = _lomo(y, ang, 0.6, chepa)
        for k in range(3):
            d = np.array([s * (0.4 + 0.25 * k), -0.5 + 0.4 * k, 1.0])
            d = d / np.linalg.norm(d)
            e.add(lambda P, a=base, b=base + d * 3.0 * crece: sd_cono(P, a, b, 0.5, 0.05), 'musgo_claro', 0, 'musgo')


def _con(sin, *rasgos):
    e = _Piezas(js.POSE(), sin)
    for r in rasgos:
        r(e)
    return e.L


CH1 = 1.2    # la chepa leve de la 1a
CH2 = 4.2    # la enorme de la 2a

VERSIONES = [
    ('jabali hoy', lambda: _con(()), ESC),
    ('1a A lanzas', lambda: _con(('colmillo',), lambda e: r_chepa(e, CH1), r_lanzas, lambda e: r_musgo_parches(e, 6, CH1)), ESC_1),
    ('1a B curvos', lambda: _con(('colmillo', 'crin'), lambda e: r_chepa(e, CH1), r_curvos, lambda e: r_musgo_crin(e, CH1)), ESC_1),
    ('2a A (sobre A)', lambda: _con(('colmillo', 'crin'), lambda e: r_chepa(e, CH2), lambda e: r_lanzas(e, 1.5, 4),
                                    lambda e: r_manto_musgo(e, CH2, 60), lambda e: r_setas(e, CH2), r_raices), ESC_2),
    ('2a B (sobre B)', lambda: _con(('colmillo', 'crin'), lambda e: r_chepa(e, CH2), lambda e: r_curvos(e, 1.6),
                                    r_drusas_morro, lambda e: r_manto_musgo(e, CH2, 80), lambda e: r_helechos(e, CH2),
                                    lambda e: r_setas(e, CH2, 3)), ESC_2),
]


def modelo(escala):
    lado = int(round(88 * escala / ESC / 2)) * 2 + 16
    return Modelo(escala, (lado, lado), (lado // 2, int(lado * 0.56)), _mat(), (0.11, 0.07, 0.05), suaves=('cuerpo',),
                  brillan=('ojo', 'pupila'), estira=E, corta_suelo=True, especular=('cristal',), umbral_especular=0.955)


if __name__ == '__main__':
    os.makedirs('tools/salida/sdf', exist_ok=True)
    filas = []
    for nombre, fn, esc in VERSIONES:
        L = fn()
        mo = modelo(esc)
        fotos = [render(mo, L, dd) for dd in range(5)]
        caja = None
        for f in fotos:
            b = f.getbbox()
            caja = b if caja is None else (min(caja[0], b[0]), min(caja[1], b[1]), max(caja[2], b[2]), max(caja[3], b[3]))
        filas.append((nombre, [f.crop((0, caja[1] - 3, f.size[0], caja[3] + 3)) for f in fotos]))
        print(nombre, 'ok')
    W = max(f[1][0].size[0] for f in filas)
    alturas = [f[1][0].size[1] for f in filas]
    ETQ = 110
    lam = Image.new('RGB', (W * 5 + ETQ, sum(alturas)), (40, 42, 50))
    dr = ImageDraw.Draw(lam)
    y0 = 0
    for j, (nombre, fotos) in enumerate(filas):
        h = alturas[j]
        dr.text((4, y0 + h // 2 - 5), nombre, fill=(220, 220, 220))
        for i, f in enumerate(fotos):
            lam.paste(f, (ETQ + i * W + (W - f.size[0]) // 2, y0), f)
        y0 += h
    lam = lam.resize((lam.width * 3, lam.height * 3), Image.NEAREST)
    lam.save('tools/salida/sdf/jabali_versiones.png')
    esc = os.path.join(os.path.expanduser('~'), 'Desktop', 'ataques_mapa', 'enemigos', 'prueba_3d', 'mutantes')
    os.makedirs(esc, exist_ok=True)
    lam.save(os.path.join(esc, 'jabali_versiones.png'))
    print(os.path.join(esc, 'jabali_versiones.png'))
