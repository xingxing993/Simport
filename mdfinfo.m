function [MDFsummary, MDFstructure, counts, channelList]=mdfinfo(fileName)
% MDFINFO Return information about an MDF (Measure Data Format) file
%
%   MDFSUMMARY = mdfinfo(FILENAME) returns an array of structures, one for
%   each data group, containing key information about all channels in each
%   group. FILENAME is a string that specifies the name of the MDF file.
%
%   [..., MDFSTRUCTURE] = mdfinfo(FILENAME) returns a structure containing
%   all MDF file information matching the structure of the file. This data structure
%   match closely the structure of the data file.
%
%   [..., COUNTS] = mdfinfo(FILENAME) contains the total
%   number of channel groups and channels.

% Open file
fid=fopen(fileName,'r');

if fid==-1
    error([fileName ' not found'])
end
% Input information about the format of the individual blocks
formats=blockformats;
channelGroup=1;

% Insert fileName into field or output data structure
MDFstructure.fileName=fileName;

%%% Read header block (HDBlock) information

% Set file poniter to start of HDBlock
offset=64;

% Read Header block info into structure
MDFstructure.HDBlock=mdfblockread(formats.HDFormat,fid,offset,1);

%%% Read Data Group blocks (DGBlock) information

% Get pointer to first Data Group block
offset=MDFstructure.HDBlock.pointerToFirstDGBlock;
for dataGroup=1:double(MDFstructure.HDBlock.numberOfDataGroups) % Work for older versions

    % Read data Data Group block info into structure
    DGBlockTemp=mdfblockread(formats.DGFormat,fid,offset,1);

    % Get pointer to next Data Group block
    offset=DGBlockTemp.pointerToNextCGBlock;

    %%% Read Channel Group block (CGBlock) information - offset set already

    % Read data Channel Group block info into structure
    CGBlockTemp=mdfblockread(formats.CGFormat,fid,offset,1);

    offset=CGBlockTemp.pointerToChannelGroupCommentText;

    % Read data Text block info into structure
    TXBlockTemp=mdfblockread(formats.TXFormat,fid,offset,1);

    % Read data Text block comment into structure after knowing length
    current=ftell(fid);
    TXBlockTemp2=mdfblockread(formatstxtext(TXBlockTemp.blockSize),fid,current,1);

    % Convert blockIdentifier and comment string data from uint8 to char
    TXBlockTemp.blockIdentifier=truncintstochars(TXBlockTemp.blockIdentifier);
    TXBlockTemp.comment=truncintstochars(TXBlockTemp2.comment); % accessing TXBlockTemp2

    % Copy temporary Text block info into main MDFstructure
    CGBlockTemp.TXBlock=TXBlockTemp;

    % Get pointer to next first Channel block
    offset=CGBlockTemp.pointerToFirstCNBlock;

    % For each Channel
    for channel=1:double(CGBlockTemp.numberOfChannels)

        %%% Read Channel block (CNBlock) information - offset set already

        % Read data Channel block info into structure

        CNBlockTemp=mdfblockread(formats.CNFormat,fid,offset,1);

        % Convert blockIdentifier, signalName, and signalDescription
        % string data from uint8 to char
        CNBlockTemp.signalName=truncintstochars(CNBlockTemp.signalName);
        CNBlockTemp.signalDescription=truncintstochars(CNBlockTemp.signalDescription);

        %%% Read Channel text block (TXBlock)

        offset=CNBlockTemp.pointerToTXBlock1;
        if double(offset)==0
            TXBlockTemp=struct('blockIdentifier','NULL','blocksize', 0);
            CNBlockTemp.longSignalName='';
        else
            % Read data Text block info into structure
            TXBlockTemp=mdfblockread(formats.TXFormat,fid,offset,1);

            if TXBlockTemp.blockSize>0 % If non-zero (check again)
                % Read data Text block comment into structure after knowing length
                current=ftell(fid);
                TXBlockTemp2=mdfblockread(formatstxtext(TXBlockTemp.blockSize),fid,current,1);

                % Convert blockIdentifier and comment string data from uint8 to char
                TXBlockTemp.blockIdentifier=truncintstochars(TXBlockTemp.blockIdentifier);
                TXBlockTemp.comment=truncintstochars(TXBlockTemp2.comment); % accessing TXBlockTemp2
                CNBlockTemp.longSignalName=TXBlockTemp.comment;
            else % If block size is zero (sometimes it is)
                TXBlockTemp=struct('blockIdentifier','NULL','blocksize', 0);
                CNBlockTemp.longSignalName='';
            end

        end
        % Copy temporary Text block info into main MDFstructure
        CNBlockTemp.TXBlock=TXBlockTemp;
        % NOTE: This could be removed later, only required for long name which
        % gets stored in structure seperately

        if CNBlockTemp.signalDataType==7 % If text only
            offset=CNBlockTemp.pointerToConversionFormula;
            CCBlockTemp=mdfblockread(formats.CCFormat,fid,offset,1);
            %% TODO to support strings
        else

            %%% Read Channel Conversion block (CCBlock)

            % Get pointer to Channel convertion block
            offset=CNBlockTemp.pointerToConversionFormula;

            if offset==0; % If no conversion formula, set to 1:1
                CCBlockTemp.conversionFormulaIdentifier=65535;
            else % Otherwise get conversion formula, parameters and physical units
                % Read data Channel Conversion block info into structure
                CCBlockTemp=mdfblockread(formats.CCFormat,fid,offset,1);

                % Extract Channel Conversion formula based on conversion
                % type(conversionFormulaIdentifier)

                switch CCBlockTemp.conversionFormulaIdentifier

                    case 0 % Parameteric, Linear: Physical =Integer*P2 + P1

                        % Get current file position
                        currentPosition=ftell(fid);

                        % Read data Channel Conversion parameters info into structure
                        CCBlockTemp2=mdfblockread(formats.CCFormatFormula0,fid,currentPosition,1);

                        % Extract parameters P1 and P2
                        CCBlockTemp.P1=CCBlockTemp2.P1;
                        CCBlockTemp.P2=CCBlockTemp2.P2;

                    case 1 % Table look up with interpolation

                        % Get number of paramters sets
                        num=CCBlockTemp.numberOfValuePairs;

                        % Get current file position
                        currentPosition=ftell(fid);

                        % Read data Channel Conversion parameters info into structure
                        CCBlockTemp2=mdfblockread(formats.CCFormatFormula1,fid,currentPosition,num);

                        % Extract parameters int value and text equivalent
                        % arrays
                        CCBlockTemp.int=CCBlockTemp2.int;
                        CCBlockTemp.phys=CCBlockTemp2.phys;

                    case 2 % table look up

                        % Get number of paramters sets
                        num=CCBlockTemp.numberOfValuePairs;

                        % Get current file position
                        currentPosition=ftell(fid);

                        % Read data Channel Conversion parameters info into structure
                        CCBlockTemp2=mdfblockread(formats.CCFormatFormula1,fid,currentPosition,num);

                        % Extract parameters int value and text equivalent
                        % arrays
                        CCBlockTemp.int=CCBlockTemp2.int;
                        CCBlockTemp.phys=CCBlockTemp2.phys;

                    case 6 % Polynomial

                        %  Get current file position
                        currentPosition=ftell(fid);

                        % Read data Channel Conversion parameters info into structure
                        CCBlockTemp2=mdfblockread(formats.CCFormatFormula6,fid,currentPosition,1);

                        % Extract parameters P1 to P6
                        CCBlockTemp.P1=CCBlockTemp2.P1;
                        CCBlockTemp.P2=CCBlockTemp2.P2;
                        CCBlockTemp.P3=CCBlockTemp2.P3;
                        CCBlockTemp.P4=CCBlockTemp2.P4;
                        CCBlockTemp.P5=CCBlockTemp2.P5;
                        CCBlockTemp.P6=CCBlockTemp2.P6;

                    case 10 % Text formula

                        %  Get current file position
                        currentPosition=ftell(fid);
                        CCBlockTemp2=mdfblockread(formats.CCFormatFormula10,fid,currentPosition,1);
                        CCBlockTemp.textFormula=truncintstochars(CCBlockTemp2.textFormula);
                        
                    case {65535, 11,12} % Physical = integer (implementation) or ASAM-MCD2 text table

                    otherwise

                        % Give warning that conversion formula is not being
                        % made
                        warning(['Conversion Formula type (conversionFormulaIdentifier='...
                            int2str(CCBlockTemp.conversionFormulaIdentifier)...
                            ')not supported.']);
                end
                
                % Convert physicalUnit string data from uint8 to char
                CCBlockTemp.physicalUnit=truncintstochars(CCBlockTemp.physicalUnit);
            end
        end


        % Copy temporary Channel Conversion block info into temporary Channel
        % block info
        CNBlockTemp.CCBlock=CCBlockTemp;

        % Get pointer to next Channel block ready for next loop
        offset=CNBlockTemp.pointerToNextCNBlock;

        % Copy temporary Channel block info into temporary Channel
        % Group info
        CGBlockTemp.CNBlock(channel,1)=CNBlockTemp;
    end
    
    % Sort channel list before copying in because sometimes the first
    % channel is not listed first in the block
    pos=zeros(length(CGBlockTemp.CNBlock),1);
    for ch = 1: length(CGBlockTemp.CNBlock)
        pos(ch)=CGBlockTemp.CNBlock(ch).numberOfTheFirstBits; % Get start bits
    end
    
    [dummy,idx]=sort(pos); % Sort positions to getindices
    clear CNBlockTemp2
    for ch = 1: length(CGBlockTemp.CNBlock)
        CNBlockTemp2(ch,1)= CGBlockTemp.CNBlock(idx(ch)); % Sort blocks
    end
    
    % Copy sorted blocks back
    CGBlockTemp.CNBlock=CNBlockTemp2;
    
    % Copy temporary Channel Group block info into temporary Channel
    % Group array in temporary Data Group info
    DGBlockTemp.CGBlock(channelGroup,1)=CGBlockTemp;


    % Get pointer to next Data Group block ready for next loop
    offset=DGBlockTemp.pointerToNextDGBlock;

    % Copy temporary Data Group block info into Data Group array
    % in main MDFstructure ready for returning from the function
    MDFstructure.DGBlock(dataGroup,1)=DGBlockTemp;
