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
        dataout.label = spyInfo.channel;
        dataout.trial = {data};
        dataout.fsample = spyInfo.samplerate;
        
        iTimeDim =  find(strcmp(spyInfo.dimord, 'time'));
        dataout.time =  {(0:size(data, iTimeDim)-1)/spyInfo.samplerate};
        dataout.sampleinfo = [1 size(data, iTimeDim)];
        % Fieldtrip can currently (4 Jul 2019) not handle data with an existing but empty hdr field
        if ~isempty(spyInfo.x0x5F_hdr)
            dataout.hdr = spyInfo.spyInfo.x0x5F_hdr;
        end
        
        % cut data in trials
        trlCfg = []; trlCfg.trl = trl;        
        dataout = ft_redefinetrial(trlCfg, dataout);
        
        % final check
        dataout.dimord = ['{rpt}_' strrep(cell2mat(join(spyInfo.dimord, '_')), 'channel', 'label')];
        dataout = ft_checkdata(dataout, 'datatype', 'raw', ...
            'feedback', 'no', 'hassampleinfo', 'yes', ...
            'dimord', '{rpt}_label_time');
        
    otherwise
        error('Currently unsupported Syncopy data class %s', spyInfo.type)
        
end