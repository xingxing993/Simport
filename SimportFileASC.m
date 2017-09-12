classdef SimportFileASC < SimportCANFile
% ASC Format assumption in this script:
% 1. all hex value are in upper case
% 2. message data all have 2-digits hex value
    
    properties

    end
    
    methods
        %% Construction
        function obj = SimportFileASC(varargin)
            obj.FileName = varargin{1};
            obj.LoadFile;
            obj.UpdateVarObjects;
            obj.VarList = {obj.VarObjects.Name}';
            [obj.VarObjects.Descriptor] = deal('CAN_ASC');
        end
        %% BLF File
        function LoadFile(obj)
            fid = fopen(obj.FileName,'r');
            hwtbar = waitbar(0, 'Processing VECTOR ASC File...');
            fileinfo = dir(obj.FileName);
            % Initialize
            BUFLEN = 100000;
            bufcnt = BUFLEN;
            msgcnt = 0;
            bufcell = cell(bufcnt, 12); %{time, id, dlc, 8*databytes, reserved}
            fgetl(fid); % 1st line
            lnstr = fgetl(fid); % 2nd line
            timeformat = regexp(lnstr, 'timestamps\s+(\w+)','tokens','once');
            timeformat = timeformat{1};
            fgetl(fid); % 3rd line
            fgetl(fid); % 4th line
            fgetl(fid); % 5th line
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
                        waitbar(wtbarproc*0.9, hwtbar, 'Processing...');
                        wtbprev = wtbarproc;
                    end
                end
                
                lnstr = fgetl(fid);
                lncell = regexp(strtrim(lnstr),'\s+','split');
                if numel(lncell)<7
                    continue;
                elseif ~all(lncell{2}>='0' & lncell{2}<='9') % if 2nd field is not integer (channel)
                    continue;
                else
                    tmps = strrep(lncell{3}, 'x', '');
                    if ~all((tmps>='0'&tmps<='9')|(tmps>='A'&tmps<='F')|(tmps>='a'&tmps<='f')) % 3rd cell not can message id
                            continue;
                    else
                        msgcnt = msgcnt+1;
                        if msgcnt>bufcnt
                            bufcnt = bufcnt+BUFLEN;
                            bufcell = [bufcell; cell(BUFLEN,size(bufcell,2))];
                        end
                        bufcell{msgcnt,1} = lncell{1}; % time stamp
                        bufcell{msgcnt,2} = lncell{3}; % message id
                        bufcell{msgcnt,3} = lncell{6}; % dlc
                        bufcell(msgcnt,4:4+numel(lncell(7:end))-1) = lncell(7:end); % data bytes
                    end
                end
            end
            fclose(fid);
            bufcell(msgcnt+1:end,:)=[]; % remove unused buffer
            obj.TimeStamp = cellfun(@str2double, bufcell(:,1));
            waitbar(0.92, hwtbar, 'Post processing...');
            if strcmp(timeformat, 'relative')
                obj.TimeStamp(1) = 0;
                for i=2:numel(obj.TimeStamp)
                    obj.TimeStamp(i) = obj.TimeStamp(i-1)+obj.TimeStamp(i);
                end
            else % absolute
                obj.TimeStamp = obj.TimeStamp-obj.TimeStamp(1);% note the offset to zero operation
            end
            waitbar(0.93, hwtbar, 'Post processing...');
            obj.MsgID = cellfun(@(idstr)h2dMsgID(strrep(idstr,'x','')), bufcell(:,2));
            waitbar(0.94, hwtbar, 'Post processing...');
            obj.DLC = cellfun(@(idstr)uint8(str2double(idstr)), bufcell(:,3));
            waitbar(0.96, hwtbar, 'Post processing...');
            dbytes = bufcell(:,4:11);
            [dbytes{cellfun('isempty', dbytes)}] = deal('00');
            obj.Data = uint8(cellfun(@h2dXX, dbytes));
            waitbar(0.98, hwtbar, 'Post processing...');
            obj.MsgCount = numel(obj.MsgID);
            obj.StartTime = obj.TimeStamp(1);
            obj.EndTime = obj.TimeStamp(end);
            waitbar(1, hwtbar, 'Post processing...');

            close(hwtbar);
        end
    end
    
    
    %% uniform interfaces
    methods

    end
end