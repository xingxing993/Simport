classdef SimportFile < handle
    
    properties
        FileName
        VarList
        VarObjects % SimportVariable object array
        
    end
    
    properties (Dependent)
        % Time configuration settings
        ZeroStart
        TimeGain
        TimeOffset
    end
    
    properties (Access=private)
        PrivateZeroStart = true
        PrivateTimeGain = 1
        PrivateTimeOffset = 0
    end
    
    methods
        function obj = SimportFile(varargin)
            if nargin>0
                obj.FileName = varargin{1};
            end
        end

        %%
        function set.ZeroStart(obj,value) 
            if value~=obj.PrivateZeroStart
                obj.PrivateZeroStart = value;
                obj.ClearUpTime;
            end
        end
        
        function set.TimeGain(obj,value) 
            if value~=obj.PrivateTimeGain
                obj.PrivateTimeGain = value;
                obj.ClearUpTime;
            end
        end
        
        function set.TimeOffset(obj,value) 
            if value~=obj.PrivateTimeOffset
                obj.PrivateTimeOffset = value;
                obj.ClearUpTime;
            end
        end
        
        function value = get.ZeroStart(obj) 
            value = obj.PrivateZeroStart;
        end
        
        function value = get.TimeGain(obj) 
            value = obj.PrivateTimeGain;
        end
        
        function value = get.TimeOffset(obj) 
            value = obj.PrivateTimeOffset;
        end
        
        function ClearUpTime(obj)
            for i=1:numel(obj.VarObjects)
                obj.VarObjects(i).Time = [];
            end
        end
    end
    
    
    
    methods (Abstract)
        LoadData(obj, varnames, reloadflg);
        varobj = GetVar(obj,varname);
        UpdateVarObjects(obj, varargin);
    end
    
end

