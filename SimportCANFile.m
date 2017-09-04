classdef SimportCANFile < SimportFile
    
    properties

    end
    
    methods
        function obj = SimportCANFile(varargin)

        end
    end
    
    methods
        %% GetData
        function LoadData(obj, varnames)

        end
        
        function varobj = GetVar(obj, varname)
            varobj = obj.VarObjects(strcmp(obj.VarList, varname));
        end
        
        %% GetVarObjects
        function varlist = GetVarObjects(obj, varargin)

        end
    end

end