%% Init

clear
clc

main_dir = fullfile(pwd,'img');

e = exam(main_dir,'SCHIRANG');

model_name = 'model_basic';

%% fetch dirs

e.addSerie('Run_1$','run_1',1)
e.addSerie('Run_2$','run_2',1)
e.addVolume('run','^run\d+_medn_afw','f')

e.addSerie('3DT1','anat',1)
e.addVolume('anat','^anat_ns_at.*nii','s',1)

e.unzipVolume

dir_func  = e.getSerie('run') .toJob;
dir_anat = e.getSerie('anat').toJob(0);

par.fake = 0;
par.redo = 0;
par.verbose = 2;


model_dir = e.mkdir(model_name);

%% Fetch onset

e.getSerie('run_1').addStim(fullfile(pwd,'stim'), 'MRI_AroundCEIL_run01.mat', 'run_1', 1 )
e.getSerie('run_2').addStim(fullfile(pwd,'stim'), 'MRI_AroundCEIL_run02.mat', 'run_2', 1 )

e.explore

%% Prepare onsets

stim_files = e.getSerie('run').getStim.toJob(1);

% matlabbatch{1}.spm.stats.fmri_spec.sess(2).cond(1).name = '<UNDEFINED>';
% matlabbatch{1}.spm.stats.fmri_spec.sess(2).cond(1).onset = '<UNDEFINED>';
% matlabbatch{1}.spm.stats.fmri_spec.sess(2).cond(1).duration = '<UNDEFINED>';

for subj = 1 : length(e)
    for run = 1 : 2
        
        s = e.getSerie(sprintf('run_%d',run)).getStim.load;
        data = s{1}.S.TaskData.RR.Data;
        
        events = {'Jitter' 'Blank' 'Picture' 'Answer'};

        regressor_idx = 0;
        
        for evt = 1:length(events)
            
            idx = regexp(data(:,1),events{evt});
            idx = ~cellfun(@isempty, idx);
            sub_data = data(idx,:);
            
            if strcmp(events{evt},'Picture')
                
                NAMES =  {'sVSu' 'sVSk'};
                
                for n = 1 : length(NAMES)
                    
                    name = NAMES{n};
                    
                    sVSx_idx = regexp(sub_data(:,1),name);
                    sVSx_idx = ~cellfun(@isempty, sVSx_idx);
                    sVSx_data = sub_data(sVSx_idx,:);
                    
                    sVSx_data(:,1) = regexprep( sVSx_data(:,1) , '+', 'p' );
                    sVSx_data(:,1) = regexprep( sVSx_data(:,1) , '-', 'm' );
                    
                    values = {'m20' 'm10' '0' 'p10' 'p20'};
                    VALUES = {'-20' '-10' '0' '+10' '+20'};
                    for val = 1 : length(values)
                        
                        % fetch value in condition
                        sVSx_val_idx = regexp(sVSx_data(:,1),[name '\d_' values{val} '$']);
                        sVSx_val_idx = ~cellfun(@isempty, sVSx_val_idx);
                        sVSx_val_data = sVSx_data(sVSx_val_idx,:);
                        
                        % save onset
                        regressor_idx = regressor_idx + 1;
                        ONSETS{subj}{run}(regressor_idx).name     = [name(end) '_' values{val}];
                        ONSETS{subj}{run}(regressor_idx).onset    = cell2mat(sVSx_val_data(:,2)) ;
                        ONSETS{subj}{run}(regressor_idx).duration = cell2mat(sVSx_val_data(:,3)) ;
                        
                    end
                    
                end
                
            else
                
                regressor_idx = regressor_idx + 1;
                ONSETS{subj}{run}(regressor_idx).name     = char(events{evt});
                ONSETS{subj}{run}(regressor_idx).onset    = cell2mat(sub_data(:,2)) ;
                ONSETS{subj}{run}(regressor_idx).duration = cell2mat(sub_data(:,3)) ;
                
            end
            
        end % evt
        
        % Yes & No button press
        regressor_idx = regressor_idx + 1;
        ONSETS{subj}{run}(regressor_idx).name     = s{1}.names    {2};
        ONSETS{subj}{run}(regressor_idx).onset    = s{1}.onsets   {2};
        ONSETS{subj}{run}(regressor_idx).duration = s{1}.durations{2};
        regressor_idx = regressor_idx + 1;
        ONSETS{subj}{run}(regressor_idx).name     = s{1}.names    {3};
        ONSETS{subj}{run}(regressor_idx).onset    = s{1}.onsets   {3};
        ONSETS{subj}{run}(regressor_idx).duration = s{1}.durations{3};
        
    end
