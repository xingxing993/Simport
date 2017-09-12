classdef SimportCANFile < SimportFile
    
    properties
        MsgCount %n
        MsgID %uint32 % [n,8]
        TimeStamp %double [n,1]
        DLC % uint8 [n,8]
        Data % uint8 [n,8]
    end
    
    methods
        function obj = SimportCANFile(varargin)

        end
    end
    
    methods
        %% GetData
        function LoadData(obj, varnames)
            varnames = cellstr(varnames);
            for i=1:numel(varnames)
                varobj = GetVar(obj, varnames{i});
                if ~isempty(varobj.Data) % if already loaded, return
                    continue;
                end
                msgid = hex2dec(regexprep(varobj.Name, '0x([0-9a-fA-F]+)(_Active)?','$1'));
                subidx = obj.MsgID==msgid;
                varobj.Time = obj.TimeStamp(subidx);
                if strcmp(varobj.UserData.Type, 'CAN Message Active')
                    varobj.Data = [];
                else
                    varobj.Data = obj.Data(subidx,:);
                end
            end
        end
        
        function varobj = GetVar(obj, varname)
            varobj = obj.VarObjects(strcmp(obj.VarList, varname));
        end
        
        %% UpdateVarObjects
        function UpdateVarObjects(obj, varargin)
            msgids = unique(obj.MsgID);
            msgidhex = arrayfun(@dec2hex, msgids, 'UniformOutput', false);
            varobjs = [];
            for i=1:numel(msgidhex)
                msgobj = SimportVariable(...
                    ['0x',msgidhex{i}],... %name
                    obj.FileName,...
                    'zoh',... % interpolation method
                    8,... % dimension
                    [],... %sample rate
                    'CAN');
                msgactvobj = SimportVariable(... % Message Active Signal
                    ['0x',msgidhex{i}, '_Active'],... %name
                    obj.FileName,...
                    @(new_time, time, data)interpmessage(time, data, new_time),... % interpolation method
                    1,... % dimension
                    [],... %sample rate
                    'CAN');
                % add extra notation information
                msgobj.UserData.Type = 'CAN Message';
                msgactvobj.UserData.Type = 'CAN Message Active';
                varobjs = [varobjs; msgobj; msgactvobj];
            end
            obj.VarObjects = varobjs;
        end
    end

end