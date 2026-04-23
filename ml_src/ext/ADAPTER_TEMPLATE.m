classdef ADAPTER_TEMPLATE < mladapter  % CHANGE THE CLASS NAME! The name of this file must be identical with it.
    properties
        % Define user variables here. They will be both readable and writable.
        
    end
    properties (SetAccess = protected)
        % Define output variables here. They will be only readable.
        
    end
    properties (Access = protected)
        % Define internal variables here. They won't be accessible from the outside of the class.
        
    end

    methods
        % To access the properties defined in the class, prefix 'obj.' to their names, like obj.Variable.
        % The first line of the constructor and four other methods (init, fini, analyze, draw) must be a call for the base class method.
        
        function obj = ADAPTER_TEMPLATE(varargin)  % CHANGE THIS LINE! The constructor name must be the same as the class name.
            obj@mladapter(varargin{:});      % DO NOT DELETE THIS LINE. It is necessary to complete the adapter chain.
            
            % Things to do when the class is instantiated.
            
        end
        function delete(obj) %#ok<INUSD>
            % Things to do when this adapter is destroyed by MATLAB

        end
        
        function init(obj,p)
            init@mladapter(obj,p);  % DO NOT DELETE THIS LINE. It is necessary to complete the adapter chain.
            
            % Things to do just before the scene starts
            
        end
        function fini(obj,p)
            fini@mladapter(obj,p);  % DO NOT DELETE THIS LINE. It is necessary to complete the adapter chain.
            
            % Things to do right after the scene ends
            
        end
        function continue_ = analyze(obj,p)
            continue_ = analyze@mladapter(obj,p);  % DO NOT DELETE THIS LINE. It is necessary to complete the adapter chain.
            
            % Things to do for behavior analysis
            % This function will be called once per each frame while the scene runs.
            %
            % To end the scene, return false (i.e., assign false to continue_).
            % obj.Success is typically used to indicate the detection of the target behavior.
            %
            % See WaitThenHold.m for an example.
            obj.Success = obj.Adapter.Success;  % You can just assign the child adapter's success state, if you don't want to do any analysis.

        end
        function draw(obj,p)
            draw@mladapter(obj,p);  % DO NOT DELETE THIS LINE. It is necessary to complete the adapter chain.
            
            % Things to do to update graphics
            % This function will be called every frame during the scene but after analyze() is called.
            
        end
    end
end
