# Micromouse — Segundo Parcial (Infografía, I/2026)

Pista B: el cerebro de un robot-ratón que explora un laberinto que no conoce con
**flood-fill**, construye su propio mapa y ejecuta una **corrida rápida** (speed
run) por la mejor ruta que descubrió.

Fork del proyecto base
[tabris2015/info_2do_parcial_micromouse](https://github.com/tabris2015/info_2do_parcial_micromouse).
El enunciado completo está en [enunciado.md](enunciado.md).

## Cómo correr el simulador

1. Abre esta carpeta en **Godot 4.6**.
2. Presiona `F5` (la escena principal es `scenes/game.tscn`).
3. El ratón arranca con el cerebro estudiante activado (casilla *Usar Cerebro
   Estudiante* del nodo `Game`). Para comparar con la demo, desactívala y se usa
   el seguidor de pared izquierda.
4. Cambia de laberinto con el **selector** de la esquina superior derecha (lista
   automáticamente los `.maz` de la carpeta `mazes/`).

Controles del panel: **Pausa/Reanudar**, **Paso** (un tick con la corrida
pausada, para depurar), **Vel x1/x2/x4** y **Reiniciar**.

## Qué implementé

### Requisitos base (B1–B5)
- **B1 — Telemetría en vivo:** el HUD muestra pasos, celdas visitadas, fase y un
  cronómetro, actualizados en cada tick mediante señales (`scripts/hud.gd`).
- **B2 — Controles de ejecución:** pausa/reanudar, paso a paso, ciclo de
  velocidad (cambia `paso_timer.wait_time` y `raton.duracion_paso`) y reinicio.
- **B3 — Máquina de estados + pantalla final:** fases explícitas
  `EXPLORANDO → VOLVIENDO → SPEED RUN → FIN` visibles en el HUD; al terminar
  aparece una pantalla con el resultado y un botón para reiniciar.
- **B4 — Sonidos:** tic de paso, choque y fanfarria de meta con los `.wav`
  provistos.
- **B5 — Corre limpio:** no se modificó el núcleo resuelto (`maze.gd`,
  `raton.gd`, `vista_laberinto.gd`, `cerebro_wall_follower.gd`).

### Mecánicas obligatorias (M1–M4)
- **M1 — Exploración con flood-fill:** el cerebro mantiene su propio mapa
  (`Laberinto.vacio()` + `poner_pared` solo con lo que sensa) y, en cada paso,
  recalcula la distancia de cada celda a la meta (flood-fill) y avanza hacia la
  vecina accesible con menor distancia. Nunca lee el laberinto real
  (`scripts/cerebro_estudiante.gd`).
- **M2 — Mapa dual:** la vista derecha (`scripts/vista_mapa.gd`, subclase de
  `VistaLaberinto`) dibuja en vivo lo que el ratón sabe: celdas visitadas vs. no
  visitadas y solo las paredes ya sensadas.
- **M3 — Speed run:** tras explorar, el ratón vuelve al inicio y ejecuta la
  mejor ruta sobre el mapa descubierto (flood-fill solo por celdas conocidas,
  sin sensar). Ambas rutas (exploración y speed run) se dibujan superpuestas y la
  pantalla final compara los pasos.
- **M4 — Laberintos data-driven + récords:** el selector lista los `.maz` sin
  tocar código y el mejor resultado (pasos del speed run) por laberinto se guarda
  en `user://records.json` y se muestra en el HUD.

### Bonus (juice)
- **Heat-map de visitas:** botón *Heat-map* que colorea el mapa del ratón por
  cuántas veces pisó cada celda (azul frío → rojo caliente).
- **Estela del ratón:** rastro que se desvanece detrás del ratón en la vista de
  dios (`scripts/estela.gd`).
- **Sacudida al chocar:** la pantalla tiembla cuando el ratón choca con una pared.
- **Celebración en la meta:** ráfaga de partículas doradas al terminar la corrida.

## Recursos externos consultados

El código es propio; consulté estos recursos para el concepto del algoritmo:

- Micromouse — Wikipedia: <https://en.wikipedia.org/wiki/Micromouse>
- Flood fill (algoritmo de inundación) — Wikipedia:
  <https://en.wikipedia.org/wiki/Flood_fill>
- Documentación de Godot 4 (Control, AudioStreamPlayer, FileAccess/DirAccess):
  <https://docs.godotengine.org/en/stable/>

## Notas de implementación

Todo lo que agregué sobre el andamiaje está comentado en el código. Los archivos
nuevos/editados son: `cerebro_estudiante.gd`, `game.gd`, `hud.gd` y el nuevo
`vista_mapa.gd` (más el cableado de `scenes/game.tscn`).
