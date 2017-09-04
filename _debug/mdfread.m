function [data, signalNames]=mdfread(file,dataBlock,varagin)
% MDFREAD Reads MDF file and returns all the channels and signal names of
% one data group in an MDF file.
%
%   DATA = MDFREAD(FILENAME,DATAGROUP) returns in the cell array DATA, all channels
%   from data group DATAGROUP from the file FILENAME.
%
%   DATA = MDFREAD(MDFINFO,DATAGROUP) returns in the cell array DATA,  all channels
%   from data group DATAGROUP from the file whos information is in the data
%   structure MDFINFO returned from the function MDFINFO.
%
%
%   [..., SIGNALNAMES] = MDFREAD(...) Creates a cell array of signal names
%   (including time).
%
%    Example 1:
%
%             %  Retrieve info about DICP_V6_vehicle_data.dat
%             [data signaNames]= mdfread('DICP_V6_vehicle_data.dat');


%% Assume for now only sorted files supported
channelGroup=1;

%% Get MDF structure info
if ischar(file)
    fileName=file;
    [MDFsummary MDFInfo]=mdfinfo(fileName);
else
    MDFInfo=file;
end

numberOfChannels=double(MDFInfo.DGBlock(dataBlock).CGBlock(channelGroup).numberOfChannels);
numberOfRecords= double(MDFInfo.DGBlock(dataBlock).CGBlock(channelGroup).numberOfRecords);

if nargin==3
    selectedChannels=varagin; % Define channel selection vector
    if any(selectedChannels>numberOfChannels)
        error('Select channel out of range');
    end
end

if numberOfRecords==0 % If no data record, ignore
    warning(['No data records in block ' int2str(dataBlock) ]);
    data=cell(1); % Return empty cell
    signalNames=''; % Return empty cell
    return
end

%% Set pointer to start of data
offset=MDFInfo.DGBlock(dataBlock).pointerToDataRecords; % Get pointer to start of data block

%% Create channel format cell array
for channel=1:numberOfChannels
    numberOfBits= MDFInfo.DGBlock(dataBlock).CGBlock(channelGroup).CNBlock(channel).numberOfBits;
    signalDataType= MDFInfo.DGBlock(dataBlock).CGBlock(channelGroup).CNBlock(channel).signalDataType;
    datatype=datatypeformat(signalDataType,numberOfBits); %Get signal data type (e.g. 'int8')
    if signalDataType==7 % If string
        channelFormat(channel,:)={datatype [1 double(numberOfBits)/8] ['channel' int2str(channel)]};
    else
        channelFormat(channel,:)={datatype [1 1] ['channel' int2str(channel)]};
    end
end

%% Check for multiple record IDs
numberOfRecordIDs=MDFInfo.DGBlock(dataBlock).numberOfRecordIDs; % Number of RecordIDs
if numberOfRecordIDs==1 % Record IDs
    channelFormat=[ {'uint8' [1 1] 'recordID1'} ; channelFormat]; % Add column to start get record IDs
elseif numberOfRecordIDs==2
    error('2 record IDs Not suported')
    %channelFormat=[ channelFormat ; {'uint8' [1 1] 'recordID2'}]; % Add column to end get record IDs
end

%% Check for time channel
timeChannel=findtimechannel(MDFInfo.DGBlock(dataBlock).CGBlock(channelGroup).CNBlock);

if length(timeChannel)~=1
    error('More than one time channel in data block');
end

%% Open File
fid=fopen(MDFInfo.fileName,'r');
if fid==-1
    error(['File ' MDFInfo.fileName ' not found']);
end

%% Read data

% Set file pointer to start of channel data
fseek(fid,double(offset),'bof');

if ~exist('selectedChannels','var')
    if numberOfRecordIDs==1 % If record IDs are used (unsorted)
        Blockcell = mdfchannelread(channelFormat,fid,numberOfRecords); % Read all
        recordIDs=Blockcell(1);         % Extract Record IDs
        Blockcell(1)=[];                % Delete record IDs
        selectedChannels=1:numberOfChannels; % Set selected channels
    else
        Blockcell = mdfchannelread(channelFormat,fid,numberOfRecords); % Read all
        selectedChannels=1:numberOfChannels; % Set selected channels
    end
else % if selectedChannels exists
    if numberOfRecordIDs==1  % If record IDs are used (unsorted)
        % Add Record ID column no mater the orientation of selectedChannels
        newSelectedChannels(2:length(selectedChannels)+1)=selectedChannels+1; % Shift
        newSelectedChannels(1)=1; % Include first channel of Record IDs
        Blockcell = mdfchannelread(channelFormat,fid,numberOfRecords,newSelectedChannels);
        recordIDs=Blockcell(1);         % Extract Record IDs, for future expansion
        Blockcell(1)=[];                % Delete record IDs,  for future expansion
    else
        Blockcell = mdfchannelread(channelFormat,fid,numberOfRecords,selectedChannels);
    end
