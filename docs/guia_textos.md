# Guía de textos del juego

Cómo se escriben las descripciones que lee el jugador: magias, habilidades, armas, objetos, sets,
estados y menús. Sale de los textos oficiales en español de Honkai: Star Rail (reliquias, conos de
luz y habilidades) y de Genshin Impact (artefactos), comparados con los nuestros el 06/11/2026.

La regla de fondo: **alguien que no ha visto el código tiene que entender exactamente qué pasa**.
Si una frase se puede leer de dos maneras, está mal.

## 1. Las reglas

1. **Se habla del «portador».** «El daño que inflige el portador aumenta en un 20 %», no «haces un
   20 % más». En habilidades y magias, el sujeto es quien la usa o el objetivo: «Inflige…»,
   «El objetivo queda…».
   - **En magias, «el lanzador»** (la magia no se porta, se lanza): «+ 12 por el poder mágico del
     lanzador».
   - **A quien se le echa, como HSR: «un aliado» y después «ese aliado»** (decidido 06/11 tras
     contarlo en los textos oficiales, ver sección 4): «Otorga Fortaleza a un aliado durante 3
     turnos», «Los golpes de ese aliado infligen…». «Todos los aliados» si va a todos. A un
     enemigo, «el objetivo seleccionado».
   - **Los números, de los datos y concretos:** nada de «resiste lo mismo que el fuego»; «recibe
     un 20 % menos de Daño de Fuego y un 20 % más de Daño de Agua».
2. **Cada porcentaje dice de qué es.** Nunca «el 30 %» a secas.
   - Mal: «hace el 30 % a quien la forma normal no tocaba».
   - Bien: «reciben como Daño de Viento un 30 % del daño que esa habilidad les habría infligido».
3. **Si solo mejora algo que ya existe, se dice.** «Los ataques y habilidades del portador que ya
   pueden causar Quemadura suman un 10 % a su probabilidad base de causarla.» Así queda claro que
   el set no da Quemadura por sí solo.
4. **Si se suma o se multiplica, se nota en la frase.**
   - Se suma: «suman un 10 % a su probabilidad base» (un 30 % pasa a ser un 40 %).
   - Se multiplica: «aumenta en un 25 %» (25 de daño pasa a ser 31).
   - Daño extra sobre otra base: «infligen un daño adicional equivalente al 5 % del daño del golpe
     que los causó».
5. **Los límites van en su propia frase, al final:** «Hasta un máximo de 5 acumulaciones.»,
   «Este efecto solo se puede activar 1 vez por combate.», «Se activa 1 vez por habilidad.»,
   «Este efecto no se puede acumular.», «Este efecto se puede volver a activar tras 4 turnos del
   portador.»
6. **Duraciones siempre con «durante»:** «durante 2 turnos».
7. **Lo que no hace, si se puede pensar que sí:** «No funciona con la magia.», «El daño con el
   tiempo no cuenta.»
8. **Los bonus fijos, en formato corto:** «Vida +12 %», «Defensa +12 %». Los efectos, en frases
   completas.
9. **Nada de jerga de desarrollo ni palabras de pasillo.** Si no lo diría un manual de juego,
   fuera (ver el glosario).
10. **Los números salen de los datos, nunca escritos a mano** (`num_txt`, `_pct`, `resumen()`).
    En la `descripcion` de sabor no va ninguna cifra.
11. **Hay que comprobarlo en el código antes de escribirlo.** Un texto bonito que miente es peor
    que uno feo.

## 2. Números

- Coma decimal y sin «,0» que sobre: «12 %», «4,5 %». Nunca «12.0 %».
- Espacio antes del %: «25 %».
- «1 turno» / «2 turnos»: el plural lo pone el código (`_turnos`).

## 3. Glosario

| No escribir | Escribir |
|---|---|
| encajar un golpe | recibir un ataque / recibir un golpe |
| pegar (en un efecto) | infligir |
| te hace / haces (en un efecto) | el portador recibe / el portador inflige |
| carga (de un estado) | acumulación |
| DoT, daño por turno | daño con el tiempo |
| prob. | probabilidad base (si la resisten la eficacia y la resistencia) / probabilidad (si no) |
| prender / abrir (un estado) | causar (Quemadura, Sangrado…) |
| dejar (un estado) | dejar + el estado («deja Electrizado») o «queda» + el estado |
| la barra | la barra de turno |
| motion value, mv, proc, stack, buff, debuff | se explica con palabras |

