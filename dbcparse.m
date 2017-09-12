function dbc=dbcparse(dbcfile)
if nargin<1
    [filename, pathname] = uigetfile('*.dbc', 'Select the CAN dbc file');
    if isequal(filename,0) || isequal(pathname,0)
        return;
    else
        dbcfile = fullfile(pathname, filename);
    end
end
backbone_pattern={
    '(?x)'
    '(?-m)'
    '(\<VERSION\>.*?)?'
    '(\<NS_\>.*?)?'
    '(\<BS_\>.*?)'
    '(\<BU_\>.*?)'
    '(\<VAL_TABLE_\>.*?)*'
    '(\<BO_\>\s+.*?)*'
    '(\<BO_TX_BU_\>\s+.*?)*'
    '(\<EV_\>.*?)*'
    '(\<ENVVAR_DATA_\>.*?)*'
    '(\<SGTYPE_\>.*?)*'
    '(\<CM_\>.*?)*'
    '(\<BA_DEF_\>\s+.*?)*'
    '(\<BA_DEF_DEF_\>\s+.*?)*'
    '(\<BA_\>\s*.*?)*'
    '(\<VAL_\>\s+.*?)*'
    '$'};
backbone_patt=sprintf('%s\n',backbone_pattern{:});

remove_empty_cell=@(c) [{},c{:}];


rawstr=fileread(dbcfile);

kw_splits = regexp(rawstr,backbone_patt,'tokens','once');

%VERSION
version_str=kw_splits{1};
if ~isempty(version_str)
    tmp=regexp(version_str,'VERSION\s*"(.*?)"','tokens','once');
    dbc.CANdb_version_string=tmp{1};
end
%NS_
new_symbols_str=kw_splits{2};
if ~isempty(new_symbols_str)
    tmp=regexprep(new_symbols_str,'NS_\s*:\s*','');
    tmp2=regexp(tmp,'[A-Z_]+','match');
    dbc.NewSymbols=tmp2;
end
%BU_
nodes_str = kw_splits{4};
tmp=regexprep(nodes_str,'BU_\s*:\s*','');
tmp2=regexp(tmp,'\s+','split');
dbc.Nodes=remove_empty_cell(tmp2);
%VAL_TABLE_
val_table_str = kw_splits{5};
if ~isempty(val_table_str)
    tmps=regexp(val_table_str,'VAL_TABLE_\s+(.*?);','match');
    s_vt(numel(tmps))=struct('Name','','Table',[]);
    for i=1:numel(tmps)
        tmp=regexp(tmps{i},'VAL_TABLE_\s+(\w+)\s+([+\-0-9e\.]+\s+".*?")*\s*;$','tokens');
        tmp=tmp{1};
        s_vt(i).Name=tmp{1};
        tmp2=regexp(tmp{2},'([+\-0-9e\.]+)\s+"(.*?)"','tokens');
        s_vt(i).Table=reshape([tmp2{:}],2,numel(tmp2))';
    end
    dbc.ValueTable=s_vt;
end
%BO_
message_str = kw_splits{6};
signal_pattern={
    '(?x)'
    '(?-m)'
    '(\w+)\s+'
    '(M|m\d*)?'
    '\s*:\s*'
    '(\d+)'
    '\s*\|\s*'
    '(\d+)'
    '\s*@\s*'
    '([01])'
    '\s*([+\-])'
    '\s*\(\s*'
    '([+\-0-9.eE]+)'
    '\s*,\s*'
    '([+\-0-9.eE]+)'
    '\s*\)'
    '\s*\[\s*'
    '([+\-0-9.eE]+)'
    '\s*\|\s*'
    '([+\-0-9.eE]+)'
    '\s*\]\s*'
    '"(.*?)"'
    '\s*(\w+\s*,?\s*)+'
    };