end

% Cloce file
fclose(fid);

% Preallocate
data=cell(1,length(selectedChannels)); % Preallocate cell array for channels

% Extract data
for selectedChannel=1:length(selectedChannels)
    channel=selectedChannels(selectedChannel); % Get delected channel
    
    % Get signal names
    longSignalName=MDFInfo.DGBlock(dataBlock).CGBlock(channelGroup).CNBlock(channel).longSignalName;
    if ~isempty(longSignalName) % if long signal name is not empty use it
        signalNames{selectedChannel,1}=longSignalName; % otherwise use signal name
    else
        signalNames{selectedChannel,1}=MDFInfo.DGBlock(dataBlock).CGBlock(channelGroup).CNBlock(channel).signalName;
    end

    if MDFInfo.DGBlock(dataBlock).CGBlock(channelGroup).CNBlock(channel).signalDataType==7
        % Strings: Signal Data Type 7
        data{selectedChannel}=truncintstochars(Blockcell{selectedChannel}); % String
    elseif MDFInfo.DGBlock(dataBlock).CGBlock(channelGroup).CNBlock(channel).signalDataType==8
        % Byte arrays: Signal Data Type 8
        error('MDFReader:signalType8','Signal data type 8 (Byte array) not currently supported');
        
%     elseif MDFInfo.DGBlock(dataBlock).CGBlock(channelGroup).CNBlock(channel).valueRangeKnown % If physical value is correct...
%         % No need for conversion formula
%         data{selectedChannel}=double(Blockcell{selectedChannel});
    else
        % Other data types: Signal Data Type 0,1,2, or 3
        
        % Get conversion formula type
        conversionFormulaIdentifier=MDFInfo.DGBlock(dataBlock).CGBlock(channelGroup).CNBlock(channel).CCBlock.conversionFormulaIdentifier;

        % Based on each convwersion fourmul type...
        switch conversionFormulaIdentifier
            case 0 % Parameteric, Linear: Physical =Integer*P2 + P1
                
                % Extract coefficients from data structure
                P1=MDFInfo.DGBlock(dataBlock).CGBlock(channelGroup).CNBlock(channel).CCBlock.P1;
                P2=MDFInfo.DGBlock(dataBlock).CGBlock(channelGroup).CNBlock(channel).CCBlock.P2;
                int=double(Blockcell{selectedChannel});
                data{selectedChannel}=int.*P2 + P1;
                
            case 1 % Tabular with interpolation
                
                % Extract look-up table from data structure                
                int_table=MDFInfo.DGBlock(dataBlock).CGBlock(channelGroup).CNBlock(channel).CCBlock.int;
                phys_table=MDFInfo.DGBlock(dataBlock).CGBlock(channelGroup).CNBlock(channel).CCBlock.phys;
                int=Blockcell{selectedChannel};
                data{selectedChannel}=interptable(int_table,phys_table,int);

            case 2 % Tabular
                
                % Extract look-up table from data structure
                int_table=MDFInfo.DGBlock(dataBlock).CGBlock(channelGroup).CNBlock(channel).CCBlock.int;
                phys_table=MDFInfo.DGBlock(dataBlock).CGBlock(channelGroup).CNBlock(channel).CCBlock.phys;
                int=Blockcell{selectedChannel};
                data{selectedChannel}=floortable(int_table,phys_table,int);
             
            case 6 % Polynomial
                
                % Extract polynomial coefficients from data structure
                P1=MDFInfo.DGBlock(dataBlock).CGBlock(channelGroup).CNBlock(channel).CCBlock.P1;
                P2=MDFInfo.DGBlock(dataBlock).CGBlock(channelGroup).CNBlock(channel).CCBlock.P2;
                P3=MDFInfo.DGBlock(dataBlock).CGBlock(channelGroup).CNBlock(channel).CCBlock.P3;
                P4=MDFInfo.DGBlock(dataBlock).CGBlock(channelGroup).CNBlock(channel).CCBlock.P4;
                P5=MDFInfo.DGBlock(dataBlock).CGBlock(channelGroup).CNBlock(channel).CCBlock.P5;
                P6=MDFInfo.DGBlock(dataBlock).CGBlock(channelGroup).CNBlock(channel).CCBlock.P6;
                
                int=double(Blockcell{selectedChannel}); % Convert to doubles
                numerator=(P2-P4.*(int-P5-P6)); % Evaluate numerator
                denominator=(P3.*(int-P5-P6)-P1); % Evaluate denominator
                
                 % Avoid divide by zero warnings and return nan
                denominator(denominator==0)=nan; % Set 0's to Nan's
                result=numerator./denominator;

                data{selectedChannel}=result;
                
            case 10 % ASAM-MCD2 Text formula
                textFormula=MDFInfo.DGBlock(dataBlock).CGBlock(channelGroup).CNBlock(channel).CCBlock.textFormula;
                x=double(Blockcell{selectedChannel}); % Assume stringvariable is 'x'
                data{selectedChannel}=eval(textFormula); % Evaluate string
                
            case 65535 % 1:1 conversion formula (Int = Phys)
                data{selectedChannel}=double(Blockcell{selectedChannel});
                
            case {11, 12} % ASAM-MCD2 Text Table or ASAM-MCD2 Text Range Table
                % Return numbers instead of strings/enumeration
                data{selectedChannel}=double(Blockcell{selectedChannel}); 

            otherwise % Un supported conversion formula
               error('MDFReader:conversionFormulaIdentifier','Conversion Formula Identifier not supported'); 

        end
    end
