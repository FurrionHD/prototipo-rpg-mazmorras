# Textos de estados y cocina

Todo el texto que el jugador LEE sobre estados, buffs, debuffs y platos.
Generado desde el catalogo, asi que no falta ninguno.

**Como usarlo:** escribe el texto nuevo en la columna `NUEVO`. Lo que dejes
vacio se queda como esta. Cuando acabes, dimelo y lo aplico.

Dos cosas a tener en cuenta al escribir:

- Los NUMEROS no se escriben a mano: los pone el codigo desde los campos del
  estado. Donde veas un `%d%%` o un `%.1f`, tiene que seguir estando.
- La `descripcion` es SABOR (se lee con calma, en la ficha). Las lineas de
  `resumen()` son INFORMACION (se leen en mitad de un turno). No mezclarlas.
- En el apartado 2, los estados de DAÑO POR TURNO (veneno, sangrado, quemadura,
  regeneracion) salen sin su linea de magnitud: esa cifra la pone quien te lo
  echa, no el catalogo, y aqui se han montado en seco. En la pelea si aparece
  un "Te hace X de daño cada turno".

---

## 1. Estados: nombre, icono y descripcion

`scripts/core/status_effects.gd` (el diccionario `_defs`).
La descripcion es la frase de sabor de la ficha.

### 1a. Buffs y debuffs de combate

| Icono | NOMBRE actual | NOMBRE nuevo | Descripcion actual | Descripcion nueva |
|---|---|---|---|---|
| ☠ | Veneno |  | Corre por dentro y no se cansa. Cada dosis nueva no se suma a la anterior: la multiplica. |  |
| 🩸 | Sangrado |  | Una herida abierta que no espera. Cuanto más fuerte el que corta, más se abre; y cada corte sangra por su cuenta. |  |
| 🔥 | Quemadura |  | Sigue ardiendo cuando la llama ya no está. El agua la apaga. |  |
| 🐌 | Lento |  | Los miembros pesan y el turno tarda en llegar. |  |
| 🕸 | Pegajoso |  | Baba que se agarra a todo. Una capa se nota poco; cuatro te dejan luchando dentro de un tarro. |  |
| 💢 | Débil |  | El golpe sale, pero sale sin nadie detrás. |  |
| 🔻 | Vulnerable |  | La guardia se ha abierto y todo entra más hondo. |  |
| 💪 | Fortaleza |  | Los golpes salen con todo el cuerpo detrás. |  |
| 💫 | Aturdido |  | El mundo se va un momento. Cuando vuelve, ya te han pegado. |  |
| ⚡ | Electrizado |  | Los músculos responden tarde y mal: un buen mazazo ahora te tumba mucho más fácil. |  |
| ✚ | Regeneración |  | La poción hace su trabajo poco a poco: te cura mientras aguantas, no antes. |  |
| 🔷 | Regen. maná |  | El pozo se va llenando solo, gota a gota. |  |
| 💧 | Mojado |  | Empapado no ardes. Pero el agua conduce, y un rayo encuentra el camino. |  |
| 🌀 | Presteza |  | Los pies llegan antes que la idea. |  |
| 🛡 | Baluarte |  | Plantado y entero. Lo que viene, rebota. |  |
| 🎯 | Marca |  | Le has enseñado a todos por dónde entra. |  |
| 🩹 | Herida profunda |  | Una herida que no cierra por mucho que la traten. |  |
| ⚗ | Corrosión |  | La coraza cede. Ya no protege lo que protegía. |  |
| 🤐 | Silencio |  | Las palabras no salen y las manos no encuentran la maña. |  |
| 😱 | Miedo |  | El cuerpo se planta y no responde. Se pasa... cuando se pasa. |  |
| 👤 | Sigilo |  | Te pierden de vista entre el ruido. Buscan a otro. |  |
| 🫀 | Guardia de carne |  | Aguantas el doble y te duele el doble. Quien pega, se acuerda de ti. |  |
| 🗡 | Escolta |  | Dejas de ir por tu cuenta: entras justo detrás del que abre el hueco. |  |