end

% CLose the file
fclose(fid);

% Calculate the total number of Channels

totalChannels=0;
for k= 1: double(MDFstructure.HDBlock.numberOfDataGroups)
    totalChannels=totalChannels+double(MDFstructure.DGBlock(k).CGBlock.numberOfChannels);
end

% Return channel coutn information in counts variable
counts.numberOfDataGroups=MDFstructure.HDBlock.numberOfDataGroups;
counts.totalChannels=totalChannels;

% Put summary of data groups into MDFsummary structure
[MDFsummary, channelList]=mdfchannelgroupinfo(MDFstructure);



function formats = blockformats
% This function returns all the predefined formats for the different blocks
% in the MDF file as specified in "Format Specification MDF Format Version 3.0"
% doucment version 2.0, 14/11/2002

%% Data Type Definitions
LINK=  'int32';
CHAR=  'uint8';
REAL=  'double';
BOOL=  'int16';
UINT8= 'uint8';
UINT16='uint16';
INT32= 'int32';
UINT32='uint32';
%BYTE=  'uint8';

formats.HDFormat={...
    UINT8  [1 4]  'ignore';...
    INT32  [1 1]  'pointerToFirstDGBlock';  ...
    UINT8  [1 8]   'ignore';  ...
    UINT16 [1 1]  'numberOfDataGroups'};

