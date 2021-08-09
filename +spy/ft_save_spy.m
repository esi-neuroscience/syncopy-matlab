function ft_save_spy(cfg, datain)
% FT_SAVE_SPY Save a Fieldtrip data struct as Syncopy file
%
%   dataout = ft_save_spy(cfg, data)
%
% INPUT
% -----
%   cfg : configuration struct with fields
%      .container :  path to Syncopy container folder (*.spy).
%      OR
%      .filename : path to Syncopy data file
%
%      .tag : (OPTIONAL) only valid if `.container` is used; tag to be appended to files in container
%      .log : (OPTIONAL) info message to append to Syncopy data object
%   data : a FieldTrip data struct
%
% See also ft_datatype_raw, spy.save_spy

% these are used by the ft_preamble/ft_postamble function and scripts
ft_nargin   = nargin;
ft_nargout  = nargout;

ft_defaults                   % this ensures that the path is correct and that the ft_defaults global variable is available
ft_preamble init              % this will reset ft_warning and show the function help if nargin==0 and return an error
ft_preamble debug             % this allows for displaying or saving the function name and input arguments upon an error
ft_preamble loadvar    datain % this reads the input data in case the user specified the cfg.inputfile option
ft_preamble provenance datain % this records the time and memory usage at the beginning of the function
ft_preamble trackconfig       % this converts the cfg structure in a config object, which tracks the cfg options that are being used

if ft_abort
  return
end

datain = ft_checkdata(datain, 'datatype', 'raw', ...
    'feedback', 'yes', 'hassampleinfo', 'yes');

dimord = ft_getopt(datain, 'dimord');
label = ft_getopt(datain, 'label');

if isempty(dimord)
    warning('No dimord found - trying to infer dim order from data')
    if isempty(label)
        error('Cannot infer dimensional info: both dimord and channel labels missing')
    end
    nChan = length(label);
    trlDim = size(datain.trial{1});
    if length(trlDim) ~=2 2;
        error('Cannot infer dimensional info from %i-D data', length(trlDim))
    end
    chanIdx = find(trlDim == nChan);
    if isempty(chanIdx) || length(chanIdx) > 1
        error('Data inconsistent: found %i channels but trial dimension is %i x %i', ...
               nChan, trlDim(1), trlDim(2))
    end
    lblIdx = setdiff([1, 2], chanIdx);
    dimCell = {};
    dimCell{chanIdx} = 'label';
    dimCell{lblIdx} = 'time';
    dimord = char(compose('%s_%s', dimCell{:}));
else
    datain = ft_checkdata(datain, 'dimord', '{rpt}_label_time');
end

container = ft_getopt(cfg, 'container', '');
filename = ft_getopt(cfg, 'filename', '');
tag = ft_getopt(cfg, 'tag', '');
log = ft_getopt(cfg, 'log', 'Created using ft_save_spy');

if isempty(container)
    if isempty(filename)
        error('Either cfg.container or cfg.filename must be provided. ');
    end
    if ~isempty(tag)
        warning('cfg.tag only has an effect with cfg.container')
    end
    [folder, basename, ext] = fileparts(filename);
    if ~strcmp(ext, '.analog')
        filename = [basename '.analog'];
    end
    filename = fullfile(what(folder).path, filename);
else
    if ~isempty(filename)
        error('Either cfg.container or cfg.filename can be used, not both. ');
    end
    [folder, basename, ext] = fileparts(container);
    if ~strcmp(ext, '.spy')
        container = [basename '.spy'];
    end
    container = fullfile(what(folder).path, container);
    prefix = '';
    if ~isempty(tag)
        prefix = '_';
    end
    filename = fullfile(container, [basename, prefix, tag, '.analog']);
    if exist(filename, 'file') && isempty(tag)
        error('File %s already exists', filename)
    end
    if ~exist(container, 'dir')
        mkdir(container)
    end
end

if exist(filename, 'file')
    warning('File %s will be overwritten!', filename)
end

dimord = tokenize(dimord, '_');
dimord(strcmp(dimord, '{rpt}')) = '';
dimord{strcmp(dimord, 'label')} = 'channel';

nTrialinfocols = 0;
if isfield(datain, 'trialinfo')
    nTrialinfocols = size(datain.trialinfo, 2);
end

trl = zeros(length(datain.trial), 3+nTrialinfocols);

indx = 1;
for iTrial = 1:length(datain.trial)
    trl(iTrial, 1) = indx;
    trl(iTrial, 2) = indx+length(datain.time{iTrial})-1;
    trl(iTrial, 3) = round(datain.time{iTrial}(1) * datain.fsample);
    indx = indx + length(datain.time{iTrial});
end
if isfield(datain, 'trialinfo')
    trl(:, 4:end) = datain.trialinfo;
end

spy.save_spy(filename, ...
    cat(2, datain.trial{:}), trl, ...
    log, datain.fsample, ...
    datain.label, dimord);

ft_postamble debug               % this clears the onCleanup function used for debugging in case of an error
ft_postamble trackconfig         % this converts the config object back into a struct and can report on the unused fields
ft_postamble previous   datain   % this copies the datain.cfg structure into the cfg.previous field. You can also use it for multiple inputs, or for "varargin"
ft_postamble provenance % this records the time and memory at the end of the function, prints them on screen and adds this information together with the function name and MATLAB version etc. to the output cfg
ft_postamble history    % this adds the local cfg structure to the output data structure, i.e. dataout.cfg = cfg


end