### 1b. Platos de cocina (los 8 ejes)

| Icono | NOMBRE actual | NOMBRE nuevo | Descripcion actual | Descripcion nueva |
|---|---|---|---|---|
| 🛡 | Aguante |  | Comida de verdad, de la que se queda en el cuerpo. Encajas lo que te echen. |  |
| 💨 | Reflejos |  | Ligero de estómago y suelto de piernas. Te ves venir los golpes. |  |
| 🔥 | Fuerza |  | Carne y fuego. Pegas con ganas y cargas con más de lo que deberías. |  |
| ✨ | Magia |  | Sabe raro y se te queda la cabeza clara. Las palabras salen solas. |  |
| 🔮 | Maná |  | Caldo largo, de los que reposan. Lo que sueltan los bichos te cunde más. |  |
| 💚 | Remedios |  | Pescado y verdura, comida de convaleciente. El frasco te dura más. |  |
| 🧄 | Estómago |  | Salazón y encurtido. Después de esto, un veneno es casi una merienda. |  |
| 🍀 | Fortuna |  | Dicen que la mazmorra se porta mejor con quien baja comido. Nadie lo ha demostrado y todo el mundo lo cumple. |  |

## 2. Ficha de un estado ACTIVO (`Instance.resumen()`)

Lo que sale al señalar un chip **dentro de la pelea**. Se lee a mitad de un
turno, asi que va al grano: que me esta pasando y cuanto.
`status_effects.gd`, `resumen()`.

| Estado | ACTUAL | NUEVO |
|---|---|---|
| ☠ Veneno | ☠  Veneno  ·  4 turnos · Acumulado 1 de 5. |  |
| 🩸 Sangrado | 🩸  Sangrado  ·  3 turnos · Acumulado 1 de 5. |  |
| 🔥 Quemadura | 🔥  Quemadura  ·  2 turnos |  |
| 🐌 Lento | 🐌  Lento  ·  3 turnos · Te mueves un 25% menos. |  |
| 🕸 Pegajoso | 🕸  Pegajoso  ·  3 turnos · Te mueves un 5% menos. · Acumulado 1 de 4. |  |
| 💢 Débil | 💢  Débil  ·  3 turnos · Haces un 20% menos. |  |
| 🔻 Vulnerable | 🔻  Vulnerable  ·  3 turnos · Aguantas un 20% menos. |  |
| 💪 Fortaleza | 💪  Fortaleza  ·  3 turnos · Haces un 25% más. |  |
| 💫 Aturdido | 💫  Aturdido  ·  1 turno · Pierdes el turno. |  |
| ⚡ Electrizado | ⚡  Electrizado  ·  3 turnos · Te aturden más fácil. |  |
| ✚ Regeneración | ✚  Regeneración  ·  3 turnos |  |
| 🔷 Regen. maná | 🔷  Regen. maná  ·  3 turnos |  |
| 💧 Mojado | 💧  Mojado  ·  3 turnos · No te puede afectar: Quemadura. |  |
| 🌀 Presteza | 🌀  Presteza  ·  3 turnos · Te mueves un 25% más. |  |
| 🛡 Baluarte | 🛡  Baluarte  ·  3 turnos · Aguantas un 25% más. |  |
| 🎯 Marca | 🎯  Marca  ·  3 turnos · Te entra un 25% más. |  |
| 🩹 Herida profunda | 🩹  Herida profunda  ·  3 turnos · Te curan un 50% menos. |  |
| ⚗ Corrosión | ⚗  Corrosión  ·  3 turnos · Tu armadura protege un 25% menos. |  |
| 🤐 Silencio | 🤐  Silencio  ·  2 turnos |  |
| 😱 Miedo | 😱  Miedo  ·  2 turnos · Pierdes el turno. |  |
| 👤 Sigilo | 👤  Sigilo  ·  3 turnos · Te buscan un 65% menos. |  |
| 🫀 Guardia de carne | 🫀  Guardia de carne  ·  3 turnos · Te entra un 100% más. |  |
| 🗡 Escolta | 🗡  Escolta  ·  3 turnos |  |
| 🛡 Aguante | 🛡  Aguante  ·  quedan 20:00 · Resistencia +10%. · Te entra un 5% menos. |  |
| 💨 Reflejos | 💨  Reflejos  ·  quedan 20:00 · Agilidad +10%. · Criticas un 5% más a menudo. · Esquivas un 5% más a menudo. |  |
| 🔥 Fuerza | 🔥  Fuerza  ·  quedan 20:00 · Fuerza +10%. · Tus golpes hacen un 5% más de daño. · Cargas con 10 más de peso. |  |
| ✨ Magia | ✨  Magia  ·  quedan 20:00 · Magia +10%. · Los hechizos cuestan un 5% menos. |  |
| 🔮 Maná | 🔮  Maná  ·  quedan 20:00 · Te recupera un 25% más de maná por enemigo muerto en combate. · Recuperas un 20% más de maná por turno. |  |
| 💚 Remedios | 💚  Remedios  ·  quedan 20:00 · Te curan un 15% más. |  |
| 🧄 Estómago | 🧄  Estómago  ·  quedan 20:00 · El daño en el tiempo te hace un 15% menos de daño. · Resistes un 10% más los estados alterados. |  |
| 🍀 Fortuna | 🍀  Fortuna  ·  quedan 20:00 · Los enemigos te sueltan botín un 25% más a menudo. · Un 10% del botín sale doble. |  |

