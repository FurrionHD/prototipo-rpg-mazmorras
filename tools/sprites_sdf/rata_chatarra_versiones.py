# ============================================================
#  rata_chatarra_versiones.py -- LA RATA DE LA CAMADA DEL REY DEL DESGUACE, propuestas en QUIETO (31/10/2026). Las ratas
#  que llama el Rey del desguace ("arma a la camada": +50 % de vida, un 25 % mas lentas) vienen con trozos de chatarra:
#  la rata de siempre (rata_sdf.py, a su tamaño 1,20) con piezas del rey (rey_rata_versiones.py), mas pocas y sueltas.
#    A  dedal       un dedal abollado de casco y una placa grande remachada al lomo.
#    B  peto        tres placas por el espinazo atadas con una hebilla, sin casco.
#    C  tapon       una chapa de botella de escudo sobre el lomo (de lado), un clavo y el dedal.
#  Uso: python tools/sprites_sdf/rata_chatarra_versiones.py -> tools/salida/sdf/rata_chatarra_versiones.png (y al
#  escritorio)
# ============================================================
import sys, os, math
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import rata_sdf as rs
import rey_rata_versiones as rv

Z = rs.Z
ESC = 1.2


class _Rata:
    """La rata de siempre (sin corona ni nada del rey)."""
    def __init__(self, pose):
        self.X = rs.huesos(pose)
        self.L = rs._escena_base(pose)

    def add(self, fn, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
        self.L.append((fn, mat, grupo, k, self.X.get(hueso, IDENT), hueso))


def r_dedal(e):
    # EL DEDAL: un casquito de hierro abollado encajado entre las orejas, con el borde oxidado.
    c = Z(0, 5.6, 4.0)
    def dedal(P):
        d = sd_cono(P, c, c + np.array([0.0, -0.3, 2.6]), 2.5, 2.0)
        return np.maximum(d, -sd_esfera(P, c + np.array([1.8, 0.6, 2.0]), 0.8))
    e.add(dedal, 'hierro', 0, 'yelmo', 'cabeza')
    e.add(lambda P: np.maximum(np.abs(sd_esfera(P, c, 2.6)) - 0.3, np.abs(P[:, 2] - c[2]) - 0.4), 'oxido', 0, 'yelmo',
          'cabeza')


def _placa(e, y, ang, mat, tam=(1.4, 1.1)):
    p = rv._sobre_cuerpo(y, ang, 0.3)
    a = math.radians(ang)
    nrm = np.array([math.sin(a), 0.0, math.cos(a)])
    lado = np.array([math.cos(a), 0.0, -math.sin(a)])
    e.add(lambda P, c=p, ej=[lado, [0, 1.0, 0], nrm]: sd_caja(P, c, ej, [tam[0], tam[1], 0.35], 0.1), mat, 0, 'placa')
    for dx in (-1, 1):
        e.add(lambda P, c=p + nrm * 0.4 + lado * dx * tam[0] * 0.6: sd_esfera(P, c, 0.35), 'oxido', 0, 'placa')


def r_placa_lomo(e):
    _placa(e, -0.8, 0, 'hierro', (3.0, 2.6))


def r_peto(e):
    for i, y in enumerate((1.6, -0.8, -3.1)):
        _placa(e, y, 0, 'oxido' if i == 1 else 'hierro', (2.6, 1.3))
    def hebilla(P):
        return np.maximum(np.abs(sd_elipsoide(P, Z(0, -0.8, 2.6), np.array([4.4, 0.8, 3.2]))) - 0.3, 1.6 - P[:, 2])
    e.add(hebilla, 'cuero', 0, 'hebilla')


def r_tapon(e):
    # LA CHAPA DE BOTELLA: un disco ondulado de hierro en el costado izquierdo, de escudo.
    c = Z(3.6, 0.0, 4.2); n = np.array([0.6, 0.0, 0.8]); n = n / np.linalg.norm(n)
    u = np.cross(n, [0, 0, 1.0]); u /= np.linalg.norm(u); v = np.cross(n, u)
    def chapa(P):
        q = (P - c) @ np.array([n, u, v]).T
        r = np.sqrt(q[:, 1] ** 2 + q[:, 2] ** 2)
        ang = np.arctan2(q[:, 2], q[:, 1])
        return np.maximum(r - (3.0 + 0.25 * np.sin(ang * 14.0)), np.abs(q[:, 0]) - 0.35)
    e.add(chapa, 'oxido', 0, 'tapa')
    e.add(lambda P: sd_esfera(P, c + n * 0.3, 1.6), 'hierro', 0, 'tapa')


def r_clavo(e):
    p = rv._sobre_cuerpo(-1.6, 0, -0.2)
    d = np.array([0.0, -0.35, 1.0]); d /= np.linalg.norm(d)
    e.add(lambda P: sd_cono(P, p, p + d * 3.4, 0.75, 0.15), 'hierro', 0, 'clavo')


def _con(*rasgos):
    e = _Rata(rs.POSE())
    for r in rasgos:
        r(e)
    return e.L


VERSIONES = [
    ('rata de siempre', lambda: _con()),
    ('A dedal + placa', lambda: _con(r_dedal, r_placa_lomo)),
    ('B peto', lambda: _con(r_peto)),
    ('C tapon + clavo', lambda: _con(r_dedal, r_tapon, r_clavo)),
]


if __name__ == '__main__':
    os.makedirs('tools/salida/sdf', exist_ok=True)
    mo = Modelo(ESC, (48, 48), (24, 24), rv._mat(), (0.12, 0.09, 0.07), suaves=('cuerpo',), brillan=('ojo', 'brillo'),
                corta_suelo=True)
    filas = []
    for nombre, fn in VERSIONES:
        L = fn()
        filas.append((nombre, [render(mo, L, dd) for dd in range(5)]))
        print(nombre, 'ok')
    W = 48; ETQ = 110
    lam = Image.new('RGB', (W * 5 + ETQ, W * len(filas)), (40, 42, 50))
    dr = ImageDraw.Draw(lam)
    for j, (nombre, fotos) in enumerate(filas):
        dr.text((4, j * W + W // 2 - 5), nombre, fill=(220, 220, 220))
        for i, f in enumerate(fotos):
            lam.paste(f, (ETQ + i * W, j * W), f)
    lam = lam.resize((lam.width * 4, lam.height * 4), Image.NEAREST)
    lam.save('tools/salida/sdf/rata_chatarra_versiones.png')
    esc = os.path.join(os.path.expanduser('~'), 'Desktop', 'ataques_mapa', 'enemigos', 'prueba_3d', 'mutantes')
    lam.save(os.path.join(esc, 'rata_chatarra_versiones.png'))
    print(os.path.join(esc, 'rata_chatarra_versiones.png'))
