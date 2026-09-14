# Herramientas de la capa de red

`net.gd` está partido en temas (`Net.<tema>.<funcion>`, índice en su cabecera). Estas herramientas
sirven para seguir troceando y para comprobar que no se ha roto nada.

## Comprobar (después de CUALQUIER cambio en la red)

Godot **no** comprueba al compilar las llamadas a `Net.algo()`: Net es un autoload y las llamadas son
dinámicas, así que una ruta vieja solo revienta al jugar por ahí. Por eso van las tres:

```sh
G=".../Godot_v4.7-stable_win64_console.exe"
python tools/verificar_net.py                                  # toda ref Net.x / Net.tema.x existe
"$G" --headless --path . res://tools/prueba_cargar_todo.tscn   # compila los ~200 scripts
"$G" --headless --path . res://tools/prueba_town_trabajadores.tscn   # host + trabajadores reales
```

La de trabajadores lanza procesos de verdad (~95 s): sala, trabajador de reserva, piso 1 con dueño
trabajador, espejos, foto al subir, vuelta con los mismos enemigos, trabajador DE PELEA esperando en el
piso, pelea ejecutada por el y jugada desde el espejo (se cierra sola y vuelve la excelia), otro que entra
a esperar la siguiente, caida en plena pelea (se deshace) y cierre de procesos. Los registros de los trabajadores: `AppData/Roaming/DungeonOratoria/logs/`.
Que el enemigo "me vea y embista solo" es aleatorio (cono + ruido): se apunta, no se exige.

## Trocear

```sh
MUDAR="_var1,_var2" EXCLUIR="func_que_se_queda" SECO=1 \
  python tools/trocear_net.py <tema> <Nodo> <ClaseConst> "<cabecera>" "<marca inicio>" "<marca fin>" [...]
```

`SECO=1` solo informa. Mira siempre sus AVISOS: nombres en cadenas (`Net.has_signal("x")`,
`Net.get("x")`) no los puede reescribir, y una local con el nombre del tema lo taparía.
