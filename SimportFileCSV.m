classdef SimportFileCSV < SimportCANFile
% CSV Format assumption in this script:
% 1. all hex value are in upper case
% 2. message data all have 2-digits hex value
    
    properties

    end
    
    methods
        %% Construction
        function obj = SimportFileCSV(varargin)
            obj.FileName = varargin{1};
            obj.LoadFile;
            obj.UpdateVarObjects;
            obj.VarList = {obj.VarObjects.Name}';
            [obj.VarObjects.Descriptor] = deal('CAN_CSV');
        end
        %% BLF File
        function LoadFile(obj)
            fid = fopen(obj.FileName,'r');
            hwtbar = waitbar(0, 'Processing Vehicle Spy CSV File...');
            fileinfo = dir(obj.FileName);
            % Initialize
            BUFLEN = 100000;
            bufcnt = BUFLEN;
            msgcnt = 0;
            bufcell = cell(bufcnt, 12); %{time, id, dlc, 8*databytes}
            % skip header lines
            lnstr = fgetl(fid);
            while ~strncmp(strtrim(lnstr), '1,',2)
                lnstr = fgetl(fid);
            end
            % process the 1st data line has been read
            lncell = regexp(strtrim(lnstr),',','split');
            msgcnt = 1;
            bufcell{msgcnt,1} = lncell{2}; % time stamp
            bufcell{msgcnt,2} = lncell{10}; % message id
            bufcell{msgcnt,3} = 8-sum(cellfun('isempty',lncell(13:20))); % dlc
            bufcell(msgcnt,4:11) = lncell(13:20); % data bytes
            % begin reading
            wtbcnt = 0;
            wtbprev = 0;
            while ~feof(fid)
                % waitbar update
                wtbcnt = wtbcnt+1;
                if wtbcnt==20 % to reduce waitbar refresh frequency save resource
                    wtbarproc = ftell(fid)/fileinfo.bytes;
                    wtbcnt = 0;
                    if wtbarproc-wtbprev>0.01 % to reduce waitbar refresh frequency save resource
                        waitbar(wtbarproc*0.9, hwtbar, ['Processing...', fileinfo.name]);
                        wtbprev = wtbarproc;
                    end
                end
                
                lnstr = fgetl(fid);
                lncell = regexp(strtrim(lnstr),',','split');
                msgcnt = msgcnt+1;
                if msgcnt>bufcnt
                    bufcnt = bufcnt+BUFLEN;
                    bufcell = [bufcell; cell(BUFLEN,size(bufcell,2))];
                end
                bufcell{msgcnt,1} = lncell{2}; % time stamp
                bufcell{msgcnt,2} = lncell{10}; % message id
                bufcell{msgcnt,3} = 8-sum(cellfun('isempty',lncell(13:20))); % dlc
                bufcell(msgcnt,4:11) = lncell(13:20); % data bytes
            end
            fclose(fid);
            bufcell(msgcnt+1:end,:)=[]; % remove unused buffer
            
            
            obj.TimeStamp = cellfun(@str2double, bufcell(:,1));
            waitbar(0.93, hwtbar, 'Post processing...');
            obj.MsgID = cellfun(@(idstr)h2dMsgID(idstr), bufcell(:,2));
            waitbar(0.94, hwtbar, 'Post processing...');
            obj.DLC = uint8([bufcell{:,3}]');
            waitbar(0.96, hwtbar, 'Post processing...');
            dbytes = bufcell(:,4:11);
            [dbytes{cellfun('isempty', dbytes)}] = deal('00');
            obj.Data = uint8(cellfun(@h2dXX, dbytes));
            waitbar(0.98, hwtbar, 'Post processing...');
            obj.MsgCount = numel(obj.MsgID);
            waitbar(1, hwtbar, 'Post processing...');

            close(hwtbar);
        end
    end
    
    
    %% uniform interfaces
    methods

    end
end