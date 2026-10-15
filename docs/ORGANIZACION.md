# Cómo se ordena el código (protocolo)

Acordado el 13/10/2026 dentro del plan de optimización. Vale para todo lo nuevo y para todo lo que se toque.

## 1. Un archivo = una funcionalidad
- Objetivo: **menos de ~800 líneas** por archivo. A partir de **1.500 se parte** sí o sí.
- Si para explicar qué hace un archivo hace falta decir «y además…», son dos archivos.
- La cabecera de cada archivo dice en 3-6 líneas **qué hace, quién lo llama y qué prueba lo cubre**.

## 2. Carpetas por tema
`scripts/<área>/<tema>/`. Áreas que ya existen: `actors`, `core`, `fx`, `items`, `net`, `town`, `ui`, `world`.
Cuando un archivo grande se parte, sus trozos van a una carpeta con su nombre:

```
scripts/core/game.gd            <- índice (el autoload): solo reparte y hace de puente
scripts/core/game/baul.gd       <- Game.baul.x
scripts/core/game/bolsa.gd      <- Game.bolsa.x
scripts/core/game/encargos.gd   ...
```

## 3. El patrón para partir un autoload (el de `net.gd`, ya probado)
- El autoload queda como **índice**: crea los temas como hijos con **nombre fijo** y en su cabecera lista cuáles hay.
- Se llaman como `Game.<tema>.<función>` (igual que `Net.peleas.x`).
- Lo que llaman desde fuera se queda un tiempo como **PUENTE** al final del archivo original
  (`func peso_actual(): return bolsa.peso()`), y se va quitando a medida que se cambian los que llaman.
- Una pantalla grande se parte en `RefCounted` con `_pantalla` (el patrón de `combat.gd`, ver la memoria
  `trocear-archivos-gigantes`).
- Herramientas: `tools/trocear_net.py`, `tools/trocear_pantalla.py`, `tools/verificar_net.py`,
  `tools/verificar_pantalla.py`.

### Trampas conocidas al mudar código
- Godot **no comprueba al compilar** las llamadas a un autoload: `Game.funcion_que_no_existe()` compila. Para eso
  están los verificadores; pasarlos tras cada corte.
- Las búsquedas **por texto** (`has_signal("x")`, `get("_campo")`, `call("x")`) no las reescribe nadie: buscarlas
  a mano antes de mover lo que nombran.
- Al pasar código de una pantalla a un `RefCounted`: `self` cambia de significado, los atajos `$Nodo` dejan de
  funcionar, las propiedades con get/set no se mudan solas y las constantes de varias líneas se cortan.
- Un `class_name` nuevo pide `--import` antes de que lo vean las pruebas.

## 4. Cada funcionalidad tiene SU prueba
- **Lógica pura** (cuentas, tablas, conversiones) → test unitario en `tools/unitarias/test_<tema>.gd`.
  Tardan milisegundos; se pasan todos con `python tools/pasar_pruebas.py --unitarias`.
- **Lo que cruza piezas** (física, red, guardado real, una pelea entera) → prueba de integración
  `tools/prueba_<tema>.tscn`.
- **Todo lo nuevo nace con su prueba.** Y **antes de mudar u optimizar algo, primero se le pone su prueba** con el
  código de antes; si el cambio la rompe, nos enteramos.
- Lo que se separe de una escena se lleva sus unitarias; las pruebas de integración que solo comprobaban esa cuenta
  se quitan o se adelgazan.
- `tools/LEEME_pruebas.md` tiene el índice **archivo → prueba**, con los huecos marcados.

## 5. Cómo se trabaja
- Una rama por fase, desde `main`. Un commit por tarea.
- Antes de cada commit: `python tools/pasar_pruebas.py --rapidas`. Antes de juntar a `main` o sacar un .exe: la
  batería entera, con red.
- Cada cambio en los mensajes de red sube el `PROTOCOLO`.
- Las cuatro reglas de los datos (memoria `contado-no-suelto`): lo igual va **contado**; lo fijo viaja **una vez**
  y se nombra por id; lo que el otro ordenador puede calcular **no viaja**; lo que no ha cambiado **no se
  recalcula ni se reenvía**.
