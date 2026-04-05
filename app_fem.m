function app_fem()
%APP_FEM  Interfaz gráfica para análisis FEM — Placa de acero con 4 barrenos
%
%   EJECUTAR   :  app_fem()
%   REQUISITOS :  MATLAB R2022b+ | PDE Toolbox
%
%   ENTRADAS (configurables en la GUI):
%     ancho   — Lado de la placa cuadrada           [m]
%     esp     — Espesor de la placa                 [m]
%     r       — Radio de los barrenos               [m]
%     d       — Distancia del centro a los barrenos [m]
%     nCPts   — Puntos por circunferencia en el STL
%     presion — Presión aplicada en la cara tope    [Pa]
%     Hmax    — Tamaño máximo de la malla           [m]
%
%   ESTRUCTURA DE LAYOUT:
%     ┌──────────────────────────────────────────────────────┐
%     │     ANÁLISIS FEM — PLACA DE ACERO CON 4 BARRENOS    │
%     ├─────────────────────────┬────────────────────────────┤
%     │  Parámetros de Entrada  │  [ ▶ Ejecutar Análisis ]   │
%     │  · Ancho de placa       │                            │
%     │  · Espesor              │  Log / Salida de consola   │
%     │  · Radio barrenos       │                            │
%     │  · Distancia al centro  │                            │
%     │  · Puntos STL           │                            │
%     │  · Presión (Pa)         │                            │
%     │  · Hmax malla           │                            │
%     ├─────────────────────────┴────────────────────────────┤
%     │  Estado: ...                                         │
%     └──────────────────────────────────────────────────────┘

%% ── Paleta de colores (tema oscuro) ─────────────────────────────
BG_DARK  = [0.13 0.13 0.16];
BG_PANEL = [0.19 0.19 0.23];
BG_FIELD = [0.26 0.26 0.31];
FG_WHITE = [1.00 1.00 1.00];
FG_GRAY  = [0.80 0.80 0.82];
FG_RED   = [0.95 0.15 0.15];
FG_GREEN = [0.35 0.90 0.40];
BTN_RED  = [0.75 0.08 0.08];

%% ── Ventana principal ────────────────────────────────────────────
fig = uifigure( ...
    'Name',     'Análisis FEM — Placa con Barrenos', ...
    'Position', [80, 80, 920, 610], ...
    'Color',    BG_DARK, ...
    'Resize',   'on');

%% ── Layout raíz: [título | contenido | barra de estado] ─────────
rootGL = uigridlayout(fig, [3, 1]);
rootGL.RowHeight        = {52, '1x', 30};
rootGL.ColumnWidth      = {'1x'};
rootGL.Padding          = [10 10 10 10];
rootGL.RowSpacing       = 8;
rootGL.BackgroundColor  = BG_DARK;

%% ── Fila 1: Encabezado ───────────────────────────────────────────
hdrPanel = uipanel(rootGL, ...
    'BackgroundColor', BG_PANEL, ...
    'BorderType',      'none');
hdrPanel.Layout.Row    = 1;
hdrPanel.Layout.Column = 1;

hdrGL = uigridlayout(hdrPanel, [1, 1]);
hdrGL.Padding          = [0 0 0 0];
hdrGL.BackgroundColor  = BG_PANEL;

uilabel(hdrGL, ...
    'Text',               'ANÁLISIS FEM — PLACA DE ACERO CON 4 BARRENOS', ...
    'FontSize',           15, ...
    'FontWeight',         'bold', ...
    'FontColor',          FG_WHITE, ...
    'HorizontalAlignment','center', ...
    'BackgroundColor',    BG_PANEL);

%% ── Fila 2: Contenido [params (izq.) | botón+log (der.)] ─────────
contentGL = uigridlayout(rootGL, [1, 2]);
contentGL.ColumnWidth   = {'1x', '1x'};
contentGL.RowHeight     = {'1x'};
contentGL.Padding       = [0 0 0 0];
contentGL.ColumnSpacing = 10;
contentGL.BackgroundColor = BG_DARK;
contentGL.Layout.Row    = 2;
contentGL.Layout.Column = 1;

