%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%extract_parameters_and_cluster.m
%function that extracts relevant parameters from predicted distributions
%and uses unsupervised clustering to group them into tissue pathology
%groups, plots results in 3 dimensions for visualization
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%CHANGE THIS TO FOLDER CONTAINING ALL LIVER SAMPLES
samples_folder = 'path_to_folder_containing_liver_samples\';

%re-load predictions
load = true;
%use only validated samples
validated_only = true;
%plot sample labels
labels = false;

if load
    T = readtable([samples_folder 'tissue_pathology.csv']);
    sample_list_all = T.Sample;
    label_all = T.Final_Label;
    idx = ones(size(sample_list_all))==1; %#ok<NASGU>
    if validated_only
        stained = T.Stained_;
        idx = contains(stained,'Yes');
    end
    sample_list = sample_list_all(idx);
    label = label_all(idx);
    %pre-allocate
    mean_vec = zeros(length(sample_list),1);
    std_vec = zeros(length(sample_list),1);
    skew_vec = zeros(length(sample_list),1);
    for i=1:length(sample_list)
        sample_path = [samples_folder sample_list{i} ...
                       '\AFM_predictions\output_masked.tiff'];
        sample = imread(sample_path);
        mean_vec(i) = nanmean(sample,'all');
        std_vec(i) = nanstd(sample,0,'all');
        skew_vec(i) = skewness(sample,1,'all');
    end
end

%for reproducibility
rng('default')
X = [mean_vec std_vec skew_vec];

%find number of clusters
eva = evalclusters(X,'gmdistribution','Gap','Distance','sqEuclidean', ...
                     'SearchMethod','firstMaxSE','KList',1:size(X,2));
num_clusters = find(abs(eva.CriterionValues) == ...
                max(abs(eva.CriterionValues)));

%fit Gaussian distribution mixture
gm = fitgmdist(X,num_clusters,'CovarianceType','diagonal', ...
                 'ProbabilityTolerance',1e-6,'RegularizationValue',0.01,...
                 'Replicates',10,'Start','randSample');
P = posterior(gm,X); %for plotting
idx = cluster(gm,X);

switch num_clusters
    case 2
        figure
        for i=1:length(X)
            scatter3(mean_vec(i),std_vec(i),skew_vec(i),[], ...
                     [P(i,1) 0 P(i,2)], 'filled')
            hold on
        end
        text(mean_vec,std_vec,skew_vec,label,'Interpreter','none')
        if labels
            text(mean_vec,std_vec,skew_vec,sample_list, ...
                 'Interpreter','none','HorizontalAlignment','right')
        end
    case 3
        figure
        for i=1:length(X)
            scatter3(mean_vec(i),std_vec(i),skew_vec(i),[],P(i,:),'filled')
            hold on
        end
        text(mean_vec,std_vec,skew_vec,label,'Interpreter','none')
        if labels
            text(mean_vec,std_vec,skew_vec,sample_list, ...
                 'Interpreter','none','HorizontalAlignment','right')
        end
    case 4       
        figure
        plot3(mean_vec(idx==1),std_vec(idx==1),skew_vec(idx==1), ...
              'o','MarkerFaceColor','r','MarkerEdgeColor','none')
        hold on
        plot3(mean_vec(idx==2),std_vec(idx==2),skew_vec(idx==2), ...
              'o','MarkerFaceColor','c','MarkerEdgeColor','none')
        plot3(mean_vec(idx==3),std_vec(idx==3),skew_vec(idx==3), ...
              'o','MarkerFaceColor','g','MarkerEdgeColor','none')
        plot3(mean_vec(idx==4),std_vec(idx==4),skew_vec(idx==4), ...
              'o','MarkerFaceColor','k','MarkerEdgeColor','none')
        text(mean_vec,std_vec,skew_vec,label,'Interpreter','none')
        if labels
            text(mean_vec,std_vec,skew_vec,sample_list, ...
                 'Interpreter','none','HorizontalAlignment','right')
        end
end