# ============================================================
#  polilla_variante_sdf.py -- HORNEA las hojas de UNA de las cuatro polillas (05/10/2026: "nos quedamos con todas").
#  El cuerpo y las animaciones (claves de tiempo del viejo) son los de polilla_sdf.py; las alas, el dibujo, los colores
#  y el TAMAÑO, los de su version en polilla_versiones.py. Normales: A pavon y D calavera; MUTANTES: C boceto y B ojos
#  (la mayor). Que salga cada una segun la profundidad se cablea en la pasada de los mutantes.
#  Uso: POLILLA_VAR=a|b|c|d python tools/sprites_sdf/polilla_variante_sdf.py [anim ...]
#       -> assets/sprites/enemigos/polilla_sdf_<var>/<anim>.png
# ============================================================
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import polilla_sdf as pm
import polilla_versiones as pv

VAR = os.environ.get('POLILLA_VAR', 'a').lower()
_VV = [v for k, v in pv.VERSIONES.items() if k.lower().startswith(VAR)][0]
MODELO = pv.modelo(_VV)
ANIMS = pm.ANIMS
SALIDA = 'assets/sprites/enemigos/polilla_sdf_%s/' % VAR
VISTAS = 'tools/salida/sdf/polilla_%s/' % VAR


def escena(pose):
    return pv.escena_version(_VV, pose)


if __name__ == '__main__':
    hornear('polilla_variante_sdf', sys.argv[1:] or list(ANIMS.keys()), SALIDA, VISTAS)
