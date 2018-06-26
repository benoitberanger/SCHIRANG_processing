clear
clc

return

%% Prepare paths and regexp

mainPath = [ pwd filesep 'img'];

%for the preprocessing : Volume selection
par.anat_file_reg  = '^s.*nii'; %le nom generique du volume pour l'anat
par.file_reg  = '^e.*nii'; %le nom generique du volume pour les fonctionel

par.display=0;
par.run=1;
par.verbose = 2;


%% Get files paths

% dfonc = get_subdir_regex_multi(suj,par.dfonc_reg) % ; char(dfonc{:})
% dfonc_op = get_subdir_regex_multi(suj,par.dfonc_reg_oposit_phase)% ; char(dfonc_op{:})
% dfoncall = get_subdir_regex_multi(suj,{par.dfonc_reg,par.dfonc_reg_oposit_phase })% ; char(dfoncall{:})
% anat = get_subdir_regex_one(suj,par.danat_reg)% ; char(anat) %should be no warning

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

e = exam(mainPath,'SCHIRANG_Pilote001');

% T1
e.addSerie('3DT1','anat',1)
e.addVolume('anat','^s.*nii','s',1)


e.addSerie('Run_1$'        , 'run_1_nm'        ,1)
e.addSerie('Run_1_BLIP$'   , 'run_1_blip'      ,1)
e.addSerie('Run_2$'        , 'run_2_nm'        ,1)
e.addSerie('Run_2_BLIP$'   , 'run_2_blip'      ,1)

allRunDir = e.getSerie('run').toJob(1);
allRunDir = allRunDir{1}';

for s = 1 : length(allRunDir)
    volume_path = fetch_echo(allRunDir(s), 2); % fetch echo 2
    [volume_path, volume_name] = get_parent_path(volume_path); % extract the name of the volume
    % File extension ?
    if strcmp(volume_name(end-6:end),'.nii.gz')
        ext_echo = '.nii.gz';
    elseif strcmp(volume_name(end-3:end),'.nii')
        ext_echo = '.nii';
    else
        error('WTF ? supported files are .nii and .nii.gz')
    end
    r_movefile(fullfile(volume_path,volume_name), fullfile(volume_path,['echo2' ext_echo]), 'linkn', par);
    e.getSerie(allRunDir{s},'path').addVolume('^echo2','e',1) % add it
end

% Unzip if necessary
e.unzipVolume

e.reorderSeries('name'); % mostly useful for topup, that requires pairs of (AP,PA)/(PA,AP) scans

e.explore

subjectDirs = e.toJob
regex_dfonc    = 'run_\d_nm'  ;
regex_dfonc_op = 'run_\d_blip';
dfonc    = e.getSerie(regex_dfonc   ).toJob
dfonc_op = e.getSerie(regex_dfonc_op).toJob
dfoncall = e.getSerie('run'         ).toJob
anat     = e.getSerie('anat'        ).toJob(0)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

t0 = tic;
return

%% Segment anat

% %anat segment
% % anat = get_subdir_regex(suj,par.danat_reg)
% fanat = get_subdir_regex_files(anat,par.anat_file_reg,1)
%
% par.GM   = [0 0 1 0]; % Unmodulated / modulated / native_space dartel / import
% par.WM   = [0 0 1 0];
% j_segment = job_do_segment(fanat,par)
%
% %apply normalize on anat
% fy = get_subdir_regex_files(anat,'^y',1)
% fanat = get_subdir_regex_files(anat,'^ms',1)
% j_apply_normalise=job_apply_normalize(fy,fanat,par)

%anat segment
fanat = e.getSerie('anat').getVolume('^s').toJob

par.GM   = [0 0 1 0]; % Unmodulated / modulated / native_space dartel / import
par.WM   = [0 0 1 0];
j_segment = job_do_segment(fanat,par)
fy    = e.getSerie('anat').addVolume('^y' ,'y' )
fanat = e.getSerie('anat').addVolume('^ms','ms')

%apply normalize on anat
j_apply_normalise=job_apply_normalize(fy,fanat,par)
e.getSerie('anat').addVolume('^wms','wms',1)


%% Brain extract

% ff=get_subdir_regex_files(anat,'^c[123]',3);
% fo=addsuffixtofilenames(anat,'/mask_brain');
% do_fsl_add(ff,fo)
% fm=get_subdir_regex_files(anat,'^mask_b',1); fanat=get_subdir_regex_files(anat,'^s.*nii',1);
% fo = addprefixtofilenames(fanat,'brain_');
% do_fsl_mult(concat_cell(fm,fanat),fo);

ff=e.getSerie('anat').addVolume('^c[123]','c',3)
fo=addsuffixtofilenames(anat{1}(1,:),'/mask_brain');
do_fsl_add(ff,fo)

fm=e.getSerie('anat').addVolume('^mask_b','mask_brain',1)
fanat=e.getSerie('anat').getVolume('^s').toJob
fo = addprefixtofilenames(fanat,'brain_');
do_fsl_mult(concat_cell(fm,fanat),fo);
e.getSerie('anat').addVolume('^brain_','brain_',1)


%% Preprocess fMRI runs

%realign and reslice
par.file_reg = '^e.*nii'; par.type = 'estimate_and_reslice';
j_realign_reslice = job_realign(dfonc,par)
e.getSerie(regex_dfonc).addVolume('^re','re',1)

%realign and reslice opposite phase
par.file_reg = '^e.*nii'; par.type = 'estimate_and_reslice';
j_realign_reslice_op = job_realign(dfonc_op,par)
e.getSerie(regex_dfonc_op).addVolume('^re','re',1)

%topup and unwarp
par.file_reg = {'^re.*nii'}; par.sge=0;
do_topup_unwarp_4D(dfoncall,par)
e.getSerie('run').addVolume('^utmeane','utmeane',1)
e.getSerie('run').addVolume('^utre.*nii','utre',1)

%coregister mean fonc on brain_anat
% fanat = get_subdir_regex_files(anat,'^s.*nii$',1) % raw anat
% fanat = get_subdir_regex_files(anat,'^ms.*nii$',1) % raw anat + signal bias correction
% fanat = get_subdir_regex_files(anat,'^brain_s.*nii$',1) % brain mask applied (not perfect, there are holes in the mask)
fanat = e.getSerie('anat').getVolume('^brain_').toJob
par.type = 'estimate';
fmean = e.getSerie('run_1_nm$').getVolume('^utmeane').toJob
fo = e.getSerie(regex_dfonc).getVolume('^utre').toJob
j_coregister=job_coregister(fmean,fanat,fo,par)

%apply normalize
fy = e.getSerie('anat').getVolume('^y').toJob
j_apply_normalize=job_apply_normalize(fy,fo,par)

%smooth the data
ffonc = e.getSerie(regex_dfonc).addVolume('^wutre','wutre',1)
par.smooth = [8 8 8];
j_smooth=job_smooth(ffonc,par)
e.getSerie(regex_dfonc).addVolume('^swutre','swutre',1)

toc(t0)

save('e','e')
