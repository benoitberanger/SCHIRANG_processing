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

        for evt = 1:length(events)
            
            idx = regexp(data(:,1),events{evt});
            idx = ~cellfun(@isempty, idx);
            sub_data = data(idx,:);
            
            ONSETS{subj}{run}(evt).name     = char(events{evt});
            ONSETS{subj}{run}(evt).onset    = cell2mat(sub_data(:,2)) ;
            ONSETS{subj}{run}(evt).duration = cell2mat(sub_data(:,3)) ;
            
        end % evt
        
        ONSETS{subj}{run}(evt + 1).name     = s{1}.names    {2};
        ONSETS{subj}{run}(evt + 1).onset    = s{1}.onsets   {2};
        ONSETS{subj}{run}(evt + 1).duration = s{1}.durations{2};
        ONSETS{subj}{run}(evt + 2).name     = s{1}.names    {3};
        ONSETS{subj}{run}(evt + 2).onset    = s{1}.onsets   {3};
        ONSETS{subj}{run}(evt + 2).duration = s{1}.durations{3};
        
    end
end

par.run = 1;

par.TR = 1.6;
par.file_reg = '^run\d+_medn_afw';
par.rp = 1;
job_first_level_specify_modulator(dir_func,model_dir,ONSETS,par)


%% Estimate

fspm = e.addModel(model_name,model_name);
job_first_level_estimate(fspm,par)


%% Contrast : definition

Jitter  = [1 0 0 0 0 0];
Blank   = [0 1 0 0 0 0];
Picture = [0 0 1 0 0 0];
Answer  = [0 0 0 1 0 0];
Yes     = [0 0 0 0 1 0];
No      = [0 0 0 0 0 1];

contrast.names = {

'Jitter'
'Blank'
'Picture'
'Answer'
'Yes'
'No'

'Picture - Answer'
'Answer - Picture'

}';

contrast.values = {

    Jitter
    Blank
    Picture
    Answer
    Yes
    No
    
    Yes + No
    
    Picture - Answer
    Answer - Picture
    
    }';


contrast.types = cat(1,repmat({'T'},[1 length(contrast.names)]));


%% Contrast : write

par.run = 1;
par.display = 0;

par.sessrep = 'repl';

par.delete_previous = 1;

job_first_level_contrast(fspm,contrast,par);


%% Display

e.getModel(model_name).show

