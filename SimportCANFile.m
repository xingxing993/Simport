classdef SimportCANFile < SimportFile
    
    properties
        MsgCount %n
        MsgID %uint32 % [n,8]
        TimeStamp %double [n,1]
        DLC % uint8 [n,8]
        Data % uint8 [n,8]
        Channel % [n,1] cell string or numeric array
        
        
        StartTime
        EndTime
        ChannelInfo = {[], {}} % nx2 cell {Channel, {MsgIDs}}, shall be initialized upon loading specific CAN file        
        
    end
    
    methods
        function obj = SimportCANFile(varargin)

        end
    end
    
    methods
        %% GetData
        function LoadData(obj, varnames, reloadflg, channel)
            if nargin<4
                channel = [];
            end
            if nargin<3
                reloadflg = false;
            end
            
            
            varnames = cellstr(varnames);
            for i=1:numel(varnames)
                varobj = GetVar(obj, varnames{i});
                if ~isempty(varobj.Time) && ~reloadflg % if already loaded, return
                    continue;
                end
                msgid = hex2dec(regexprep(varobj.Name, '0x([0-9a-fA-F]+)(_Active)?','$1'));
                if ~isempty(strfind(varobj.Name, '@CH')) % if signal names contains "@CH" keyword
                    ch = regexprep(varobj.Name, '.*@CH','');
                elseif ~isempty(channel)
                    ch = channel;
                else
                    ch = [];
                end
                if ~isempty(ch)
                    if isnumeric(obj.Channel)
                        subidx_ch = obj.Channel==str2double(ch);
                    else
                        subidx_ch = strcmp(obj.Channel, ch);
                    end
                    subidx = (obj.MsgID==msgid) & subidx_ch;
                else % message id only, no channel info
                    subidx = obj.MsgID==msgid;                    
                end

                varobj.Time = obj.TimeStamp(subidx);
                varobj.Time = (varobj.Time-varobj.Time(1)*obj.ZeroStart)*obj.TimeGain + obj.TimeOffset;
                if strcmp(varobj.UserData.Type, 'CAN Message Active')
                    varobj.Data = []; % data can only be interpolated with known sample time, thus set to zero, @interpmessage handles this situation
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
            if isempty(obj.Channel)
                msg_idhex_str = arrayfun(@dec2hex, obj.MsgID, 'UniformOutput', false);
                msg_ch_str = cell(numel(obj.MsgID),1);   [msg_ch_str{:}] = deal('');
            elseif isnumeric(obj.Channel)
                msgs_id_ch = unique([obj.MsgID, obj.Channel], 'rows');
                msg_idhex_str = arrayfun(@dec2hex, msgs_id_ch(:,1), 'UniformOutput', false);
                msg_ch_str = arrayfun(@(ch)['@CH',int2str(ch)], msgs_id_ch(:,2), 'UniformOutput', false);
            else % Channel is cell string
                [msgs_id_ch, uidx] = unique(cellfun(@(id,chstr) sprintf('%s@CH%s',dec2hex(id),chstr), num2cell(obj.MsgID), obj.Channel, 'UniformOutput', false));
                msg_idhex_str = arrayfun(@dec2hex, obj.MsgID(uidx), 'UniformOutput', false);
                msg_ch_str = ['@CH',obj.Channel(uidx)];
            end
            
            varobjs = [];
            for i=1:size(msgs_id_ch,1)
                msgobj = SimportVariable(...
                    ['0x',msg_idhex_str{i},msg_ch_str{i}],... %name
                    obj.FileName,...
                    'zoh',... % interpolation method
                    8,... % dimension
                    [],... %sample rate
                    'CAN');
                msgactvobj = SimportVariable(... % Message Active Signal
                    ['0x',msg_idhex_str{i}, '_Active',msg_ch_str{i}],... %name
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