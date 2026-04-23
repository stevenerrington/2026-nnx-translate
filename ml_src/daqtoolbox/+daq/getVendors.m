function vendorInfo = getVendors()

adaptors = mdqmex(20,1,1);
if isempty(adaptors)
    vendorInfo = struct('ID','','FullName','No adaptor found!','AdaptorVersion','','DriverVersion','','IsOperational',0);
else
    if any(strcmp(adaptors,'nidaq')), adaptor = 'nidaq'; else adaptor = adaptors{1}; end
    [~,vendorInfo] = mdqmex(20,2,adaptor);
    [~,vendorInfo.AdaptorVersion] = daq.getToolboxInfo;
end
