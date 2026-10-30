# ============================================================
#  rata_elegida.py -- EL ARBOL DE LA RATA, lo elegido (30/10/2026, sobre rata_versiones.py): ESCURRIDIZA A (sombra) y
#  CRISTAL B (drusas) de primera evolucion, y su MEZCLA de segunda ("y haz la mezcla tambien"): negra, flaca y pegada al
#  suelo, con los racimos de cristales. La mezcla en dos tonos de cristal para que elija: los cian de siempre o ahumados.
#  Uso: python tools/sprites_sdf/rata_elegida.py  -> tools/salida/sdf/rata_elegida.png
# ============================================================
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rata_versiones as rv
import rata_sdf as rs


def mezcla():
    return rv._con(rs.POSE(estira=1.12, agacha=0.22), rv.r_drusas)


rv.VERSIONES = [
    ('rata hoy', rs.MAT, rv.normal, rv.ESC_NORMAL),
    ('1a: escurridiza', rv._mat(ojo=rv.OJO_AMARILLO, **rv.SOMBRA), rv.escurridiza_a, rv.ESC_MUTANTE),
    ('1a: cristal', rv._mat(), rv.cristal_b, rv.ESC_MUTANTE),
    ('2a: cristal cian', rv._mat(ojo=rv.OJO_AMARILLO, **rv.SOMBRA), mezcla, rv.ESC_EVO2),
    ('2a: cristal ahumado', rv._mat(ojo=rv.OJO_AMARILLO, cristal=rv.CRISTAL_OSC, **rv.SOMBRA), mezcla, rv.ESC_EVO2),
]

if __name__ == '__main__':
    import runpy
    sys.argv = ['rata_versiones.py']
    src = open(rv.__file__, encoding='utf-8').read()
    principal = src[src.index("if __name__ == '__main__':"):].replace("if __name__ == '__main__':", "if True:", 1)
    principal = principal.replace("rata_versiones.png", "rata_elegida.png")
    exec(compile(principal, 'rata_elegida_main', 'exec'), vars(rv))
