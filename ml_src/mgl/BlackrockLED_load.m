function BlackrockLED_load(id,intensity,duration)

if 0~=mod(duration,2) || duration < 1, error('Duration must be a multiple of 2 greather than 0.'); end

mdqmex(6,id,'loadfile',double(intensity),double(duration));
