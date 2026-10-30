# ============================================================
#  rey_rata_versiones.py -- LOS MUTANTES DEL REY RATA, propuestas en QUIETO (30/10/2026). El jefe eligio una LINEA:
#  REY DE LA CAMADA (1a: el rey que manda, llama a su camada) -> REY DE CHATARRA (2a, la version fuerte: sigue llamando
#  a la camada y ademas se arma con lo que dejan los aventureros). Dos versiones de cada uno, sobre el rey de siempre
#  (rata_sdf.py, RATA_VAR=rey) y a su tamaño de mutante (x1,2 la 1a, x1,32 la 2a), al MISMO zoom que el de hoy.
#    CAMADA A  manto     mas gordo, un MANTO de pieles sucias por el lomo con el borde deshilachado y cuello de piel;
#                        la corona MAS ALTA (siete puntas).
#    CAMADA B  collar    mas gordo, un COLLAR de huesecillos y dientes al cuello y una capa corta raida; la corona
#                        grande, abollada y torcida (una punta doblada).
#    CHATARRA A  yelmo   la A con un YELMO abollado bajo la corona, la TAPA DE OLLA de escudo en el costado y clavos por
#                        el lomo.
#    CHATARRA B  placas  la B con un PETO de placas remachadas y hebillas por el lomo, hombrera, el escudo de tapa por
#                        delante del hombro y la corona clavada al yelmo.
#  Solo QUIETAS: la(s) elegida(s) pasan a rata_sdf.py para animarlas con las claves de la rata.
#  Uso: python tools/sprites_sdf/rey_rata_versiones.py  -> tools/salida/sdf/rey_rata_versiones.png (y al escritorio)
# ============================================================
import sys, os, math, random
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import rata_sdf as rs

Z = rs.Z
ESC_REY = 1.7
ESC_MUT = 1.7 * 1.2     # la tabla de los mutantes: x1,2
ESC_MUT2 = 1.7 * 1.32   # la 2a: x1,32

PIEL = [(0.17, 0.14, 0.12), (0.28, 0.24, 0.20), (0.46, 0.41, 0.35)]       # el manto de pieles sucias
PIEL_CLARA = [(0.62, 0.58, 0.50), (0.80, 0.76, 0.66), (0.93, 0.90, 0.82)]  # su cuello de piel
HUESO = [(0.66, 0.62, 0.52), (0.84, 0.80, 0.68), (0.96, 0.93, 0.84)]
TELA = [(0.30, 0.10, 0.10), (0.44, 0.16, 0.14), (0.56, 0.24, 0.20)]      # la capa raida (un rojo real, gastado)
HIERRO = [(0.28, 0.29, 0.31), (0.46, 0.47, 0.50), (0.68, 0.69, 0.72)]
OXIDO = [(0.34, 0.18, 0.08), (0.50, 0.28, 0.12), (0.64, 0.40, 0.20)]
CUERO = [(0.26, 0.16, 0.09), (0.38, 0.25, 0.14), (0.50, 0.35, 0.21)]


def _mat(**cambios):
    m = dict(rs.MAT)
    m.update(piel=PIEL, piel_clara=PIEL_CLARA, hueso=HUESO, tela=TELA, hierro=HIERRO, oxido=OXIDO, cuero=CUERO)
    m.update(cambios)
    return m