%% ── Panel izquierdo: Parámetros de entrada ───────────────────────
leftPanel = uipanel(contentGL, ...
    'Title',           ' Parámetros de Entrada', ...
    'FontSize',        11, ...
    'FontWeight',      'bold', ...
    'ForegroundColor', FG_RED, ...
    'BackgroundColor', BG_PANEL, ...
    'BorderType',      'line');
leftPanel.Layout.Row    = 1;
leftPanel.Layout.Column = 1;

% {etiqueta, valor_defecto, formato_display}
PARAMS = { ...
    'Ancho de placa  (m)',          0.20,              '%g';    ...
    'Espesor  (m)',                 0.015,             '%g';    ...
    'Radio de barrenos  (m)',       (0.75*0.0254)/2,   '%.6f'; ...
    'Distancia al centro d  (m)',   0.07,              '%g';    ...
    'Puntos STL por círculo',       64,                '%.0f'; ...
    'Presión aplicada  (Pa)',       50e6,              '%.4g'; ...
    'Tamaño de malla Hmax  (m)',    0.008,             '%g'    ...
};
nParams = size(PARAMS, 1);

paramGL = uigridlayout(leftPanel, [nParams, 2]);
paramGL.RowHeight       = repmat({'1x'}, 1, nParams);
paramGL.ColumnWidth     = {'2x', '1x'};
paramGL.Padding         = [14 10 14 10];
paramGL.RowSpacing      = 6;
paramGL.ColumnSpacing   = 8;
paramGL.BackgroundColor = BG_PANEL;

hFields = gobjects(nParams, 1);
for i = 1:nParams
    lbl = uilabel(paramGL, ...
        'Text',               PARAMS{i,1}, ...
        'FontSize',           10, ...
        'FontColor',          FG_GRAY, ...
        'HorizontalAlignment','right', ...
        'BackgroundColor',    BG_PANEL);
    lbl.Layout.Row    = i;
    lbl.Layout.Column = 1;

    fld = uieditfield(paramGL, 'numeric', ...
        'Value',              PARAMS{i,2}, ...
        'ValueDisplayFormat', PARAMS{i,3}, ...
        'FontSize',           10, ...
        'BackgroundColor',    BG_FIELD, ...
        'FontColor',          FG_WHITE);
    fld.Layout.Row    = i;
    fld.Layout.Column = 2;
    hFields(i) = fld;
end

%% ── Panel derecho: Botón de ejecución + Log ──────────────────────
rightGL = uigridlayout(contentGL, [2, 1]);
rightGL.RowHeight       = {58, '1x'};
rightGL.ColumnWidth     = {'1x'};
rightGL.Padding         = [0 0 0 0];
rightGL.RowSpacing      = 8;
rightGL.BackgroundColor = BG_DARK;
rightGL.Layout.Row      = 1;
rightGL.Layout.Column   = 2;

btnRun = uibutton(rightGL, 'push', ...
    'Text',            '▶   Ejecutar Análisis FEM', ...
    'FontSize',        13, ...
    'FontWeight',      'bold', ...
    'BackgroundColor', BTN_RED, ...
    'FontColor',       FG_WHITE, ...
    'ButtonPushedFcn', @(~,~) ejecutarFEM());
btnRun.Layout.Row    = 1;
btnRun.Layout.Column = 1;

logArea = uitextarea(rightGL, ...
    'Value',    {'[Listo]  Configure los parámetros y presione Ejecutar.'}, ...
    'FontSize', 9.5, ...
    'BackgroundColor', [0.10 0.10 0.12], ...
    'FontColor', FG_GREEN, ...
    'Editable', 'off');
logArea.Layout.Row    = 2;
logArea.Layout.Column = 1;

%% ── Fila 3: Barra de estado ──────────────────────────────────────
statusPanel = uipanel(rootGL, ...
    'BackgroundColor', [0.10 0.10 0.12], ...
    'BorderType',      'none');
statusPanel.Layout.Row    = 3;
statusPanel.Layout.Column = 1;

statusGL = uigridlayout(statusPanel, [1, 1]);
statusGL.Padding         = [8 4 8 4];
statusGL.BackgroundColor = [0.10 0.10 0.12];

