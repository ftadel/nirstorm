function [local_fns, downloaded_files] = nst_request_files(relative_fns, confirm_download, remote_repository, default_file_size, local_repository, download_title)
% Request local files: if they are not available in the given local repository
% then attempt to download them from given remote repository.
% The given files in relative_fns are relative to both local_repository and 
% remote_repository.
% More precisely, for a given requested file 'subd1/subd2/file.ext', it first 
% looks in "<local_repository>/subd1/subd2/file.ext".
% If not found, it tries to download it from the http url 
% "<remote_repository(http|https|ftp)>/subd1/subd2/file.ext
% and copy the downloaded file in <local_repository>/subd1/subd2/file.ext.
%
% The amount of data to download is first evaluated and a confirmation 
% can be asked to the user (if confirm_download is 1) to avoid downloading
% too much data by mistake.
%
% The function checks the consistency between local and remote 
% files. If one file is available locally but is not available
% remotely, an exception is thrown.
% 
% Args:
%    - relative_fns (cell array of cell array of string):
%        Pathes to files relative to the repository root which is 
%        either local or remote.
%        Each relative path is broken down into subdirectories and 
%        file name.
%        Files at the root dir (not in subdir) also have to be encapsulated
%        in a cell array.
%        Example:  { {'subd1', 'subd1_2', 'file.txt'},
%                    {'subd2', 'file2.txt'},
%                    {'file_at_root.txt'} }
%        Note: this is used as a portable way of specifying file pathes that can 
%              be used both for url where separator is "/" and for windows
%              where separator is "\".
%    - confirm_download (boolean):
%        Whether to give the user the volume of data to be downloaded and 
%        ask for confirmation.
%   [- remote_repository (string):]
%        http URL pointing to the remote repository, where file listings 
%        have been generated by webfs.
%        Each directory containing files may contain a file called
%        "file_sizes.csv" listing all files in the directory and their size
%        in bytes.
%        Default is gotten from nst_get_repository_url.
%   [- default_file_size (int):]
%        Default file size in bytes to use when "file_sizes.csv" is not
%        available in the online repository.
%   [- local_repository (string):]
%        Local repository path where to look first for requested files.
%        Must be consistent with remote repository.
%        Default is gotten from nst_get_local_user_dir
%
%  Outputs:
%      - local_fns (cell array of string):
%          Full local filenames for requested files.
%      - downloaded_files (cell array of string):
%          Remote file names that actually got downloaded (were not
%          available locally)
global GlobalData;

bst_interactive = ~isempty(GlobalData) && isfield(GlobalData, 'Program') && ...
                  ~isempty(GlobalData.Program) && ...
                  (~isfield(GlobalData.Program, 'isServer') || ...
                   ~GlobalData.Program.isServer);

if nargin < 2
    confirm_download = 1;
end

if nargin < 3
    remote_repository = nst_get_repository_url();
end

if nargin < 4
    default_file_size = nan;
end

if nargin < 5
    local_repository = nst_get_local_user_dir();
end
if nargin < 6
    download_title = 'Download data';
end

if ~iscell(relative_fns) || (~isempty(relative_fns) && (~iscell(relative_fns{1}) || ~isstr(relative_fns{1}{1})))
    error('Given relative_fns must be a cell array of cell arrays of str');
end

to_download_urls = {};
remote_files_not_found = {};
to_download_sizes = [];
idownload = 1;

bst_progress('start', download_title, 'Checking data on server...', 1, length(relative_fns));
for ifn=1:length(relative_fns)
    local_fns{ifn} = fullfile(local_repository, strjoin(relative_fns{ifn}, filesep));
    [output_dir, ignore_bfn, ignore_ext] = fileparts(local_fns{ifn});
    if ~exist(output_dir, 'dir')
        mkdir(output_dir)
    end
    if ~exist(local_fns{ifn}, 'file')
        remote_folder = strjoin({remote_repository, strjoin(relative_fns{ifn}(1:(end-1)), '/')}, '/');
        url = strjoin({remote_folder, relative_fns{ifn}{end}}, '/');
        % Check if remote file exist:
        jurl = java.net.URL(url);
        conn = openConnection(jurl);
        conn.setConnectTimeout(15000);
        if ~isempty(strfind(url, 'http:'))
            try
                status = getResponseCode(conn);
                if status == 404
                    remote_files_not_found{end+1} = url;
                    continue;
                end
            catch
                remote_files_not_found{end+1} = url;
                continue;
            end

        else % ftp
            try
                conn.connect();
            catch
                remote_files_not_found{end+1} = url;
                continue;
            end
        end
        to_download_sizes(idownload) = conn.getContentLength();
        to_download_urls{idownload} = url;
        download_targets{idownload} = local_fns{ifn};
        idownload = idownload + 1;
