classdef mlbhvz < handle
    properties (SetAccess = protected)
        filename
    end
    properties (Access = protected)
        fid
        var_pos       % cache for variable positions; [name start end]
        readonly
        indexed       % whether the variable position data is in the file or not
        update_index  % whether to update the variable positions before closing
        fileinfo      % endianness and encoding
    end
    
    methods
        function obj = mlbhvz(filename,mode)  % mode: read, write, append
            obj.fid = -1;
            if ~exist('mode','var'), mode = 'r'; end
            if exist('filename','var'), obj.open(filename,mode); end
        end
        function open(obj,filename,mode)
            close(obj);
            if ~exist('mode','var'), mode = 'r'; end
            obj.filename = filename;
            obj.readonly = false;
            obj.indexed = true;
            obj.update_index = false;
            obj.fileinfo = struct('machinefmt','ieee-le','encoding','UTF-8');
            switch lower(mode(1))
                case 'r'
                    obj.fid = fopen(filename,'r',obj.fileinfo.machinefmt,obj.fileinfo.encoding);
                    [~,info] = read_index(obj);
                    if ~strcmp(info.machinefmt,obj.fileinfo.machinefmt) || ~strcmp(info.encoding,obj.fileinfo.encoding)
                        obj.fileinfo = info; fclose(obj.fid); obj.fid = fopen(filename,'r',obj.fileinfo.machinefmt,obj.fileinfo.encoding);
                    end
                    obj.readonly = true;
                case 'w'
                    obj.fid = fopen(filename,'w',obj.fileinfo.machinefmt,obj.fileinfo.encoding);
                    write(obj,-1,'IndexPosition',false);
                    write(obj,obj.fileinfo,'FileInfo',false);
                case 'a'
                    if 2==exist(filename,'file')
                        obj.fid = fopen(filename,'r+',obj.fileinfo.machinefmt,obj.fileinfo.encoding);
                        [pos,info] = read_index(obj);
                        if ~strcmp(info.machinefmt,obj.fileinfo.machinefmt) || ~strcmp(info.encoding,obj.fileinfo.encoding)
                            obj.fileinfo = info; fclose(obj.fid); obj.fid = fopen(filename,'r+',obj.fileinfo.machinefmt,obj.fileinfo.encoding);
                        end
                        if isempty(pos), fseek(obj.fid,0,1); else, fseek(obj.fid,pos,-1); end
                    else
                        obj.fid = fopen(filename,'w',obj.fileinfo.machinefmt,obj.fileinfo.encoding);
                        write(obj,-1,'IndexPosition',false);
                        write(obj,obj.fileinfo,'FileInfo',false);
                    end
            end
        end
        function close(obj)
            if -1~=obj.fid
                try
                    if obj.indexed && obj.update_index
                        s = ftell(obj.fid);
                        write_recursively(obj,obj.var_pos,'FileIndex',obj.fid,false);
                        fseek(obj.fid,0,-1);
                        write_recursively(obj,s,'IndexPosition',obj.fid,false);
                    end
                catch
                end
                fclose(obj.fid);
                obj.fid = -1;
            end
        end
        function val = isopen(obj), val = -1~=obj.fid; end
        function delete(obj), close(obj); end
        
        function s = write(obj,val,name,compress)
            if ~exist('compress','var'), compress = true; end
            if obj.readonly, error('This file is not opened in the write or append mode.'); end
            if ~isempty(obj.var_pos) && ~isempty(find(strcmp(obj.var_pos(:,1),name),1)), error('The variable, %s, exists in the file already.',name); end
            idx = size(obj.var_pos,1);
            s = ftell(obj.fid);
            
            if compress
                filename = tempname; %#ok<*PROPLC>
                zipfile = [filename '.zip'];
                try
                    fid = fopen(filename,'w',obj.fileinfo.machinefmt,obj.fileinfo.encoding);
                    write_recursively(obj,val,name,fid,false);
                    fclose(fid);
                    zip(zipfile,filename);
                    delete(filename);
                    fid = fopen(zipfile,'r');
                    val = fread(fid,Inf,'*uint8');
                    fclose(fid);
                    delete(zipfile);
                catch err
                    if exist(filename,'file'), delete(filename); end
                    if exist(zipfile,'file'), delete(zipfile); end
                    rethrow(err);
                end
            end
            write_recursively(obj,val,name,obj.fid,compress);
            
            idx = idx + 1;
            obj.var_pos{idx,1} = name;
            obj.var_pos{idx,2} = s;
            obj.var_pos{idx,3} = ftell(obj.fid);
            obj.update_index = true;
        end
        function val = read(obj,name)
            if ~obj.readonly, error('This file is not opened in the read mode.'); end
            pos = 0;
            if exist('name','var')
                if ~isempty(obj.var_pos)
                    row = find(strcmp(obj.var_pos(:,1),name),1);
                    if ~isempty(row)
                        fseek(obj.fid,obj.var_pos{row,2},-1);
                        val = read_recursively(obj);
                        return
                    end
                    pos = obj.var_pos{end,3};
                end
            else
                obj.var_pos = [];
            end
            fseek(obj.fid,pos,-1);
            idx = size(obj.var_pos,1);
            while true
                try
                    s = ftell(obj.fid);
                    [a,b] = read_recursively(obj);
                    idx = idx + 1;
                    obj.var_pos{idx,1} = b;
                    obj.var_pos{idx,2} = s;
                    obj.var_pos{idx,3} = ftell(obj.fid);
                    if exist('name','var')
                        if strcmp(b,name), val = a; return, end
                    else
                        val.(b) = a;
                    end
                catch err
                    if ~strcmp(err.identifier,'mlbhvz:eof'), fprintf(2,'%s\n\n',err.message); end
                    break;
                end
            end
            if ~exist('val','var'), val = []; end
        end
        function val = read_trial(obj)
            if ~obj.readonly, error('This file is not opened in the read mode.'); end
            if isempty(obj.var_pos)
                pos = 0;
            else
                for m=[obj.var_pos{~cellfun(@isempty,regexp(obj.var_pos(:,1),'^Trial\d+$','once')),2}]
                    fseek(obj.fid,m,-1);
                    try
                        [a,b] = read_recursively(obj);
                    catch err
                        warning(err.message);
                        continue
                    end
                    val(str2double(regexp(b,'\d+','match'))) = a; %#ok<AGROW>
                end
                pos = obj.var_pos{end,3};
            end
            fseek(obj.fid,pos,-1);
            idx = size(obj.var_pos,1);
            while true
                try
                    s = ftell(obj.fid);
                    [a,b] = read_recursively(obj);
                    idx = idx + 1;
                    obj.var_pos{idx,1} = b;
                    obj.var_pos{idx,2} = s;
                    obj.var_pos{idx,3} = ftell(obj.fid);
                    if ~isempty(regexp(b,'^Trial\d+$','once')), val(str2double(regexp(b,'\d+','match'))) = a; end
                catch err
                    if ~strcmp(err.identifier,'mlbhvz:eof'), fprintf(2,'%s\n\n',err.message); end
                    break;
                end
            end
            if ~exist('val','var'), val = []; end
        end
        function val = who(obj)
            if obj.readonly
                if isempty(obj.var_pos), pos = 0; else, pos = obj.var_pos{end,3}; end
                fseek(obj.fid,pos,-1);
                idx = size(obj.var_pos,1);
                while true
                    try
                        s = ftell(obj.fid);
                        [~,b] = read_recursively(obj);
                        idx = idx + 1;
                        obj.var_pos{idx,1} = b;
                        obj.var_pos{idx,2} = s;
                        obj.var_pos{idx,3} = ftell(obj.fid);
                    catch err
                        if ~strcmp(err.identifier,'mlbhvz:eof'), fprintf(2,'%s\n\n',err.message); end
                        break;
                    end
                end
            end
            if isempty(obj.var_pos), val = []; else, val = obj.var_pos(:,1); end
        end
    end
    
    methods (Access = protected)
        function [pos,fileinfo] = read_index(obj)
            obj.indexed = false;
            pos = [];
            fileinfo = struct('machinefmt','ieee-le','encoding','UTF-8');  % BHVZ used UTF-8 from the beginning
            fseek(obj.fid,0,-1);
            lname = fread(obj.fid,1,'uint64=>double');
            name = fread(obj.fid,[1 lname],'char*1=>char');
            if strcmp(name,'IndexPosition')
                obj.indexed = true;
                fseek(obj.fid,0,-1);
                pos = read_variable(obj,obj.fid);

                s = ftell(obj.fid);
                lname = fread(obj.fid,1,'uint64=>double');
                name = fread(obj.fid,[1 lname],'char*1=>char');
                if strcmp(name,'FileInfo')
                    fseek(obj.fid,s,-1);
                    fileinfo = read_variable(obj,obj.fid);
                end
                
                if 0<pos
                    try
                        fseek(obj.fid,pos,-1);
                        [obj.var_pos,name] = read_variable(obj,obj.fid);
                        if ~strcmp(name,'FileIndex'), error('FileIndex is not found!'); end
                    catch
                        obj.var_pos = []; pos = [];
                    end
                end
            end
        end
        function write_recursively(obj,val,name,fid,zipbit)  % zipbit should be written only for the variable root
            try
                type = class(val);
                switch type
                    case {'string','datetime','duration','calendarDuration','categorical','table','timetable','containers.Map','timeseries','tscollection'}
                    otherwise
                        if isobject(val)
                            type = 'struct';
                            try if ~isvalid(val), val = 'invalid object'; type = class(val); end, catch, end
                        end
                end

                dim = ndims(val);
                sz = size(val);
                fwrite(fid,length(name),'uint64');
                fwrite(fid,name,'char*1');
                fwrite(fid,length(type),'uint64');
                fwrite(fid,type,'char*1');
                fwrite(fid,dim,'uint64');
                fwrite(fid,sz,'uint64');
                if exist('zipbit','var'), fwrite(fid,logical(zipbit),'logical'); end
                
                switch type
                    case 'struct'
                        try field = fieldnames(val)'; catch, field = properties(val)'; end, nfield = length(field); fwrite(fid,nfield,'uint64');
                        count = prod(sz);
                        if 1==count
                            for m=field, write_recursively(obj,val.(m{1}),m{1},fid); end  % some objects do not allow indexing
                        else
                            for m=1:count, for n=field, write_recursively(obj,val(m).(n{1}),n{1},fid); end, end
                        end
                    case 'cell'
                        for m=1:prod(sz), write_recursively(obj,val{m},'',fid); end
                    case {'string','categorical'}  % string: from R2016b
                        write_recursively(obj,cellstr(val),'',fid);
                    case 'datetime'
                        field = fieldnames(val)'; nfield = length(field); fwrite(fid,nfield,'uint64');
                        for m=field, write_recursively(obj,val.(m{1}),m{1},fid); end
                    case 'duration'
                        write_recursively(obj,hours(val),'',fid);
                        field = fieldnames(val)'; nfield = length(field); fwrite(fid,nfield,'uint64');
                        for m=field, write_recursively(obj,val.(m{1}),m{1},fid); end
                    case 'calendarDuration'
                        write_recursively(obj,datevec(val),'',fid);
                        field = fieldnames(val)'; nfield = length(field); fwrite(fid,nfield,'uint64');
                        for m=field, write_recursively(obj,val.(m{1}),m{1},fid); end
                    case 'table'
                        write_recursively(obj,table2cell(val),'',fid);
                        field = mlsetdiff(fieldnames(val.Properties)','CustomProperties'); nfield = length(field); fwrite(fid,nfield,'uint64');
                        for m=field, write_recursively(obj,val.Properties.(m{1}),m{1},fid); end
                        customprop = isprop(val.Properties,'CustomProperties'); fwrite(fid,customprop,'logical');  % CustomProperties: from R2018b
                        if customprop, write_recursively(obj,saveobj(val.Properties.CustomProperties),'CustomProperties',fid); end
                    case 'timetable'  % from R2016b
                        write_recursively(obj,table2cell(timetable2table(val)),'',fid);
                        field = mlsetdiff(fieldnames(val.Properties)',{'RowTimes','StartTime','CustomProperties'}); nfield = length(field); fwrite(fid,nfield,'uint64');
                        for m=field, write_recursively(obj,val.Properties.(m{1}),m{1},fid); end
                        customprop = isprop(val.Properties,'CustomProperties'); fwrite(fid,customprop,'logical');  % CustomProperties: from R2018b
                        if customprop, write_recursively(obj,saveobj(val.Properties.CustomProperties),'CustomProperties',fid); end
                    case 'function_handle'
                        write_recursively(obj,func2str(val),'',fid);
                    case 'containers.Map'
                        write_recursively(obj,keys(val),'keys',fid);
                        write_recursively(obj,values(val),'values',fid);
                    case {'timeseries','tsdata.event'}  % same as struct
                        field = fieldnames(val)'; nfield = length(field); fwrite(fid,nfield,'uint64');
                        for m=1:prod(sz), for n=field, write_recursively(obj,val(m).(n{1}),n{1},fid); end, end
                    case 'tscollection'
                        ts = gettimeseriesnames(val);  % put timeseries in the front
                        field = [ts mlsetdiff(fieldnames(val)',[ts,'Time','TimeInfo','Length'])]; nfield = length(field); fwrite(fid,nfield,'uint64');
                        for m=field, write_recursively(obj,val.(m{1}),m{1},fid); end
                    otherwise
                        fwrite(fid,val,type);
                end
            catch err
                rethrow(err);
            end
        end
        function [val,name] = read_recursively(obj)
            try
                [val,name,zipbit] = read_variable(obj,obj.fid);

                if zipbit
                    zipfile = [tempname '.zip'];
                    try
                        fid = fopen(zipfile,'w'); %#ok<*PROP>
                        fwrite(fid,val);
                        fclose(fid);
                        filename = unzip(zipfile,tempdir);
                        try
                            delete(zipfile);
                            fid = fopen(filename{1},'r',obj.fileinfo.machinefmt,obj.fileinfo.encoding);
                            val = read_variable(obj,fid);
                            fclose(fid);
                            delete(filename{1});
                        catch err
                            if exist(filename{1},'file'), delete(filename{1}); end
                            rethrow(err);
                        end
                    catch err
                        if exist(zipfile,'file'), delete(zipfile); end
                        rethrow(err);
                    end
                end
            catch err
                rethrow(err);
            end
        end
        function [val,name,zipbit] = read_variable(obj,fid,~)  % set the 3rd argument true for recursive iterations
            try
                lname = fread(fid,1,'uint64=>double');
                if feof(fid), error('mlbhvz:eof','End of file.'); end
                name = fread(fid,[1 lname],'char*1=>char');
                ltype = fread(fid,1,'uint64=>double');
                type = fread(fid,[1 ltype],'char*1=>char');
                dim = fread(fid,1,'uint64=>double');
                sz = fread(fid,[1 dim],'uint64=>double');
                zipbit = false; if 2==nargin, zipbit = fread(fid,1,'logical'); end
                
                switch type
                    case 'struct'
                        val = repmat(struct,sz);
                        nfield = fread(fid,1,'uint64=>double'); for m=1:prod(sz), for n=1:nfield, [a,b] = read_variable(obj,fid,true); val(m).(b) = a; end, end
                    case 'cell'
                        val = cell(sz); for m=1:prod(sz), val{m} = read_variable(obj,fid,true); end
                    case 'string'
                        val = string(read_variable(obj,fid,true));
                    case 'datetime'
                        val = datetime(ones(sz),'ConvertFrom','datenum');
                        nfield = fread(fid,1,'uint64=>double'); for m=1:nfield, [a,b] = read_variable(obj,fid,true); try val.(b) = a; catch, end, end
                    case 'duration'
                        val = duration(read_variable(obj,fid,true),0,0);
                        nfield = fread(fid,1,'uint64=>double'); for m=1:nfield, [a,b] = read_variable(obj,fid,true); val.(b) = a; end
                    case 'calendarDuration'
                        val = reshape(calendarDuration(read_variable(obj,fid,true)),sz);
                        nfield = fread(fid,1,'uint64=>double'); for m=1:nfield, [a,b] = read_variable(obj,fid,true); val.(b) = a; end
                    case 'categorical'
                        val = categorical(read_variable(obj,fid,true));
                    case 'table'
                        val = cell2table(read_variable(obj,fid,true));
                        nfield = fread(fid,1,'uint64=>double'); for m=1:nfield, [a,b] = read_variable(obj,fid,true); val.Properties.(b) = a; end
                        if fread(fid,1,'*logical')
                            s = read_variable(obj,fid,true);
                            for m=fieldnames(s.tabularProps)', val = addprop(val,m{1},'table'); val.Properties.CustomProperties.(m{1}) = s.tabularProps.(m{1}); end
                            for m=fieldnames(s.varProps)', val = addprop(val,m{1},'variable'); val.Properties.CustomProperties.(m{1}) = s.varProps.(m{1}); end
                        end
                    case 'timetable'
                        s = read_variable(obj,fid,true);
                        if isempty(s), val = timetable; else, val = table2timetable(cell2table(s)); end
                        nfield = fread(fid,1,'uint64=>double'); for m=1:nfield, [a,b] = read_variable(obj,fid,true); val.Properties.(b) = a; end
                        if fread(fid,1,'*logical')
                            s = read_variable(obj,fid,true);
                            for m=fieldnames(s.tabularProps)', val = addprop(val,m{1},'table'); val.Properties.CustomProperties.(m{1}) = s.tabularProps.(m{1}); end
                            for m=fieldnames(s.varProps)', val = addprop(val,m{1},'variable'); val.Properties.CustomProperties.(m{1}) = s.varProps.(m{1}); end
                        end
                    case 'function_handle'
                        val = str2func(read_variable(obj,fid,true));
                    case 'containers.Map'
                        keySet = read_variable(obj,fid,true);
                        valueSet = read_variable(obj,fid,true);
                        if isempty(keySet), val = containers.Map; else, val = containers.Map(keySet,valueSet); end
                    case 'timeseries'
                        val = repmat(timeseries,sz);
                        nfield = fread(fid,1,'uint64=>double');
                        args = {'Data','Time','Quality'};
                        field = mlsetdiff(fieldnames(val),args);
                        warning('off');  % suppress read-only warnings
                        for m=1:prod(sz)
                            s = struct; for n=1:nfield, [a,b] = read_variable(obj,fid,true); s.(b) = a; end
                            for n=args, val(m).(n{1}) = s.(n{1}); end
                            val(m) = copyfield(obj,val(m),s,field);
                        end
                        warning('on');
                    case 'tscollection'
                        nfield = fread(fid,1,'uint64=>double');
                        for m=1:nfield
                            [a,b] = read_variable(obj,fid,true);
                            switch class(a)  % timeseries variables come in first, if there is any
                                case 'timeseries', if exist('val','var'), val = addts(val,a); else, val = tscollection(a); end
                                otherwise, if exist('val','var'), val.(b) = a; else, val = tscollection; val.(b) = a; end
                            end
                        end
                    case 'tsdata.event'
                        val = repmat(tsdata.event,sz);
                        nfield = fread(fid,1,'uint64=>double'); for m=1:prod(sz), for n=1:nfield, [a,b] = read_variable(obj,fid,true); val(m).(b) = a; end, end
                    otherwise
                        val = reshape(fread(fid,prod(sz),['*' type]),sz);  % fread can handle only a 2-d size arg.
                end
            catch err
                if exist('name','var')
                    error(err.identifier,'An error occurred while reading the variable, ''%s''.\n\n%s',name,err.message);
                else
                    rethrow(err);
                end
            end
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
    end
end