end

function dataType= datatypeformat(signalDataType,numberOfBits)
% DATATYPEFORMAT Data type format precision to give to fread
%   DATATYPEFORMAT(SIGNALDATATYPE,NUMBEROFBITS) is the precision string to
%   give to fread for reading the data type specified by SIGNALDATATYPE and
%   NUMBEROFBITS

switch signalDataType
    
    case 0 % unsigned
        switch numberOfBits
            case 8
                dataType='uint8';
            case 16
                dataType='uint16';
            case 32
                dataType='uint32';
            case 1
                dataType='ubit1';
            case 2
                dataType='ubit2';
            otherwise
                error('Unsupported number of bits for unsigned int');
        end
        
    case 1 % signed int
        switch numberOfBits
            case 8
                dataType='int8';
            case 16
                dataType='int16';
            case 32
                dataType='int32';
            otherwise
                error('Unsupported number of bits for signed int');
        end
        
    case {2, 3} % floating point
        switch numberOfBits
            case 32
                dataType='single';
            case 64
                dataType='double';
            otherwise
                error('Unsupported number of bit for floating point');
        end
        
    case 7 % string
        dataType='uint8';
        
     otherwise
        error('Unsupported Signal Data Type');
end


function Block=mdfchannelread(blockFormat,fid,repeat,varagin)

% Store starting point of file pointer
offset=ftell(fid);

if nargin==4
    selectedChannels=varagin; % Define channel selection vector
end

% Extract parameters
numFields=size(blockFormat,1); % Number of fields
precisions=blockFormat(:,1); % Precisions (data types) of each field

% Number of elements of a data type in one field
% This is only not relevent to one for string arrays

% For R14SP3: counts= cellfun(@max,blockFormat(:,2));
counts=zeros(numFields,1);
for k=1:numFields
    counts(k,1)=max(blockFormat{k,2});
end

% For R14 SP3: numFieldBytes=cellfun(@getsize,precisions).*counts;

% Number of bytes in each field
for k=1:numFields
    numFieldBytes(k,1)=getsize(precisions{k}).*counts(k); % Number of bytes in each field
end

numBlockBytes=sum(numFieldBytes); % Total number of bytes in block
numBlockBytesAligned=ceil(numBlockBytes); % Aligned to byte boundary
cumNumFieldBytes=cumsum(numFieldBytes); % Cumlative number of bytes
startFieldBytes=[0; cumNumFieldBytes]; % Starting number of bytes for each field relative to start

% Preallocate Clock cell array
Block= cell(1,numFields);

% Find groups of fields with the same data type
fieldGroup=1;
numSameFields(fieldGroup)=1;
countsSameFields(fieldGroup)=counts(1);
for field =1:numFields-1
    if strcmp(precisions(field),precisions(field+1))& counts(field)==counts(field+1) % Next field is the same data type
        numSameFields(fieldGroup,1)=numSameFields(fieldGroup,1)+1; % Increment counter

    else
        numSameFields(fieldGroup+1,1)=1; % Set to 1...
        countsSameFields(fieldGroup+1)=counts(field+1);
        fieldGroup=fieldGroup+1; % ...and more to next filed group
    end
end

