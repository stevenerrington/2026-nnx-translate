function mglreset()

try [engine,device,format] = mglaudioengine; catch, end

mdqmex(11,12);

try mglaudioengine(engine,device,format); catch, end
