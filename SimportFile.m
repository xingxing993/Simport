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
            obj.FileName = varargin{1};
        end
    end
    
    methods (Abstract)
        td = LoadData(obj, varnames);
        varobjs = GetVarObjects(obj, varargin);
    end
    
end

