classdef SimportFile < handle
    
    properties
        FileName
        VarList
        VarObjects % SimportVariable object array
        StartTime
        EndTime
        TimeOffset = 0
        TimeGain = 1
    end
    
    methods
        function obj = SimportFile(varargin)
            if nargin>0
                obj.FileName = varargin{1};
            end
        end
    end
    
    methods (Abstract)
        LoadData(obj, varnames);
        varobj = GetVar(obj,varname);
        UpdateVarObjects(obj, varargin);
    end
    
end

