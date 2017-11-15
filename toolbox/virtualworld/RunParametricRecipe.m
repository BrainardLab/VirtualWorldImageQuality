function RunParametricRecipe(varargin)
% RunParametricRecipe  Wrapper function for MakeRecipesByCombinations
% 
% Description:
%    Make, execute, and analyze virtual world recipes.  This is basically a
%    wrapper for MakeRecipesByCombinations.  
%
%    It is not entirely clear that we need this function, perhaps we should
%    just be calling MakeRecipesByCombinations from whatever is calling this.
%
% Optional key/value pairs
%   'outputName' - Output File Name, Default ExampleOutput
%   'imageWidth'  - MakeRecipesByCombinations width, Should be kept
%                  small to keep redering time low for rejected recipes
%   'imageHeight'  - MakeRecipesByCombinations height, Should be kept
%                  small to keep redering time low for rejected recipes
%   'nOtherObjectSurfaceReflectance' - Number of spectra to be generated
%                   for choosing background surface reflectance (max 999)
%   'luminanceLevels' - Luminance levels of target object
%   'reflectanceNumbers' - A row vetor containing Reflectance Numbers of 
%                   target object. These are just dummy variables to give a
%                   unique name to each random spectra.
%   'illuminantSpectrumNotFlat' - boolean to specify illumination spectra 
%                   shape to be not flat, i.e. random, (true= random)
%   'minMeanIlluminantLevel' - Min of mean value of ilumination spectrum
%   'maxMeanIlluminantLevel' - Max of mean value of ilumination spectrum
%   'targetSpectrumNotFlat' - boolean to specify arget spectra 
%                   shape to be not flat, i.e. random, (true= random)
%   'allTargetSpectrumSameShape' - boolean to specify all target spectrum 
%                   to be of same shape
%   'targetReflectanceScaledCopies' - boolean to specify target reflectance
%                   shape to be same at each reflectance number. This will
%                   create multiple hue, but the same hue will be repeated
%                   at each luminance level
%   'baseSceneSet'  - Base scenes to be used for renderings. One of these
%                  base scenes is used for each rendering
%   'objectShapeSet'  - Shapes of the target object other inserted objects

%% Want each run to start with its own random seed
rng('shuffle');

%% Get inputs and defaults.
p = inputParser();
p.addParameter('outputName','ExampleOutput',@ischar);
p.addParameter('imageWidth', 320, @isnumeric);
p.addParameter('imageHeight', 240, @isnumeric);
p.addParameter('nOtherObjectSurfaceReflectance', 100, @isnumeric);
p.addParameter('luminanceLevels', [0.2 0.6], @isnumeric);
p.addParameter('reflectanceNumbers', [1 2], @isnumeric);
p.addParameter('illuminantSpectrumNotFlat', true, @islogical);
p.addParameter('minMeanIlluminantLevel', 10, @isnumeric);
p.addParameter('maxMeanIlluminantLevel', 30, @isnumeric);
p.addParameter('targetSpectrumNotFlat', true, @islogical);
p.addParameter('allTargetSpectrumSameShape', false, @islogical);
p.addParameter('targetReflectanceScaledCopies', false, @islogical);
p.addParameter('objectShape','Barrel', @ischar);
p.addParameter('baseScene', 'Library', @ischar);
p.parse(varargin{:});

%% Set up full-sized parpool if available.
% if exist('parpool', 'file')
%     delete(gcp('nocreate'));
%     nCores = feature('numCores');
%     parpool('local', nCores);
% end

%% Go through the steps for this combination of parameters.
%try
    % Using one base scene and one object at a time
    MakeParametricRecipe( ...
        'outputName',p.Results.outputName,...
        'imageWidth', p.Results.imageWidth, ...
        'imageHeight', p.Results.imageHeight, ...
        'nOtherObjectSurfaceReflectance', p.Results.nOtherObjectSurfaceReflectance,...
        'luminanceLevels', p.Results.luminanceLevels, ...
        'reflectanceNumbers', p.Results.reflectanceNumbers,...
        'illuminantSpectrumNotFlat',p.Results.illuminantSpectrumNotFlat,...
        'minMeanIlluminantLevel', p.Results.minMeanIlluminantLevel,...
        'maxMeanIlluminantLevel', p.Results.maxMeanIlluminantLevel,...
        'targetSpectrumNotFlat',p.Results.targetSpectrumNotFlat,...
        'allTargetSpectrumSameShape',p.Results.allTargetSpectrumSameShape,...
        'targetReflectanceScaledCopies',p.Results.targetReflectanceScaledCopies,...
        'objectShapeSet', {p.Results.objectShape}, ...
        'baseSceneSet', {p.Results.baseScene});
    
% catch err
%     workingFolder = fullfile(getpref('VirtualWorldImageQuality', 'outputDataFolder'),p.Results.outputName);
%     SaveVirtualWorldError(workingFolder, err, 'RunVirtualWorldRecipes', varargin);
% end

%% Save timing info.
PlotVirtualWorldTiming('outputName',p.Results.outputName);

%% Save summary of conditions in text file
SaveRecipeConditionsInTextFile(p);
