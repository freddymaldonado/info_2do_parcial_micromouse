# Segundo Parcial — Micromouse (Infografía, I/2026)

**Modalidad:** proyecto para casa, individual. **Plazo y fecha de entrega:** se publican en Moodle.
**Motor:** Godot 4.6. **Entrega:** URL de tu repositorio (ver *Entrega* al final).

> Esta es la **pista B** del parcial. Hay varias pistas (Match-3, Micromouse,
> Planta SCADA); eliges **una sola**. Todas valen lo mismo y se califican con la
> misma estructura. Esta pista premia sobre todo el **trabajo algorítmico**
> (exploración, flood-fill, rutas); si prefieres UI y visualización, mira la
> pista SCADA.

---

## 1. Contexto

[Micromouse](https://en.wikipedia.org/wiki/Micromouse) es una competencia real
de robótica que existe desde los años 70: un robot-ratón se coloca en la esquina
de un laberinto de 16×16 celdas **que nunca ha visto**, lo explora sensando las
paredes a su alrededor, y luego corre hacia el centro por la mejor ruta que
descubrió. Tu trabajo es el cerebro de ese ratón — y las herramientas visuales
para verlo pensar y depurarlo.

Recibes un simulador **funcional pero incompleto**. El núcleo ya está resuelto:
el laberinto se carga desde archivos de texto, se dibuja completo (la "vista de
dios"), y el ratón se mueve celda a celda con animación, sensa las paredes de su
celda y choca si intenta atravesar una. Hay un cerebro de demostración
(seguidor de pared izquierda) que muestra cómo usar la API: ábrelo en Godot,
presiona Play y míralo recorrer el laberinto de entrenamiento.

Lo que **no** está hecho es lo que convierte ese núcleo en un micromouse de
verdad: el algoritmo de exploración, el mapa que el ratón construye en su
memoria, la corrida rápida final y la telemetría para depurar todo eso. Ese es
tu trabajo.

> **Regla de oro (léela dos veces).** Tu cerebro solo puede usar la **API
> pública del ratón**: sensar las paredes de su celda actual y moverse. Leer el
> laberinto real (`game.laberinto`, `raton._laberinto`) desde tu cerebro es
> hacer trampa — el ratón de verdad no ve a través de las paredes — y **anula
> las mecánicas M1 y M3**. La revisión incluye leer tu código.

> **Aviso de honestidad académica.** Flood-fill para micromouse está muy
> documentado (papers, blogs, videos de la competencia). Puedes consultar
> recursos — y **debes citarlos** en tu README — pero el código es tuyo: la
> entrega se evalúa **corriendo tu ratón en laberintos que no conoces** y
> revisando tu historial de commits. El plagio entre compañeros y el "volcado
> único" de todo el código en un solo commit se penalizan.

---

## 2. Qué se te entrega

- `scripts/maze.gd` — el laberinto: carga de archivos `.maz`, paredes, inicio y
  metas. Incluye `Laberinto.vacio()` para que construyas tu propio mapa
  descubierto. **Resuelto, no lo modifiques.**
- `scripts/raton.gd` — el ratón: sensado (`pared_frente/izquierda/derecha`),
  movimiento (`avanzar`, `girar_*`), animación y señales (`paso_terminado`,
  `choque`). **Resuelto.**
- `scripts/vista_laberinto.gd` — dibuja un laberinto (rejilla, paredes, inicio,
  metas). Se usa para la vista de dios y está lista para que la reutilices en
  la vista "mapa del ratón" (M2). **Resuelto.**
- `scripts/cerebro_wall_follower.gd` — cerebro de demostración. Llega a la meta
  en el laberinto 01; en los 16×16 con ciclos puede dar vueltas para siempre
  (ese es el punto). **Resuelto.**
- `scripts/cerebro_estudiante.gd` — **tu cerebro**, con el contrato y el plan
  sugerido en comentarios. Actívalo con la casilla *Usar Cerebro Estudiante*
  del nodo `Game`.
- `scripts/game.gd` — el controlador: tick del cerebro, detección de meta, y
  los botones del panel ya conectados con cuerpos vacíos. Tiene marcadores
  `# TODO (PARCIAL · ...)` en cada hueco.
- `scripts/hud.gd` — etiquetas de telemetría, creadas pero sin conectar.
- `mazes/` — tres laberintos: `01_entrenamiento.maz` (8×8, resoluble por
  wall-follower), `02_clasico.maz` y `03_clasico.maz` (16×16 estilo
  competencia). El formato es texto plano: ábrelos, son legibles.
- `assets/sounds/` — `paso.wav`, `choque.wav`, `meta.wav`.

**Cómo ejecutarlo:** abre esta carpeta en el editor de Godot y presiona `F5`.
La escena principal es `scenes/game.tscn`. Cambia de laberinto en el Inspector
del nodo `Game` (propiedad *Archivo Laberinto*).

---

## 3. Requisitos base — "termina el simulador" (45 pts)

| # | Requisito | Pts | Criterio de aceptación |
|---|---|---:|---|
| B1 | Telemetría en vivo | 10 | el HUD muestra pasos, celdas visitadas y cronómetro, actualizados en cada tick |
| B2 | Controles de ejecución | 8 | pausa/reanudar, paso a paso con la corrida pausada, ciclo de velocidad y reinicio funcionan |
| B3 | Máquina de estados + pantalla final | 15 | fases explícitas (EXPLORANDO → … → FIN) visibles en el HUD; al terminar hay una pantalla con el resultado y se puede reiniciar |
| B4 | Efectos de sonido | 7 | tic de paso, sonido de choque y fanfarria de meta, usando los wav provistos |
| B5 | Corre limpio | 5 | sin errores en consola; el núcleo (cargar, sensar, moverse) sigue funcionando |

---

## 4. Mecánicas obligatorias — el micromouse de verdad (45 pts)

### M1. Exploración con flood-fill — 15 pts
- Tu cerebro mantiene su **propio mapa** (`Laberinto.vacio()` + `poner_pared`)
  alimentado solo por el sensado, y explora guiado por **flood-fill**: distancia
  de cada celda a la meta, recalculada al descubrir paredes, moviéndose siempre
  hacia la vecina con menor distancia.
- *Aceptación:* el ratón llega al centro de `02_clasico` y `03_clasico` (donde
  el wall-follower no llega) **y de los laberintos ocultos de la revisión**;
  el cerebro no toca el laberinto real.

### M2. Mapa dual — 10 pts
- La vista derecha ("mapa del ratón") dibuja **lo que tu cerebro sabe**: paredes
  descubiertas y celdas visitadas vs. no visitadas, actualizándose en vivo.
- *Aceptación:* durante la exploración se ve crecer el conocimiento del ratón;
  las paredes que aún no sensó **no aparecen**; visitadas y no visitadas se
  distinguen a simple vista.

### M3. Speed run — 14 pts
- Tras explorar, el ratón **vuelve al inicio** y ejecuta la **corrida rápida**:
  la mejor ruta sobre el mapa descubierto (flood-fill solo por celdas
  conocidas), sin sensar.
- Dibuja **ambas rutas** (exploración y speed run) superpuestas en una vista, y
  muestra la comparación de pasos en la pantalla final.
- *Aceptación:* la ruta del speed run es claramente más corta que la de
  exploración y el ratón la ejecuta sin chocar.

### M4. Laberintos data-driven + récords — 6 pts
- Un **selector de laberintos** que lista los archivos de `mazes/` (agregar un
  `.maz` nuevo no debe requerir tocar código).
- **Persistencia**: guarda el mejor resultado (pasos del speed run) por
  laberinto en `user://` y muéstralo en el HUD.
- *Aceptación:* copio un laberinto nuevo a `mazes/`, aparece en el selector, lo
  corro, cierro y reabro el juego y el récord sigue ahí.

---

## 5. Bonus (tope 10 pts)

Suma solo si los requisitos base y obligatorios están sólidos. Ejemplos:
- **Heat-map de visitas** (celdas más visitadas más calientes).
- **Movimiento diagonal** en el speed run (como los micromouse reales).
- **Editor de laberintos** en el juego (clic en una pared para ponerla/quitarla,
  guardar como `.maz`).
- Comparación contra la **ruta óptima real** (flood-fill sobre la vista de
  dios — solo para mostrar, no para guiar al ratón).
- **Partículas / juice**: estela del ratón, sacudida al chocar, celebración en
  la meta.

---

## 6. Evaluación

**Total:** 90 pts de requisitos + 10 pts de bonus = **100**.

| Bloque | Pts |
|---|---:|
| Base ("termina el simulador") | 45 |
| Mecánicas obligatorias (M1–M4) | 45 |
| Bonus | 10 (tope) |

**Regla de tope:** si tu entrega **no implementa ninguna** de las cuatro
mecánicas obligatorias, tu nota **no supera 50/100**, sin importar cuán pulido
esté lo demás.

**La revisión corre tu ratón en 2–3 laberintos ocultos** (formato `.maz`
estándar, 16×16, meta central). Si tu exploración solo funciona en los
laberintos incluidos, M1 y M3 no cuentan.

**Calidad e integridad** (pueden bajar la nota): historial de commits con
"volcado único" de último momento, similitud alta con la entrega de otro
compañero, o cerebro que lee el laberinto real. Cita en tu README todo recurso
externo que hayas usado.

---

## 7. Entrega

1. Haz un **fork** (o copia a un repo propio) de este proyecto base.
2. Trabaja con **commits frecuentes y descriptivos**: el historial cuenta y se revisa.
3. En el **README** de tu repo, escribe: cómo correr el simulador, qué mecánicas
   implementaste, y la lista de recursos externos consultados (con enlaces).
4. Entrega la **URL de tu repositorio** por Moodle antes de la fecha límite.

Asegúrate de que el proyecto **abra y corra en Godot 4.6 sin errores** en una
máquina limpia (no subas la carpeta `.godot/`).
