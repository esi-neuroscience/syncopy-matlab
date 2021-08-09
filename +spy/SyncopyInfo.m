classdef SyncopyInfo < dynamicprops
    % Class for required fields in Syncopy INFO file
    %
    % For private Python properties (_*) the underscore at the beginning has to
    % be replaced with its hex value 'x0x5F' (95). jsonlab then handles
    % replacing it when writing/reading to the JSON file.
    %
    properties
        filename
        dimord
        x0x5F_version = '0.1b'
        x0x5F_log
        cfg
        data_dtype
        data_shape
        data_offset
        file_checksum
        checksum_algorithm
        trl_dtype
        trl_shape
        trl_offset
        dataclass
        channel
        samplerate
        x0x5F_hdr
        order = 'C'
    end

    properties (Access = private, Constant = true, Hidden=true)
        supportedDataTypes = {'int8', 'uint8', 'int16', 'uint16', ...
            'int32', 'uint32', 'int64', 'uint64', ...
            'float32', 'float64', ...
            'complex64', 'complex128'};
        requiredFields = {'dimord', 'x0x5F_version', 'x0x5F_log', 'cfg', ...
            'data_dtype', 'data_shape', 'data_offset', ...
            'trl_dtype', 'trl_shape', 'trl_offset'}
    end

    methods

        function obj = SyncopyInfo(infoStruct)

            if nargin > 0

                if ischar(infoStruct)
                    assert(exist(infoStruct, 'file') == 2, ...
                        'Info-file %s does not exist', infoStruct)
                    infoStruct = spy.jsonlab.loadjson(infoStruct);
                end

                fields = fieldnames(infoStruct);

                for iField = 1:length(fields)
                    name = fields{iField};

                    if isempty(infoStruct.(name))
                        continue
                    elseif ~isprop(obj, name)
                        prop = obj.addprop(name);
                    end

                    obj.(name) = infoStruct.(name);

                end

            end

        end

        function obj = set.dimord(obj, value)
            assert(iscell(value), 'dimord must be cell array of strings')
            assert(all(cellfun(@ischar, value)), 'dimord must be cell array of strings')
            obj.dimord = value;
        end

        function obj = set.x0x5F_version(obj, value)
            assert(ischar(value), 'version must be a string')
            obj.x0x5F_version = value;
        end

        % FIXME: implement other set functions as sanity checks

        function obj = set.data_dtype(obj, value)
            assert(ismember(value, obj.supportedDataTypes), ...
                'Unsupported dtype %s', value)
            obj.data_dtype = value;
        end

        function obj = set.trl_dtype(obj, value)
            assert(ismember(value, obj.supportedDataTypes), ...
                'Unsupported dtype %s', value)
            obj.trl_dtype = value;
        end

        function output_struct = struct(obj)
            output_struct = obj.obj2struct(obj);

        end

        function hasAllRequired = assert_has_all_required(obj)
            hasAllRequired = true;

            for iRequired = 1:length(obj.requiredFields)
                name = obj.requiredFields{iRequired};
                assert(~isempty(obj.(name)), ...
                    'Required field %s is not set', name)
            end

        end

        function write_to_file(obj, filename)
            obj.assert_has_all_required();
            spy.jsonlab.savejson('', struct(obj), filename);
        end

    end

    methods ( Static = true )
        function output_struct = obj2struct(obj)
            props = fieldnames(obj); % works on structs & classes (public properties)

            for i = 1:length(props)
                val = obj.(props{i});
                if numel(val) > 256
                    val = sprintf('[%d element %s]', numel(val), class(val));
                end
                if ~isstruct(val) &&~isobject(val)
                    output_struct.(props{i}) = val;
                else

                    if isa(val, 'serial') || isa(val, 'visa') || isa(val, 'tcpip')
                        % don't convert communication objects
                        continue
                    end

                    temp = spy.SyncopyInfo.obj2struct(val);

                    if ~isempty(temp)
                        output_struct.(props{i}) = temp;
                    end

                end

            end

        end
    end

end
