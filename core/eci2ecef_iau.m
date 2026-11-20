function [r_ecef, v_ecef] = eci2ecef_iau(r_eci, v_eci, t_sec, const)
% ECI2ECEF_IAU High-precision vectorized J2000 ECI to WGS-84 ECEF transformation.
% Anchors Earth orientation at mission epoch using Aerospace Toolbox IAU-2000/2006
% precession-nutation-Earth-rotation DCM (`dcmeci2ecef`), then applies exact sidereal
% rotation R_z(omegaE * t_sec). Gracefully falls back to Vallado GMST (Alg. 15) if
% Aerospace Toolbox is unavailable.
%
% Inputs:
%   r_eci  - Position in J2000 ECI [m] (3xN)
%   v_eci  - Velocity in J2000 ECI [m/s] (3xN)
%   t_sec  - Elapsed time since mission epoch [s] (1xN)
%   const  - Constants struct
%
% Outputs:
%   r_ecef - Position in ECEF [m] (3xN)
%   v_ecef - Velocity in ECEF [m/s] (3xN)

    if nargin < 4
        const = constants();
    end

    % Compute exact ECI -> ECEF orientation matrix at t = 0 (mission epoch)
    if exist('dcmeci2ecef', 'file') == 2
        DCM0 = dcmeci2ecef('IAU-2000/2006', const.epoch_utc);
    else
        % Vallado Algorithm 15 (GMST at J2000 epoch)
        T_ut1 = (const.epoch_jd - 2451545.0) / 36525.0;
        gmst_sec = 67310.54841 + (876600.0*3600.0 + 8640184.812866)*T_ut1 ...
                   + 0.093104*(T_ut1^2) - 6.2e-6*(T_ut1^3);
        gmst0_rad = deg2rad(mod(gmst_sec / 240.0, 360.0));
        c0 = cos(gmst0_rad); s0 = sin(gmst0_rad);
        DCM0 = [c0, s0, 0; -s0, c0, 0; 0, 0, 1];
    end

    % Rotate all ECI states into epoch-aligned ECEF0 first (fast BLAS multiply)
    r0 = DCM0 * r_eci;
    v0 = DCM0 * v_eci;

    % Vectorized sidereal rotation about Earth Z-axis for elapsed time t_sec
    theta = const.omegaE * t_sec(:)'; % 1xN
    ct = cos(theta);
    st = sin(theta);

    r_ecef = [ ct .* r0(1, :) + st .* r0(2, :);
              -st .* r0(1, :) + ct .* r0(2, :);
               r0(3, :)];

    if nargout > 1
        v_rot = [ ct .* v0(1, :) + st .* v0(2, :);
                 -st .* v0(1, :) + ct .* v0(2, :);
                  v0(3, :)];
        % Subtract Earth transport velocity: omega_E x r_ecef
        v_ecef = [v_rot(1, :) + const.omegaE * r_ecef(2, :);
                  v_rot(2, :) - const.omegaE * r_ecef(1, :);
                  v_rot(3, :)];
    end
end
