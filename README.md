# README — FEM: Placa cuadrada con 4 barrenos (Notas técnicas personales)

Última actualización: 2026-04-05
Autor: Tú (repositorio local: fem_tesina)

Este README es una guía técnica exhaustiva diseñada para que tú, como autor/ingeniero, recuperes rápidamente detalles estructurales, hipótesis, decisiones de implementación y pasos prácticos para reproducir, modificar y depurar el proyecto MATLAB.

---

## Propósito

Proveer una implementación MATLAB (script + GUI) para analizar una placa cuadrada de acero con 4 agujeros (barrenos) sometida a una presión uniforme en la cara superior. La geometría STL se genera programáticamente para evitar problemas con las operaciones 3D de `fegeometry/subtract`.

Archivos principales:
- `fem.m` (script original — análisis y visualización)
- `app_fem.m` (interfaz `uifigure` — controlador para ejecución interactiva)
- `generarPlacaSTL` (función local incluida en ambos archivos para escribir un STL watertight)

---

## Requisitos y entorno

- MATLAB (preferible R2022b o posterior). El código fue desarrollado con referencia a R2025b.
- PDE Toolbox (obligatorio para `createpde`, `importGeometry`, `generateMesh`, `pdeplot3D`, `solve`).
- `stlwrite` usado en `generarPlacaSTL`: si tu versión de MATLAB no incluye `stlwrite` nativa, instala la versión fiable desde File Exchange o reemplaza la llamada por una alternativa (`writeSTL`, `exportGeometry`, etc.).
- Funciones base usadas: `polyshape`, `delaunayTriangulation`, `incenter`, `isinterior`, `findNodes`.

Recomendación de hardware: mallas finas incrementan RAM y tiempo. Para malla con `Hmax = 0.008 m` se observan tiempos razonables en orden de segundos—minutos dependiendo del equipo.

---

## Parámetros (valores por defecto y unidades)

Todos los valores usan SI (m, Pa).

- `ancho` — lado de la placa (m). Default: `0.20` m.
- `esp` — espesor (m). Default: `0.015` m.
- `r` — radio de los barrenos (m). Default: `(0.75 * 0.0254)/2` (0.75 in → m / 2).
- `d` — distancia del centro a cada barreno (m). Default: `0.07` m.
- `nCPts` — puntos por circunferencia para aproximar el cilindro en el STL. Default: `64` (≥32 recomendados).
- `presion` — presión aplicada en la cara superior (Pa). Default: `50e6` (50 MPa en los ejemplos).
- `Hmax` — tamaño máximo del elemento de la malla (m). Default: `0.008` m.

Nota: `nCPts` balancea precisión de la pared cilíndrica (barreno) y tamaño del STL. Reducir `nCPts` acelera creación y reduce tamaño, pero puede producir geometría menos suave.

---

## Flujo de ejecución (lógica del programa)

1. Generar la sección transversal 2D mediante `polyshape`: rectángulo menos círculos (barrenos).
   - Se usa `subtract(polyshape, hole)` repetidamente (esto es 2D — sin bug conocido).
2. Triangulación 2D:
   - Se extraen los vértices de `polyshape` y se construye `delaunayTriangulation(pts)`.
   - Se calcula el `incenter` de cada triángulo y se filtra por `isinterior(cs, Cx, Cy)` para descartar triángulos en los agujeros.
   - Razonamiento: `triangulate(cs)` puede chocar con CV Toolbox; esta aproximación es robusta y no requiere toolboxes adicionales.
3. Extrusión a 3D y ensamblado STL:
   - Se generan: cara inferior (z=0), cara superior (z=esp), 4 paredes rectangulares externas y paredes cilíndricas alrededor de cada barreno.
   - Atención al ordenamiento (winding) de vértices para garantizar normales exteriores correctas.
   - Se escribe un STL binario watertight con `stlwrite(triangulation(F,V), filename)`.