statusLbl = uilabel(statusGL, ...
    'Text',            'Estado:  Esperando...', ...
    'FontSize',        9.5, ...
    'FontColor',       [0.60 0.60 0.65], ...
    'BackgroundColor', [0.10 0.10 0.12]);

%% ================================================================
%%  FUNCIONES ANIDADAS
%%  (acceden a: fig, hFields, btnRun, logArea, statusLbl)
%% ================================================================

    %% ── Callback principal ──────────────────────────────────────
    function ejecutarFEM()
        btnRun.Enable = 'off';
        btnRun.Text   = '⏳  Ejecutando...';
        logArea.Value = {''};        % Limpiar log
        drawnow;

        try
            %−−− 1. Leer parámetros de la GUI ─────────────────────
            ancho   = hFields(1).Value;
            esp     = hFields(2).Value;
            r       = hFields(3).Value;
            d       = hFields(4).Value;
            nCPts   = max(8, round(hFields(5).Value));
            presion = hFields(6).Value;
            Hmax    = hFields(7).Value;

            pos = [ d,  d;
                   -d,  d;
                    d, -d;
                   -d, -d];

            log_('=== INICIO DEL ANÁLISIS ===');
            log_(sprintf('Placa    : %.0f × %.0f × %.0f mm', ...
                ancho*1e3, ancho*1e3, esp*1e3));
            log_(sprintf('Barrenos : R=%.5f m (%.4f pulg)  d=±%.0f mm', ...
                r, r/0.0254, d*1e3));
            log_(sprintf('Carga    : P=%.2f MPa  Hmax=%.4f m', ...
                presion/1e6, Hmax));

            %−−− 2. Modelo estructural ─────────────────────────────
            setStatus('Creando modelo estructural...');
            model = createpde('structural', 'static-solid');

            %−−− 3. Geometría vía STL ─────────────────────────────
            setStatus('Generando geometría STL...');
            stlPath = [tempname '.stl'];
            generarPlacaSTL(stlPath, ancho, esp, r, pos, nCPts);
            log_(sprintf('STL  →  %s', stlPath));

            setStatus('Importando geometría...');
            importGeometry(model, stlPath);
            geom = model.Geometry;
            log_(sprintf('Geom.    : %d caras | %d aristas | %d vértices', ...
                geom.NumFaces, geom.NumEdges, geom.NumVertices));

            %−−− 4. Material (Acero estructural) ──────────────────
            setStatus('Asignando material (E=210 GPa, ν=0.3)...');
            structuralProperties(model, ...
                'YoungsModulus', 210e9, 'PoissonsRatio', 0.3);

            %−−− 5. Malla ─────────────────────────────────────────
            setStatus(sprintf('Generando malla  (Hmax=%.4f m)...', Hmax));
            generateMesh(model, 'Hmax', Hmax, 'GeometricOrder', 'linear');
            nNod = size(model.Mesh.Nodes,    2);
            nEle = size(model.Mesh.Elements, 2);
            log_(sprintf('Malla    : %d nodos | %d elementos', nNod, nEle));

            %−−− 6. Identificación dinámica de caras ──────────────
            setStatus('Identificando caras de frontera...');
            tolZ     = esp * 0.05;
            caraBase = [];
            caraTope = [];
            for fid = 1:geom.NumFaces
                nodeIDs = findNodes(model.Mesh, 'region', 'Face', fid);
                if isempty(nodeIDs), continue; end
                zc = model.Mesh.Nodes(3, nodeIDs);
                if max(zc) < tolZ
                    caraBase = [caraBase, fid]; %#ok<AGROW>
                elseif min(zc) > (esp - tolZ)
                    caraTope = [caraTope, fid]; %#ok<AGROW>
                end
            end
            log_(sprintf('Base Z≈0      : Faces %s', mat2str(caraBase)));
            log_(sprintf('Tope Z≈%.3f  : Faces %s', esp, mat2str(caraTope)));

            if isempty(caraBase)
                error('No se encontró cara base (Z≈0). Verificar STL.');
            end
            if isempty(caraTope)
                error('No se encontró cara tope (Z≈%.4f). Verificar STL.', esp);
            end

            %−−− 7. Condiciones de frontera ───────────────────────
            setStatus('Aplicando condiciones de frontera...');
            structuralBC(model, 'Face', caraBase, 'Constraint', 'fixed');
            structuralBoundaryLoad(model, 'Face', caraTope, ...
                'Pressure', presion);
            log_(sprintf('C.C.     : Base empotrada  |  Tope P=%.2f MPa', ...
                presion/1e6));

            %−−− 8. Resolver ──────────────────────────────────────
            setStatus('Resolviendo sistema FEM (puede tardar)...');
            tic;
            res  = solve(model);
            tSol = toc;

            vm   = res.VonMisesStress;
            uMag = sqrt(res.Displacement.x.^2 + ...
                        res.Displacement.y.^2 + ...
                        res.Displacement.z.^2);

            log_('--- Resultados --------------------------');
            log_(sprintf('Tiempo   : %.1f s',           tSol));
            log_(sprintf('VM  Mín  : %.2f MPa',   min(vm)/1e6));
            log_(sprintf('VM  Máx  : %.2f MPa',   max(vm)/1e6));
            log_(sprintf('VM  Prom : %.2f MPa',  mean(vm)/1e6));
            log_(sprintf('Desp Máx : %.4f mm',  max(uMag)*1e3));
            log_('-----------------------------------------');

            %−−− 9. Visualización ─────────────────────────────────
            setStatus('Generando figuras...');
            sf = (ancho * 0.05) / max(uMag);
            graficarResultados(model, res, vm, sf, presion);

            %−−− 10. Notificación de éxito ────────────────────────
            log_('=== ANÁLISIS COMPLETADO ===');
            setStatus('✔  Análisis completado.');

            uialert(fig, sprintf([ ...
                'Análisis finalizado exitosamente.\n\n' ...
                '  Von Mises máx  :  %.2f MPa\n'         ...
                '  Desplaz. máx   :  %.4f mm\n'          ...
                '  Tiempo         :  %.1f s\n\n'         ...
                'STL guardado en:\n  %s'],               ...
                max(vm)/1e6, max(uMag)*1e3, tSol, stlPath), ...
                'Análisis FEM Completado', 'Icon', 'success');

        catch ME
            setStatus(['⚠  Error: ' ME.message]);
            log_(['¡ERROR!  ' ME.message]);
            uialert(fig, ME.message, 'Error en el Análisis', 'Icon', 'error');
        end

        btnRun.Enable = 'on';
        btnRun.Text   = '▶   Ejecutar Análisis FEM';
    end % ejecutarFEM

    %% ── Agregar línea al log ─────────────────────────────────────
    function log_(msg)
        logArea.Value = [logArea.Value; {msg}];
        scroll(logArea, 'bottom');
        drawnow;
    end

    %% ── Actualizar barra de estado ───────────────────────────────
    function setStatus(msg)
        statusLbl.Text = ['Estado:  ' msg];
        drawnow;
    end

