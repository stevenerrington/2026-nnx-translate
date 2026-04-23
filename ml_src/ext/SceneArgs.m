classdef SceneArgs < SceneParam
    properties
        Visual
        Movie
        Sound
        STM
        TTL
        
        Position
        Scale
        Angle
        Zorder
        BackgroundColor
        MovieCurrentPosition
        MovieLooping
        Cursor

        Time
    end
    properties (Hidden = true)
        Adapter
    end
    
    methods
        function o = copy(obj)
            fn = fieldnames(obj);
            for m=1:length(fn), o.(fn{m}) = obj.(fn{m}); end
        end
    end
end