4. Importar STL a `createpde` mediante `importGeometry(model, stlPath)`.
5. Generar malla con `generateMesh(model, 'Hmax', Hmax, 'GeometricOrder', 'linear')`.
6. Identificación dinámica de caras (no predecible tras `importGeometry`):
   - Para cada `Face` se buscan nodos (`findNodes(...,'region','Face', fid)`) y se inspecciona la componente Z.
   - Si `max(zc) < tol` → cara base (Z≈0). Si `min(zc) > (esp - tol)` → cara tope (Z≈esp).
   - `tol` por defecto: `esp * 0.05` (5% del espesor). Ajustar si la geometría cambia.
7. Asignar propiedades del material: `E = 210e9` (Pa), `nu = 0.3`.
8. Condiciones de frontera: base empotrada (ux=uy=uz=0), tope con `Pressure = presion`.
9. Resolver con `solve(model)` (estático, `structural`).
10. Postprocesado: Von Mises y desplazamientos; figuras con `pdeplot3D`.

---

## Detalles de ingeniería estructural (hipótesis y conversiones)

- Material: acero isotrópico lineal-elástico, E = 210 GPa, ν = 0.3.
- Carga: presión uniforme normal sobre la cara superior. Si necesitas carga puntual o distribución diferente, sustituir `structuralBoundaryLoad`.
- Unidades: todo en metros y Pascales. Para convertir pulgadas a metros: `1 in = 0.0254 m`.
- Interpretación de resultados:
  - `res.VonMisesStress` devuelto en Pa. Convertir a MPa dividiendo por `1e6`.
  - `res.Displacement` en metros; multiplicar por `1e3` para obtener mm.
- Escalado de deformación en visualización: `sf = (ancho * 0.05) / max(uMag)` escala la deformación a ~5% del ancho para visualización. No afecta resultados numéricos.

---

## Notas de implementación y decisiones importantes

- Motivación para la ruta STL: existe un bug reportado (observado en entornos recientes) relacionado con `fegeometry/subtract` donde la conversión DiscreteGeometry→fegeometry produce geometrías internas que fallan en restas posteriores. Solución pragmática: construir STL 3D manualmente a partir de una triangulación 2D y luego importar el STL.

- Triangulación 2D:
  - No usar `cs.triangulate()` si aparece ``Unrecognized method``.
  - `delaunayTriangulation` + `isinterior` es robusto y evita colisiones con CV Toolbox.

- Orden de caras y normales:
  - Se presta especial atención al `winding` de los triángulos para que las normales apunten hacia el exterior del sólido. Esto evita caras invertidas que pueden llevar a importGeometry a crear regiones inconsistentes.

- Identificación de caras tras `importGeometry`:
  - No se puede asumir la numeración de caras; por eso se usa la estrategia por coordenadas Z de los nodos.
  - Si la STL no está perfectamente plana en Z=0 o Z=esp (por tolerancias numéricas), aumenta `tolZ`.

- Manejo de errores:
  - Verificar que `stlwrite` creó un archivo legible.
  - Si `importGeometry` falla, inspeccionar STL con `stlread` o software externo (Meshlab, Paraview).

---

## Debugging y errores comunes

1. Error: "Unable to subtract the geometry" al usar `subtract` 3D.
   - Causa: conversión automática DiscreteGeometry→fegeometry con geometría interna corrupta.
   - Solución: usar el flujo STL tal como está en este proyecto.

2. `uitextarea.Value` errores (al usar `app_fem`):
   - `Value` debe ser un arreglo N×1 de celdas con strings o `string` arrays. Evita asignar `{}` vacío: usar `{''}` para limpiar.

3. `stlwrite` no encontrado:
   - Instalar desde File Exchange o reemplazar por la función nativa si existe.

4. Caras no detectadas (cara base o tope):
   - Aumentar `tolZ` (p.ej. `tolZ = esp*0.1`) o inspeccionar `model.Mesh.Nodes(3,:)` para entender la dispersión en Z.