Los elementos, con mayúscula cuando son tipo de daño: Daño de Fuego, Daño de Viento, Daño de Rayo,
Daño de Luz, Daño de Oscuridad. Los estados, con la mayúscula de su nombre: Quemadura, Sangrado,
Veneno, Electrizado, Mojado, Pegajoso, Aturdido, Lento, Congelación, Ceguera.

**Distancias (decidido 06/11):** nada de «px». Se dicen en palabras, comparando, pero sin frases
forzadas del tipo «el doble de lejos que el gusano». Primer caso, los cebos: «Atracción: Corta /
Media / Larga». Pendiente de aplicar igual a Hilo conductor, Filo de aire y Campo magnético.

## 2b. Pociones y objetos

- **Efecto:** «Restaura 90 de vida + 12 % de la vida máxima de quien la bebe (114 para Dasui).»
  El número de ejemplo es el del líder.
- **Se reparte en:** «3 turnos en combate · 6 s fuera de combate». Solo en lo que se reparte.
- **Bonus de platos y estados:** formato corto, «Agilidad +12 % · Esquiva +6 %».

## 4. Ejemplos de referencia

**Fuentes** (los textos oficiales en español, en JSON):
- Honkai: Star Rail: `https://raw.githubusercontent.com/Mar-7th/StarRailRes/master/index_new/es/<f>.json`
  con `<f>` = `character_skills`, `relic_sets`, `light_cones`.
- Genshin Impact: `https://raw.githubusercontent.com/theBowja/genshin-db/main/src/data/Spanish/artifacts/<a>.json`.

Cómo nombra HSR a quien recibe una habilidad de apoyo (contado en `character_skills`, 06/11): «un
aliado» (65 veces), «todos los aliados» (82), y después «ese aliado»; «aliado seleccionado» sale una
vez. Ejemplos: «Otorga una Gracia a un aliado y aumenta el ATQ de ese aliado en un 25 %» (Tingyun),
«Cura a un aliado con una cantidad de PV equivalente al 10 % de los PV máx. de Bailu + 200» (Bailu),
«Otorga a un aliado un escudo… durante 3 turnos» (Siete de Marzo).

**Honkai: Star Rail**, set «Prisionero aislado»: «Por cada estado de Daño con el tiempo que tenga el
objetivo, el portador ignora un 6 % de su DEF cuando le inflige daño, hasta un máximo de 3 estados
de Daño con el tiempo.»

**Honkai: Star Rail**, Hook: «Inflige un 100 % del ATQ de Hook como Daño de Fuego a un enemigo.
Además, tiene un 100 % de probabilidad base de afectar con Quemadura al enemigo atacado durante
2 turnos.»

**Genshin Impact**, «Bruja Carmesí en Llamas» (4 piezas): «Aumenta el daño causado por Sobrecarga,
Quemadura y Crepitar en un 40 %… Puede acumularse hasta un máximo de 3 veces.»

**Nuestro**, Ignición, antes: «+10 % de prender Quemadura, y tus Quemaduras pegan un 25 % más.»
Después: «Los ataques y habilidades del portador que ya pueden causar Quemadura suman un 10 % a su
probabilidad base de causarla. El daño de las Quemaduras que causa el portador aumenta en un 25 %.»

## 5. Estado del pase

| Sección | Estado |
|---|---|
| Sets de runas (`Runas.efecto_txt`) | Hecho 06/11 |
| Magias (fichas, línea compacta, Filos y Mantos con su afinidad; sabor y tildes) | Hecho 06/11 |
| Habilidades | Pendiente |
| Armas y armaduras (fichas) | Pendiente |
| Objetos y consumibles (fichas, pociones, platos, unturas, cebos; sabor de pociones) | Hecho 06/11 |
| Estados (ver también `textos_estados_y_cocina.md`) | Pendiente |
| Menús y avisos | Pendiente |
| Log de combate (frases; números con coma y sin ceros: `CombatPantalla._n`) | Hecho 06/11 |
