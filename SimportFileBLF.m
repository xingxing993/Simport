classdef SimportFileBLF < SimportCANFile
    
    properties

    end
    
    methods
        %% Construction
        function obj = SimportFileBLF(varargin)
            obj.FileName = varargin{1};
            obj.LoadFile;
            if isempty(obj.Data)
                return;
            end
            obj.UpdateVarObjects;
            obj.VarList = {obj.VarObjects.Name}';
            [obj.VarObjects.Descriptor] = deal('CAN_BLF');
        end
        %% BLF File
        function LoadFile(obj)
            [bytes,msgids,channls,timestamps]=simblfextractor(obj.FileName, 1);
            obj.Data = bytes';
            obj.MsgID = msgids';
            obj.Channel = channls';
            obj.TimeStamp = timestamps';
%             obj.DLC=[]; %not extracted
            obj.MsgCount = numel(obj.MsgID);
            
        end
        

%% BLF Load m-file version, replaced by faster mex version
%         %% BLF File
%         function LoadFile(obj)
%             fid_blf = fopen(obj.FileName,'r');
%             filehdr = fread(fid_blf, 144, '*uint8'); % file header
%             if ~strcmp(char(filehdr(1:4))', 'LOGG')
%                 error('The file is not valid Vector BLF format');
%             end
%             fileinfo = dir(obj.FileName);
%             hwtbar = waitbar(0, 'Processing BLF File...');
%             % INITIALIZE VARIABLES
%             BUFLEN = 200000;
%             CANOBJSIZE = 0;
%             TIME_UNIT = 0;
%             HEADER_SIZE = 0;
%             bufcnt = BUFLEN;
%             tail = []; % to contain the remaining incomplete bytes in LOG_CONTAINER, which intends to be joined with the next LOG_CONTAINER object
%             msgcnt = 0;
%             obj.MsgID = zeros(bufcnt,1,'uint32'); % ID, TIME, DLC, DATA[8] initalize
%             timestamp = zeros(bufcnt,8,'uint8');
%             obj.DLC = zeros(bufcnt,1,'uint8');
%             obj.Data = zeros(bufcnt,8,'uint8');
%             while ~feof(fid_blf)
%                 waitbar(ftell(fid_blf)/fileinfo.bytes, hwtbar, ['Processing...', fileinfo.name]);
%                 % --------------VBLObjectHeaderBase------------
%                 objhdrbase = fread(fid_blf, 16, '*uint8'); %sizeof(VBLObjectHeaderBase)=16
%                 if isempty(objhdrbase)
%                     break;
%                 end
%                 if ~strcmp(char(objhdrbase(1:4))', 'LOBJ')
%                     if all(objhdrbase==0) % trailing padding bytes
%                         continue;
%                     else
%                         error('The file is not valid Vector BLF format');
%                     end
%                 end
%                 % Assume this file uses single type of Header, the subsequent headers
%                 % will be bypassed to improve code efficiency
%                 % Header size is 40 (16base+24) bytes for header version 2 (VBLObjectHeader2)
%                 % Header size is 32 (16base+16)bytes for header version 1 (VBLObjectHeader)
%                 if HEADER_SIZE==0
%                     hdrver = sum(bitshift(uint16(objhdrbase(7:8)), [0 8]'));
%                     if hdrver==2
%                         HEADER_SIZE = 40;
%                     else
%                         HEADER_SIZE = 32;
%                     end
%                 end
%                 objsize = sum(bitshift(uint32(objhdrbase(9:12)), [0 8 16 24]'));
%                 objtype = sum(bitshift(uint32(objhdrbase(13:16)), [0 8 16 24]'));
%                 % --------------VBLObjectHeader(2) remaining------------
%                 objhdrext = fread(fid_blf, HEADER_SIZE-16); % continue to read in entire object header
%                 if TIME_UNIT==0
%                     objflags = sum(bitshift(uint32(objhdrext(1:4)), [0 8 16 24]'));
%                     if objflags == 1 % BL_OBJ_FLAG_TIME_TEN_MICS
%                         TIME_UNIT = 1e-5;
%                     elseif objflags == 2 % BL_OBJ_FLAG_TIME_ONE_NANS
%                         TIME_UNIT = 1e-9;
%                     else
%                         TIME_UNIT = 1e-9; % by default
%                     end
%                 end
%                 % -------------Object Data--------------------------
%                 log_data = fread(fid_blf, objsize-32);
%                 fread(fid_blf, rem(objsize-32, 4)); % read padding bytes
%                 
%                 if objtype == 10 % BL_OBJ_TYPE_LOG_CONTAINER
%                     obj_data = zlibdecode(uint8(log_data)); % decode zlib compress
%                     obj_data = [tail, obj_data]; % add tail from previous container object
%                     ptr = 1; % initialize pointer
%                     while ptr < numel(obj_data)-HEADER_SIZE
%                         objhdrbase = obj_data(ptr:ptr+15);
%                         % mObjectType shall be DWORD, but according to binlog.h the
%                         % value doesn't exceed 255, so take only the LSB byte may work well
%                         objtype = objhdrbase(13);
%                         
%                         if objtype==1 %BL_OBJ_TYPE_CAN_MESSAGE
%                             if CANOBJSIZE==0
%                                 % assume only single CAN_MESSAGE type used in this
%                                 % file, calculate the object size only once to avoid operation in every cycle
%                                 objsize = sum(bitshift(uint32(objhdrbase(9:12)), [0 8 16 24]));
%                                 CANOBJSIZE = objsize;
%                             else
%                                 objsize = CANOBJSIZE;
%                             end
%                             if ptr+objsize-1>numel(obj_data)
%                                 break;
%                             end
%                             canmsginfo = obj_data(ptr+HEADER_SIZE:ptr+CANOBJSIZE-1);
%                             id = bitand(sum(bitshift(uint32(canmsginfo(5:8)), [0 8 16 24])), uint32(536870911)); % 0b11111111111111111111111111111 is 536870911
%                             dlc = canmsginfo(4);
%                             candata = canmsginfo(9:16);
%                             % add to buffer
%                             msgcnt = msgcnt+1;
%                             if msgcnt>bufcnt
%                                 bufcnt = bufcnt+BUFLEN;
%                                 obj.MsgID = [obj.MsgID; zeros(BUFLEN,1,'uint32')]; % ID, TIME, DLC, DATA[8] initalize
%                                 timestamp = [timestamp; zeros(BUFLEN,8,'uint8')];
%                                 obj.DLC = [obj.DLC; zeros(BUFLEN,1,'uint8')];
%                                 obj.Data = [obj.Data; zeros(BUFLEN,8,'uint8')];
%                             end
%                             obj.MsgID(msgcnt) = id;
%                             timestamp(msgcnt,:) = obj_data(ptr-1+(25:32));
%                             obj.DLC(msgcnt) = dlc;
%                             obj.Data(msgcnt,:) = candata;
%                         else % Type other than CAN_MESSAGE
%                             objsize = sum(bitshift(uint32(objhdrbase(9:12)), [0 8 16 24]));
%                             if ptr+objsize-1>numel(obj_data)
%                                 break;
%                             end
%                         end
%                         ptr = ptr + objsize;
%                         ptr = ptr + rem(objsize,4); % increment of padding bytes
%                     end
%                     tail = obj_data(ptr:end);
%                 end
%             end
%             obj.MsgID(msgcnt+1:end)=[];
%             obj.DLC(msgcnt+1:end)=[];
%             obj.Data(msgcnt+1:end,:)=[];
%             timestamp(msgcnt+1:end,:)=[];
%             % convert time to phyisical value
%             obj.TimeStamp = double(timestamp)*(2.^(0:8:56)');
%             obj.TimeStamp = obj.TimeStamp*TIME_UNIT;
%             obj.MsgCount = numel(obj.MsgID);
%             fclose(fid_blf);
%             close(hwtbar);
%         end
        
        
        
    end
    
    
    %% uniform interfaces
    methods

    end
end