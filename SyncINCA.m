function NF_INCA=SyncINCA(cals)
%return NF_INCA, containing the calibrations not found in current
%experiment in INCA
NF_INCA=[];
inca=actxserver('INCA.INCA');
exp=inca.GetOpenedExperiment;
if isempty(exp)
    warndlg('Experiment not opened in INCA.');
    return;
end
hwtbar=waitbar(0,'Updating data...');
total=numel(cals);

for i=1:total
    waitbar(i/total,hwtbar,sprintf('Updating %s...',strrep(cals(i).CalName,'_','\_')));
    cals(i).CalName=strtrim(cals(i).CalName);
    %Get the value from INCA
    calel_inca=exp.GetCalibrationElement(cals(i).CalName);
    if isempty(calel_inca) % if cannot locate the calibration element, try other pattern
        aliaslist = get_alias_list(cals(i).CalName);
        for kk=1:size(aliaslist,1)
            calel_inca=exp.GetCalibrationElement(aliaslist{kk,1});
            aliastype=aliaslist{kk,2};
            if ~isempty(calel_inca)
                break;
            end 
        end
        if isempty(calel_inca)
            NF_INCA=[NF_INCA;cals(i)];%save
            continue;
        end
    else
        aliastype='Normal';
    end
    switch aliastype
        case 'X'
            if calel_inca.IsOneDTable
                val_inca_raw=calel_inca.GetValue.GetDistribution.GetDoublePhysValue;
            elseif calel_inca.IsTwoDTable
                val_inca_raw=calel_inca.GetValue.GetXDistribution.GetDoublePhysValue;
            else
                val_inca_raw=get_raw_incaval(calel_inca);
            end
        case 'Y'
            if calel_inca.IsTwoDTable
                val_inca_raw=calel_inca.GetValue.GetYDistribution.GetDoublePhysValue;
            else
                val_inca_raw=get_raw_incaval(calel_inca);
            end
        case 'Z'
            val_inca_raw=get_raw_incaval(calel_inca)';
        otherwise
            val_inca_raw=get_raw_incaval(calel_inca);
    end
    if iscell(val_inca_raw)
        val_inca = cell2mat(val_inca_raw);
    else
        val_inca = val_inca_raw';
    end

    %Update the value in MATLAB workspace, or add one if not exist
    try
        tmpval=evalin('base',cals(i).CalName);
    catch
        tmpval=[];
    end
    if regexp(class(tmpval),'.Parameter$')
        dttypebkup=tmpval.DataType;
        tmpval.Value=min(max(val_inca,tmpval.Min),tmpval.Max);
        switch tmpval.DataType
            case 'uint8'
                tmpval.Value=uint8(tmpval.Value);
            case 'boolean'
                tmpval.Value=boolean(tmpval.Value);
            case 'single'
                tmpval.Value=single(tmpval.Value);
            otherwise
        end
        tmpval.DataType=dttypebkup;
    else
        tmpval=val_inca;
    end
    assignin('base',cals(i).CalName,tmpval);
    fprintf('>> %s has been updated by INCA value\n',cals(i).CalName);
end
close(hwtbar);




function rawval=get_raw_incaval(calel_inca)
inca_valel=calel_inca;
while inca_valel.ismethod('GetValue')
    inca_valel=inca_valel.GetValue;
end
if strncmp(inca_valel.GetPhysType,'real',4)
    rawval=inca_valel.GetDoublePhysValue;
else
    rawval=inca_valel.GetDoublePhysValue; % temporarily use this solution
end


function alias_list = get_alias_list(rawname)
% return alias_list with N*2 size cell matrix, each row represents {'ALIASNAME', 'ALIASTYPE'}
alias_list={};
if ~isempty(regexp(rawname, '_?[XYZ]$', 'once')) % If end with 'X','Y','Z'
    newname=regexprep(rawname,'_?[XYZ]$','');
    alias_list = [alias_list;{newname, rawname(end)}];
    alias_list = [alias_list;{[newname,'_1_A'], rawname(end)}]; % '_1_A' suffix, special case for BOSCH
elseif ~isempty(regexp(rawname, '_?(CA)$', 'once')) % If end with 'CA'
    newname=regexprep(rawname,'_?(CA)$','');
    alias_list = [alias_list;{newname, 'CA'}];
else
end
alias_list = [alias_list;{[rawname,'_1_A'], 'Normal'}];