sig_patt=sprintf('%s\n',signal_pattern{:});
if ~isempty(message_str)
    msgs=regexp(message_str,'BO_\s*','split'); % split by 'BO_' to get string of each message
    msgs=remove_empty_cell(msgs);
    s_msg(numel(msgs))=struct('ID',[],'Name','','Size',[],'Transmitter','','Signals',[]);
    for imsg=1:numel(msgs)
        flds=regexp(msgs{imsg},'(\d+)\s+(\w+)\s*:\s*(\d+)\s+(\w+)\s+(SG_\s*.*?)*$','tokens');
        if isempty(flds)
            error('Failed to parse the message in:\n\t<%s>\n',msgs{i});
        end
        flds=flds{1};
        s_msg(imsg).ID=str2double(flds{1});
        s_msg(imsg).Name=flds{2};
        s_msg(imsg).Size=str2double(flds{3});
        s_msg(imsg).Transmitter=flds{4};
        if isempty(flds{5})
            s_msg(imsg).Signals=[];
            continue;
        end
        % parse each signal in message
        sg_strs=regexp(flds{5},'\s*SG_\s+','split');
        sg_strs=remove_empty_cell(sg_strs);
        clear('s_sig');
        s_sig(numel(sg_strs))=struct('Name','','Multiplexer','', 'StartBit',[],'SignalSize',[],'ByteOrder',[],'ValueType',[],'Factor',[],'Offset',[],'Minimum',[],'Maximum',[],'Unit','','Receiver',[]);
        for isig=1:numel(sg_strs)
            sigtks=regexp(sg_strs{isig}, sig_patt,'tokens');
            if isempty(sigtks)
                error('Failed to parse the signal in:\n\t<%s>\n',sg_strs{isig});
            else
                sigtks=sigtks{1};
                s_sig(isig).Name=sigtks{1};
                s_sig(isig).Multiplexer=regexp(sigtks{2},'(?<multiplexer_type>[mM])(?<multiplexer_switch_value>\d*)','names');
                s_sig(isig).StartBit=str2double(sigtks{3});
                s_sig(isig).SignalSize=str2double(sigtks{4});
                s_sig(isig).ByteOrder=str2double(sigtks{5});
                s_sig(isig).ValueType=double(sigtks{6}=='-');
                s_sig(isig).Factor=str2double(sigtks{7});
                s_sig(isig).Offset=str2double(sigtks{8});
                s_sig(isig).Minimum=str2double(sigtks{9});
                s_sig(isig).Maximum=str2double(sigtks{10});
                s_sig(isig).Unit=sigtks{11};
                s_sig(isig).Receiver=regexp(sigtks{12},',','split');
            end
        end
        s_msg(imsg).Signals=s_sig;
    end
    dbc.Message=s_msg;
end
%BO_TX_BU_
message_tx_str = kw_splits{7};
s_msgtx=regexp(message_tx_str,'BO_TX_BU_\s+(?<MessageID>\d+)\s*:\s*(?<Transmitter>.*?);','names');
for imsgtx=1:numel(s_msgtx) % split extra transmitters into cell
    s_msgtx(imsgtx).Transmitter=remove_empty_cell(regexp(s_msgtx(imsgtx).Transmitter, '\s*,\s*','split'));
end
%EV_
ev_str = kw_splits{8};
if isempty(ev_str)
    evvar_pattern={
        '(?x)'
        '(?-m)'
        'EV_\s+'
        '(?<Name>\w+)'
        '\s*:\s*'
        '(?<Type>[012])'
        '\s*\[\s*'
        '(?<Minimum>[+\-0-9.eE]+)'
        '\s*\|\s*'
        '(?<Maximum>[+\-0-9.eE]+)'
        '\s*\]\s*'
        '"(?<Unit>.*?)"'
        '\s*(?<InitValue>[+\-0-9.eE]+)\s+'
        '(?<ID>\d+)\s+'
        '(?<AccessType>DUMMY_NODE_VECTOR0|DUMMY_NODE_VECTOR1|DUMMY_NODE_VECTOR2|DUMMY_NODE_VECTOR3)\s*'
        '(?<AccessNode>[\w,\s]+)'
        ';'
        };
    evvar_patt=sprintf('%s\n',evvar_pattern{:});
    evtmp=regexp(ev_str,evvar_patt,'names');
    for ievvar=1:numel(evtmp)
        evtmp(ievvar).Type = str2double(evtmp(ievvar).Type);
        evtmp(ievvar).Minimum = str2double(evtmp(ievvar).Minimum);
        evtmp(ievvar).Maximum = str2double(evtmp(ievvar).Maximum);
        evtmp(ievvar).InitValue = str2double(evtmp(ievvar).InitValue);
        evtmp(ievvar).ID = str2double(evtmp(ievvar).ID);
        evtmp(ievvar).AccessNode = remove_empty_cell(regexp(evtmp(ievvar).AccessNode,'\s*,\s*','split'));
    end
    dbc.EnvironmentVariable=evtmp;
