function style_figure(fig, filename_png, dpi)
% STYLE_FIGURE Forces crisp Light-Theme academic styling (overrides MATLAB R2026a dark mode!)
% and exports publication-grade high-DPI PNG figures ready for LaTeX/PDF inclusion.

    if nargin < 3
        dpi = 250;
    end

    % Override MATLAB R2025a/R2026a default dark theme to crisp publication light theme!
    try
        theme(fig, 'light');
    catch
        % Pre-R2025a MATLAB fallback
    end
    set(fig, 'Color', 'w');

    % Enforce crisp dark-ink axes, light gridlines, and white legend backgrounds on all subplots
    ax_all = findall(fig, 'Type', 'axes');
    ink    = [0.16, 0.22, 0.27]; % SRR.tex Ink #283746
    for k = 1:length(ax_all)
        set(ax_all(k), 'Color', 'w', 'XColor', ink, 'YColor', ink, ...
                       'GridColor', [0.78, 0.82, 0.86], 'GridAlpha', 0.65, ...
                       'MinorGridColor', [0.88, 0.90, 0.92], 'MinorGridAlpha', 0.5, ...
                       'FontName', 'Helvetica');
    end

    leg_all = findall(fig, 'Type', 'legend');
    for k = 1:length(leg_all)
        set(leg_all(k), 'Color', [1 1 1], 'TextColor', ink, 'EdgeColor', [0.75, 0.80, 0.85]);
    end

    cb_all = findall(fig, 'Type', 'colorbar');
    for k = 1:length(cb_all)
        set(cb_all(k), 'Color', ink);
    end

    if ~isempty(filename_png)
        [folder, ~, ~] = fileparts(filename_png);
        if ~isempty(folder) && ~exist(folder, 'dir')
            mkdir(folder);
        end
        if exist('exportgraphics', 'file') == 2
            exportgraphics(fig, filename_png, 'Resolution', dpi, 'BackgroundColor', 'white');
        else
            saveas(fig, filename_png);
        end
    end
end
