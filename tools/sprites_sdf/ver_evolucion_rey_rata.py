# LA EVOLUCION DEL REY RATA DE CERCA (31/10, rey-rata-mutante): la hoja 'evolucion' del mutante (RATA_VAR=cloacas |
# desguace) mirando al S y al SE, a 4x, para ver paso a paso como le cae el manto o le sale la chatarra.
#   RATA_VAR=cloacas python tools/sprites_sdf/ver_evolucion_rey_rata.py -> Desktop/.../mutantes/rey_rata_<var>_evolucion.png
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rata_sdf as rs
from sdf_comun import render
from PIL import Image

n = rs.ANIMS['evolucion'][0]
fn = rs.ANIMS['evolucion'][4]
W = rs.MODELO.W
dirs = (0, 1)
hoja = Image.new('RGB', (W * n, W * len(dirs)), (40, 42, 50))
for j, d in enumerate(dirs):
    for i in range(n):
        im = render(rs.MODELO, rs.escena(fn(i / n)), d)
        hoja.paste(im, (i * W, j * W), im)
hoja = hoja.resize((hoja.width * 3, hoja.height * 3), Image.NEAREST)
ruta = os.path.join(os.path.expanduser('~'), 'Desktop', 'ataques_mapa', 'enemigos', 'prueba_3d', 'mutantes',
                    'rey_rata_%s_evolucion.png' % rs.VAR)
hoja.save(ruta)
print(ruta)