end % app_fem


%% ================================================================
%%  graficarResultados — dos figuras independientes con mapa jet
%% ================================================================
function graficarResultados(model, res, vm, sf, presion)

    % ── Vista isométrica 3D ──────────────────────────────────────
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
    cb.Label.Color    = 'r';
    cb.Color          = 'r';

    title({ ...
        'Esfuerzos de Von Mises — Placa de Acero con 4 Barrenos', ...
        sprintf('Presión = %.0f MPa  |  \\sigma_{VM}^{max} = %.1f MPa  |  Deformación ×%.0f', ...
                presion/1e6, max(vm)/1e6, sf)}, ...
        'FontSize', 13, 'FontWeight', 'bold', 'Color', 'r');

    xlabel('X [m]','Color','r');
    ylabel('Y [m]','Color','r');
    zlabel('Z [m]','Color','r');
    set(gca, 'XColor','r', 'YColor','r', 'ZColor','r');
    view(35, 25); axis equal; grid on;

    % ── Vista superior ───────────────────────────────────────────
    figure('Color','w', 'Position',[120, 120, 900, 700], ...
           'Name','Von Mises — Vista Superior');

    pdeplot3D(model, ...
        'ColorMapData',           vm, ...
        'Deformation',            res.Displacement, ...
        'DeformationScaleFactor', sf);

    colormap('jet');
    cb2 = colorbar;
    cb2.Color = 'r';

    title('Vista Superior — Concentración de Esfuerzos en Barrenos', ...
          'FontSize', 12, 'Color', 'r');

    xlabel('X [m]','Color','r');
    ylabel('Y [m]','Color','r');
    zlabel('Z [m]','Color','r');
    set(gca, 'XColor','r', 'YColor','r', 'ZColor','r');
    view(0, 90); axis equal; grid on;

