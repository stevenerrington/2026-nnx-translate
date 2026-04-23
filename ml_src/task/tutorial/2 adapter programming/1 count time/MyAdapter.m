% This is skeletal code copied from "ext\ADAPTER_TEMPLATE.m". There are
% more comments to read in that file.

% 1. The class and the constructor should have the same name as the mfile.
%
% 2. The constructor, init(), fini(), analyze() and draw() should have the
%    same function definition as shown here and they all should call their
%    superclass method before doing anything.
%    See https://www.mathworks.com/help/matlab/matlab_oop/calling-superclass-methods-on-subclass-objects.html
%
% 3. Those functions can be omitted if they do not need overriding. Note
%    that init(), fini() and draw() are commented out below.
%
% 4. Class properties need prefixing 'obj.' when referenced in the methods,
%    like obj.endtime below. All adapters inherit the Success property from
%    the mladapter class.

classdef MyAdapter < mladapter                  % class name
    properties
        endtime
    end
    methods
        function obj = MyAdapter(varargin)      % constructor
            obj@mladapter(varargin{:});   % Call the superclass method
        end
%         function delete(obj)
%         end
        
%         function init(obj,p)
%             init@mladapter(obj,p);              % Call the superclass method
%         end
%         function fini(obj,p)
%             fini@mladapter(obj,p);              % Call the superclass method
%         end
        function continue_ = analyze(obj,p)
            analyze@mladapter(obj,p);             % Call the superclass method
            obj.Success = obj.Adapter.Success;
            
            elapsed = p.scene_time();           % Get the time elapsed from the scene start
            continue_ = elapsed < obj.endtime;  % Continue the scene until the elapsed time is over obj.endtime
            p.dashboard(1,sprintf('Elapsed time: %4.0f ms', elapsed));  % Display the elapsed time
        end
%         function draw(obj,p)
%             draw@mladapter(obj,p);              % Call the superclass method
%         end
    end
end
