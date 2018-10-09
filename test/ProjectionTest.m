classdef ProjectionTest < matlab.unittest.TestCase
    
    properties
        tmp_dir
    end
    
    methods(TestMethodSetup)
        function setup(testCase)
            tmpd = tempname;
            mkdir(tmpd);o
            testCase.tmp_dir = tmpd;
            utest_bst_setup();
        end
    end
    
    methods(TestMethodTeardown)
        function tear_down(testCase)
            rmdir(testCase.tmp_dir, 's');
            utest_clean_bst();
        end
    end

    methods(Test)
        
        function test_single_channel(testCase)
            global GlobalData;
            [subject_name, sSubject] = bst_create_test_subject();
            
            dt = 0.05; %sec (20Hz)
            time = (0:8000) * dt; %sec
            nb_samples = length(time);
            
            % simulate single-channel dummy signal 
            signals = randn(1, nb_samples);
            nirs_input_mat_fn = bst_create_nirs_data('test_single_channel', signals, time);
            
            
            % Generate fluences
            head_mesh_fn = sSubject.Surface(sSubject.iScalp).FileName;
            sMri = in_mri_bst(sSubject.Anatomy(sSubject.iAnatomy).FileName);
            sHead = in_tess_bst(head_mesh_fn);
            nirs_input = in_bst_data(nirs_input_mat_fn);
            ChannelMat = in_bst_channel(nirs_input.ChannelFile);
            [tt, tt, tt, tt, src_coords, tt, tt, det_coords, tt, tt] = process_nst_import_head_model('explode_channels', ChannelMat);
            [src_hv_idx det_hv_idx] = process_nst_import_head_model('get_head_vertices_closest_to_optodes', ...
                                                                    sMri, sHead, src_coords, det_coords);
            fluence_dir = cpt_spherical_fluences(sSubject, [src_hv_idx det_hv_idx], ChannelMat.Nirs.Wavelengths);
            
            % compute head model
            bst_process('CallProcess', ...
                'process_nst_import_head_model', nirs_input_mat_fn, [], ...
                'data_source', fluence_dir, ...
                'do_export_fluence_vol', 1, ...
                'outputdir', fluence_dir);
            
            % Do projection
            
            % Test that projected signals == channel signal up to amplitude
            % factor
            
               
            if 0
            stg_vertex_id = 19552;
            roi_scout_selection = bst_create_scout(subject_name, 'cortex', 'roi_temporal', ...
                                                   stg_vertex_id, 2, 'User scouts');

            extent_cm = 3; % centimeter
            head_vertices = process_nst_cpt_fluences_from_cortex('proj_cortex_scout_to_scalp', ...
                                                                 roi_scout_selection, extent_cm * 0.01);
            wavelengths = 685;
            fluence_dir = cpt_spherical_fluences(roi_scout_selection.sSubject, head_vertices, wavelengths);
            bst_process('CallProcess', ...
                'process_nst_OM_from_cortex', [], [], ...
                'scout_sel_roi', roi_scout_selection, ...
                'cortex_to_scalp_extent', extent_cm, ...
                'condition_name', 'OM_test', ...
                'wavelengths', strjoin(arrayfun(@num2str, wavelengths, 'UniformOutput', false), ','), ...
                'data_source', fluence_dir, ...
                'nb_sources', 1, ...
                'nb_detectors', 2, ...
                'nAdjacentDet', 0, ...
                'exist_weight', 0, ...
                'sep_optode', {[0 55],'mm', 0});
            
            testCase.assertEmpty(GlobalData.lastestFullErrMsg);
            % TODO add checks on nb optodes + separations
            end
        end
    end
end



% function fluence = load_fluence_spherical(vertex_id, sInputs)
% 
% ChannelMat = in_bst_channel(sInputs(1).ChannelFile);
% wavelengths = ChannelMat.Nirs.Wavelengths;
% 
% fluence_bfn =  sprintf('fluence_spherical_%d.mat', vertex_id); 
% fluence_fn = bst_fullfile(bst_get('BrainstormUserDir'), 'defaults', ...
%                               'nirstorm', fluence_bfn);
% if ~file_exist(fluence_fn)
%     % Create folder
%     if ~file_exist(bst_fileparts(fluence_fn))
%         mkdir(bst_fileparts(fluence_fn));
%     end
%     
%     [sSubject, iSubject] = bst_get('Subject', sInputs.SubjectName);
%     anatomy_file = sSubject.Anatomy(sSubject.iAnatomy).FileName;    
%     head_mesh_fn = sSubject.Surface(sSubject.iScalp).FileName;
%     
%     % Obtain the head mesh
%     sHead = in_tess_bst(head_mesh_fn);
%     
%     % Obtain the anatomical MRI
%     sMri = in_mri_bst(anatomy_file);
%     [dimx, dimy, dimz] = size(sMri.Cube);
%     
%     vertex = sHead.Vertices(vertex_id, :);
%     % Vertices: SCS->MRI, MRI(MM)->MRI(Voxels)
%     vertex = round(cs_convert(sMri, 'scs', 'mri', vertex) * 1000 ./ sMri.Voxsize);
%     
%     dcut = 30; %mm
%     svox = sMri.Voxsize;
%     fluence_vol = zeros(dimx, dimy, dimz);
%     for i=1:dimx
%         for j=1:dimy
%             for k=1:dimz
%                 cp = (vertex - [i,j,k]) .* svox;
%                 fluence_vol(i,j,k) = max(0, 1 - sqrt(sum(cp .* cp)) / dcut);
%             end
%         end
%     end
%     save(fluence_fn, 'fluence_vol');
% else
%     load(fluence_fn, 'fluence_vol');
% end
% 
% for iwl=1:length(wavelengths)
%     fluence{iwl}.fluence.data = fluence_vol;
% end
%     
% end
% 