formats.TXFormat={...
    UINT8  [1 2]  'blockIdentifier';...
    UINT16 [1 1]  'blockSize'};

% Can use anonymous fuction for R14 onwards instead of subfuntion
% formats.TXtext= @(blockSize)( [{'uint8'}  {[1 double(blockSize)]}  {'comment'}]);


formats.DGFormat={...
    UINT8  [1 4]  'ignore';...
    LINK   [1 1]  'pointerToNextDGBlock';  ...
    LINK   [1 1]  'pointerToNextCGBlock';  ...
    UINT8  [1 4]  'ignore'; ...
    LINK   [1 1]  'pointerToDataRecords'; ...
    UINT16  [1 1] 'numberOfChannelGroups';...
    UINT16  [1 1] 'numberOfRecordIDs'}; % Ignore rest

formats.CGFormat={...
    UINT8  [1 8]  'ignore';...
    LINK   [1 1]  'pointerToFirstCNBlock';  ...
    LINK   [1 1]  'pointerToChannelGroupCommentText'; ...
    UINT16 [1 1]  'recordID'; ...
    UINT16 [1 1]  'numberOfChannels'; ...
    UINT16 [1 1]  'dataRecordSize'; ...
    UINT32 [1 1]  'numberOfRecords'};

% last one missing

