%% ================================================================
%%  ANÁLISIS FEM - PLACA DE ACERO CON 4 BARRENOS  (v2 — R2025b)
%%  Ubuntu 24.04 / MATLAB R2025b / PDE Toolbox
%%
%%  SOLUCIÓN AL BUG fegeometry/subtract:
%%   La conversión automática DiscreteGeometry → fegeometry que
%%   ocurre en la 1ª resta produce una geometría interna que falla
%%   en restas posteriores ("Unable to subtract the geometry").
%%
%%   ESTRATEGIA: No se usa ningún subtract 3D.
%%   Se construye la geometría como STL usando:
%%     1) polyshape 2D   → sección transversal (rectángulo − 4 círculos)
%%     2) triangulate()  → malla 2D de la sección
%%     3) Extrusión manual de paredes y cilindros
%%     4) stlwrite()     → archivo STL binario watertight
%%     5) importGeometry → modelo PDE con caras identificadas
%% ================================================================
clear; clc; close all;

%% ----------------------------------------------------------------
%% 1. PARÁMETROS
%% ----------------------------------------------------------------
ancho  = 0.20;               % Lado de la placa [m]
esp    = 0.015;              % Espesor          [m]
r      = (0.75 * 0.0254)/2;  % Radio de barreno [m]  (0.75 pulg)
d      = 0.07;               % Distancia del centro al barreno [m]
nCPts  = 64;                 % Nº de puntos por circunferencia en STL

% Posiciones (x,y) de los 4 barrenos
pos = [ d,  d;   % Cuadrante I
       -d,  d;   % Cuadrante II
        d, -d;   % Cuadrante IV
       -d, -d];  % Cuadrante III

fprintf('========================================\n');
fprintf(' ANÁLISIS FEM — PLACA CON BARRENOS\n');
fprintf('========================================\n');
fprintf('Placa    : %.0f × %.0f × %.0f mm\n', ancho*1e3, ancho*1e3, esp*1e3);
fprintf('Barrenos : R = %.4f m  (%.4f pulg)\n', r, r/0.0254);
fprintf('Posición : ±%.0f mm del centro\n\n', d*1e3);

%% ----------------------------------------------------------------
%% 2. MODELO ESTRUCTURAL
%% ----------------------------------------------------------------
model = createpde('structural', 'static-solid');

%% ----------------------------------------------------------------
%% 3. GEOMETRÍA VÍA STL
%%    Se genera el STL en tempdir y se importa.
%%    Evita completamente DiscreteGeometry/fegeometry subtract.
%% ----------------------------------------------------------------
stlPath = fullfile(tempdir, 'placa_barrenos_fem.stl');
fprintf('Generando STL...\n');
generarPlacaSTL(stlPath, ancho, esp, r, pos, nCPts);

fprintf('Importando geometría...\n');
importGeometry(model, stlPath);
geom = model.Geometry;
fprintf('OK — Caras: %d | Aristas: %d | Vértices: %d\n\n', ...
        geom.NumFaces, geom.NumEdges, geom.NumVertices);

%% ----------------------------------------------------------------
%% 4. PROPIEDADES DEL MATERIAL (Acero estructural)
%% ----------------------------------------------------------------
structuralProperties(model, 'YoungsModulus', 210e9, 'PoissonsRatio', 0.3);

%% ----------------------------------------------------------------
%% 5. MALLADO FINO
%%    GeometricOrder = 'linear' → tetraedros de 4 nodos (T4)
%%    Cambiar a 'quadratic' (T10) para mayor precisión (más RAM).
%% ----------------------------------------------------------------
fprintf('Generando malla  (Hmax = 0.008 m)...\n');
generateMesh(model, 'Hmax', 0.008, 'GeometricOrder', 'linear');

nNod = size(model.Mesh.Nodes,    2);
nEle = size(model.Mesh.Elements, 2);
fprintf('OK — Nodos: %d | Elementos: %d\n\n', nNod, nEle);

%% ----------------------------------------------------------------
%% 6. IDENTIFICACIÓN DINÁMICA DE CARAS
%%    Tras importGeometry la numeración de caras NO es predecible.
%%    Se identifica dinámicamente qué cara está en Z=0 y cuál en Z=esp.
%% ----------------------------------------------------------------
fprintf('Identificando caras de frontera...\n');