## 3. Chip corto (`Instance.etiqueta()`)

El recuadrito de la tarjeta. Aqui manda el ESPACIO: son 3-6 caracteres.

| Estado | ACTUAL | NUEVO |
|---|---|---|
| Veneno | `☠ 4t` |  |
| Sangrado | `🩸 3t` |  |
| Quemadura | `🔥 2t` |  |
| Lento | `🐌 3t` |  |
| Pegajoso | `🕸 3t` |  |
| Débil | `💢 3t` |  |
| Vulnerable | `🔻 3t` |  |
| Fortaleza | `💪 3t` |  |
| Aturdido | `💫 1t` |  |
| Electrizado | `⚡ 3t` |  |
| Regeneración | `✚ 3t` |  |
| Regen. maná | `🔷 3t` |  |
| Mojado | `💧 3t` |  |
| Presteza | `🌀 3t` |  |
| Baluarte | `🛡 3t` |  |
| Marca | `🎯 3t` |  |
| Herida profunda | `🩹 3t` |  |
| Corrosión | `⚗ 3t` |  |
| Silencio | `🤐 2t` |  |
| Miedo | `😱 2t` |  |
| Sigilo | `👤 3t` |  |
| Guardia de carne | `🫀 3t` |  |
| Escolta | `🗡 3t` |  |
| Aguante | `🛡 20:00` |  |
| Reflejos | `💨 20:00` |  |
| Fuerza | `🔥 20:00` |  |
| Magia | `✨ 20:00` |  |
| Maná | `🔮 20:00` |  |
| Remedios | `💚 20:00` |  |
| Estómago | `🧄 20:00` |  |
| Fortuna | `🍀 20:00` |  |

## 4. Frase "que hace" (`efecto_legible()`)

La que sale en las fichas de habilidades, hechizos y platos, detras de
"aplica X:". Va en tercera persona y sin punto final.