5. Triángulos degenerados en la triangulación 2D:
   - Aumentar `nCPts` para una mejor aproximación de circunferencias, o limpiar vértices repetidos.

---

## Reproducibilidad y configuración de salidas

- El STL se escribe por defecto en `stlPath = [tempname '.stl']` para evitar colisiones entre ejecuciones. Si deseas comparar ejecuciones, guarda en una ruta determinística:

```matlab
stlPath = fullfile(pwd, sprintf('placa_R%.3f_H%.4f.stl', r, Hmax));
```

- Para guardar resultados numéricos (solución) al final del análisis:

```matlab
save(fullfile(pwd, 'resultados.mat'), 'model', 'res', 'vm', 'uMag');
```

- Para reproducir un experimento sin GUI usar:

```bash
matlab -batch "run('fem.m')"
```

o convertir `fem.m` a una función `fem(params)` y llamarla via `matlab -batch "fem(params)"`.

---

## Performance y límites prácticos

- Reducción de `Hmax` → mayor número de nodos y elementos → memoria y tiempo aumentan (potencialmente cuadrático/cúbico según solver y estructura de matriz).
- Si la malla excede la memoria, reducir `nCPts` (menos triángulos en la pared del barreno) y aumentar `Hmax` localmente.
- Si necesitas cálculos de producción, considera:
  - Guardar y reutilizar la malla (`model.Mesh`) para cambios pequeños en las cargas.
  - Usar `Adaptive Mesh Refinement` si está disponible en tu versión (requiere flujo adicional).
  - Ejecutar en un nodo con mayor RAM o usar máquinas con MATLAB paralelo si el solver lo soporta.

---

## Extensiones recomendadas (ideas futuras)

- Implementar modo "headless": función `run_fem(params)` que acepta estructura de parámetros y exporta resultados sin figuras.
- Guardado automático de: STL, `resultados.mat`, capturas de pantalla PDF/PNG de figuras y un `report.json` con metadatos (parámetros usados, tiempo de ejecución, hashes de código).
- Tests unitarios básicos: validar que el volumen del STL coincide con la resta analítica (volumen placa − volumen 4 cilindros aprox.).
- Refinamiento local con densificación de malla alrededor de los bordes del barreno.
- Comparación con soluciones analíticas / fórmulas de chapas perforadas para sanity checks.

---

## Comandos útiles (rápidos)

Abrir la GUI:

```matlab
app_fem()
```

Ejecutar script original:

```matlab
run('fem.m')
% o simplemente
fem
```

Ejecutar en modo batch (sin desktop UI) desde terminal:

```bash
matlab -batch "run('fem.m')"
```

Guardar resultados y STL con nombre determinístico:

```matlab
stlPath = fullfile(pwd, sprintf('placa_R%.3f_d%.3f_H%.4f.stl', r, d, Hmax));
stlwrite(triangulation(F,V), stlPath);
save('resultados.mat','res','model');
```

---

## Registro de cambios (changelog)

- 2026-04-05 — Creación inicial del README técnico. Se añadió `app_fem.m` (GUI moderna), se corrigieron colores de texto a rojo en visualizaciones y se documentó el workaround para `fegeometry/subtract` (generación STL).

---

## Notas finales y consejos rápidos

- Si más adelante cambias la topología (p. ej. más agujeros o formas no-circulares), ajusta la generación 2D y revisa `isinterior` para filtrar triángulos.
- Mantén copias de los STL generados para comparar resultados si decides ajustar parámetros de malla.
- Si observas diferencias importantes entre ejecuciones idénticas, compara la versión de MATLAB y los toolboxes (pueden cambiar implementaciones internas del solver).

---

Archivo(s) principales en este repo:
- [fem.m](fem.m)
- [app_fem.m](app_fem.m)

Si quieres, puedo:
- Añadir un modo "headless" y un script `run_example.m` que ejecute un caso estándar y guarde resultados automáticamente.
- Incluir un pequeño test que calcule el área efectiva de la sección y compare con valor teórico.

