classdef SimportFileVSB < SimportCANFile
% Target VSB version 0x102
    properties

    end
    
    methods
        %% Construction
        function obj = SimportFileVSB(varargin)
            obj.FileName = varargin{1};
            obj.LoadFile;
            obj.UpdateVarObjects;
            obj.VarList = {obj.VarObjects.Name}';
            [obj.VarObjects.Descriptor] = deal('CAN_VSB');
        end
        %% BLF File
        function LoadFile(obj)
            fid = fopen(obj.FileName,'r');
            hwtbar = waitbar(0, 'Processing Vehicle Spy VSB File...');
            fileinfo = dir(obj.FileName);
            % INITIALIZE VARIABLES
            MSGNUM = floor((fileinfo.bytes - 10)/64);
            TIME_UNIT = 0.25e-7;
            msgcnt = 0;
            vsbbuf = zeros(MSGNUM, 21, 'uint8');

            wtbcnt = 0;
            wtbprev = 0;
            % begin reading file
            fread(fid,6); % 'icsbin'
            fread(fid,4); % icsversion: 0x102
            while ~feof(fid)
                % waitbar update
                wtbcnt = wtbcnt+1;
                if wtbcnt==20 % to reduce waitbar refresh frequency save resource
                    wtbarproc = ftell(fid)/fileinfo.bytes;
                    wtbcnt = 0;
                    if wtbarproc-wtbprev>0.01 % to reduce waitbar refresh frequency save resource
                        waitbar(wtbarproc, hwtbar, ['Processing...', fileinfo.name]);
                        wtbprev = wtbarproc;
                    end
                end
                
                msgblk = fread(fid,64,'*uint8');
                if ~isempty(msgblk)
                    msgcnt = msgcnt + 1;
                    vsbbuf(msgcnt,:) = msgblk([9:16, 33, 37:40, 41:48]); % Time, DLC, ID, DATA
                end
            end
            fclose(fid);
            % data post process
            obj.TimeStamp = double(vsbbuf(:,1:8))*(2.^(0:8:56)')*TIME_UNIT;
            obj.MsgID = double(vsbbuf(:,10:13))*(2.^(0:8:24)');
            obj.DLC = vsbbuf(:,9);
            obj.Data = vsbbuf(:,14:21);
            obj.MsgCount = numel(obj.MsgID);

            close(hwtbar);
        end
    end
    
    
    %% uniform interfaces
    methods

    end
end