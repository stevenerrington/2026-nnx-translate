function temperature = BlackrockLED_temp(id,adapter_ver)

if ~exist('adapter_ver','var'), adapter_ver = 2; end

try
    raw = mdqmex(7,id,'temperature');

    switch adapter_ver
        case 1, pullup = 10;    % old adapter
        otherwise, pullup = 5;  % new adapter
    end

    temperature = -4.4617 * pullup ./ (65535./raw - 1) + 66;
catch
    temperature = NaN(1,4);
end