field=1;
for fieldGroup=1:length(numSameFields)

    % Set pointer to start of fieldGroup
    offsetPointer=offset+startFieldBytes(field);
    fseek(fid,offsetPointer,'bof');

    count=1*repeat; % Number of rows repeated
    precision=precisions{field}; % Extract precision of all channels in field

    % Calculate precision string
    if strcmp(precision, 'ubit1')
        skip=8*(numBlockBytesAligned-getsize(precision)*numSameFields(fieldGroup)); % ensure byte aligned
        precisionString=[int2str(numSameFields(fieldGroup)) '*ubit1=>uint8'];
    elseif strcmp(precision, 'ubit2')
        skip=8*(numBlockBytesAligned-getsizealigned(precision)*numSameFields(fieldGroup)); % ensure byte aligned
        precisionString=[int2str(numSameFields(fieldGroup)) '*ubit2=>uint8']; % TO DO change skip to go to next byte
    else        
        skip=numBlockBytesAligned-getsize(precision)*countsSameFields(fieldGroup)*numSameFields(fieldGroup); % ensure byte aligned
        precisionString=[int2str(numSameFields(fieldGroup)*countsSameFields(fieldGroup)) '*' precision '=>' precision];
    end

    % Read file
    if countsSameFields(fieldGroup)==1  % TO Do remove condistiuon
        data=fread(fid,double(count)*numSameFields(fieldGroup),precisionString,skip);
    else %% string
        % Read in columnwize, ech column is a string lengt - countsSameFields(fieldGroup)
         data=fread(fid,double([countsSameFields(fieldGroup) count*numSameFields(fieldGroup)]),precisionString,skip);   
         data=data';
    end

    % Copy each field from the field group into the cell array
    if numSameFields(fieldGroup)==1
        Block{field}=data;
        field=field+1;
    else
        for k=1:numSameFields(fieldGroup)
            Block{field}=data(k:numSameFields(fieldGroup):end);
            field=field+1;
        end
    end
end
if exist('selectedChannels','var')
    Block=Block(:,selectedChannels);
end

%% Align to start of next row
current=ftell(fid); % Current poisition
movement=current-offset; % Distance gone
remainder=rem(movement,numBlockBytesAligned); % How much into next row it is
fseek(fid,-remainder,'cof'); % Rewind to start of next row


function interpdata=interptable(int_table,phys_table,int)
% INTERPTABLE return physical values from look up table
%   FLOORTABLE(INT_TABLE,PHYS_TABLE,INT) returns the physical value
%   from PHYS_TABLE corresponding to the value in INT_TABLE that is closest
%   to and less than INT.
%
%   Example:
%   floorData=floortable([1 5 7],[10 50 70],3);

if ~all(diff(int_table)>=0)
    error('Interpolation table not monotically increasing');
end

int=double(int);
if min(size(int_table))==1 || min(size(phys_table))==1
    % Saturate data to min and max
    int(int>int_table(end))= int_table(end);
    int(int<int_table(1))= int_table(1);

    % Interpolate
    interpdata=interp1(int_table,phys_table,int,'linear');

else
    error('Only vector input supported');
end
function floorData=floortable(int_table,phys_table,int)
% FLOORTABLE return physcial values looked up
%   FLOORTABLE(INT_TABLE,PHYS_TABLE,INT) returns the physical value
%   from PHYS_TABLE corresponding to the value in INT_TABLE that is closest
%   to and less than INT.

%   Example:
%   floorData=floortable([1 5 7],[10 50 70],3);

if ~all(diff(int_table)>=0)
    error('Table not monotically increasing');
end

int=double(int);
if min(size(int_table))==1 || min(size(phys_table))==1

    % Saturate data to min and max
    int(int>int_table(end))= int_table(end);
    int(int<int_table(1))= int_table(1);
    floorData=zeros(size(int)); % Preallocate
    
    % Look up value in table
    for k=1:length(int)
        differences=(int(k)-int_table);
        nonNegative=differences>=0;
        [floorInt,index]=min(differences(nonNegative));
        temp=phys_table(nonNegative);
        floorData(k)=temp(index);
    end

else
    error('Only vector input supported');
end


function sz = getsize(f)
% GETSIZE returns the size in bytes of the data type f
%
%   Example: 
%
% a=getsize('uint32');

switch f
    case {'double', 'uint64', 'int64'}
        sz = 8;
    case {'single', 'uint32', 'int32'}
        sz = 4;
    case {'uint16', 'int16'}
        sz = 2;
    case {'uint8', 'int8'}
        sz = 1;
    case {'ubit1'}
        sz = 1/8;
    case {'ubit2'}
        sz = 2/8; % for purposes of fread
end


function timeChannel=findtimechannel(CNBlock)
% Finds the locations of time channels in the channel block
% Take channel blcok array of structures

% % Sort channel list
% position=zeros(length(CNBlock),1);
% for channel = 1: length(CNBlock)
%     position(channel)=CNBlock.numberOfFirstBits;
% end

channelsFound=0; % Initialize to number of channels found to 0

% For each channel
for channel = 1: length(CNBlock)
    if CNBlock(channel).channelType==1; % Check to see if is time
        channelsFound=channelsFound+1; % Increment couner of found time channels
        timeChannel(channelsFound)=channel; % Store time channel location
    end
end