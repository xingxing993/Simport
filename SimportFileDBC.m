classdef SimportFileDBC < SimportFile
% CSV Format assumption in this script:
% 1. all hex value are in upper case
% 2. message data all have 2-digits hex value
    
    properties
        DataFile %SimoportFile object
        SignalList = []
        dbcInfo
    end
    
    methods
        %% Construction
        function obj = SimportFileDBC(varargin)
            obj.FileName = varargin{1};
            obj.dbcInfo = dbcparse(obj.FileName);
            % create signal list with message id stored for each
            for i=1:numel(obj.dbcInfo.Message)
               msgsigs =  [obj.dbcInfo.Message(i).Signals]';
               [msgsigs.MsgID] = deal(obj.dbcInfo.Message(i).ID);
               obj.SignalList = [obj.SignalList; msgsigs];
            end
            if nargin<2
                [datafilename, datafilepath] = uigetfile( ...
                    {'*.blf;*asc','Vector CAN Binary Log File(*.blf) or ASC log(*.asc)'; ...
                    '*.vsb;*csv','Interpidcs Vehicle Spy Binary(*.vsb) or CSV log(*.csv)'; ...
                    '*.log','BusMaster CAN Log File(*.log)';}, ...
                    'Select data file associated with the dbc');
                 if isequal(datafilename,0) || isequal(datafilepath,0)
                     error('A CAN data file must be associated with the dbc file');
                 end
                 datafile = fullfile(datafilepath, datafilename);
            else
                datafile = varargin{2};
            end
            obj.DataFile = simport_filedispatcher(datafile);
            obj.UpdateVarObjects;
            obj.VarList = {obj.VarObjects.Name}';
        end
       %% GetVar
        function varobjs = GetVar(obj, varnames)
            varnames = cellstr(varnames);
            [~, ia] = intersect(obj.VarList, varnames);
            varobjs = obj.VarObjects(ia);
        end
        %% GetVarList
        function UpdateVarObjects(obj, varargin)
            varobjs = [];
            interpmethod = {'zoh','linear'};
            for i=1:numel(obj.SignalList)
                sigobj = SimportVariable(...
                    obj.SignalList(i).Name,... %name
                    obj.FileName,...
                    interpmethod{(obj.SignalList(i).SignalSize<5)+1},... % interpolation method, consider num of bits<5 as boolean or enumeration signals
                    1,... % dimension
                    [],... %sample rate
                    'DBC');
                sigobj.UserData.Type = 'dbc Signal';
                sigobj.UserData.Message = ['0x',dec2hex(obj.SignalList(i).MsgID)];
                sigobj.UserData.dbcInfo = obj.SignalList(i);
                varobjs = [varobjs; sigobj];
            end
            [varobjs.Descriptor] = deal('CAN_DBC');
            % merge dbc file and data file signals
            obj.VarObjects = [varobjs;obj.DataFile.VarObjects];
        end
        %%
        function LoadData(obj, varnames)
            varnames = cellstr(varnames);
            % first load can raw message signals involved
            canmsgidx = strncmp(varnames, '0x', 2); % split CAN raw message signals, dbc signal cannot start with number
            obj.DataFile.LoadData(varnames(canmsgidx));
            % then process dbc signals
            dbcsigs = varnames(~canmsgidx);
            % first load message to prepare data
            varobjs = GetVar(obj, dbcsigs);
            dbcrelativemsgs = unique(arrayfun(@(v)v.UserData.Message, varobjs, 'UniformOutput', false));
            obj.DataFile.LoadData(dbcrelativemsgs);
            fun_intel2motorola_bitpos = @(intelpos)floor(intelpos/8)*16+7-intelpos; % convert start bit to Byte0-Bit7, and end bit to Byte7-Bit0
            for i=1:numel(varobjs)
%                 if ~isempty(varobjs(i).Data)
%                     continue;
%                 end
                siginfo = varobjs(i).UserData.dbcInfo;
                msgvarobj = obj.GetVar(varobjs(i).UserData.Message);
                msgdata = uint8(msgvarobj.Data); % must be uint8 type
                % CONVERT TO PHYSICAL VALUE
                if mod(siginfo.SignalSize,8)==0 && mod(siginfo.StartBit,8)~=0
                    nbytes = ceil(siginfo.SignalSize/8)+1;
                else
                    nbytes = ceil(siginfo.SignalSize/8);
                end
                startbyte = floor(siginfo.StartBit/8); % zero index
                if nbytes==1 % use original info for signal in one byte
                    bitmsk = bitand(...
                        bitshift(uint8(255), siginfo.StartBit),...
                        bitshift(uint8(255), siginfo.StartBit+siginfo.SignalSize-8)...
                        );
                    sigrawval = bitand(msgdata(:,startbyte+1), bitmsk);
                else
                    msgdata(:,[1:startbyte, (startbyte+1+nbytes):end]) = []; % remove unnecessary data
                    validbitdigit = 8*ones(1, size(msgdata,2));
                    if siginfo.ByteOrder==1  % intel format, high byte MSB (seems the definitoin in the DBC format specification file is wrong)
                        startbit = siginfo.StartBit; % start bit is lsb for intel format
                    else % motorola format, low byte MSB
                        % translate to different bit sequence system to
                        % facilitate later calculation
                        startbit = fun_intel2motorola_bitpos(siginfo.StartBit);
                    end
                    endbit = startbit+siginfo.SignalSize-1;
                    validbitdigit(1)=8-mod(startbit, 8);
                    validbitdigit(end)=mod(endbit, 8)+1;
                    if siginfo.ByteOrder==0 % motorola
                        msgdata = fliplr(msgdata);
                        validbitdigit = fliplr(validbitdigit);
                    end
                    tmppwrdigit = [0, validbitdigit(1:end-1)];
                    pwrdigit = arrayfun(@(n)sum(tmppwrdigit(1:n)), 1:numel(tmppwrdigit)); % bit weight
                    msgdata(:,1) = bitshift(msgdata(:,1), validbitdigit(1)-8);
                    msgdata(:,end) = bitand(msgdata(:,end), bitshift(uint8(255), validbitdigit(end)-8));
                    sigrawval = double(msgdata)*(2.^pwrdigit)';
                end
                sigval = sigrawval*siginfo.Factor + siginfo.Offset;
                % CONVERT TO PHYSICAL VALUE END
                varobjs(i).Time = msgvarobj.Time;
                varobjs(i).Data = sigval;
            end
        end
    end

end
