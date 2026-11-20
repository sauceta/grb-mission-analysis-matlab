function fig = plot_ground_track(sat_lat, sat_lon, cfg, geomag, comms, const, out_png)
% PLOT_GROUND_TRACK Clean publication-grade 2D ground track with IGRF-14 SAA B-field contours,
% polar radiation horn boundaries (L=3.2), TT&C stations, and equatorial VHF chain.
% Fixes the unreadable overlapping text labels from v1 by labeling only TT&C stations
% and rendering VHF receivers as clean, compact markers.

    fig = figure('Name', sprintf('Ground Track - %s', cfg.code), ...
                 'Units', 'pixels', 'Position', [80, 80, 1100, 580], 'Visible', 'off', 'Color', 'w');
    hold on; grid on; box on;

    % 1. World coastline background (uses Mapping coastlines or base-MATLAB topo.mat)
    if exist('coastlines.mat', 'file') == 2
        coast = load('coastlines');
        plot(coast.coastlon, coast.coastlat, 'Color', [0.55, 0.60, 0.65], 'LineWidth', 0.8, 'HandleVisibility', 'off');
    elseif exist('topo.mat', 'file') == 2
        t_dat = load('topo');
        % Shift topo from [0..360] to [-180..180] longitude
        topo_shift = [t_dat.topo(:, 181:360), t_dat.topo(:, 1:180)];
        lon_t = -179.5:1:179.5;
        lat_t = -89.5:1:89.5;
        contour(lon_t, lat_t, topo_shift, [0 0], 'Color', [0.52, 0.58, 0.64], 'LineWidth', 0.85, 'HandleVisibility', 'off');
    else
        rectangle('Position', [-180, -90, 360, 180], 'FaceColor', [0.97, 0.98, 0.99], 'EdgeColor', 'k');
    end

    % 2. Live IGRF-14 SAA Contour & Polar Radiation Horn Contour at exact orbit altitude
    [LON_g, LAT_g] = meshgrid(-180:3:180, -90:3:90);
    ALT_g = cfg.h_km * ones(size(LAT_g));
    B_map = geomag.F_B(LAT_g, LON_g, ALT_g);
    L_map = geomag.F_L(LAT_g, LON_g, ALT_g);

    % Mask SAA region
    saa_mask = double((B_map < geomag.B_saa_crit_nT) & (L_map >= geomag.L_saa_min) & ...
                      (L_map <= geomag.L_saa_max) & (LAT_g < 12) & (LON_g > -115) & (LON_g < 45));
    contourf(LON_g, LAT_g, saa_mask, [0.5, 1.5], 'FaceColor', [0.92, 0.35, 0.35], ...
             'FaceAlpha', 0.30, 'EdgeColor', const.colors.TUMRed, 'LineWidth', 1.4, ...
             'DisplayName', sprintf('IGRF-14 SAA (|B| < %.1f uT @ %d km)', geomag.B_saa_crit_nT*1e-3, round(cfg.h_km)));

    % Polar/Auroral electron radiation belt boundary (L > 3.2)
    pol_mask = double(L_map > geomag.L_polar_crit);
    contourf(LON_g, LAT_g, pol_mask, [0.5, 1.5], 'FaceColor', [0.60, 0.45, 0.80], ...
             'FaceAlpha', 0.16, 'EdgeColor', const.colors.TUMPurple, 'LineStyle', '--', 'LineWidth', 1.0, ...
             'DisplayName', 'Polar Radiation Horns (L > 3.2)');

    % 3. Plot Ground Track (first 24 hours for crisp visual clarity without spaghetti overlap!)
    num_sats = size(sat_lat, 1);
    n_plot   = min(size(sat_lat, 2), round(86400 / 10)); % 1 day at 10 s step (~15 orbits)
    sat_cols = {const.colors.TUMBlue, const.colors.TUMOrange, const.colors.TUMGreen, ...
                const.colors.TUMPurple, const.colors.TUMGold, const.colors.TUMDark};

    for s = 1:num_sats
        lons = sat_lon(s, 1:n_plot);
        lats = sat_lat(s, 1:n_plot);
        jumps = find(abs(diff(lons)) > 180.0);
        st = 1;
        col_s = sat_cols{mod(s-1, length(sat_cols)) + 1};
        lw = 1.25;
        if num_sats > 2, lw = 0.85; end

        for j = 1:length(jumps)
            seg = st:jumps(j);
            if j == 1 && s <= 3
                lbl = sprintf('Sat %d Track (24h)', s);
                if num_sats > 3 && s == 3, lbl = sprintf('Sats 3-%d Tracks', num_sats); end
                plot(lons(seg), lats(seg), 'Color', col_s, 'LineWidth', lw, 'DisplayName', lbl);
            else
                plot(lons(seg), lats(seg), 'Color', col_s, 'LineWidth', lw, 'HandleVisibility', 'off');
            end
            st = jumps(j) + 1;
        end
        if st <= length(lons)
            plot(lons(st:end), lats(st:end), 'Color', col_s, 'LineWidth', lw, 'HandleVisibility', 'off');
        end
    end

    % 4. Equatorial VHF Alert Receivers (compact green dots, single legend entry)
    vhf_lons = [comms.vhf_stations.lon];
    vhf_lats = [comms.vhf_stations.lat];
    plot(vhf_lons, vhf_lats, 'o', 'MarkerFaceColor', const.colors.TUMGreen, ...
         'MarkerEdgeColor', [0.1, 0.25, 0.05], 'MarkerSize', 4.5, ...
         'DisplayName', sprintf('Equatorial VHF Chain (%d stations)', length(vhf_lons)));

    % 5. Primary TT&C Stations (distinct blue triangles with clean labels)
    ttc_lons = [comms.ttc_stations.lon];
    ttc_lats = [comms.ttc_stations.lat];
    plot(ttc_lons, ttc_lats, '^', 'MarkerFaceColor', const.colors.TUMDark, ...
         'MarkerEdgeColor', 'w', 'MarkerSize', 8.5, 'LineWidth', 0.9, ...
         'DisplayName', 'Primary S/X-Band TT&C Stations');
    for i = 1:length(comms.ttc_stations)
        gs = comms.ttc_stations(i);
        short_nm = strtok(gs.name, ' ');
        text(gs.lon + 3.0, gs.lat + 2.5, short_nm, 'FontSize', 8, 'FontWeight', 'bold', ...
             'Color', const.colors.TUMNavy, 'BackgroundColor', [1 1 1 0.72], 'Margin', 1, 'Interpreter', 'none');
    end

    xlim([-180, 180]); ylim([-90, 90]);
    xticks(-180:30:180); yticks(-90:30:90);
    xlabel('Geodetic Longitude [deg E]', 'FontSize', 10, 'FontWeight', 'bold');
    ylabel('Geodetic Latitude [deg N]', 'FontSize', 10, 'FontWeight', 'bold');
    title(sprintf('%s — 24h Ground Track, IGRF-14 Radiation Zones & Ground Network (%d km, %.1f^\\circ)', ...
          cfg.name, round(cfg.h_km), cfg.inc_deg), 'FontSize', 11.5, 'FontWeight', 'bold', 'Color', const.colors.TUMNavy);
    legend('Location', 'southoutside', 'NumColumns', 3, 'FontSize', 8.5);

    if nargin >= 7 && ~isempty(out_png)
        style_figure(fig, out_png, 250);
    end
end
