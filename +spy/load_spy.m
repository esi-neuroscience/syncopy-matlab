function [data, trl, spyInfo] = load_spy(inFile)
% LOAD_SPY Load data from HDF5/JSON Syncopy files
%
%   [data, trl, spyInfo] = load_spy(in_file)
%
% INPUT
% -----
%   inFile : (OPTIONAL) filename of INFO or HDF5 file
%            If not provided, a file selector will show up.
%
% OUTPUT
% ------
%  data    : data array
%  trl     : [nTrials x 3+N] trial definition array
%  spyInfo : spy.SyncopyInfo object with metadata
%
% See also spy.SyncopyInfo, spy.ft_load_spy

if nargin == 0
    [infoFile, pathname] = uigetfile({...
        '*.*.info', 'Syncopy Data Files (*.*.info)';...
        '*' 'All files (*)'}, ...
        'Pick a data file');
    if infoFile == 0; return; end
    inFile = fullfile(pathname, infoFile);
else
    if isa(inFile, 'str')
        inFile = char(inFile);
    elseif ~isa(inFile, 'char')
        error('Input has to be a file-name, not %s', class(inFile))
    end
end

[folder, filestem, ext] = fileparts(inFile);
folder = what(folder).path;

filenameTokens = split([filestem, ext], '.');
assert(length(filenameTokens) >= 2 && length(filenameTokens) <= 3, ...
    'Invalid filename %s. Must be *.ext or *.ext.info', ...
    inFile)

dataclassToken = filenameTokens{2};
filestem = filenameTokens{1};


infoFile = fullfile(folder, [filestem, '.', dataclassToken, '.info']);

% read json file
spyInfo = spy.SyncopyInfo(infoFile);

hdfFile = fullfile(folder, spyInfo.filename);
assert(strcmp(fullfile(folder, [filestem, '.' dataclassToken]), hdfFile), ...
    ['Filename mismatch between metadata in INFO file and actual filename: \n,%s vs %s'], spyInfo.filename, [filestem, '.' dataclassToken])


% Get content info of dat-HDF5 container
h5toc = h5info(hdfFile);
dset_names = {h5toc.Datasets.Name};
msk = ~strcmp(dset_names, 'trialdefinition');
dclass = dset_names{msk};
ndim = length(h5toc.Datasets(msk).Dataspace.Size);

% Account for C-ordering by permuting contents of dataset
data = permute(h5read(hdfFile, ['/', dclass]), ndim:-1:1);

% The `trialdefinition` part is always 2D -just transpose it
trl = h5read(hdfFile, '/trialdefinition')';
% Add 1 to the start sample to consider zero-based indexing. The second
% column is fine because ranges in Python don't include the last element.
trl(:,1) = trl(:,1) + 1;

% extract container attributes
h5attrs = h5toc.Attributes;

% compare JSON to HDF5 attributes
for iAttr = 1:length(h5attrs)
    name = h5attrs(iAttr).Name;
    value = h5attrs(iAttr).Value;
    if iscell(value) && numel(value) == 1
        value = value{1};
    end
    if ~ischar(value)
        value = value';
    end
    name = strrep(name, '_', 'x0x5F_');
    attrs.(name) = value;
    assert(isequal(spyInfo.(name), value), ...
        'JSON/HDF5 mismatch for attribute %s', name)
end

% FIXME: check other json attributes: data_dtype, data_shape, ...

return
end
