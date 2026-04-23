function BlackrockLED_setmax(id,max_intensity)

if max_intensity<0 || 1<max_intensity, error('Max intensity must be between 0 and 1.'); end

mdqmex(6,id,'max_intensity',double(max_intensity));