end



%% Job define model


par.run = 1;

par.TR = 1.6;
par.file_reg = '^run\d+_medn_afw';
par.rp = 1;
% job_first_level_specify_modulator(dir_func,model_dir,ONSETS,par)


%% Estimate

fspm = e.addModel(model_name,model_name);
% job_first_level_estimate(fspm,par)


%% Contrast : definition

names = {ONSETS{subj}{run}.name}';

Jitter  = [ 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 ];
Blank   = [ 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 ];

u_m20   = [ 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 ];
u_m10   = [ 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 ];
u_0     = [ 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 ];
u_p10   = [ 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 ];
u_p20   = [ 0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 ];

k_m20   = [ 0 0 0 0 0 0 0 1 0 0 0 0 0 0 0 ];
k_m10   = [ 0 0 0 0 0 0 0 0 1 0 0 0 0 0 0 ];
k_0     = [ 0 0 0 0 0 0 0 0 0 1 0 0 0 0 0 ];
k_p10   = [ 0 0 0 0 0 0 0 0 0 0 1 0 0 0 0 ];
k_p20   = [ 0 0 0 0 0 0 0 0 0 0 0 1 0 0 0 ];

Answer  = [ 0 0 0 0 0 0 0 0 0 0 0 0 1 0 0 ];
Yes     = [ 0 0 0 0 0 0 0 0 0 0 0 0 0 1 0 ];
No      = [ 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 ];

contrast.names = {

'Jitter'
'Blank'
'u_m20'
'u_m10'
'u_0'
'u_p10'
'u_p20'
'k_m20'
'k_m10'
'k_0'
'k_p10'
'k_p20'
'Answer'
'Yes'
'No'

'All faces'

'Unknown : increase activity with Value' 
'Unknown : decrease activity with Value' 

'Known   : increase activity with Value' 
'Known   : decrease activity with Value' 

'k_m20-k_0 '
'k_m10-k_0 '
'k_0-k_p10 '
'k_0-k_p20 '

'u_m20-u_0 '
'u_m10-u_0 '
'u_0-u_p10 '
'u_0-u_p20 '

}';

contrast.values = {
    
Jitter
Blank
u_m20
u_m10
u_0
u_p10
u_p20
k_m20
k_m10
k_0
k_p10
k_p20
Answer
Yes
No

u_m20 + u_m10 + u_0 + u_p10 + u_p20  +  k_m20 + k_m10 + k_0 + k_p10 + k_p20  

( -2*u_m20 -1*u_m10 +0*u_0 +1*u_p10 +2*u_p20 )
( -2*u_p20 -1*u_p10 +0*u_0 +1*u_m10 +2*u_m20 )

( -2*k_m20 -1*k_m10 +0*k_0 +1*k_p10 +2*k_p20 )
( -2*k_p20 -1*k_p10 +0*k_0 +1*k_m10 +2*k_m20 )

k_m20-k_0 
k_m10-k_0 
k_0-k_p10 
k_0-k_p20 

u_m20-u_0
u_m10-u_0
u_0-u_p10
u_0-u_p20

}';


contrast.types = cat(1,repmat({'T'},[1 length(contrast.names)]));


%% Contrast : write

par.run = 1;
par.display = 0;

par.sessrep = 'both';
% par.sessrep = 'none';

par.delete_previous = 1;

job_first_level_contrast(fspm,contrast,par);


%% Display

e.getModel(model_name).show