| Estado | ACTUAL | NUEVO |
|---|---|---|
| Veneno | le hace daño cada turno |  |
| Sangrado | le hace daño cada turno |  |
| Quemadura | le hace daño cada turno |  |
| Lento | -25% velocidad |  |
| Pegajoso | -5% velocidad |  |
| Débil | -20% ataque |  |
| Vulnerable | -20% defensa |  |
| Fortaleza | +25% ataque |  |
| Aturdido | le hace perder el turno |  |
| Electrizado |  |  |
| Regeneración | le cura cada turno |  |
| Regen. maná | le devuelve maná cada turno |  |
| Mojado |  |  |
| Presteza | +25% velocidad |  |
| Baluarte | +25% defensa |  |
| Marca | +25% daño recibido |  |
| Herida profunda | -50% curación recibida |  |
| Corrosión | -25% armadura |  |
| Silencio | le corta hechizos y habilidades |  |
| Miedo | le hace perder el turno |  |
| Sigilo | -65% de atención de los enemigos |  |
| Guardia de carne | +100% daño recibido y +100% vida máxima |  |
| Escolta | pegas detrás de cada aliado realizando un 50% de daño |  |
| Aguante | +10% Resistencia y -5% daño recibido |  |
| Reflejos | +10% Agilidad y +5% crítico y +5% esquiva |  |
| Fuerza | +10% Fuerza y +5% daño hecho y +10 de carga |  |
| Magia | +10% Magia y -5% coste de los hechizos |  |
| Maná | +25% maná por enemigo y +20% regeneración de maná |  |
| Remedios | +15% curación recibida |  |
| Estómago | -15% daño por turno recibido y +10% resistencia a estados |  |
| Fortuna | +25% probabilidad de botín y +10% de que el botín salga doble |  |

## 5. Platos: nombre, ficha y sabor

`resources/consumables/plato_*.tres`. El NOMBRE es el del menu del Cocinero
y el del inventario. La ficha (`resumen_plato()`) la deriva el codigo.

| Fichero | NOMBRE actual | NOMBRE nuevo | Descripcion actual | Descripcion nueva |
|---|---|---|---|---|
| `plato_kebab_rata` | Kebab de rata |  | Se ve venir de lejos y huele mucho mejor de lo que debería. Nadie pregunta qué lleva dentro, y todos repiten. |  |
| `plato_parrillada_jabali` | Parrillada de jabalí y rata |  | Todo al fuego y mucho ajo. Te levantas de la mesa con ganas de partir algo por la mitad. |  |
| `plato_gobio_sal` | Gobio a la sal |  | Pescado pequeño, sal gorda y un chorro de aceite. Se come de pie y en dos minutos. |  |
| `plato_lubina_horno` | Lubina al horno con patatas |  | Comida de convaleciente, de la que sacan cuando alguien vuelve mal de abajo. Sienta como una manta. |  |
| `plato_sopa_setas` | Sopa de setas de las simas |  | Sabe a sótano y a cosa que no ha visto el sol. Después las palabras salen ordenadas solas. |  |
| `plato_caldo_puerro` | Caldo de puerro de gruta |  | Caldo claro de los que hierven media tarde. No llena nada, y aun así algo deja dentro. |  |
| `plato_encurtidos_sal` | Encurtidos en salazón |  | Vinagre, sal y paciencia. Después de esto el estómago aguanta lo que le eches. |  |
| `plato_revuelto_setas` | Revuelto de dos setas |  | Las dos setas de ahí abajo en la misma sartén. Nadie sabe por qué, pero el que lo desayuna vuelve con la bolsa llena. |  |
| `plato_kebab_bestia` | Kebab de bestia |  | La misma receta de siempre, con carne que sí impone. Se sigue sin preguntar nada. |  |
| `plato_parrillada_insecto` | Parrillada de insecto y bestia |  | Cruje distinto y sabe a hierro. Cuesta el primer bocado y ninguno más. |  |
| `plato_anguila_ajillo` | Anguila al ajillo |  | Se resiste hasta dentro del plato. Después andas suelto y con los ojos rápidos. |  |
| `plato_bagre_guisado` | Bagre guisado con tubérculo |  | Un guiso espeso de los que reposan toda la noche. Lo que te tomes después te dura el doble. |  |
| `plato_crema_hongo` | Crema de hongo de azufre |  | Pica en la garganta y deja la cabeza rarísima. Los que la prueban no hablan de otra cosa. |  |
| `plato_pure_tuberculo` | Puré de tubérculo pálido |  | Espeso, pálido y sin sabor a gran cosa. Después notas el aire distinto y no sabes explicar por qué. |  |
| `plato_encurtidos_hongo` | Encurtidos de hongo de azufre |  | Los de siempre, pero con algo dentro que no debería comerse nadie. Funciona igual. |  |
| `plato_espejo_sal` | Espejo abisal a la sal |  | Cocinarse el pez que casi nadie saca ya es tentar a la suerte. Cómetelo y a ver qué pasa. |  |