%         % Resolve file size:
%         if isempty(strfind(remote_folder, 'ftp:'))
%             remote_listing_file_sizes_fn = strjoin({remote_folder, 'file_sizes.csv'}, '/');
%             try
%                 file_sizes = webread(remote_listing_file_sizes_fn);
%                 to_download_sizes(end+1) = file_sizes(strcmp(file_sizes.file_name, ...
%                                                       relative_fns{ifn}{end}),:).size;
%             catch ME
%                 disp(['Warning: table of file sizes not found at ' remote_listing_file_sizes_fn ...
%                     '. Using default file size.']);
%                 to_download_sizes(end+1) = default_file_size;
%             end
%         else
%             [ftp_site, rdir] = nst_split_ftp(remote_folder);
%             hftp = ftp(ftp_site);
%             rftp = dir(hftp, [rdir '/' relative_fns{ifn}{end}]);
%             to_download_sizes(end+1) = rftp.bytes;
%         end
    end
    bst_progress('inc',1);
end
bst_progress('stop');

if ~isempty(remote_files_not_found)
    exception = MException('NIRSTORM:RemoteFilesNotFound', ...
                           strjoin(['Remote files not found:', remote_files_not_found], '\n'));
    throw(exception);
end

nans = isnan(to_download_sizes);
if any(~nans)
    total_download_size = sum(to_download_sizes(~nans));
else
    total_download_size = nan;
end
downloads_failed = {};
if ~isempty(to_download_urls)
    confirm_msg = sprintf('Warning: %s of data (%d files) will be downloaded to %s.\n\nConfirm download?', ...
                          format_file_size(total_download_size), length(to_download_urls), local_repository);
    if confirm_download && ~java_dialog('confirm', confirm_msg, 'Download warning')
        downloaded_files = {};
        return;
    end
    
    bst_progress('start', download_title, 'Downloading data...', 1, length(to_download_urls));
    for idownload=1:length(to_download_urls)
        if ~nst_download(to_download_urls{idownload}, download_targets{idownload})
            downloads_failed{end+1} = to_download_urls{idownload};
        end
        bst_progress('inc',1);
    end
    bst_progress('stop');
else
    if ~isempty(local_fns)
        if length(local_fns) == 1
            message = sprintf('%s: File "%s" already downloaded (erase to redownload)', ...
                              download_title, local_fns{1});
        else
            root_dirs = unique(cellfun(@(fn) dirname(fn), local_fns, 'UniformOutput', false));
            if length(root_dirs) == 1
                message = sprintf('%s: Files in "%s" already downloaded (erase to redownload)', ...
                                  download_title, root_dirs{1});
            else
                message = sprintf('%s: already done (erase files to redownload)',...
                                  download_title);
            end
        end
    else
        message = 'Nothing to download';        
    end
    fprintf('Nirstorm:RequestFiles >>> %s\n', message);
end

if ~isempty(downloads_failed)
    throw(MException('NIRSTORM:DownloadFailed', strjoin(['Failed downloads:', downloads_failed], '\n')));
end

downloaded_files = to_download_urls;
end

function ssize = format_file_size(size)
if isnan(size)
    ssize = 'unknown amount';
elseif size < 1000
    ssize = [num2str(size) 'B'];
elseif size < 1e6
    ssize = sprintf('%1.2f Kb', size / 1e3);
elseif size < 1e9
    ssize = sprintf('%1.2f Mb', size / 1e6);
elseif size < 1e12
    ssize = sprintf('%1.2f Gb', size / 1e9);
else
    ssize = sprintf('%1.2f Tb', size / 1e12);
end
end


function dn = dirname(fn)
[dn, tmpf, tmpe] = fileparts(fn);
end