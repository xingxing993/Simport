classdef SimportFileBMLOG < SimportCANFile
    
    properties

    end
    
    methods
        %% Construction
        function obj = SimportFileBMLOG(varargin)
            obj.FileName = varargin{1};
            obj.LoadFile;
            obj.UpdateVarObjects;
            obj.VarList = {obj.VarObjects.Name}';
            [obj.VarObjects.Descriptor] = deal('CAN_BMLOG');
        end
        %% BLF File
        function LoadFile(obj)
            fid = fopen(obj.FileName,'r');
            hwtbar = waitbar(0, 'Processing BUSMASTER LOG File...');
            fileinfo = dir(obj.FileName);
            % Initialize
            BUFLEN = 100000;
            bufcnt = BUFLEN;
            msgcnt = 0;
            bufcell = cell(bufcnt, 12); %{time, id, dlc, 8*databytes, reserved}
            wtbcnt = 0;
            wtbprev = 0;
            % begin reading
            while ~feof(fid)
                 % waitbar update
                wtbcnt = wtbcnt+1;
                if wtbcnt==20 % to reduce waitbar refresh frequency save resource
                    wtbarproc = ftell(fid)/fileinfo.bytes;
                    wtbcnt = 0;
                    if wtbarproc-wtbprev>0.01 % to reduce waitbar refresh frequency save resource
                        waitbar(wtbarproc*0.9, hwtbar, 'Processing...');
                        wtbprev = wtbarproc;
                    end
                end
                
                lnstr = fgetl(fid);
                if strncmp(lnstr,'***',3) % comment line
                    continue;
                elseif isempty(strrep(lnstr, ' ', '')) % empty line
                    continue;
                else
                    msgcnt = msgcnt+1;
                    if msgcnt>bufcnt
                        bufcnt = bufcnt+BUFLEN;
                        bufcell = [bufcell; cell(BUFLEN,size(bufcell,2))];
                    end
                    lncell = regexp(lnstr,'\s+','split');
                    bufcell{msgcnt,1} = lncell{1}; % time stamp
                    bufcell{msgcnt,2} = lncell{4}; % message id
                    bufcell{msgcnt,3} = lncell{6}; % dlc
                    bufcell(msgcnt,4:4+numel(lncell(7:end))-1) = lncell(7:end); % data bytes
                end
            end
            fclose(fid);
            bufcell(msgcnt+1:end,:)=[]; % remove unused buffer
            
            obj.TimeStamp = cellfun(@(tstr)datevec(datenum(tstr, 'HH:MM:SS:FFF'))*[0 0 0 3600 60 1]', bufcell(:,1));
            obj.TimeStamp = obj.TimeStamp-obj.TimeStamp(1);% note the offset to zero operation
            obj.MsgID = cellfun(@(idstr)h2dMsgID(strrep(idstr,'0x','')), bufcell(:,2));
            obj.DLC = cellfun(@(idstr)uint8(str2double(idstr)), bufcell(:,3));
            dbytes = bufcell(:,4:11);
            [dbytes{cellfun('isempty', dbytes)}] = deal('00');
            obj.Data = uint8(cellfun(@h2dXX, dbytes));
            obj.MsgCount = numel(obj.MsgID);
            obj.StartTime = obj.TimeStamp(1);
            obj.EndTime = obj.TimeStamp(end);

            close(hwtbar);
        end
    end
    
    
    %% uniform interfaces
    methods

    end
end