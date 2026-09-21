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

```sh
"$G" --headless --path . res://tools/prueba_town_dos_jugadores.tscn   # host + jugador B + trabajadores (~2 min)
```

La de DOS JUGADORES lanza ademas al jugador B como otro proceso (`prueba_town_dos_cliente.tscn`): dos peleas
a la vez en dos trabajadores de pelea, B se une a la pelea del host y huye (la pelea sigue para el host).
Se coordinan por un fichero de fase (`user://logs/prueba_dos_fase.txt`) y B apunta lo suyo en
`logs/prueba_jugador_b.log`, que el host lee al final. Ojo al elegir grupos de la partida de referencia: el
personaje 1 es enorme y acaba las peleas del piso 1 antes de que al otro le llegue un turno.

### La sala de los mundos compartidos (fase 3)

```sh
"$G" --headless --path . res://tools/prueba_sala.tscn -- nube_local                 # ~15 s
"$G" --headless --path . res://tools/prueba_sala_entrar.tscn -- nube_local sala_vacia=4   # ~30 s
"$G" --headless --path . res://tools/prueba_sala_dos_jugadores.tscn -- nube_local    # ~1 min, 3 procesos
```

**Siempre con `-- nube_local`** (o `nube_url=http://127.0.0.1:8787` con el `wrangler dev` de
`servidor/nube`): sin eso, las pruebas que abren mundos escribirían en la nube de verdad, y se niegan a
arrancar. `sala_vacia=N` / `sala_espera=N` acortan lo que la sala espera antes de cerrarse sola (se le
pasan a la sala que lance el juego). Los registros: `logs/sala.log` (la que lanza el juego),
`logs/sala_prueba.log` y `logs/prueba_sala2_{sala,A,B}.log`.

## Trocear

```sh
MUDAR="_var1,_var2" EXCLUIR="func_que_se_queda" SECO=1 \
  python tools/trocear_net.py <tema> <Nodo> <ClaseConst> "<cabecera>" "<marca inicio>" "<marca fin>" [...]
```

`SECO=1` solo informa. Mira siempre sus AVISOS: nombres en cadenas (`Net.has_signal("x")`,
`Net.get("x")`) no los puede reescribir, y una local con el nombre del tema lo taparía.