### Ficha completa de cada plato (derivada; solo para que veas como queda)

**Kebab de rata** (T1)

```
🛡 Aguante: +10% Resistencia y -5% daño recibido
Dura 20 minutos.
```

**Parrillada de jabalí y rata** (T1)

```
🔥 Fuerza: +10% Fuerza y +5% daño hecho y +10 de carga
Dura 20 minutos.
```

**Gobio a la sal** (T1)

```
💨 Reflejos: +10% Agilidad y +5% crítico y +5% esquiva
Dura 20 minutos.
```

**Lubina al horno con patatas** (T1)

```
💚 Remedios: +15% curación recibida
Dura 20 minutos.
```

**Sopa de setas de las simas** (T1)

```
✨ Magia: +10% Magia y -5% coste de los hechizos
Dura 20 minutos.
```

**Caldo de puerro de gruta** (T1)

```
🔮 Maná: +25% maná por enemigo y +20% regeneración de maná
Dura 20 minutos.
```

**Encurtidos en salazón** (T1)

```
🧄 Estómago: -15% daño por turno recibido y +10% resistencia a estados
Dura 20 minutos.
```

**Revuelto de dos setas** (T1)

```
🍀 Fortuna: +25% probabilidad de botín y +10% de que el botín salga doble
Dura 20 minutos.
```

**Kebab de bestia** (T2)

```
🛡 Aguante: +12% Resistencia y -6% daño recibido
Dura 20 minutos.
```

**Parrillada de insecto y bestia** (T2)

```
🔥 Fuerza: +12% Fuerza y +6% daño hecho y +12 de carga
Dura 20 minutos.
```

**Anguila al ajillo** (T2)

```
💨 Reflejos: +12% Agilidad y +6% crítico y +6% esquiva
Dura 20 minutos.
```

**Bagre guisado con tubérculo** (T2)

```
💚 Remedios: +18% curación recibida
Dura 20 minutos.
```

**Crema de hongo de azufre** (T2)

```
✨ Magia: +12% Magia y -6% coste de los hechizos
Dura 20 minutos.
```

**Puré de tubérculo pálido** (T2)

```
🔮 Maná: +30% maná por enemigo y +24% regeneración de maná
Dura 20 minutos.
```

**Encurtidos de hongo de azufre** (T2)

```
🧄 Estómago: -18% daño por turno recibido y +12% resistencia a estados
Dura 20 minutos.
```

**Espejo abisal a la sal** (T2)

```
🍀 Fortuna: +30% probabilidad de botín y +12% de que el botín salga doble
Dura 20 minutos.
```

## 6. Lineas del log de combate

Estan sueltas en `scripts/ui/combat.gd`; aqui van con su sitio.
Los `%s` son huecos que rellena el codigo, no se tocan.

| Donde | ACTUAL | NUEVO |
|---|---|---|
| combat.gd:~3370 (aplicar estado) | `✨ %s: %s recibe %s.` |  |
| combat.gd:~2465 (daño por turno) | `%s sufre %s (%.2f).` |  |
| combat.gd (empezar a cargar, jugador) | `⚡ %s se prepara para %s. (si te aturden, se interrumpe)` |  |
| combat.gd (seguir cargando, jugador) | `%s sigue cargando %s... ⚡` |  |
| combat.gd (empezar a cargar, enemigo) | `⚡ %s se prepara para %s. ¡Prepárate! (aturdirlo lo interrumpe)` |  |
| combat.gd (seguir cargando, enemigo) | `%s sigue cargando %s... ⚡ (prepárate)` |  |
| combat.gd (carga interrumpida) | `%s está aturdido: se le interrumpe %s. 💫` |  |
| combat.gd (aturdido sin carga) | `%s está aturdido y pierde el turno. 💫` |  |
| combat.gd (cae por estados) | `%s cae por el daño de sus estados. ☠` |  |
| game.gd:~4098 (se pasa, por el mapa) | `[estado] %s: se le pasa el %s` |  |
