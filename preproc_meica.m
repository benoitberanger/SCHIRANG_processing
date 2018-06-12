clear
clc

% if 0
%     do_delete(fullfile(pwd,'img'),0);
%     r_copy_suj({fullfile(pwd,'raw','2018_04_17_HIRES_LEX_TLF04')},fullfile(pwd,'img'));
% end

main_dir = fullfile(pwd,'img');

e = exam(main_dir,'SCHIRANG');

e.addSerie('Run_\d$','run',2)
e.addVolume('run','^f','f')

e.addSerie('3DT1','anat',1)
e.addVolume('anat','^s.*nii','s',1)


e.explore

dir_func  = e.getSerie('run') .toJob;
dir_anat = e.getSerie('anat').toJob(0);

par.fake = 0;
par.redo = 0;
par.verbose = 2;

% par.cmd_arg = '--daw=3';

%%
tic
job_meica_afni(dir_func, dir_anat, par);
toc
