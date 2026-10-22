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
"$G" --headless --path . res://tools/prueba_town_pelea_sala.tscn -- nube_local   # una pelea en la sala, de principio a fin
```

La de trabajadores lanza procesos de verdad (~95 s): sala, trabajador de reserva, piso 1 con dueño
trabajador, espejos, foto al subir, vuelta con los mismos enemigos, trabajador DE PELEA esperando en el
piso, pelea ejecutada por el y jugada desde el espejo (se cierra sola y vuelve la excelia), otro que entra
a esperar la siguiente, caida en plena pelea (se deshace) y cierre de procesos. Los registros de los trabajadores: `AppData/Roaming/DungeonOratoria/logs/`.
Que el enemigo "me vea y embista solo" es aleatorio (cono + ruido): se apunta, no se exige.
Con `PRUEBA_CABOS=1` (~1 min) hace solo el arranque y los dos cabos sueltos del 07/10: el ruido de la pelea de un
trabajador va a nombre del humano que la abrio, y si el trabajador de pelea se cae con tus fichas en la mano la
pelea te vuelve a tu PC. No espera a que acabe ninguna pelea: en las pruebas el grupo solo sabe ir recto y se
atasca en fila, asi que el "termina en 150 s" de la larga puede fallar sin que el juego este mal.
Si una pasada se corta a medias, quedan Godots vivos con el puerto 24599: cerrarlos antes de relanzar.

```sh
"$G" --headless --path . res://tools/prueba_town_dos_jugadores.tscn -- nube_local   # A + sala + B + trabajadores (~2 min)
```

La de DOS JUGADORES lanza ademas al jugador B como otro proceso (`prueba_town_dos_cliente.tscn`): dos peleas
a la vez en dos trabajadores de pelea, B se une a la pelea de A y huye (la pelea sigue para A).
Se coordinan por un fichero de fase (`user://logs/prueba_dos_fase.txt`) y B apunta lo suyo en
`logs/prueba_jugador_b.log`, que A lee.

**POR LA SALA (20/10, fase 2 paso 6):** `town_dos_jugadores`, `town_tactico`, `town_zona_ajena` y `town_baul_red` ya
no hostean: hacen una ranura temporal de `mundo_ref` (ranuras 86-89) con A y B dentro, lanzan su sala y entran los dos
como clientes (`prueba_town_sala_comun.gd`). Van con `-- nube_local`. Lo de dentro de la sala (en que piso esta cada
uno, quien lleva cada piso, los trabajadores de pelea, las fotos) lo apunta la sala en su registro
(`logs/prueba_ranura_<n>_sala.log`) con lineas `[S] dato clave=valor` cuando cambia: la pone `tools/sonda_sala.gd` si
la sala se lanza con la palabra `sonda`, y avisa tambien de sus tirones (`[S] tiron`). Los grupos se eligen por NOMBRE
(el orden de la plantilla cambia segun como se cargue): A = Agirato + Catalardio, B = Dasui + Daniel; Dawnsin es
enorme y acaba las peleas antes de que a los demas les llegue un turno. Desde la etapa 3 no hay trabajadores: la sala
ejecuta las peleas (`town_pelea_sala`, `town_dos_peleas`).

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