end
%ENVVAR_DATA_
evdata_str = kw_splits{9};
if ~isempty(evdata_str)
    evvar_data_pattern={
        '(?x)'
        '(?-m)'
        'ENVVAR_DATA_\s+'
        '(?<Name>\w+)'
        '\s*:\s*'
        '(?<Size>\d+)'
        '\s*;'};
    evvardata_patt=sprintf('%s\n',evvar_data_pattern{:});
    evdatatmp=regexp(evdata_str,evvardata_patt,'names');
    for ievdata=1:numel(evdatatmp)
        evdatatmp(ievdata).Size=str2double(evdatatmp(ievdata).Size);
    end
    dbc.EnvironmentVariableData=evtmp;
end
%SGTYPE_
sgtype_str = kw_splits{10};
if ~isempty(sgtype_str)
    sgtype_pattern={
        '(?x)'
        '(?-m)'
        'SGTYPE_\s+'
        '(?<Name>\w+)'
        '\s*:\s*'
        '(?<Size>\d+)'
        '\s*@\s*'
        '(?<ByteOrder>[01])'
        '\s*(?<ValueType>[+\-])'
        '\s*\(\s*'
        '(?<Factor>[+\-0-9.eE]+)'
        '\s*,\s*'
        '(?<Offset>[+\-0-9.eE]+)'
        '\s*\)'
        '\s*\[\s*'
        '(?<Minimum>[+\-0-9.eE]+)'
        '\s*\|\s*'
        '(?<Maximum>[+\-0-9.eE]+)'
        '\s*\]\s*'
        '"(?<Unit>.*?)"'%%
        '\s*(?<DefaultValue>[+\-0-9.eE]+)'
        '\s*,\s*'
        '(?<ValueTable>\w+)'
        '\s*;'
        };
    sgtype_patt=sprintf('%s\n',sgtype_pattern{:});
    sgtypetmp=regexp(sgtype_str,sgtype_patt,'names');
    for isgt=1:numel(sgtypetmp)
        sgtypetmp(isgt).Size=str2double(sgtypetmp(isgt).Size);
        sgtypetmp(isgt).ByteOrder=str2double(sgtypetmp(isgt).ByteOrder);
        sgtypetmp(isgt).Factor=str2double(sgtypetmp(isgt).Factor);
        sgtypetmp(isgt).Offset=str2double(sgtypetmp(isgt).Offset);
        sgtypetmp(isgt).Minimum=str2double(sgtypetmp(isgt).Minimum);
        sgtypetmp(isgt).Maximum=str2double(sgtypetmp(isgt).Maximum);
    end
    dbc.SignalType=sgtypetmp;
end
%CM_
cm_str = kw_splits{11};
if ~isempty(cm_str)
    cmtks=regexp(cm_str,'CM_\s+(SG_|BU_|BO_|EV_)\s+(.*?);','tokens');
    if ~isempty(cmtks)
        s_cm(numel(cmtks))=struct('Type','','Entry',[]);
    else
        s_cm = [];
    end
    for icm=1:numel(cmtks)
        switch cmtks{icm}{1}
            case 'SG_'
                s_cm(icm).Type='Signal';
                s_cm(icm).Entry=regexp(cmtks{icm}{2},'(?<MessageID>\d+)\s+(?<Name>\w+)\s+"(?<Comment>.*?)"','names');
            case 'BU_'
                s_cm(icm).Type='Node';
                s_cm(icm).Entry=regexp(cmtks{icm}{2},'(?<Name>\w+)\s+"(?<Comment>.*?)"','names');
            case 'BO_'
                s_cm(icm).Type='Message';
                s_cm(icm).Entry=regexp(cmtks{icm}{2},'(?<MessageID>\d+)\s+"(?<Comment>.*?)"','names');
            case 'EV_'
                s_cm(icm).Type='EnvironmentVariable';
                s_cm(icm).Entry=regexp(cmtks{icm}{2},'(?<Name>\w+)\s+"(?<Comment>.*?)"','names');
        end
    end
    dbc.Comments=s_cm;
