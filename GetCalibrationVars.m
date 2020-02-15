function CalInfo=GetCalibrationVars(rtsys,varargin)
if nargin<1
    rtsys=gcs;
end
sel=varargin;
pattern_match = '^[a-zA-Z]\w+$';
pattern_ignore = {'^ENUM_'
                  '^SY_'
                  '^C_TICK_'
                  '^SYNC_TICK'
                  'TRUE'
                  'FALSE'
                  'true'
                  'false'};
              
block_Defs={...
    'Constant', 'Value';
    'DataStoreRead', 'DataStoreName';
    'Lookup', {'InputValues','Table'};
    'Lookup2D', {'RowIndex','ColumnIndex','Table'};
    'Saturate', {'UpperLimit','LowerLimit'};
    'PreLookup', 'BreakpointsData';
    'Interpolation_n-D', 'Table';
    'Lookup_n-D',{'Table','BreakpointsForDimension1','BreakpointsForDimension2','BreakpointsForDimension3','BreakpointsForDimension4'};
    };

block_Defs_mask={
    'MotoHawk Calibration', 'val';
    'MotoHawk Data Definition', 'data';
    'MotoHawk Data Read', 'nam';
    'MotoHawk Interpolation (1-D)', 'table_data';
%     'MotoHawk Interpolation Reference (1-D)', 'nam';
    'MotoHawk Interpolation (2-D)', 'table_data';
%     'MotoHawk Interpolation Reference (2-D)', 'nam';
    'MotoHawk Prelookup Index Search', 'breakpoint_data';
%     'MotoHawk Prelookup Index Search (Reference)', 'nam';
    'MotoHawk Lookup Table (1-D)', {'breakpoint_data', 'table_data'};
    'MotoHawk Lookup Table (2-D)', {'row_breakpoint_data', 'col_breakpoint_data', 'table_data'};
    };
%Calibration
cals={};
calpaths={};

for i=1:size(block_Defs,1)
    [blktype, blkparas]=block_Defs{i,:};
    tgtblks = find_system(rtsys,'FollowLinks','on','LookUnderMasks','on','FindAll','on','BlockType',blktype,sel{:});
    if isstr(blkparas)
        blkparas = {blkparas}; % convert string to 1x1 cell
    end
    for k=1:numel(blkparas)
        cals=[cals;get_param(tgtblks,blkparas{k})];
        calpaths=[calpaths;regexprep(getfullname(tgtblks),['^',rtsys],'.')];
    end
end
for i=1:size(block_Defs_mask,1)
    [blktype, blkparas]=block_Defs_mask{i,:};
    tgtblks = find_system(rtsys,'FollowLinks','on','LookUnderMasks','on','FindAll','on','MaskType',blktype,sel{:});
    if isstr(blkparas)
        blkparas = {blkparas}; % convert string to 1x1 cell
    end
    for k=1:numel(blkparas)
        rawstr = strrep(get_param(tgtblks,blkparas{k}), '''', ''); % motohawk "nam" field
        calstr = regexprep(rawstr, '(IdxArr|Tbl|Map)$', '');
        cals=[cals;calstr];
        calpaths=[calpaths;regexprep(getfullname(tgtblks),['^',rtsys],'.')];
    end
end
% stateflow
sfs = find_system(rtsys,'FollowLinks','on','LookUnderMasks','on','FindAll','on','MaskType', 'Stateflow', sel{:});
for i=1:numel(sfs)
    sfobj = get_param(sfs(i),'Object');
    sfparas = sfobj.find('-isa','Stateflow.Data','Scope','Parameter');
    for k=1:numel(sfparas)
        cals=[cals;sfparas(k).Name];
        calpaths=[calpaths;regexprep(sfparas(k).Path,['^',rtsys],'.')];
    end
end
% remove those not calibrations
bmatch = ~cellfun(@isempty,regexp(cals,pattern_match));
% cals=cals(bmatch);calpaths=calpaths(bmatch);
bignore=~boolean(1:numel(cals))';
for i=1:numel(pattern_ignore)
    bignore = bignore | ~cellfun(@isempty,regexp(cals,pattern_ignore{i}));
end
cals=cals(bmatch&~bignore);
calpaths=calpaths(bmatch&~bignore);


% Post processing
calpaths=regexprep(calpaths,'(/.*)/.+$','$1');
CalName={};
CalPath={};
for i=1:numel(cals)
    [TF,LOC]=ismember(cals{i},CalName);
    if isempty(TF)||~TF
        CalName=[CalName;cals{i}];
        CalPath=[CalPath;{{calpaths{i}}}];
    else
        if ~ismember(calpaths{i},CalPath{LOC})
            CalPath{LOC}=[CalPath{LOC};calpaths{i}];
        end
    end
end

for i=1:numel(CalPath)
    path=CalPath{i};
    ss=sprintf('%s\n',path{:});
    ss=ss(1:end-1);
    CalPath{i}=ss;
end

CalInfo=struct('CalName',CalName,'CalPath',CalPath);
