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
        function varobjs = LoadData(obj, varnames, reloadflg, channel)
            if nargin<4
                channel = [];
            end
            if nargin<3
                reloadflg = false;
            end
            
            
            varnames = cellstr(varnames);
            varobjs = [];
            for i=1:numel(varnames)
                varobj = GetVar(obj, varnames{i}, channel);
                if isempty(varobj) || (~isempty(varobj.Time) && ~reloadflg) % if already loaded, return
                    continue;
                end
                if ~isempty(strfind(varobj.Name, '@CH')) % if signal names contains "@CH" keyword
                    ch = regexprep(varobj.Name, '.*@CH','');
                elseif ~isempty(channel) %if channel specified
                    ch = channel;
                else
                    ch = [];
                end
                msgid = hex2dec(regexprep(varobj.Name, '0x([0-9a-fA-F]+)(_Active)?(@CH.*)','$1'));
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
                varobjs = [varobjs; varobj];
            end
        end
        %% GetVar
        function varobjs = GetVar(obj, varnames, channel)
            if nargin<3
                channel = [];
            end
            varnames = cellstr(varnames);
            if ischar(channel)
                [chstrs{1:numel(varnames)}] = deal(channel);
            elseif isnumeric(channel)
                if numel(channel)>1
                    chstrs = cellfun(@(s)num2str, num2cell(channel), 'UniformOutput', false);
                else % numel(channel)==1
                    [chstrs{1:numel(varnames)}] = deal(num2str(channel));
                end
            else %should be cell
                chstrs = cellfun(@(s)num2str(s), channel, 'UniformOutput', false);
            end
            varobjs = [];
            for i=1:numel(varnames)
                vn = varnames{i};
                if ~isempty(strfind(vn, '@CH')) %already contains @CH keyword
                    varname = vn;
                elseif isempty(chstrs{i}) % no channel info
                    varname = vn;
                else
                    varname = sprintf('%s@CH%s', vn, chstrs{i});
                end
                varobj = obj.VarObjects(strcmp(obj.VarList, varname));
                varobjs = [varobjs;varobj];
            end
        end
        
        
        %% UpdateVarObjects
        function UpdateVarObjects(obj, varargin) %Update variable objects and channel info
            if isempty(obj.Channel)
                msgs_id_ch = unique(obj.MsgID);
                msg_idhex_str = arrayfun(@dec2hex, msgs_id_ch, 'UniformOutput', false);
                msg_ch_str = cell(numel(msg_idhex_str),1);   [msg_ch_str{:}] = deal('');
                obj.ChannelInfo = {[], msgs_id_ch', msg_idhex_str'};
            elseif isnumeric(obj.Channel)
                msgs_id_ch = unique([obj.MsgID, obj.Channel], 'rows');
                msg_idhex_str = arrayfun(@dec2hex, msgs_id_ch(:,1), 'UniformOutput', false);
                msg_ch_str = arrayfun(@(ch)['@CH',int2str(ch)], msgs_id_ch(:,2), 'UniformOutput', false);
                % construct ChannelInfo
                unqchnls = unique(msgs_id_ch(:,2));
                msgids_ch  = arrayfun(@(ch) msgs_id_ch(msgs_id_ch(:,2)==ch, 1)', unqchnls, 'UniformOutput', false);
                msgidstrs_ch = cellfun(@(chmsglist)arrayfun(@dec2hex, chmsglist, 'UniformOutput', false), msgids_ch, 'UniformOutput', false);
                obj.ChannelInfo = [num2cell(unqchnls), msgids_ch, msgidstrs_ch];
            else % Channel is cell string
                [msgs_id_ch, uidx] = unique(cellfun(@(id,chstr) sprintf('%s@CH%s',dec2hex(id),chstr), num2cell(obj.MsgID), obj.Channel, 'UniformOutput', false));
                % construct ChannelInfo
                msgids_array = num2cell(obj.MsgID(uidx));
                chnls = obj.Channel(uidx);
                msg_idhex_str = arrayfun(@dec2hex, obj.MsgID(uidx), 'UniformOutput', false);
                msg_ch_str = ['@CH',chnls];
                unqchnls = unique(chnls);
                msgids_ch  = cellfun(@(ch) msgids_array(strcmp(chnls, ch)), unqchnls, 'UniformOutput', false);
                tmp = cellfun(@(chmsglist)arrayfun(@dec2hex, chmsglist, 'UniformOutput', false), msgids_ch, 'UniformOutput', false);
                msgidstrs_ch = cellfun(@(c) [c{:}], tmp, 'UniformOutput', false);
                obj.ChannelInfo = [num2cell(unqchnls), msgids_ch, msgidstrs_ch];
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
                % add channel information
                if isempty(obj.Channel)
                    [msgobj.Channel, msgactvobj.Channel, msgobj.UserData.Channels, msgactvobj.UserData.Channels] = deal([]);
                elseif isnumeric(obj.Channel)
                    [msgobj.Channel, msgactvobj.Channel, msgobj.UserData.Channels, msgactvobj.UserData.Channels] = deal(msgs_id_ch(i,2));
                else % Channel is cell string
                    [msgobj.Channel, msgactvobj.Channel, msgobj.UserData.Channels, msgactvobj.UserData.Channels] = deal(chnls{i});
                end
                % add extra notation information
                msgobj.UserData.Type = 'CAN Message';
                msgactvobj.UserData.Type = 'CAN Message Active';
                varobjs = [varobjs; msgobj; msgactvobj];
            end
            obj.VarObjects = varobjs;
        end
        
        %%
        function ch = GetChannel(obj, msgid)
            %msgid could be 0xXXX string, or numeric value
            if isempty(obj.Channel)
                ch = [];
            else
                if ischar(msgid)
                    msgid = regexprep(msgid, '^0x','');
                    ch = obj.ChannelInfo(cellfun(@(chmsgids)ismember(msgid, chmsgids), obj.ChannelInfo(:,3)'), 1)';
                else
                    ch = obj.ChannelInfo(cellfun(@(chmsgids)ismember(msgid, chmsgids), obj.ChannelInfo(:,2)'), 1)';
                end
                if isnumeric(obj.Channel)
                    ch = cell2mat(ch);
                end
            end
        end
    end

end