tol      = esp * 0.05;   % Tolerancia: ±5% del espesor
nFaces   = geom.NumFaces;
caraBase = [];            % Face IDs  ⟶  Z ≈ 0   (base fija)
caraTope = [];            % Face IDs  ⟶  Z ≈ esp  (presión)

for fid = 1:nFaces
    nodeIDs = findNodes(model.Mesh, 'region', 'Face', fid);
    if isempty(nodeIDs), continue; end
    zc = model.Mesh.Nodes(3, nodeIDs);
    if max(zc) < tol
        caraBase = [caraBase, fid]; %#ok<AGROW>
    elseif min(zc) > (esp - tol)
        caraTope = [caraTope, fid]; %#ok<AGROW>
    end
end

fprintf('  Cara(s) base  [Z ≈ 0    ]: Faces %s\n', mat2str(caraBase));
fprintf('  Cara(s) tope  [Z ≈ %.3f]: Faces %s\n\n', esp, mat2str(caraTope));

% Guardia: abortar si no se encontraron las caras clave
if isempty(caraBase)
    error('No se encontró cara en Z=0. Verificar geometría STL o aumentar tol.');
end
if isempty(caraTope)
    error('No se encontró cara en Z=%.4f. Verificar geometría STL o aumentar tol.', esp);
end

%% ----------------------------------------------------------------
%% 7. CONDICIONES DE FRONTERA
%% ----------------------------------------------------------------
% Base Z=0 → empotramiento completo (ux=uy=uz=0)
structuralBC(model, 'Face', caraBase, 'Constraint', 'fixed');

% Tope Z=esp → presión de compresión de 50 MPa
structuralBoundaryLoad(model, 'Face', caraTope, 'Pressure', 50e6);

fprintf('Condiciones de frontera:\n');
fprintf('  Base  → Empotrado  (u = 0)\n');
fprintf('  Tope  → Presión = 50 MPa\n\n');

%% ----------------------------------------------------------------
%% 8. RESOLVER
%% ----------------------------------------------------------------
fprintf('Resolviendo sistema FEM...\n');
tic;
res = solve(model);
tSol = toc;

vm     = res.VonMisesStress;
uMag   = sqrt(res.Displacement.x.^2 + ...
              res.Displacement.y.^2 + ...
              res.Displacement.z.^2);

fprintf('Tiempo de solución : %.1f s\n', tSol);
fprintf('Von Mises  — Mín  : %8.2f MPa\n', min(vm)/1e6);
fprintf('           — Máx  : %8.2f MPa\n', max(vm)/1e6);
fprintf('           — Prom : %8.2f MPa\n', mean(vm)/1e6);
fprintf('Desp. máximo       : %.4f mm\n\n', max(uMag)*1e3);

%% ----------------------------------------------------------------
%% 9. VISUALIZACIÓN — Vista isométrica con deformación
%% ----------------------------------------------------------------

% Factor de escala: deformación visible ≈ 5% del lado de la placa
sf = (ancho * 0.05) / max(uMag);

figure('Color','w', 'Position',[80, 80, 1100, 750], ...
       'Name','Von Mises — Vista 3D');

pdeplot3D(model, ...
    'ColorMapData',           vm, ...
    'Deformation',            res.Displacement, ...
    'DeformationScaleFactor', sf);

colormap('jet');
cb = colorbar;
cb.Label.String   = 'Esfuerzo de Von Mises [Pa]';
cb.Label.FontSize = 11;

title({ ...
    'Esfuerzos de Von Mises — Placa de Acero con 4 Barrenos', ...
    sprintf('Presión = 50 MPa  |  \\sigma_{VM}^{max} = %.1f MPa  |  Deformación ×%.0f', ...
            max(vm)/1e6, sf)}, ...
    'FontSize', 13, 'FontWeight', 'bold');

xlabel('X [m]'); ylabel('Y [m]'); zlabel('Z [m]');
view(35, 25);
axis equal; grid on;