formats.CNFormat={...
    UINT8  [1 4]   'ignore';...
    LINK   [1 1]   'pointerToNextCNBlock';  ...
    LINK   [1 1]   'pointerToConversionFormula';  ...
    UINT8  [1 12]   'ignore'; ...
    UINT16 [1 1]   'channelType'; ...
    CHAR   [1 32]  'signalName'; ...
    CHAR   [1 128] 'signalDescription'; ...

    UINT16 [1 1]   'numberOfTheFirstBits'; ...
    UINT16 [1 1]   'numberOfBits'; ...
    UINT16 [1 1]   'signalDataType'; ...
    BOOL   [1 1]   'valueRangeKnown'; ...
    REAL   [1 1]   'valueRangeMinimum'; ...
    REAL   [1 1]   'valueRangeMaximum'; ...
    REAL   [1 1]   'rateVariableSampled';...
    LINK   [1 1]   'pointerToTXBlock1'};


formats.CCFormat={...
    UINT8  [1 22]  'ignore';...
    CHAR   [1 20]  'physicalUnit'; ...
    UINT16 [1 1]   'conversionFormulaIdentifier'; ...
    UINT16 [1 1]   'numberOfValuePairs'};

formats.CCFormatFormula0={...
    REAL   [1 1] 'P1'; ...
    REAL   [1 1] 'P2'};

formats.CCFormatFormula1={... % Tablular or Tabular with interp
    REAL   [1 1] 'int'; ...
    REAL   [1 1] 'phys'};

formats.CCFormatFormula10={... % Text formula
    CHAR   [1 256] 'textFormula'};

formats.CCFormatFormula11={... % ASAM-MCD2 text table
    REAL  [1 1] 'int'; ...
    CHAR  [1 32] 'text'};

formats.CCFormatFormula6={...
    REAL   [1 1] 'P1'; ... % polynomial
    REAL   [1 1] 'P2'; ...
    REAL   [1 1] 'P3'; ...
    REAL   [1 1] 'P4'; ...
    REAL   [1 1] 'P5'; ...
    REAL   [1 1] 'P6'};


function [summary, channelList]=mdfchannelgroupinfo(MDFStructure)
% Returns summary information of an MDF file (summary) taken from the
% MDFstrusture data structure and a cell array containing many
% important fields of informtation for each channel in the file
% (channelList)

numberOfDataGroups=double(MDFStructure.HDBlock.numberOfDataGroups);
channelGroup=1;
fieldNames=fieldnames(MDFStructure.DGBlock(1).CGBlock(channelGroup).CNBlock);
startChannel=1;

