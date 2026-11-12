# ============================================================
#  polilla_mezcla_versiones.py -- OPCIONES DE CUERPO PARA EL RANGO 2 DE LA POLILLA, LA MEZCLA (12/11/2026). Los dos rango 1
#  son la B ojos (LUZ, del pavon) y la C boceto (OSCURIDAD, de la calavera) de polilla_versiones.py; la mezcla junta las
#  dos (memoria polilla-mutante). "Varias opciones para que elijamos la mas god". Mas grande que las dos (escala 3,3).
#    1 partida     asimetrica: el ala izquierda es la B (luz) y la derecha la C (sombra)
#    2 picuda de oro  la forma de la C (picuda, cola) con el color y los ojos dorados de la B y el tercer ojo
#    3 ojos en humo  la forma de la B, negra, deshilachada en humo como la C; ojos dorados de la B y dianas blancas
#    4 luz y sombra  delanteras de la B (luz) y traseras de la C en cola (sombra)
#    5 eclipse dorado  la C negra con un anillo de oro dentro del borde y los ojos de la B
#    6 invertida   la B en negativo: alas crema con ojos negros, y las colas de humo de la C
#  Solo QUIETAS, cinco direcciones. Uso: python tools/sprites_sdf/polilla_mezcla_versiones.py
#    -> tools/salida/sdf/polilla_mezcla_versiones.png
# ============================================================
import sys, os
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import polilla_sdf as pm
import polilla_versiones as pv

B, C = pv.VERSIONES['B ojos'], pv.VERSIONES['C boceto']
ESC = 3.3

# UN ALA DISTINTA A CADA LADO: si el ala trae 'izq' y 'der', cada lado pinta la suya (s < 0 izquierda).
_ala_original = pv.ala_generica


def _ala_por_lado(add, p, s, A, nombre):
    if 'izq' in A:
        A = A['der'] if s > 0 else A['izq']
    _ala_original(add, p, s, A, nombre)


pv.ala_generica = _ala_por_lado


def tonos(c, k=(0.62, 0.82, 1.0)):
    return [tuple(min(1.0, v * f) for v in c) for f in k]


ORO = tonos((0.86, 0.70, 0.40))
# Los materiales de la C con otro nombre, para que convivan con los de la B en la misma polilla.
C_MAT = {'ala_c': C['mat']['ala'], 'ala_tras_c': C['mat']['ala_tras'], 'humo': C['mat']['humo'],
         'linea_c': C['mat']['linea'], 'diana': C['mat']['ocelo']}


def de_c(ala, **cambios):
    """Un ala de la C con sus materiales renombrados (ala_c, linea_c...)."""
    a = dict(ala)
    a['mat'] = {'ala': 'ala_c', 'ala_tras': 'ala_tras_c'}[a['mat']]
    a['lineas'] = [(x, y, 'linea_c', n, amp) for x, y, _m, n, amp in a.get('lineas', [])]
    a.update(cambios)
    return a


MEZCLAS = {}

MEZCLAS['1 partida'] = dict(
    mat=dict(B['mat'], **C_MAT), escala=ESC,
    ala1=dict(izq=B['ala1'], der=de_c(C['ala1'])),
    ala2=dict(izq=B['ala2'], der=de_c(C['ala2'])),
    extra='tercer_ojo',
)

MEZCLAS['2 picuda de oro'] = dict(
    mat=dict(B['mat'], humo=tonos((0.16, 0.13, 0.11))), escala=ESC,
    ala1=dict(C['ala1'], mat='ala', jirones='humo', contorno=(1.7, 'linea'), lineas=[], ocelos=[((9.0, -0.6), 2.4, 'ojo')]),
    ala2=dict(C['ala2'], mat='ala_tras', jirones='humo', contorno=(1.5, 'linea'), lineas=[],
              ocelos=[((5.6, 5.0), 1.8, 'ojo'), ((4.3, 10.6), 1.2, 'ojo')]),
    extra='tercer_ojo',
)

