function release_Simport(mversion)
if nargin<1
    mversion = false;
end
if ~isdir('releases')
    mkdir('releases');
end
rtdir = pwd;
packdir = ['.\releases\Simport_V', datestr(now, 'yyyymmddHHMM')];
copy_exlist = {
    'releases',
    'document',
    '^_demo',
    '^_debug',
    '^release_',
    '^\.git',
    '\.asv$',
    '\.autosave$',
    '^sfun_.*\.c'};
pcode_exlist = {'whichtorun','mdfinfo','mdfread','zlibdecode'};


mkdir(packdir);
df = dir;
for i=1:numel(df)
    if ismember(df(i).name, {'.', '..'})
        continue;
    end
    if isempty(cell2mat(regexp(df(i).name, copy_exlist, 'once')))
        copyfile(df(i).name, fullfile(packdir, df(i).name));
    end
end

cd(packdir);
if ~mversion
    pfolder(pwd, pcode_exlist);
end
cd('..');

% zip file
[~, packname] = fileparts(packdir);
zip(packname, packname);

cd(rtdir);



function pfolder(fd, pcode_exlist)
dfs = dir(fd);
ds = dfs([dfs.isdir]);
%remove .asv files
asvs = dfs(~cellfun(@isempty, regexp({dfs.name}, '\.asv$', 'once')));
for i=1:numel(asvs)
    delete(fullfile(fd, asvs(i).name));
end

mfs = what(fd);
mfs = mfs.m;
for i=1:numel(mfs)
    if isempty(cell2mat(regexp(mfs{i}, pcode_exlist)))
        fmf = fullfile(fd, mfs{i});
        pcode(fmf, '-inplace');
        delete(fmf);
    end
end
for i=1:numel(ds)
    if ds(i).name~='.'
        pfolder(fullfile(fd, ds(i).name), pcode_exlist);
    end
end

