classdef mlmat < handle
    properties (SetAccess = protected)
        filename
    end
    properties (Access = protected)
        mode
    end
    
    methods
        function obj = mlmat(filename,mode)
            if ~exist('mode','var'), mode = 'r'; end
            if exist('filename','var'), obj.open(filename,mode); end
        end
        function open(obj,filename,mode)
            obj.filename = filename;
            obj.mode = lower(mode);
        end            
        function close(~), end
        function val = isopen(obj), val = ~isempty(obj.filename) & ischar(obj.filename); end
        
        function write(obj,val,name,reserved) %#ok<INUSD>
            if isobject(val)
                field = fieldnames(val);
                for m=1:length(field)
                    a.(name).(field{m}) = val.(field{m}); %#ok<*STRNU>
                end
            else
                a.(name) = val;
            end
            switch obj.mode
                case 'a'
                    if 2==exist(obj.filename,'file')
                        save(obj.filename,'-struct','a','-append');
                    else
                        save(obj.filename,'-struct','a');
                    end
                case 'w'
                    save(obj.filename,'-struct','a');
                    obj.mode = 'a';
                case 'r'
                    error('This file is read-only!!!');
                otherwise
                    error('Unknown file access mode!!!');
            end
        end
        function val = read(obj,name)
            s = warning('off','MATLAB:load:variableNotFound');
            try
                a = load(obj.filename,name);
                if isfield(a,name), val = a.(name); else, val = []; end
            catch
            end
            warning(s);
        end
        function val = read_trial(obj)
            a = load(obj.filename,'-regexp','^Trial\d+$');
            field = fieldnames(a);
            for m=1:length(field)
                val(m) = a.(sprintf('Trial%d',m)); %#ok<AGROW>
            end
        end
        function val = who(obj)
            val = who('-file',obj.filename);
       end
    end
end
