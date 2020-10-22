function dataout = ft_load_spy(varargin)
% FT_LOAD_SPY Load Syncopy file as Fieldtrip data struct
% 
%   dataout = ft_load_spy({filename})
%
% INPUT
% -----
%   inFile : optional, filename of INFO or HDF5 file
%            If not provided, a file selector will show up.
%
% OUTPUT
% ------
%  dataout : a Fieldtrip raw data struct
% 
% See also ft_datatype_raw, spy.write_spy

ft_defaults

[data, trl, spyInfo] = spy.load_spy(varargin{:});

switch spyInfo.dataclass
    case 'AnalogData'
    
        dataout = [];
        dataout.label = spyInfo.channel(:);
        
        dataout.fsample = spyInfo.samplerate;
        
        iTimeDim =  find(strcmp(spyInfo.dimord, 'time'));
        dataout.time =  {(0:size(data, iTimeDim)-1)/spyInfo.samplerate};
        dataout.sampleinfo = [1 size(data, iTimeDim)];
        % Fieldtrip can currently (4 Jul 2019) not handle data with an existing but empty hdr field
        if ~isempty(spyInfo.x0x5F_hdr)
            dataout.hdr = spyInfo.spyInfo.x0x5F_hdr;
        end
        
        dimord = spyInfo.dimord;
        if iTimeDim == 1
            data = data';
            dimord = dimord';
        end
        dataout.trial = {data};

        % cut data in trials
        trlCfg = []; trlCfg.trl = trl;
        dataout = ft_redefinetrial(trlCfg, dataout);
        dataout.dimord = ['{rpt}_' strrep(cell2mat(join(dimord, '_')), 'channel', 'label')];
        
        % final check
        dataout = ft_checkdata(dataout, 'datatype', 'raw', ...
            'feedback', 'no', 'hassampleinfo', 'yes');
        
    case 'SpectralData'

        % get axis position of dimensional quantities
        iTimeDim  = find(strcmp(spyInfo.dimord, 'time'));
        iTaperDim = find(strcmp(spyInfo.dimord, 'taper'));
        iFreqDim  = find(strcmp(spyInfo.dimord, 'freq'));
        iChanDim  = find(strcmp(spyInfo.dimord, 'channel'));
        nChan     = size(data, iChanDim);
        nFreq     = size(data, iFreqDim);
        nTrials   = size(trl, 1);

        if size(data, iTaperDim) > 1
            error(['Importing SpectralData objects with multiple tapers ',...
                   'currently unsupported. Please average tapers first. '])
        end

        % assign everything that is common to both static and time-frequency structs
        dataout = [];
        dataout.label = spyInfo.channel(:);
        dataout.dimord = '';
        if nTrials > 1
            dataout.dimord = 'rpt_';
        end
        dataout.dimord = [dataout.dimord, 'chan_freq'];
        if isreal(data)
            dataLabel = 'powspctrm';
        else
            dataLabel = 'fourierspctrm';
        end
        dataout.freq = spyInfo.freq(:)';

        % time-frequency data have an additional time property, take care of this
        isTimeFreq = size(data, iTimeDim) > nTrials;
        if isTimeFreq
            dataout.dimord = [dataout.dimord, '_time'];
            data = permute(data, [iTaperDim, iChanDim, iFreqDim, iTimeDim]);
            dataout.time = ((0:(trl(1, 2) - trl(1, 1))) + trl(1, 3)) ./ spyInfo.samplerate;
            if nTrials == 1
                dataout.(dataLabel) = squeeze(data);
            else
                tLens = diff(trl(:,1:2), 1, 2) + 1;
                if length(unique(tLens)) > 1
                    error(['Importing time-frequency SpectralData with differing trial lengths ', ...)
                           'currently unsupported. Please use `spy.selectdata` to consolidate trials first. '])
                end
                dataout.(dataLabel) = reshape(data, [nTrials, nChan, nFreq, tLens(1)]);
            end
        else
            dataout.(dataLabel) = squeeze(permute(data, [iTimeDim, iTaperDim, iChanDim, iFreqDim]));
        end

        % final check
        dataout = ft_checkdata(dataout, 'datatype', 'freq', 'feedback', 'no', 'hassampleinfo', 'yes');

    otherwise
        error('Currently unsupported Syncopy data class %s', spyInfo.type)

end