MEZCLAS['3 ojos en humo'] = dict(
    mat=dict(B['mat'], **C_MAT), escala=ESC,
    ala1=dict(B['ala1'], festones=None, jirones='humo', semilla=5, jiron_r=(0.7, 1.5), jiron_sale=(0.3, 1.3),
              ocelos=B['ala1']['ocelos'] + [((4.2, 2.6), 1.1, 'diana')]),
    ala2=dict(B['ala2'], festones=None, jirones='humo', semilla=9, jiron_r=(0.6, 1.3), jiron_sale=(0.3, 1.2)),
    extra='tercer_ojo',
)
MEZCLAS['3 ojos en humo']['mat']['ocelo_d'] = C['mat']['ocelo']

MEZCLAS['4 luz y sombra'] = dict(
    mat=dict(B['mat'], **C_MAT), escala=ESC,
    ala1=B['ala1'],
    ala2=de_c(C['ala2']),
    extra='tercer_ojo',
)

MEZCLAS['5 eclipse dorado'] = dict(
    mat=dict(B['mat'], **C_MAT, linea=ORO, borde=ORO), escala=ESC, brillan=('brillo', 'linea'),
    ala1=de_c(C['ala1'], contorno=(1.6, 'linea'), lineas=[], ocelos=[((9.0, -1.0), 2.4, 'ojo')]),
    ala2=de_c(C['ala2'], contorno=(1.4, 'linea'), lineas=[],
              ocelos=[((5.6, 5.0), 1.8, 'ojo'), ((4.3, 10.6), 1.3, 'diana')]),
    extra='tercer_ojo',
)

MEZCLAS['6 invertida'] = dict(
    mat=dict(B['mat'], **C_MAT, ala=tonos((0.84, 0.74, 0.58)), ala_tras=tonos((0.78, 0.68, 0.52)),
             linea=tonos((0.20, 0.16, 0.13)), borde=tonos((0.20, 0.16, 0.13)), ocelo=tonos((0.12, 0.10, 0.10)),
             iris=ORO, pelo=tonos((0.70, 0.62, 0.50))), escala=ESC,
    ala1=B['ala1'],
    ala2=dict(de_c(C['ala2']), mat='ala_tras'),
    extra='tercer_ojo',
)


def modelo(vv):
    mat = dict(pv.COMUN); mat.update(vv['mat'])
    esc = vv.get('escala', 2.0)
    lado = int(round(90 * esc / 2.0 / 2)) * 2
    return Modelo(esc, (lado, lado), (lado // 2, lado // 2), mat, (0.05, 0.04, 0.05), suaves=('cuerpo', 'cabeza'),
                  brillan=vv.get('brillan', ('brillo',)), corta_suelo=True, especular=('ojo',), umbral_especular=0.8)


if __name__ == '__main__':
    os.makedirs('tools/salida/sdf', exist_ok=True)
    lista = [('B luz (rango 1)', B), ('C sombra (rango 1)', C)] + list(MEZCLAS.items())
    filas = []
    for nombre, vv in lista:
        mo = modelo(vv)
        L = pv.escena_version(vv, pm.POSE())
        filas.append((nombre, [render(mo, L, dd) for dd in range(5)]))
        print(nombre, 'ok', flush=True)
    W = max(f[1][0].size[0] for f in filas)
    alturas = [f[1][0].size[1] for f in filas]
    lam = Image.new('RGB', (W * 5 + 120, sum(alturas)), (40, 42, 50))
    dr = ImageDraw.Draw(lam)
    y0 = 0
    for j, (nombre, fotos) in enumerate(filas):
        h = alturas[j]
        dr.text((4, y0 + h // 2), nombre, fill=(220, 220, 220))
        for i, f in enumerate(fotos):
            lam.paste(f, (120 + i * W + (W - f.size[0]) // 2, y0), f)
        y0 += h
    lam = lam.resize((lam.width * 2, lam.height * 2), Image.NEAREST)
    lam.save('tools/salida/sdf/polilla_mezcla_versiones.png')
    print('tools/salida/sdf/polilla_mezcla_versiones.png')
