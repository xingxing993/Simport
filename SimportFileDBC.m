classdef SimportFileDBC < SimportCANFile
% CSV Format assumption in this script:
% 1. all hex value are in upper case
% 2. message data all have 2-digits hex value
    
    properties
        DataFileName
        dbcSignalList = []
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
               if isempty(msgsigs)
                   continue;
               end
               [msgsigs.MsgID] = deal(obj.dbcInfo.Message(i).ID);
               obj.dbcSignalList = [obj.dbcSignalList; msgsigs];
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
            obj.AttachDataFile(datafile);
        end
       %% GetVar
        function varobjs = GetVar(obj, varnames)
            varnames = cellstr(varnames);
            [~, ia] = intersect(obj.VarList, varnames);
            varobjs = obj.VarObjects(ia);
        end
        %% GetVarList
        function UpdateVarObjects(obj, varargin)
            datafileobj = varargin{1};
            varobjs = [];
            interpmethod = {'zoh','linear'};
            for i=1:numel(obj.dbcSignalList)
                sigobj = SimportVariable(...
                    obj.dbcSignalList(i).Name,... %name
                    obj.FileName,...
                    interpmethod{(obj.dbcSignalList(i).SignalSize<5)+1},... % interpolation method, consider num of bits<5 as boolean or enumeration signals
                    1,... % dimension
                    [],... %sample rate
                    'DBC');
                sigobj.UserData.Type = 'dbc Signal';
                sigobj.UserData.Message = ['0x',dec2hex(obj.dbcSignalList(i).MsgID)];
                sigobj.UserData.dbcInfo = obj.dbcSignalList(i);
                varobjs = [varobjs; sigobj];
            end
            [varobjs.Descriptor] = deal('CAN_DBC');
            % merge dbc file and data file signals
            obj.VarObjects = [varobjs;datafileobj.VarObjects];
        end
        %%
        function LoadData(obj, varnames, reloadflg, channel)
            if nargin<4
                channel = [];
            end
            if nargin<3
                reloadflg = false;
            end
            varnames = cellstr(varnames);
            % first load can raw message signals involved
            canmsgidx = strncmp(varnames, '0x', 2); % split CAN raw message signals, dbc signal cannot start with number
            LoadData@SimportCANFile(obj, varnames(canmsgidx), false, channel);
            % then process dbc signals
            dbcsigs = varnames(~canmsgidx);
            % first load message to prepare data
            varobjs = GetVar(obj, dbcsigs);
            varrelativemsgs = unique(arrayfun(@(v)v.UserData.Message, varobjs, 'UniformOutput', false));
            LoadData@SimportCANFile(obj,varrelativemsgs, false, channel);
            % begin to convert message data to physical value
            fun_intel2motorola_lsbbit = @(intelpos)floor(intelpos/8)*16+7-intelpos; % convert start bit to Byte0-Bit7, and end bit to Byte7-Bit0
            fun_getmotorola_msbbit = @(lsbbit,sz) (lsbbit+sz-1)-2*(floor((lsbbit+sz-1)/8)-floor(lsbbit/8))*8;
            for i=1:numel(varobjs)
                if ~isempty(varobjs(i).Time) && ~reloadflg % if already loaded, return
                    continue;
                end
                siginfo = varobjs(i).UserData.dbcInfo;
                msgvarobj = obj.GetVar(varobjs(i).UserData.Message);
                msgdata = uint8(msgvarobj.Data); % must be uint8 type
                if siginfo.ByteOrder==1  % intel format, high byte MSB (seems the definitoin in the DBC format specification file is wrong)
                    lsbbit = siginfo.StartBit; % start bit is lsb for intel format
                    msbbit = lsbbit+siginfo.SignalSize-1;
                else % motorola format, low byte MSB
                    % translate to different bit sequence system to
                    % facilitate later calculation
                    lsbbit = fun_intel2motorola_lsbbit(siginfo.StartBit);
                    msbbit = fun_getmotorola_msbbit(lsbbit, siginfo.SignalSize);
                end
                
                % CONVERT TO PHYSICAL VALUE
                nbytes = abs(floor(msbbit/8)-floor(lsbbit/8))+1;
                startbyte = floor(siginfo.StartBit/8); % zero based index
                if nbytes==1 % use original info for signal in one byte
                    sigrawval = double(bitshift(...
                        bitand(msgdata(:,startbyte+1), bitshift(uint8(255), mod(msbbit,8)-7))...
                            , -1*mod(lsbbit,8)));
                else
                    msgdata(:,[1:startbyte, (startbyte+1+nbytes):end]) = []; % remove unnecessary data
                    validbitdigit = 8*ones(1, size(msgdata,2));
                    validbitdigit(1)=8-mod(lsbbit, 8);
                    validbitdigit(end)=mod(msbbit, 8)+1;
                    if siginfo.ByteOrder==0 % motorola
                        msgdata = fliplr(msgdata);
                        validbitdigit = fliplr(validbitdigit);
                    end
                    tmppwrdigit = [0, validbitdigit(1:end-1)];
                    pwrdigit = cumsum(tmppwrdigit); % bit weight
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
       %%
        function AttachDataFile(obj, datafile)
            obj.DataFileName = datafile;
            datafileobj = simport_filedispatcher(datafile);
            % manual copy properties
            obj.MsgCount = datafileobj.MsgCount;
            obj.MsgID = datafileobj.MsgID;
            obj.TimeStamp = datafileobj.TimeStamp;
            obj.DLC = datafileobj.DLC;
            obj.Data = datafileobj.Data;
            obj.StartTime = datafileobj.StartTime;
            obj.EndTime = datafileobj.EndTime;
            % merge variable objects and list
            obj.UpdateVarObjects(datafileobj);
            obj.VarList = {obj.VarObjects.Name}';
        end
    end
    
    methods
        
    end

end