end % graficarResultados


%% ================================================================
%%  generarPlacaSTL — STL watertight de placa rectangular con barrenos
%% ================================================================
function generarPlacaSTL(filename, ancho, esp, r, pos, nCPts)

    theta = linspace(0, 2*pi, nCPts+1)';
    theta = theta(1:end-1);   % nCPts ángulos uniformes [0, 2π)

    % ── Sección 2D: rectángulo − N círculos (polyshape, sin bug 3D) ──
    cs = polyshape( ...
        [-ancho/2,  ancho/2,  ancho/2, -ancho/2], ...
        [-ancho/2, -ancho/2,  ancho/2,  ancho/2]);

    for k = 1:size(pos,1)
        cs = subtract(cs, polyshape( ...
            pos(k,1) + r*cos(theta), ...
            pos(k,2) + r*sin(theta)));
    end

    % ── Triangulación Delaunay filtrada por isinterior ────────────
    allV  = cs.Vertices;
    pts2D = allV(~any(isnan(allV), 2), :);
    DT    = delaunayTriangulation(pts2D(:,1), pts2D(:,2));
    keep  = isinterior(cs, incenter(DT));
    tri2D = DT.ConnectivityList(keep, :);
    nP    = size(pts2D, 1);

    V = zeros(0,3);
    F = zeros(0,3);

    % Cara inferior (z=0, normal −Z) y superior (z=esp, normal +Z)
    V = [V;  pts2D, zeros(nP,1);   pts2D, esp*ones(nP,1)];
    F = [F;  tri2D(:,[1,3,2]);     tri2D + nP            ];

    % ── Paredes exteriores (4 rectángulos) ───────────────────────
    corn = [-ancho/2,-ancho/2;   ancho/2,-ancho/2;
             ancho/2, ancho/2;  -ancho/2, ancho/2];
    for k = 1:4
        k2 = mod(k,4) + 1;
        p1 = corn(k,:);   p2 = corn(k2,:);
        dx = p2(1)-p1(1); dy = p2(2)-p1(2);
        off = size(V,1);
        V   = [V;  p1,0;  p2,0;  p2,esp;  p1,esp]; %#ok<AGROW>
        if dot([dy,-dx], (p1+p2)/2) > 0
            F = [F;  off+[1,2,3];  off+[1,3,4]]; %#ok<AGROW>
        else
            F = [F;  off+[1,3,2];  off+[1,4,3]]; %#ok<AGROW>
        end
    end

    % ── Paredes cilíndricas (N barrenos × nCPts strips) ──────────
    for k = 1:size(pos,1)
        cx = pos(k,1);   cy = pos(k,2);
        for j = 1:nCPts
            j2 = mod(j, nCPts) + 1;
            x1 = cx + r*cos(theta(j));   y1 = cy + r*sin(theta(j));
            x2 = cx + r*cos(theta(j2));  y2 = cy + r*sin(theta(j2));
            off = size(V,1);
            V   = [V;  x1,y1,0;  x2,y2,0;  x2,y2,esp;  x1,y1,esp]; %#ok<AGROW>
            F   = [F;  off+[1,3,2];  off+[1,4,3]];                   %#ok<AGROW>
        end
    end

    stlwrite(triangulation(F, V), filename);
    fprintf('  STL: %d triángulos | %d vértices\n', size(F,1), size(V,1));

end % generarPlacaSTL
