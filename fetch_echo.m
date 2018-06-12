function volume_path = fetch_echo( serie_path, echo_number )

[~, serie_name] = get_parent_path(char(serie_path));

% Fetch json dics
jsons = get_subdir_regex_files(serie_path,'dic.*json',struct('verbose',0));
assert(~isempty(jsons), 'no dic.*json file detected in : %s', serie_path)

% Fetch all TE and reorder them
res = get_string_from_json(cellstr(jsons{1}),'EchoTime','numeric');
allTE = cell2mat([res{:}]);
[sortedTE,order] = sort(allTE); %#ok<ASGLU>
% fprintf(['TEs are : ' repmat('%g ',[1,length(allTE)]) ], allTE)

% Fetch volume corrsponding to the echo
allEchos = cell(length(order),1);
for echo = 1 : length(order)
    
    if order(echo) == 1
        allEchos(echo) = get_subdir_regex_files(serie_path, ['^f\d+_' serie_name '.nii'], 1);
        json = get_subdir_regex_files(serie_path, ['dic_.*f\d+_' serie_name '.json'], 1);
    else
        allEchos(echo) = get_subdir_regex_files(serie_path, ['^f\d+_' serie_name '_' sprintf('V%.3d',order(echo)) '.nii'], 1);
        json = get_subdir_regex_files(serie_path, ['dic_.*f\d+_' serie_name '_' sprintf('V%.3d',order(echo)) '.json'], 1);
    end
    
    [~, json] = get_parent_path(json);
    if ~strcmp( json{1}(1) , '_' ) && echo ~= echo_number
        r_movefile(fullfile(serie_path,json),fullfile(char(serie_path),['_' json{1}]),'move');
    end
    
end % echo
% fprintf(['sorted as : ' repmat('%g ',[1,length(sortedTE)]) 'ms \n'], sortedTE)

volume_path = allEchos{echo_number};

end % function