class _Piezas:
    """El rey de siempre (rata_sdf.escena con rey=True), sin su corona si se la cambiamos."""
    def __init__(self, pose, sin_corona=False):
        self.X = rs.huesos(pose)
        self.L = rs.escena(pose, True)
        if sin_corona:
            keep = [t for t in self.L if t[2] != 'corona']
            del self.L[:]
            self.L.extend(keep)

    def add(self, fn, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
        self.L.append((fn, mat, grupo, k, self.X.get(hueso, IDENT), hueso))


def _sobre_cuerpo(y, ang, fuera=0.0):
    """Un punto de la piel del cuerpo (la elipse trasera de rata_sdf): 'ang' 0 = arriba, +-90 = los flancos."""
    a = math.radians(ang)
    u = max(-0.95, min(0.95, (y + 1.2) / 5.0))
    k = math.sqrt(1.0 - u * u)
    return Z((4.0 + fuera) * k * math.sin(a), y, 2.7 + (2.8 + fuera) * k * math.cos(a))


# ------------------------------------------------------------
#  LOS RASGOS
# ------------------------------------------------------------
def r_gordo(e):
    # MAS GORDO: una panza y unas ancas de mas, fundidas con el cuerpo.
    e.add(lambda P: sd_elipsoide(P, Z(0, -0.6, 2.6), np.array([4.7, 5.2, 3.0])), 'pelo', 1.4)
    e.add(lambda P: sd_elipsoide(P, Z(0, 0.0, 1.5), np.array([3.7, 4.8, 1.5])), 'vientre', 1.0)


def r_corona(e, puntas=5, alto=2.0, z=5.9, ladeo=0.0, abollada=False, mat='oro'):
    # LA CORONA (la de rata_sdf, con lo que se le cambie): aro y puntas con bola; el rubi delante.
    cc = Z(0.3, 5.0, z)
    def aro(P, c=cc):
        q = P - c
        q = np.stack([q[:, 0], q[:, 1], q[:, 2] - q[:, 0] * ladeo], axis=1)
        return np.maximum(np.abs(sd_elipsoide(q, np.zeros(3), np.array([2.4, 2.4, 1.0]))) - 0.45, np.abs(q[:, 2]) - 0.8)
    e.add(aro, mat, 0, 'corona', 'cabeza')
    rnd = random.Random(5)
    for k in range(puntas):
        a = k / puntas * 2 * math.pi + math.pi / 2
        h = alto * (rnd.uniform(0.6, 1.15) if abollada else 1.0)
        b = cc + np.array([math.cos(a) * 2.2, math.sin(a) * 2.2, 0.5 + math.cos(a) * 2.2 * ladeo])
        punta = b + np.array([math.cos(a) * 0.3, math.sin(a) * 0.3, h])
        if abollada and k == 2:   # una punta doblada hacia fuera
            punta = b + np.array([math.cos(a) * 1.4, math.sin(a) * 1.4, h * 0.45])
        e.add(lambda P, a_=b, b_=punta: sd_cono(P, a_, b_, 0.6, 0.22), mat, 0, 'corona', 'cabeza')
        e.add(lambda P, c=punta + (punta - b) * 0.1: sd_esfera(P, c, 0.34), mat, 0, 'corona', 'cabeza')
    e.add(lambda P: sd_esfera(P, cc + np.array([0.0, 2.5, 0.0]), 0.55), 'rubi', 0, 'corona', 'cabeza')


def r_manto(e):
    # EL MANTO DE PIELES: una capa por el lomo, de los hombros a la grupa, que cae por los flancos con el borde
    # deshilachado (mechones colgando).
    c = Z(0, -0.4, 2.8)
    rad = np.array([5.3, 6.0, 3.7])
    def manto(P):
        d = np.abs(sd_elipsoide(P, c, rad)) - 0.55
        ang = np.arctan2(P[:, 1] - c[1], P[:, 0] - c[0])
        borde = 2.3 + 0.45 * np.sin(ang * 9.0)
        return np.maximum(d, borde - P[:, 2])
    e.add(manto, 'piel', 0, 'manto')
    for k in range(10):
        ang = k / 10 * 2 * math.pi
        x = math.cos(ang) * 5.0; y = -0.4 + math.sin(ang) * 5.7
        e.add(lambda P, a=Z(x, y, 2.6), b=Z(x * 1.04, y * 1.02, 1.4): sd_cono(P, a, b, 0.55, 0.2), 'piel', 0, 'manto')
    # Y el cuello de piel clara, mullido, a los hombros.
    for k in range(9):
        a = math.radians(-120 + k * 30)
        e.add(lambda P, cc=Z(3.6 * math.sin(a), 3.9, 3.2 + 2.6 * math.cos(a)): sd_esfera(P, cc, 1.3), 'piel_clara', 0.3,
              'manto')


def r_collar(e):
    # EL COLLAR DE HUESECILLOS: una tira de cuero al cuello con dientes y huesitos colgando.
    for k in range(13):
        a = math.radians(-110 + k * 18.3)
        p = Z(3.3 * math.sin(a), 4.1, 3.3 + 2.4 * math.cos(a))
        e.add(lambda P, cc=p: sd_esfera(P, cc, 0.5), 'cuero', 0, 'collar')
        if k % 2 == 0:
            e.add(lambda P, a_=p, b_=p + np.array([0.3 * math.sin(a), 0.6, -1.9]): sd_cono(P, a_, b_, 0.45, 0.14),
                  'hueso', 0, 'collar')


def r_capa(e):
    # LA CAPA CORTA Y RAIDA: de los hombros a medio lomo, roja gastada, con jirones.
    c = Z(0, -0.4, 2.9)
    rad = np.array([4.5, 3.8, 3.2])
    def capa(P):
        d = np.abs(sd_elipsoide(P, c, rad)) - 0.3
        corte = -1.2 + 0.7 * np.sin(P[:, 0] * 2.3)    # cae hasta medio lomo, con jirones
        return np.maximum(np.maximum(d, corte - P[:, 1]), 2.9 - P[:, 2])
    e.add(capa, 'tela', 0, 'capa')


def r_yelmo(e):
    # EL YELMO ABOLLADO: un casco de hierro sobre la cabeza, con la ranura de los ojos y dos abolladuras; las orejas
    # asoman por los lados.
    c = Z(0, 5.5, 3.5)
    def yelmo(P):
        d = sd_elipsoide(P, c, np.array([3.1, 3.2, 2.7]))
        d = np.maximum(d, 2.7 - P[:, 2])                                       # solo la mitad de arriba
        d = np.maximum(d, -sd_esfera(P, c + np.array([1.9, 1.3, 1.6]), 0.8))   # abolladuras
        d = np.maximum(d, -sd_esfera(P, c + np.array([-1.2, -0.6, 2.2]), 0.7))
        d = np.maximum(d, -sd_caja(P, c + np.array([0.0, 2.6, 0.2]), [[1, 0, 0], [0, 1, 0], [0, 0, 1]], [2.2, 0.8, 0.28], 0.05))
        return d
    e.add(yelmo, 'hierro', 0, 'yelmo', 'cabeza')
    # Una cresta remachada por arriba.
    e.add(lambda P: sd_caja(P, c + np.array([0, -0.4, 2.55]), [[1, 0, 0], [0, 1, 0], [0, 0, 1]], [0.4, 2.0, 0.45]), 'oxido', 0,
          'yelmo', 'cabeza')


def r_tapa(e, delante=False):
    # LA TAPA DE OLLA de escudo: un disco de hierro con el borde oxidado y el asa en medio. En el costado (A) o por
    # delante del hombro (B).
    if delante:
        c = Z(3.6, 3.6, 2.8); n = np.array([0.75, 0.66, 0.0])
    else:
        c = Z(5.0, -0.4, 3.0); n = np.array([1.0, 0.0, 0.25])
    n = n / np.linalg.norm(n)
    u = np.cross(n, [0, 0, 1.0]); u /= np.linalg.norm(u); v = np.cross(n, u)
    ejes = [n, u, v]
    def disco(P, c=c, ejes=ejes):
        q = (P - c) @ np.array(ejes).T
        r = np.sqrt(q[:, 1] ** 2 + q[:, 2] ** 2)
        return np.maximum(r - (2.7 if delante else 3.2), np.abs(q[:, 0]) - 0.32)
    e.add(disco, 'hierro', 0, 'tapa')
    def borde(P, c=c, ejes=ejes):
        q = (P - c) @ np.array(ejes).T
        r = np.sqrt(q[:, 1] ** 2 + q[:, 2] ** 2)
        return np.maximum(np.abs(r - (2.6 if delante else 3.1)) - 0.32, np.abs(q[:, 0]) - 0.42)
    e.add(borde, 'oxido', 0, 'tapa')
    e.add(lambda P, cc=c + n * 0.45: sd_esfera(P, cc, 0.55), 'oxido', 0, 'tapa')


def r_clavos(e):
    # CLAVOS por el lomo: puntas de hierro cosidas al pelo, hacia arriba y atras.
    for (y, ang) in ((1.6, 0), (0.2, 25), (0.2, -25), (-1.4, 0), (-2.6, 30), (-2.6, -30), (-3.6, 0)):
        p = _sobre_cuerpo(y, ang, -0.2)
        d = np.array([math.sin(math.radians(ang)) * 0.4, -0.35, 1.0]); d /= np.linalg.norm(d)
        e.add(lambda P, a=p, b=p + d * 2.8: sd_cono(P, a, b, 0.55, 0.1), 'hierro', 0, 'clavo')


def r_placas(e):
    # EL PETO DE PLACAS: chapas remachadas por el lomo (unas de hierro y otras oxidadas), con hebillas de cuero.
    for i, (y, ang) in enumerate(((1.4, 0), (-0.6, 0), (-2.6, 0), (0.4, 50), (0.4, -50), (-1.8, 55), (-1.8, -55))):
        p = _sobre_cuerpo(y, ang, 0.15)
        a = math.radians(ang)
        nrm = np.array([math.sin(a), 0.0, math.cos(a)])
        lado = np.array([math.cos(a), 0.0, -math.sin(a)])
        e.add(lambda P, c=p, ej=[lado, [0, 1.0, 0], nrm]: sd_caja(P, c, ej, [1.4, 1.1, 0.22], 0.1),
              'hierro' if i % 3 else 'oxido', 0, 'placa')
        e.add(lambda P, c=p + nrm * 0.25: sd_esfera(P, c, 0.22), 'oxido', 0, 'placa')
    for y in (0.4, -1.6):
        def hebilla(P, y=y):
            return np.maximum(np.abs(sd_elipsoide(P, Z(0, y, 2.6), np.array([4.25, 0.6, 3.05]))) - 0.18, 1.8 - P[:, 2])
        e.add(hebilla, 'cuero', 0, 'hebilla')
    # La hombrera: una chapa curva sobre el hombro derecho.
    e.add(lambda P: np.maximum(np.abs(sd_esfera(P, Z(-3.0, 3.0, 3.6), 1.9)) - 0.25, 3.4 - P[:, 2]), 'hierro', 0, 'placa')


def r_clavada(e):
    # LA CORONA CLAVADA AL YELMO: tres clavos que la atraviesan.
    for x in (-1.6, 0.4, 2.0):
        e.add(lambda P, a=Z(x, 4.6, 8.0), b=Z(x * 0.9, 4.8, 6.0): sd_cono(P, a, b, 0.25, 0.08), 'hierro', 0, 'clavo',
              'cabeza')


def _con(sin_corona, *rasgos):
    e = _Piezas(rs.POSE(), sin_corona)
    for r in rasgos:
        r(e)
    return e.L


def hoy():
    return _con(False)


def camada_a():
    return _con(True, r_gordo, r_manto, lambda e: r_corona(e, puntas=7, alto=3.1, z=6.0))


def camada_b():
    return _con(True, r_gordo, r_collar, r_capa, lambda e: r_corona(e, puntas=6, alto=2.6, z=6.0, ladeo=0.18, abollada=True))


def chatarra_a():
    return _con(True, r_gordo, r_manto, r_yelmo, lambda e: r_corona(e, puntas=7, alto=2.2, z=7.3), r_tapa, r_clavos)


def chatarra_b():
    return _con(True, r_gordo, r_collar, r_placas, r_yelmo,
                lambda e: r_corona(e, puntas=6, alto=2.0, z=7.3, ladeo=0.18, abollada=True), r_clavada,
                lambda e: r_tapa(e, True))


# [nombre, escena, escala]
VERSIONES = [
    ('rey rata hoy', hoy, ESC_REY),
    ('CAMADA A manto', camada_a, ESC_MUT),
    ('CAMADA B collar', camada_b, ESC_MUT),
    ('CHATARRA A yelmo (sobre A)', chatarra_a, ESC_MUT2),
    ('CHATARRA B placas (sobre B)', chatarra_b, ESC_MUT2),
]


def modelo(L, escala):
    lado = int(round(66 * escala / ESC_REY / 2)) * 2 + 10
    return Modelo(escala, (lado, lado), (lado // 2, lado // 2), _mat(), (0.12, 0.09, 0.07), suaves=('cuerpo',),
                  brillan=('ojo', 'brillo', 'cicatriz', 'rubi'), corta_suelo=True)


if __name__ == '__main__':
    os.makedirs('tools/salida/sdf', exist_ok=True)
    filas = []
    for nombre, fn, esc in VERSIONES:
        L = fn()
        mo = modelo(L, esc)
        fotos = [render(mo, L, dd) for dd in range(5)]
        caja = None
        for f in fotos:
            b = f.getbbox()
            caja = b if caja is None else (min(caja[0], b[0]), min(caja[1], b[1]), max(caja[2], b[2]), max(caja[3], b[3]))
        filas.append((nombre, [f.crop((0, caja[1] - 3, f.size[0], caja[3] + 3)) for f in fotos]))
        print(nombre, 'ok')
    W = max(f[1][0].size[0] for f in filas)
    alturas = [f[1][0].size[1] for f in filas]
    ETQ = 150
    lam = Image.new('RGB', (W * 5 + ETQ, sum(alturas)), (40, 42, 50))
    dr = ImageDraw.Draw(lam)
    y0 = 0
    for j, (nombre, fotos) in enumerate(filas):
        h = alturas[j]
        dr.text((4, y0 + h // 2 - 5), nombre, fill=(220, 220, 220))
        for i, f in enumerate(fotos):
            lam.paste(f, (ETQ + i * W + (W - f.size[0]) // 2, y0), f)
        y0 += h
    lam = lam.resize((lam.width * 4, lam.height * 4), Image.NEAREST)
    lam.save('tools/salida/sdf/rey_rata_versiones.png')
    esc = os.path.join(os.path.expanduser('~'), 'Desktop', 'ataques_mapa', 'enemigos', 'prueba_3d', 'mutantes')
    os.makedirs(esc, exist_ok=True)
    lam.save(os.path.join(esc, 'rey_rata_versiones.png'))
    print(os.path.join(esc, 'rey_rata_versiones.png'))