for dataBlock = 1: numberOfDataGroups

    numberOfChannels=double(MDFStructure.DGBlock(dataBlock).CGBlock(channelGroup).numberOfChannels);
    numberOfRecords=double(MDFStructure.DGBlock(dataBlock).CGBlock(channelGroup).numberOfRecords);
    endChannel=startChannel+numberOfChannels-1;

    % Make summary
    summary(dataBlock,1).numberOfChannels=numberOfChannels;
    summary(dataBlock,1).numberOfRecords=numberOfRecords;
    summary(dataBlock,1).rateVariableSampled=MDFStructure.DGBlock(dataBlock).CGBlock(channelGroup).CNBlock(1).rateVariableSampled;
    channelCells=[fieldNames struct2cell(MDFStructure.DGBlock(dataBlock).CGBlock(channelGroup).CNBlock)];

    % Signal Name and descriptions
    signalNames=channelCells(4,:)'; % Signal names
    longSignalNames=channelCells(14,:)'; % Long names
    useNames=cell(size(signalNames)); % Pre allocate

    for signal=1:length(signalNames)
        if isempty(longSignalNames{signal}) % If no long name, use signal name
            useNames(signal)=signalNames(signal);
        else
            useNames(signal)=longSignalNames(signal); % Use Long name
        end
    end
    summary(dataBlock,1).signalNamesandDescriptions(:,1)=useNames;
    summary(dataBlock,1).signalNamesandDescriptions(:,2)=channelCells(5,:)';

    % Other
    summary(dataBlock,1).channelCells=channelCells;

    % Make channel List
    channelCells2=struct2cell(MDFStructure.DGBlock(dataBlock).CGBlock(channelGroup).CNBlock);

    % Signal Names
    signalNames=channelCells2(4,:)'; % Signal names
    longSignalNames=channelCells2(14,:)'; % Long names
    useNames=cell(size(signalNames)); % Pre allocate

    for signal=1:length(signalNames)
        if length(signalNames{signal})>length(longSignalNames{signal}) % If signal name longer use it
            useNames(signal)=signalNames(signal);
        else
            useNames(signal)=longSignalNames(signal); % Use Long name
        end
    end

    channelList(startChannel:endChannel,1)= useNames; % Names

    channelList(startChannel:endChannel,2)= channelCells2(5,:)'; % Descriptons
    channelList(startChannel:endChannel,3)= num2cell((1:numberOfChannels)');
    channelList(startChannel:endChannel,4)={dataBlock};
    channelList(startChannel:endChannel,5)={MDFStructure.DGBlock(dataBlock).CGBlock.CNBlock(1).rateVariableSampled};
    channelList(startChannel:endChannel,6)={numberOfRecords};
    channelList(startChannel:endChannel,7)=channelCells2(7,:)';
    channelList(startChannel:endChannel,8)=channelCells2(8,:)';
    channelList(startChannel:endChannel,9)=channelCells2(3,:)';
    channelList(startChannel:endChannel,10)={MDFStructure.DGBlock(dataBlock).CGBlock.TXBlock.comment};

    startChannel=endChannel+1;

end


function tx = formatstxtext(blockSize)
% Return format for txt block section

tx= [{'uint8'}  {[1 double(blockSize)]}  {'comment'}];

function  truncstring=truncintstochars(ints)
% Converts an array of integers to characters and truncates the string to
% the first non zero integers.

[m,n]=size(ints);

if m > 1 % if multiple strings
    truncstring=cell(m,1); %preallocate
end

for k=1:m % for each row
    % For R14: lastchar=find(ints==0,1,'first')-1;
    lastchar=find(ints(k,:)==0)-1;

    if isempty(lastchar) % no blanks
        truncstring{k}=char(ints(k,:));
    else
        lastchar=lastchar(1); % Get first
        truncstring{k}=char(ints(k,1:lastchar));
    end
end

if m == 1 % If just one string
    truncstring=truncstring{1}; % Convert to char
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


function Block=mdfblockread(blockFormat,fid,offset,repeat)
% MDFBLOCKREAD Extract block of data from MDF file in orignal data types
%   Block=MDFBLOCKREAD(BLOCKFORMAT, FID, OFFSET, REPEAT) returns a
%   structure with field names specified in data structure BLOCKFORMAT, fid
%   FID, at byte offset in the file OFFSET and repeat factor REPEAT
%
% Example block format is:
% blockFormat={...
%     UINT8  [1 4]  'ignore';...
%     INT32  [1 1]  'pointerToFirstDGBlock';  ...
%     UINT8  [1 8]   'ignore';  ...
%     UINT16 [1 1]  'numberOfDataGroups'};
%
% Example function call is:
% Block=mdfblockread(blockFormat, 1, 413, 1);

% Extract parameters
numFields=size(blockFormat,1); % Number of fields
precisions=blockFormat(:,1); % Precisions (data types) of each field
fieldnames=blockFormat(:,3); % Field names

% Number of elements of a data type in one field
% This is only not relevent to one for string arrays

% Calculate counts variable to store number of data types
% For R14SP3: counts= cellfun(@max,blockFormat(:,2));
counts=zeros(numFields,1); 
for k=1:numFields
    %counts(k)=max(blockFormat{k,2});
    counts(k)=blockFormat{k,2}(end); % Get last value
end

fseek(fid,double(offset),'bof');
for record=1:double(repeat)
    for field=1:numFields
        count=counts(field);
        precision=precisions{field};
        fieldname=fieldnames{field};
        if strcmp(fieldname,'ignore')
            fseek(fid,getsize(precision)*count,'cof');
        else
            Block.(fieldname)(record,:)=fread(fid,count,['*' precision])';
        end
    end
end