%% ----------------------------------------------------------------
%% 10. VISUALIZACIÓN — Vista superior (concentración en barrenos)
%% ----------------------------------------------------------------
figure('Color','w', 'Position',[120, 120, 900, 700], ...
       'Name','Von Mises — Vista Superior');

pdeplot3D(model, ...
    'ColorMapData',           vm, ...
    'Deformation',            res.Displacement, ...
    'DeformationScaleFactor', sf);

colormap('jet');
colorbar;
title('Vista Superior — Concentración de Esfuerzos en Barrenos', ...
      'FontSize', 12);
xlabel('X [m]'); ylabel('Y [m]'); zlabel('Z [m]');
view(0, 90);
axis equal; grid on;

fprintf('========================================\n');
fprintf(' ANÁLISIS COMPLETADO\n');
fprintf('========================================\n');


%% ================================================================
%%  FUNCIÓN LOCAL:  generarPlacaSTL
%%  ----------------------------------------------------------------
%%  Construye un STL watertight de una placa rectangular con
%%  N barrenos cilíndricos usando:
%%    - polyshape  → sección transversal 2D (rectángulo − círculos)
%%    - triangulate → malla de la sección
%%    - Extrusión manual de 4 paredes planas y N paredes cilíndricas
%%    - stlwrite    → escribe binario STL
%%
%%  Entradas
%%    filename : ruta del archivo STL de salida
%%    ancho    : lado de la placa cuadrada  [m]
%%    esp      : espesor                   [m]
%%    r        : radio de los barrenos     [m]
%%    pos      : Nx2 posiciones (x,y)      [m]
%%    nCPts    : puntos por circunferencia (≥32 para precisión)
%% ================================================================
function generarPlacaSTL(filename, ancho, esp, r, pos, nCPts)

    theta = linspace(0, 2*pi, nCPts+1)';
    theta = theta(1:end-1);   % nCPts ángulos uniformes [0, 2π)

    % ----------------------------------------------------------
    % A) Sección transversal 2D con polyshape
    %    (los subtract de polyshape son 2D y no tienen el bug 3D)
    % ----------------------------------------------------------
    outerRect = polyshape( ...
        [-ancho/2,  ancho/2,  ancho/2, -ancho/2], ...
        [-ancho/2, -ancho/2,  ancho/2,  ancho/2]);

    cs = outerRect;
    for k = 1:size(pos,1)
        holeK = polyshape(pos(k,1) + r*cos(theta), ...
                          pos(k,2) + r*sin(theta));
        cs = subtract(cs, holeK);  % polyshape/subtract — sin bug
    end

    % Triangulación 2D de la sección con agujeros
    %
    % NOTA: triangulate(ps) es una FUNCIÓN STANDALONE, no un método de la
    % clase polyshape. La notación cs.triangulate() falla con "Unrecognized
    % method" y triangulate(cs) colisiona con el CV Toolbox.
    %
    % SOLUCIÓN: delaunayTriangulation sobre los vértices de cs, filtrada
    % con isinterior() para descartar triángulos dentro de agujeros.
    % No requiere ningún toolbox adicional.
    allVerts = cs.Vertices;                         % [nV×2], NaN separa regiones
    mask     = ~any(isnan(allVerts), 2);
    pts2D    = allVerts(mask, :);                   % [nP×2]  sin filas NaN
    DT       = delaunayTriangulation(pts2D(:,1), pts2D(:,2));
    C        = incenter(DT);                        % centroide de cada triángulo
    inMask   = isinterior(cs, C(:,1), C(:,2));
    tris2D   = DT.ConnectivityList(inMask, :);      % [nT×3]  solo interiores
    % pts2D  : [nP × 2]  coordenadas X,Y de los vértices de la malla 2D
    % tris2D : [nT × 3]  índices de los triángulos (base 1)
    nP = size(pts2D, 1);

    % ----------------------------------------------------------
    % B) Ensamblado de vértices y triángulos 3D
    %
    %   Convención de normales: Right-Hand Rule → normal apunta
    %   hacia el EXTERIOR del sólido.
    %   - Cara inferior (z=0)  → normal (-Z): invertir winding
    %   - Cara superior (z=esp)→ normal (+Z): winding original
    %   - Paredes exteriores   → normal hacia afuera del prisma
    %   - Paredes cilíndricas  → normal hacia el eje (adentro del
    %     sólido = afuera del vacío del barreno)
    % ----------------------------------------------------------
    V = zeros(0,3);
    F = zeros(0,3);

    % ── Cara inferior  (z = 0,  normal = -Z) ──────────────────
    V = [V;  pts2D,  zeros(nP,1)];
    F = [F;  tris2D(:,[1,3,2])];      % invertir winding → -Z

    % ── Cara superior  (z = esp, normal = +Z) ─────────────────
    off = nP;
    V   = [V;  pts2D,  esp*ones(nP,1)];
    F   = [F;  tris2D + off];          % winding original → +Z

    % ── Paredes exteriores (4 caras rectangulares) ─────────────
    %   Esquinas del rectángulo en sentido CCW visto desde arriba
    corners = [-ancho/2, -ancho/2;
                ancho/2, -ancho/2;
                ancho/2,  ancho/2;
               -ancho/2,  ancho/2];

    for k = 1:4
        k2 = mod(k,4) + 1;
        p1 = corners(k,:);   p2 = corners(k2,:);
        mx = (p1(1)+p2(1))/2;  my = (p1(2)+p2(2))/2;
        dx = p2(1)-p1(1);      dy = p2(2)-p1(2);

        off = size(V,1);
        V   = [V;  p1,0;  p2,0;  p2,esp;  p1,esp]; %#ok<AGROW>
        % v1=(p1,0) v2=(p2,0) v3=(p2,esp) v4=(p1,esp)
        %
        % Normal del triángulo (v1,v2,v3) = (v2−v1)×(v3−v1)
        %   = (dx,dy,0) × (dx,dy,esp)
        %   = (dy·esp, −dx·esp, 0)  ∝ (dy,−dx)
        %
        % Queremos normal apuntando FUERA del prisma.
        % El vector "fuera" es el que tiene dot positivo con (mx,my).
        % Si (dy,−dx)·(mx,my) > 0 → winding directo [1,2,3],[1,3,4]
        % Si no → invertir winding
        if dot([dy, -dx], [mx, my]) > 0
            F = [F;  off+[1,2,3];  off+[1,3,4]]; %#ok<AGROW>
        else
            F = [F;  off+[1,3,2];  off+[1,4,3]]; %#ok<AGROW>
        end
    end

    % ── Paredes cilíndricas (normal hacia el eje del barreno) ──
    %
    %   Para una pared cilíndrica de un agujero, la normal del
    %   sólido apunta HACIA el eje del cilindro (−r̂).
    %   Winding para normal inward (−cos θ, −sin θ, 0):
    %     Triángulo (v1,v3,v2) → Normal = (v3−v1)×(v2−v1)
    %       = (x2−x1, y2−y1, esp)×(x2−x1, y2−y1, 0)
    %       ≈ (−dy·esp, dx·esp, 0)  ∝ (−dy, dx)
    %       = (−r·cosθ·dθ·esp, −r·sinθ·dθ·esp, 0)  ∝ (−cosθ,−sinθ)
    %     → apunta hacia el eje ✓

    for k = 1:size(pos,1)
        cx = pos(k,1);  cy = pos(k,2);
        for j = 1:nCPts
            j2 = mod(j, nCPts) + 1;
            x1 = cx + r*cos(theta(j));    y1 = cy + r*sin(theta(j));
            x2 = cx + r*cos(theta(j2));   y2 = cy + r*sin(theta(j2));

            off = size(V,1);
            V   = [V;  x1,y1,0;  x2,y2,0;  x2,y2,esp;  x1,y1,esp]; %#ok<AGROW>
            % v1=(x1,y1,0) v2=(x2,y2,0) v3=(x2,y2,esp) v4=(x1,y1,esp)
            F   = [F;  off+[1,3,2];  off+[1,4,3]]; %#ok<AGROW>
        end
    end

    % ----------------------------------------------------------
    % C) Escribir STL binario
    % ----------------------------------------------------------
    TR3D = triangulation(F, V);
    stlwrite(TR3D, filename);

    fprintf('  STL generado: %d triángulos | %d vértices\n', ...
            size(F,1), size(V,1));
end
