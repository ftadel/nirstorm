function [isrcs, idets, measures, channel_type] = nst_unformat_channels(channel_labels)
% NST_UNFORMAT_CHANNELS extract sources, dectectors and measures information 
% from channel labels with *homogeneous* type (eg wavelength or Hb).
%
%   [ISRCS, IDETS, MEAS, CHAN_TYPE] = NST_UNFORMAT_CHANNELS(CHANNEL_LABELS)
%       CHANNEL_LABELS (cell array of str): 
%           each str is formatted as 'SxDyWLz' or 'SxDyHbt', where:
%               x: source index
%               y: detector index
%               z: wavelength
%               t: Hb type (O, R, T).
%           Consistency is asserted so that:
%               - channels are unique
%               - channel type is homogeneous
%           Warning is issued if:
%               - the number of measures per pair is not homogeneous
%                 eg one pair has only one wavelength
%
%           Examples: S1D2WL685, S01D7WL830, S3D01HbR
%           
%
%        ISRCS (array of int): extracted source indexes
%        IDETS (array of int): extracted detector indexes
%        MEAS (array of int | cell array of str): extracted measure values
%        CHAN_TYPE (array of int): channel type (see NST_CHANNEL_TYPES for enum).
%
%   See also NST_UNFORMAT_CHANNEL, NST_CHANNEL_TYPES, NST_FORMAT_CHANNEL

assert(iscellstr(channel_labels));
nb_channels = length(channel_labels);
isrcs = zeros(1, nb_channels);
idets = zeros(1, nb_channels);
measures = cell(1, nb_channels);
ctypes = zeros(1, nb_channels);
reformated_channels = cell(1, nb_channels);
for ichan=1:nb_channels
    [isrc, idet, meas, ctype] = nst_unformat_channel(channel_labels{ichan});
    isrcs(ichan) = isrc;
    idets(ichan) = idet;
    measures{ichan} = meas;
    ctypes(ichan) = ctype;
    % reformat channels to make sure formatting is consistent
    % -> allow proper duplicate detection after
    reformated_channels{ichan} = nst_format_channel(isrc, idet, meas);
end

% check uniqueness
[~, i_unique] = unique(reformated_channels);
duplicates = reformated_channels;
duplicates(i_unique) = [];
i_duplicates = ismember(reformated_channels, unique(duplicates));
if ~isempty(duplicates)
    msg = sprintf('Duplicated channels: "%s". Indexes: %s', ...
                  strjoin(channel_labels(i_duplicates), ', '), num2str(i_duplicates));
    throw(MException('NIRSTORM:NonUniqueChannels', msg));
end

% check homogeneity of channel type
if length(unique(ctypes)) > 1
    throw(MException('NIRSTORM:NonHomogeneousChannelType', 'Channel type is not homogeneous.'));
end

chan_types = nst_channel_types();

channel_type = ctypes(1);
if channel_type == chan_types.WAVELENGTH
   measures = cell2mat(measures);
end

%% Check number of measures per pair
max_idet = (max(idets)+1);
pairs_hash = isrcs * max_idet + idets;
unique_pairs_hash = unique(pairs_hash);
mcounts = sparse(ones(1, length(unique_pairs_hash)), unique_pairs_hash, ...
                      ones(1, length(unique_pairs_hash)), 1, max(unique_pairs_hash), ...
                      nb_channels);
all_measures = unique(measures);
for ichan=1:nb_channels
    if channel_type == chan_types.WAVELENGTH
        measure_hash = find(measures(ichan)==all_measures);
    elseif channel_type == chan_types.HB
        measure_hash = find(strcmp(measures(ichan),all_measures));
    end
    h_idx = isrcs(ichan) * max_idet + idets(ichan);
    mcounts(h_idx) = mcounts(h_idx) + measure_hash;
end

% pairs with too many measures:
i_inconsistant_measures = (mcounts ~= sum(1:length(all_measures)) + 1) & (mcounts ~= 0);

if nnz(i_inconsistant_measures) > 0
    [isrc_incon,idet_incon,counts] = find(i_inconsistant_measures);
    inconsistent_pairs = cell(1, length(isrc_incon));
    for ipair=1:length(isrc_incon)
        inconsistent_pairs{ipair} = sprintf('S%dD%d', isrc_incon(ipair), idet_incon(ipair));
    end 
    warning('Inconsistent measure(s) for pair(s): %s', strjoin(inconsistent_pairs, ', '));
end

end