end
%BA_DEF_
badef_str = kw_splits{12};
if ~isempty(badef_str)
    badef_pattern={
        '(?x)'
        '(?-m)'
        'BA_DEF_\s+'
        '(BU_|BO_|SG_|EV_)?\s*'
        '"(\w+)"\s*'
        '(INT|HEX|FLOAT|STRING|ENUM)\s+'
        '(.*?);'
        };
    badef_patt=sprintf('%s\n',badef_pattern{:});
    badef_tks=regexp(badef_str, badef_patt, 'tokens');
    s_badef(numel(badef_tks))=struct('Type','','Name','','ValueType','');
    for ibadef=1:numel(badef_tks)
        switch badef_tks{ibadef}{1}
            case 'SG_'
                s_badef(ibadef).Type='Signal';
            case 'BU_'
                s_badef(ibadef).Type='Node';
            case 'BO_'
                s_badef(ibadef).Type='Message';
            case 'EV_'
                s_badef(ibadef).Type='EnvironmentVariable';
            otherwise
                s_badef(ibadef).Type='';
        end
        s_badef(ibadef).Name=badef_tks{ibadef}{2};
        s_badef(ibadef).ValueType.Type=badef_tks{ibadef}{3};
        tmp=remove_empty_cell(regexp(badef_tks{ibadef}{4},'\s*,?\s*','split'));
        switch badef_tks{ibadef}{3}
            case {'INT','HEX','FLOAT'}
                s_badef(ibadef).ValueType.Minimum = str2double(tmp{1});
                s_badef(ibadef).ValueType.Maximum = str2double(tmp{2});
            case 'ENUM'
                s_badef(ibadef).ValueType.Enum=strrep(tmp,'"','');
        end
    end
    dbc.AttributeDefinition = s_badef;
end
%BA_DEF_DEF_
badefdef_str = kw_splits{13};
if ~isempty(badefdef_str)
    badefdef_tks=regexp(badefdef_str, 'BA_DEF_DEF_\s*"(\w+)"\s*(.*?)\s*;', 'tokens');
    s_badefdef(numel(badefdef_tks))=struct('Name','','ValueString',[]);
    for ibdd=1:numel(badefdef_tks)
        s_badefdef(ibdd).Name=badefdef_tks{ibdd}{1};
        s_badefdef(ibdd).ValueString=strrep(badefdef_tks{ibdd}{1},'"','');
    end
    dbc.AttributeDefault=s_badefdef;
end
%BA_
ba_str = kw_splits{14};
if ~isempty(ba_str)
    ba_tks=regexp(ba_str, 'BA_\s*"(\w+)"\s*(BU_|BO_|SG_|EV_)?\s+(.*?\s*;)', 'tokens');
    s_ba(numel(ba_tks))=struct('Name','','Type',[],'Entry',[]);
    for iba=1:numel(ba_tks)
        s_ba(iba).Name=ba_tks{iba}{1};
        switch ba_tks{iba}{2}
            case 'SG_'
                s_ba(iba).Type='Signal';
                s_ba(iba).Entry=regexp(ba_tks{iba}{3},'(?<MessageID>\d+)\s+(?<Name>\w+)\s+(?<Value>.*?)\s*;','names');
            case 'BU_'
                s_ba(iba).Type='Node';
                s_ba(iba).Entry=regexp(ba_tks{iba}{3},'(?<Name>\w+)\s+(?<Value>.*?)\s*;','names');
            case 'BO_'
                s_ba(iba).Type='Message';
                s_ba(iba).Entry=regexp(ba_tks{iba}{3},'(?<MessageID>\d+)\s+(?<Value>.*?)\s*;','names');
            case 'EV_'
                s_ba(iba).Type='EnvironmentVariable';
                s_ba(iba).Entry=regexp(ba_tks{iba}{3},'(?<Name>\w+)\s+(?<Value>.*?)\s*;','names');
            otherwise
                s_ba(iba).Type='';
        end
    end
    dbc.AttributeValue = s_ba;
end
%VAL_
val_str = kw_splits{15};
if ~isempty(val_str)
    val_tks=regexp(val_str, 'VAL_\s+(\d+)\s+(\w+)\s+(.*?)\s*;', 'tokens');
    s_val(numel(val_tks))=struct('MessageID',[],'SignalName','','Table',[]);
    for ival=1:numel(val_tks)
        s_val(ival).MessageID=str2double(val_tks{ival}{1});
        s_val(ival).SignalName=val_tks{ival}{2};
        tmp2=regexp(val_tks{ival}{3},'([+\-0-9e\.]+)\s+"(.*?)"','tokens');
        s_val(ival).Table=reshape([tmp2{:}],2,numel(tmp2))';
    end
    dbc.ValueDescription = s_val;
end
