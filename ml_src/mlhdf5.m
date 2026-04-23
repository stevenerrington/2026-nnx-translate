classdef mlhdf5 < handle
    properties (SetAccess = protected)
        filename
    end
    properties (Access = protected)
        fid
        opened
        gcpl
        
        int8
        uint8
        int16
        uint16
        int32
        uint32
        int64
        uint64
        single
        double
    end
    properties (Constant)
        root = '/ML/'
    end
    
    methods
        function obj = mlhdf5(filename,mode)  % mode: r, w, a
            obj.opened = false;
            if ~exist('mode','var'), mode = 'r'; end
            if exist('filename','var'), obj.open(filename,mode); end
        end
        function open(obj,filename,mode)
            close(obj);
            if ~exist('mode','var'), mode = 'r'; end
            obj.filename = filename;
            
            tracked = H5ML.get_constant_value('H5P_CRT_ORDER_TRACKED');
            indexed = H5ML.get_constant_value('H5P_CRT_ORDER_INDEXED');
            order = bitor(tracked,indexed);
            obj.gcpl = H5P.create('H5P_GROUP_CREATE');
            H5P.set_link_creation_order(obj.gcpl,order);
            
            switch lower(mode)
                case {'r','read'}
                    if 2~=exist(filename,'file'), error('File not found'); end
                    obj.fid = H5F.open(filename,'H5F_ACC_RDONLY','H5P_DEFAULT');
                case {'w','write'}
                    obj.fid = H5F.create(filename,'H5F_ACC_TRUNC','H5P_DEFAULT','H5P_DEFAULT');
                    gid = H5G.create(obj.fid,obj.root,'H5P_DEFAULT',obj.gcpl,'H5P_DEFAULT');
                    H5G.close(gid);
                case {'a','append'}
                    if 2==exist(filename,'file')
                        obj.fid = H5F.open(filename,'H5F_ACC_RDWR','H5P_DEFAULT');
                    else
                        obj.fid = H5F.create(filename,'H5F_ACC_TRUNC','H5P_DEFAULT','H5P_DEFAULT');
                        gid = H5G.create(obj.fid,obj.root,'H5P_DEFAULT',obj.gcpl,'H5P_DEFAULT');
                        H5G.close(gid);
                    end
            end
            obj.opened = true;
            
            obj.int8 = H5T.copy('H5T_NATIVE_CHAR');
            obj.uint8 = H5T.copy('H5T_NATIVE_UCHAR');
            obj.int16 = H5T.copy('H5T_NATIVE_SHORT');
            obj.uint16 = H5T.copy('H5T_NATIVE_USHORT');
            obj.int32 = H5T.copy('H5T_NATIVE_INT');
            obj.uint32 = H5T.copy('H5T_NATIVE_UINT');
            obj.int64 = H5T.copy('H5T_NATIVE_LLONG');
            obj.uint64 = H5T.copy('H5T_NATIVE_ULLONG');
            obj.single = H5T.copy('H5T_NATIVE_FLOAT');
            obj.double = H5T.copy('H5T_NATIVE_DOUBLE');
        end
        function close(obj)
            if ~obj.opened, return, end
            H5T.close(obj.int8);
            H5T.close(obj.uint8);
            H5T.close(obj.int16);
            H5T.close(obj.uint16);
            H5T.close(obj.int32);
            H5T.close(obj.uint32);
            H5T.close(obj.int64);
            H5T.close(obj.uint64);
            H5T.close(obj.single);
            H5T.close(obj.double);
            
            H5P.close(obj.gcpl);
            H5F.close(obj.fid);
            obj.opened = false;
        end
        function val = isopen(obj), val = obj.opened; end
        function delete(obj), close(obj); end
        
        function val = read(obj,name)
            if exist('name','var')
                try val = read_variable(obj,[obj.root name]); catch, val = []; end
            else
                names = who(obj);
                for m=1:length(names)
                    val.(names{m}) = read_variable(obj,[obj.root names{m}]);
                end
            end
        end
        function val = read_trial(obj)
            names = who(obj);
            idx = 0;
            for m=1:length(names)
                if ~isempty(regexp(names{m},'Trial\d+','once'))
                    idx = idx + 1;
                    val(idx) = read_variable(obj,[obj.root names{m}]); %#ok<AGROW>
                end
            end
        end
        function val = who(obj,location)
            if ~exist('location','var'), location = obj.root; end
            group_id = H5G.open(obj.fid,location);
            val = {};
            H5L.iterate(group_id,'H5_INDEX_CRT_ORDER','H5_ITER_INC',0,@iterfunc,0);
            
            function [status,opdata_out] = iterfunc(~,name,~)
                status = []; opdata_out = []; val{end+1} = name;
            end
        end
        function write(obj,val,name,reserved) %#ok<INUSD>
            location = [obj.root name];
            type = class(val);
            switch type
                case {'string','datetime','duration','calendarDuration','categorical','table','timetable','containers.Map','timeseries','tscollection'}
                otherwise
                    if isobject(val)
                        type = 'struct';
                        try if ~isvalid(val), val = 'invalid object'; type = class(val); end, catch, end
                    end
            end
            
            sz = size(val);
            count = prod(sz);
            switch type  % primitive types
                case 'char', write_char(obj,val,location); return
                case 'logical', write_numeric(obj,cast(val,'uint8'),location,'logical'); return  % save as uint8
                case {'int8','uint8','int16','uint16','int32','uint32','int64','uint64','single','double'}, write_numeric(obj,val,location); return
            end
            
            write_header(obj,location,type,sz);
            switch type  % object types
                case 'struct'
                    switch count
                        case 1
                            try field = fieldnames(val)'; catch, field = properties(val)'; end
                            for m=field, write(obj,val.(m{1}),[name '/' m{1}]); end
                        otherwise
                            for m=1:count, write(obj,val(m),[name '/' num2str(m)]); end
                    end
                case 'cell'
                    for m=1:count, write(obj,val{m},[name '/' num2str(m)]); end
                case {'string','categorical'}  % string: from R2016b
                    write(obj,cellstr(val),[name '/1']);
                case 'datetime'
                    for m=fieldnames(val)', write(obj,val.(m{1}),[name '/' m{1}]); end
                case 'duration'
                    write(obj,hours(val),[name '/1']);
                    for m=fieldnames(val)', write(obj,val.(m{1}),[name '/' m{1}]); end
                case 'calendarDuration'
                    write(obj,datevec(val),[name '/1']);
                    for m=fieldnames(val)', write(obj,val.(m{1}),[name '/' m{1}]); end
                case 'table'
                    write(obj,table2cell(val),[name '/1']);
                    for m=mlsetdiff(fieldnames(val.Properties)','CustomProperties'), write(obj,val.Properties.(m{1}),[name '/' m{1}]); end
                    if isprop(val.Properties,'CustomProperties'), write(obj,saveobj(val.Properties.CustomProperties),[name '/CustomProperties']); end  % CustomProperties: from R2018b
                case 'timetable'  % from R2016b
                    write(obj,table2cell(timetable2table(val)),[name '/1']);
                    for m=mlsetdiff(fieldnames(val.Properties)',{'RowTimes','StartTime','CustomProperties'}), write(obj,val.Properties.(m{1}),[name '/' m{1}]); end
                    if isprop(val.Properties,'CustomProperties'), write(obj,saveobj(val.Properties.CustomProperties),[name '/CustomProperties']); end  % CustomProperties: from R2018b
                case 'function_handle'
                    write(obj,func2str(val),[name '/1']);
                case 'containers.Map'
                    write(obj,keys(val),[name '/keys']);
                    write(obj,values(val),[name '/values']);
                case {'timeseries','tsdata.event'}  % same as struct
                    switch count
                        case 1, for m=fieldnames(val)', write(obj,val.(m{1}),[name '/' m{1}]); end
                        otherwise, for m=1:count, write(obj,val(m),[name '/' num2str(m)]); end
                    end
                case 'tscollection'
                    ts = gettimeseriesnames(val);  % put timeseries in the front
                    for m=[ts mlsetdiff(fieldnames(val)',[ts,'Time','TimeInfo','Length'])], write(obj,val.(m{1}),[name '/' m{1}]); end
                otherwise
                    error('The variable class, ''%s'', is unknown',type);
            end
        end
    end
    
    methods (Access = protected)
        function val = read_variable(obj,location)
            try
                id = H5O.open(obj.fid,location,'H5P_DEFAULT');
                info = H5O.get_info(id);
                type = read_char_attribute(obj,id,'class');
                sz = read_numeric_attribute(obj,id,'size');
                if strncmp(type,'ml',2), type = 'struct'; end  % for compatibility with very old h5

                switch info.type
                    case 0
                        switch type
                            case 'struct'
                                count = prod(sz);
                                switch count
                                    case 0, val = repmat(struct,sz);
                                    case 1, val = struct; names = who(obj,location); for m=names, val.(m{1}) = read_variable(obj,[location '/' m{1}]); end
                                    otherwise
                                        for m=1:count
                                            s = read_variable(obj,[location '/' num2str(m)]);
                                            if 1==m, val = repmat(s,sz); else, val(m) = s; end
                                        end
                                end
                            case 'cell'
                                val = cell(sz); for m=1:prod(sz), val{m} = read_variable(obj,[location '/' num2str(m)]); end
                            case 'string'
                                val = string(read_variable(obj,[location '/1']));
                            case 'datetime'
                                val = datetime(ones(sz),'ConvertFrom','datenum');
                                names = who(obj,location); for m=names, try val.(m{1}) = read_variable(obj,[location '/' m{1}]); catch, end, end
                            case 'duration'
                                val = duration(read_variable(obj,[location '/1']),0,0);
                                names = mlsetdiff(who(obj,location),'1'); for m=names, val.(m{1}) = read_variable(obj,[location '/' m{1}]); end
                            case 'calendarDuration'
                                val = reshape(calendarDuration(read_variable(obj,[location '/1'])),sz);
                                names = mlsetdiff(who(obj,location),'1'); for m=names, val.(m{1}) = read_variable(obj,[location '/' m{1}]); end
                            case 'categorical'
                                val = categorical(read_variable(obj,[location '/1']));
                            case 'table'
                                val = cell2table(read_variable(obj,[location '/1']));
                                names = who(obj,location); for m=mlsetdiff(names,{'1','CustomProperties'}), val.Properties.(m{1}) = read_variable(obj,[location '/' m{1}]); end
                                if ismember('CustomProperties',names)
                                    s = read_variable(obj,[location '/CustomProperties']);
                                    for m=fieldnames(s.tabularProps)', val = addprop(val,m{1},'table'); val.Properties.CustomProperties.(m{1}) = s.tabularProps.(m{1}); end
                                    for m=fieldnames(s.varProps)', val = addprop(val,m{1},'variable'); val.Properties.CustomProperties.(m{1}) = s.varProps.(m{1}); end
                                end
                            case 'timetable'
                                s = read_variable(obj,[location '/1']);
                                if isempty(s), val = timetable; else, val = table2timetable(cell2table(s)); end
                                names = who(obj,location); for m=mlsetdiff(names,{'1','CustomProperties'}), val.Properties.(m{1}) = read_variable(obj,[location '/' m{1}]); end
                                if ismember('CustomProperties',names)
                                    s = read_variable(obj,[location '/CustomProperties']);
                                    for m=fieldnames(s.tabularProps)', val = addprop(val,m{1},'table'); val.Properties.CustomProperties.(m{1}) = s.tabularProps.(m{1}); end
                                    for m=fieldnames(s.varProps)', val = addprop(val,m{1},'variable'); val.Properties.CustomProperties.(m{1}) = s.varProps.(m{1}); end
                                end
                            case 'function_handle'
                                val = str2func(read_variable(obj,[location '/1']));
                            case 'containers.Map'
                                keySet = read_variable(obj,[location '/keys']);
                                valueSet = read_variable(obj,[location '/values']);
                                if isempty(keySet), val = containers.Map; else, val = containers.Map(keySet,valueSet); end
                            case 'timeseries'
                                count = prod(sz);
                                switch count
                                    case 1
                                        names = who(obj,location); s = struct; for m=names, a = read_variable(obj,[location '/' m{1}]); s.(m{1}) = a; end
                                        val = timeseries;
                                        args = {'Data','Time','Quality'}; for m=args, val.(m{1}) = s.(m{1}); end
                                        warning('off'); val = copyfield(obj,val,s,mlsetdiff(names,args)); warning('on');  % suppress read-only warnings
                                    otherwise
                                        val = repmat(timeseries,sz); for m=1:count, val(m) = read_variable(obj,[location '/' num2str(m)]); end
                                end
                            case 'tsdata.event'
                                count = prod(sz);
                                switch count
                                    case 1, val = tsdata.event; names = who(obj,location); for m=names, val.(m{1}) = read_variable(obj,[location '/' m{1}]); end
                                    otherwise, val = repmat(tsdata.events,sz); for m=1:count, val(m) = read_variable(obj,[location '/' num2str(m)]); end
                                end
                            case 'tscollection'
                                for m=who(obj,location)
                                    a = read_variable(obj,[location '/' m{1}]);
                                    switch class(a)  % timeseries variables come in first, if there is any
                                        case 'timeseries', if exist('val','var'), val = addts(val,a); else, val = tscollection(a); end
                                        otherwise, if exist('val','var'), val.(m{1}) = a; else, val = tscollection; val.(m{1}) = a; end
                                    end
                                end
                        end
                    case 1
                        if 0==prod(sz)  % If the size attribute is 0, do not read the dataset. See write_numeric().
                            val = reshape(cast([],type),sz);
                        else
                            val = H5D.read(id);
                            switch type
                                case 'char', if iscell(val), val = val{1}; end
                                case 'logical', val = logical(val);
                            end
                            val = reshape(val,sz);
                        end
                end
            catch err
                rethrow(err);
            end
            close(id);
        end
        function dest = copyfield(obj,dest,src,field)
            if ~exist('field','var'), field = intersect(fieldnames(dest),fieldnames(src)); end
            for m=1:length(field)
                try
                    if isobject(dest.(field{m}))
                        dest.(field{m}) = copyfield(obj,dest.(field{m}),src.(field{m}));
                    else
                        dest.(field{m}) = src.(field{m});
                    end
                catch err
                    if ~strcmp(err.identifier,'MATLAB:class:SetProhibited'), rethrow(err); end  % suppress read-only errors
                end
            end
        end
        function varargout = write_header(obj,location,type,sz)
            gid = H5G.create(obj.fid,location,'H5P_DEFAULT',obj.gcpl,'H5P_DEFAULT');
            write_char_attribute(obj,gid,'class',type);
            write_numeric_attribute(obj,gid,'size',sz);
            if 0<nargout, varargout{1} = gid; else, H5G.close(gid); end
        end
        function write_char(obj,val,location)
            type_id = H5T.copy('H5T_C_S1'); H5T.set_size(type_id,'H5T_VARIABLE');
            space_id = H5S.create('H5S_SCALAR');
            dset_id = H5D.create(obj.fid,location,type_id,space_id,'H5P_DEFAULT');
            H5D.write(dset_id,'H5ML_DEFAULT','H5S_ALL','H5S_ALL','H5P_DEFAULT',{val});
            write_char_attribute(obj,dset_id,'class','char');
            write_numeric_attribute(obj,dset_id,'size',size(val));
            H5D.close(dset_id);
            H5S.close(space_id);
            H5T.close(type_id);
        end
        function write_numeric(obj,val,location,alt_class)
            type = class(val); sz = size(val); count = prod(sz);
            if ~exist('alt_class','var'), alt_class = type; end
            if 0==count && verLessThan('matlab','8.5')
                space_id = H5S.create_simple(1,1,[]); val = cast(0,type);
            else
                space_id = H5S.create_simple(ndims(val),fliplr(sz),[]);
            end
            dset_id = H5D.create(obj.fid,location,obj.(type),space_id,'H5P_DEFAULT');
            H5D.write(dset_id,'H5ML_DEFAULT','H5S_ALL','H5S_ALL','H5P_DEFAULT',val);
            write_char_attribute(obj,dset_id,'class',alt_class);
            write_numeric_attribute(obj,dset_id,'size',sz);
            H5D.close(dset_id);
            H5S.close(space_id);
        end
        function write_char_attribute(~,id,name,val)
            type_id = H5T.copy('H5T_C_S1'); H5T.set_size(type_id,length(val));
            space_id = H5S.create('H5S_SCALAR');
            attr_id = H5A.create(id,name,type_id,space_id,'H5P_DEFAULT');
            H5A.write(attr_id,'H5ML_DEFAULT',val); H5A.close(attr_id);
            H5S.close(space_id);
            H5T.close(type_id);
        end
        function write_numeric_attribute(obj,id,name,val)
            type = class(val); sz = size(val);
            space_id = H5S.create_simple(ndims(val),fliplr(sz),fliplr(sz));
            attr_id = H5A.create(id,name,obj.(type),space_id,'H5P_DEFAULT');
            H5A.write(attr_id,'H5ML_DEFAULT',val); H5A.close(attr_id);
            H5S.close(space_id);
        end
        function val = read_numeric_attribute(~,id,name)
            attr_id = H5A.open(id,name);
            val = H5A.read(attr_id);
            H5A.close(attr_id);
        end
        function val = read_char_attribute(~,id,name)
            attr_id = H5A.open(id,name);
            val = H5A.read(attr_id)';  % transpose
            H5A.close(attr_id);
        end
%         function write_cellstr(obj,val,location)
%             type_id = H5T.copy('H5T_C_S1'); H5T.set_size(type_id,'H5T_VARIABLE');
%             space_id = H5S.create_simple(1,length(val),[]);
%             dset_id = H5D.create(obj.fid,location,type_id,space_id,'H5P_DEFAULT');
%             H5D.write(dset_id,obj.string,'H5S_ALL','H5S_ALL','H5P_DEFAULT',val);
%             H5D.close(dset_id);
%             H5S.close(space_id);
%             H5T.close(type_id);
%         end
    end
end
