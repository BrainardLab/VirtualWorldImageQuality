function MakeParametricRecipe(varargin)
% MakeParametricRecipe  Construct and render a recipe, with parametric control.
%
% Description:
%   Setup and render a recipe where we insert an object into a base scene,
%   and provide parametric control over key scene parameters.
%
% Optional key/value pairs
%   'outputName' - Output folder name (default 'ExampleOutput')
%   'imageWidth' - Image width, should be kept small to keep redering time
%                   low for rejected recipes
%   'imageHeight'- Image height, Should be kept small to keep redering time
%                   low for rejected recipes
%   'nOtherObjectSurfaceReflectance' - Number of spectra to be generated
%                   for choosing background surface reflectance (max 999)
%   'luminanceLevels' - luminance levels of target object
%   'reflectanceNumbers' - A row vetor containing Reflectance Numbers of
%                   target object. These are just dummy variables to give a
%                   unique name to each random spectra.
%   'illuminantSpectrumNotFlat' - boolean to specify illumination spectra
%                   shape to be not flat, i.e. random, (true= random)
%   'minMeanIlluminantLevel' - Min of mean value of ilumination spectrum
%   'maxMeanIlluminantLevel' - Max of mean value of ilumination spectrum
%   'targetSpectrumNotFlat' - boolean to specify arget spectra
%                   shape to be not flat, i.e. random, (true= random)
%   'allTargetSpectrumSameShape' - boolean to specify all target spectrum to
%                   be of same shape
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
p.addParameter('cropImageHalfSize', 25, @isnumeric);
p.addParameter('nOtherObjectSurfaceReflectance', 100, @isnumeric);
p.addParameter('luminanceLevels', [0.2 0.6], @isnumeric);
p.addParameter('reflectanceNumbers', [1 2], @isnumeric);
p.addParameter('illuminantSpectrumNotFlat', true, @islogical);
p.addParameter('minMeanIlluminantLevel', 10, @isnumeric);
p.addParameter('maxMeanIlluminantLevel', 30, @isnumeric);
p.addParameter('targetSpectrumNotFlat', true, @islogical);
p.addParameter('allTargetSpectrumSameShape', false, @islogical);
p.addParameter('targetReflectanceScaledCopies', false, @islogical);
p.addParameter('objectShapeSet', ...
    {'Barrel', 'BigBall', 'ChampagneBottle', 'RingToy', 'SmallBall', 'Xylophone'}, @iscellstr);
p.addParameter('lightShapeSet', ...
    {'Barrel', 'BigBall', 'ChampagneBottle', 'RingToy', 'SmallBall', 'Xylophone'}, @iscellstr);
p.addParameter('baseSceneSet', ...
    {'CheckerBoard', 'IndoorPlant', 'Library', 'Mill', 'TableChairs', 'Warehouse'}, @iscellstr);
p.parse(varargin{:});

%% Some convenience variables
nLuminanceLevels = numel(p.Results.luminanceLevels);
nReflectances = numel(p.Results.reflectanceNumbers);

%% Basic setup we don't (yet) want to expose as parameters.
projectName = 'VirtualWorldImageQuality';
hints.renderer = 'Mitsuba';
hints.isPlot = false;

%% Set up output.
%
% Use project specific preferences to get the output folder.  These
% preferences are set in the project local hook; see
% configuration/VirtualWorldImageQualityLocalHookTemplate.m.  Make a local
% copy of this, modify to suit your needs, and run before working on this
% project.  If you use ToolboxToolbox, much of this will happen
% automatically.
hints.workingFolder = fullfile(getpref(projectName, 'outputDataFolder'),p.Results.outputName,'Working');
originalsFolder = fullfile(getpref(projectName, 'outputDataFolder'),p.Results.outputName,'Originals');
if (~exist(originalsFolder, 'dir'))
    mkdir(originalsFolder);
end

%% Set size of rendered output image
hints.imageHeight = p.Results.imageHeight;
hints.imageWidth = p.Results.imageWidth;

%% Configure where to find assets
aioPrefs.locations = aioLocation( ...
    'name', 'VirtualScenesExampleAssets', ...
    'strategy', 'AioFileSystemStrategy', ...
    'baseDir', fullfile(vseaRoot(), 'examples'));

%% Get base scenes
%
% This loads in base scenes from our assets
nBaseScenes = numel(p.Results.baseSceneSet);
baseScenes = cell(1, nBaseScenes);
baseSceneInfos = cell(1, nBaseScenes);
for bb = 1:nBaseScenes
    name = p.Results.baseSceneSet{bb};
    [baseScenes{bb}, baseSceneInfos{bb}] = VseModel.fromAsset('BaseScenes', name, ...
        'aioPrefs', aioPrefs, ...
        'nameFilter', 'blend$');
end

%% Get shapes to insert
%
% This will load object models, as above for base scenes
nObjectShapes = numel(p.Results.objectShapeSet);
objectShapes = cell(1, nObjectShapes);
for ss = 1:nObjectShapes
    name = p.Results.objectShapeSet{ss};
    objectShapes{ss} = VseModel.fromAsset('Objects', name, ...
        'aioPrefs', aioPrefs, ...
        'nameFilter', 'blend$');
end

%% Get light shapes to insert
%
% This will load light models, as above
nLightShapes = numel(p.Results.lightShapeSet);
lightShapes = cell(1, nLightShapes);
for ll = 1:nLightShapes
    name = p.Results.lightShapeSet{ll};
    lightShapes{ll} = VseModel.fromAsset('Objects', name, ...
        'aioPrefs', aioPrefs, ...
        'nameFilter', 'blend$');
end

%% Make some illuminant spectra and store them in the Data/Illuminants/BaseScene folder.
%
% See comment above about the project specific 'outputDataFolder' preference, which defines
% the parent folder for these.
%
% * [NOTE - DHB: The hard coding of the number of illuminant spectra here
%    not good, and should be made more transparent.]
dataBaseDir = fullfile(getpref(projectName,'outputDataFolder'),p.Results.outputName,'Data');
illuminantsFolder = fullfile(getpref(projectName,'outputDataFolder'),p.Results.outputName,'Data','Illuminants','BaseScene');
totalLightSpectra = 1;
if (p.Results.illuminantSpectrumNotFlat)
    makeIlluminants(projectName,totalLightSpectra,illuminantsFolder, ...
        p.Results.minMeanIlluminantLevel, p.Results.maxMeanIlluminantLevel);
else
    makeFlatIlluminants(totalLightSpectra,illuminantsFolder, ...
        p.Results.minMeanIlluminantLevel, p.Results.maxMeanIlluminantLevel);
end


%% Make some reflectances and store them where they want to be
%
% This makes reflectance spectra both for the inserted target object and
% for the other objects in the scene.
%
% * [NOTE - DHB: Figure out a bit better about how many surfaces get made,
%    and document here.]
otherObjectFolder = fullfile(getpref(projectName, 'outputDataFolder'),p.Results.outputName,'Data','Reflectances','OtherObjects');
makeOtherObjectReflectance(p.Results.nOtherObjectSurfaceReflectance,otherObjectFolder);
targetObjectFolder = fullfile(getpref(projectName, 'outputDataFolder'),p.Results.outputName,'Data','Reflectances','TargetObjects');
if (p.Results.targetSpectrumNotFlat)
    if (p.Results.allTargetSpectrumSameShape)
        makeSameShapeTargetReflectance(p.Results.luminanceLevels,p.Results.reflectanceNumbers, targetObjectFolder);
    elseif (p.Results.targetReflectanceScaledCopies)
        makeTargetReflectanceScaledCopies(p.Results.luminanceLevels,p.Results.reflectanceNumbers, targetObjectFolder)
    else
        makeTargetReflectance(p.Results.luminanceLevels, p.Results.reflectanceNumbers, targetObjectFolder);
    end
else
    makeFlatTargetReflectance(p.Results.luminanceLevels, p.Results.reflectanceNumbers, targetObjectFolder);
end

%% Choose illuminant spectra from the illuminants folder.
%
% * [NOTE - DHB: I think these are selected from the illuminants we created
%    above, but now pushed through the API that the virtual scenes engine
%    likes.]
illuminantsLocations.config.baseDir = dataBaseDir;
illuminantsLocations.name = 'WorldIlluminants';
illuminantsLocations.strategy = 'AioFileSystemStrategy';
illuminantsAioPrefs = aioPrefs;
illuminantsAioPrefs.locations = illuminantsLocations;
illuminantSpectra = aioGetFiles('Illuminants', 'BaseScene', ...
    'aioPrefs', illuminantsAioPrefs, ...
    'fullPaths', false);

%% Choose reflectance for scene overall
%
% * [NOTE - DHB: I think these are selected from the surface reflectances we created
%    above, but now pushed through the API that the virtual scenes engine
%    likes.]
otherObjectLocations.config.baseDir = dataBaseDir;
otherObjectLocations.name = 'WorldReflectances';
otherObjectLocations.strategy = 'AioFileSystemStrategy';
otherObjectAioPrefs = aioPrefs;
otherObjectAioPrefs.locations = otherObjectLocations;
otherObjectReflectances = aioGetFiles('Reflectances', 'OtherObjects', ...
    'aioPrefs', otherObjectAioPrefs, ...
    'fullPaths', false);
baseSceneReflectances = otherObjectReflectances;

%% Choose Reflectance for target object overall
%
% * [NOTE - DHB: I think these are selected from the target surface
%    reflectances we created above, but now pushed through the API that the
%    virtual scenes engine likes.]
targetLocations.config.baseDir = dataBaseDir;
targetLocations.name = 'WorldTarget';
targetLocations.strategy = 'AioFileSystemStrategy';
targetAioPrefs = aioPrefs;
targetAioPrefs.locations = targetLocations;
targetObjectReflectance = aioGetFiles('Reflectances', 'TargetObjects', ...
    'aioPrefs', targetAioPrefs, ...
    'fullPaths', false);

%% Assemble recipies by combinations of target luminances reflectances.
%
% nReflectances is the number of distinct target reflectances to use for
% each target luminance level specified.  For each specfied target
% luminance, we render nReflectances scenes, with the base scene, target
% object, illuminant shape, illuminant spectrum, and surface reflectances
% for the objects in the scene chosen randomly.
nScenes = nLuminanceLevels * nReflectances;
sceneRecord = struct( ...
    'targetLuminanceLevel', [], ...
    'reflectanceNumber', [],  ...
    'choices', [], ...
    'hints', hints, ...
    'rejected', [], ...
    'recipe', [], ...
    'styles', []);

% Pre-fill luminance and reflectance conditions per scene record,
% so that we can unroll the nested loops below
for ll = 1:nLuminanceLevels
    targetLuminanceLevel = p.Results.luminanceLevels(ll);
    for rr = 1:nReflectances
        reflectanceNumber = p.Results.reflectanceNumbers(rr);
        
        sceneIndex = rr + (ll-1)*nReflectances;
        sceneRecord(sceneIndex).targetLuminanceLevel = targetLuminanceLevel;
        sceneRecord(sceneIndex).reflectanceNumber = reflectanceNumber;
    end
end

% This is one big loop, with each time through creating one scene.
%
% We use one loop rather than nesting because we can switch to parfor
% without having to recode.
for sceneIndex = 1:nScenes
    % Grab the scene record for this scene
    workingRecord = sceneRecord(sceneIndex);
    
    
%    try
        % Try/catch in case something goes awry with the rendering.
        % Nothing should go wrong, but you never know.  The catch statement
        % below tries to save out some diagnostic information if there is
        % an error.
        
        % Pick the base scene randomly.
        bIndex = randi(size(p.Results.baseSceneSet, 2), 1);
        baseSceneInfo = baseSceneInfos{bIndex};
        workingRecord.choices.baseSceneName = baseSceneInfo.name;
        sceneData = baseScenes{bIndex}.copy('name',workingRecord.choices.baseSceneName);
        
        % Pick the target object randomly
        targetShapeIndex = randi(nObjectShapes, 1);
        targetShapeName = p.Results.objectShapeSet{targetShapeIndex};
        
        % Choose a unique name for this recipe, constructed in part
        % from the chosen base scene and target object.
        recipeName = FormatRecipeName( ...
            workingRecord.targetLuminanceLevel, ...
            workingRecord.reflectanceNumber, ...
            targetShapeName, ...
            workingRecord.choices.baseSceneName);
        workingRecord.hints.recipeName = recipeName;
        
        % This next block of code sets up where the target object
        % goes in the scene.
        %
        % These positions taken from a run of the routine that chooses
        % parameters randomly, but using annotated base scene info to help
        % them be sensible.
        
        % Target object rotation
        % Fixed rotation.
        % These values were chosen for the mill-ringtoy case by Vijay Singh
        targetShape = objectShapes{targetShapeIndex};
        targetRotationX = 265;
        targetRotationY = 260;
        targetRotationZ = 101;
 
        % Fixed position.  Some possible choices below
        targetPosition = [0.15769 -0.77352 -0.36083];    % Barrel-Library
        
        % Fixed scaling
        targetScale =  1;  
        
        % Target object transformation
        transformation = mexximpScale(targetScale) ...
            * mexximpRotate([1 0 0], targetRotationX) ...
            * mexximpRotate([0 1 0], targetRotationY) ...
            * mexximpRotate([0 0 1], targetRotationZ) ...
            * mexximpTranslate(targetPosition);
        
        % Set up target for insertion after transformation.  The
        % insertShapes cell array will hold information for the target
        % object plus the additional inserted objects.
        insertShapes = cell(1, 1);
        insertShapes{1} = targetShape.copy( ...
            'name', 'shape-01', ...
            'transformation', transformation);
        
        % Store the shape, locations, rotation, etc. of each of the
        % inserted objects in a conditions.txt file
        %
        % Basic setup of the conditions.txt file.  The allNames cell array
        % will hold the column header names that can be understood from a
        % conditions file, and the allValues cell array contains what
        % should go under each column.  We start out with the name
        % ('normal') that we'll be using for the one condition we render
        % for each scene, and then below concatenate in more and more
        % columns as we build up information.
        allNames = {'imageName', 'groupName'};
        allValues = cat(1, {'normal', 'normal'});
       
        % Setup for the target object position, rotation and scale, etc
        % for the conditions file.
        objectColumn = sprintf('object-%d', 1);
        positionColumn = sprintf('object-position-%d', 1);
        rotationColumn = sprintf('object-rotation-%d', 1);
        scaleColumn = sprintf('object-scale-%d', 1);
        varNames = {objectColumn, positionColumn, rotationColumn, scaleColumn};
        allNames = cat(2, allNames, varNames);
        varValues = {targetShape.name, ...
            targetPosition, ...
            [targetRotationX targetRotationY targetRotationZ], ...
            targetScale};
        allValues = cat(2, allValues, varValues);
        
        % Position the camera.
        %   Variable eye is position is from the first camera "slot"
        %   Variable target is the target object's position
        %   Variable up is direction somehow relative to the first camera "slot"
        eye = baseSceneInfo.cameraSlots(1).position;
        up = baseSceneInfo.cameraSlots(1).up;
        lookAt = mexximpLookAt(eye, targetPosition, up);
        cameraName = sceneData.model.cameras(1).name;
        isCameraNode = strcmp(cameraName, {sceneData.model.rootNode.children.name});
        sceneData.model.rootNode.children(isCameraNode).transformation = lookAt;
        
        % Write out the condition file for our scenes
        conditionsFile = fullfile(hints.workingFolder,recipeName,'Conditions.txt');
        rtbWriteConditionsFile(conditionsFile, allNames, allValues);
        
        % Choose styles for the full radiance rendering.
        fullRendering = VwccMitsubaRenderingQuality( ...
            'integratorPluginType', 'path', ...
            'samplerPluginType', 'ldsampler');
        fullRendering.addIntegratorProperty('maxDepth', 'integer', 10);
        fullRendering.addSamplerProperty('sampleCount', 'integer', 512);
        
        % Bless specific meshes in the base scene as area lights.
        %
        % * [NOTE - DHB: I think this is an annoyance having to do with how
        %    meshes are understood by the render and that we need to take
        %    the meshes of both the base scene and of the objects we
        %    inserted as lights and "bless" them them into lights in the
        %    scene description.  I think the word "bless" is just because
        %    BSH thought it was funny.  But I am not very sure about the
        %    whole blessing thing, and ideally someday we will figure it
        %    out more carefully.]
        %
        % The lights in the base scene
        nBaseLights = numel(baseSceneInfo.lightIds);
        baseLightNames = cell(1,nBaseLights);
        for ll = 1:nBaseLights
            lightId = baseSceneInfo.lightIds{ll};
            meshSuffixIndex = strfind(lightId, '-mesh');
            if ~isempty(meshSuffixIndex)
                baseLightNames{ll} = lightId(1:meshSuffixIndex-1);
            else
                baseLightNames{ll} = lightId;
            end
        end
        baseLightFilter = sprintf('%s|', baseLightNames{:});
        baseLightFilter = baseLightFilter(1:end-1);
        blessBaseLights = VseMitsubaAreaLights( ...
            'name', 'blessBaseLights', ...
            'applyToInnerModels', false, ...
            'elementNameFilter', baseLightFilter);
        
        % Assign spectra to all the lights.  
        % 
        % This is magic VSE code that gets the illuminant spcectra assigned
        % to each light.
        areaLightSpectra = VseMitsubaEmitterSpectra( ...
            'name', 'areaLightSpectra', ...
            'pluginType', 'area', ...
            'propertyName', 'radiance');
        areaLightSpectra.resourceFolder = dataBaseDir;
        tempIlluminantSpectra = illuminantSpectra;
        areaLightSpectra.addManySpectra(tempIlluminantSpectra);
        
        % Assign spectra to materials in the base scene.
        %
        % This is more magic VSE code.
        %
        % Note setting of resourceFolder to point to where the
        % files with the spectra live.  This is necessary so
        % that when the recipe gets built, these spectral files
        % can be found and copied into the right place.
        baseSceneDiffuse = VseMitsubaDiffuseMaterials( ...
            'name', 'baseSceneDiffuse', ...
            'applyToInnerModels', false);
        baseSceneDiffuse.resourceFolder = dataBaseDir;
        tempBaseSceneReflectances = baseSceneReflectances;
        baseSceneDiffuse.addManySpectra(tempBaseSceneReflectances);
        
        % Assign spectra to all materials of inserted shapes
        insertedDiffuse = VseMitsubaDiffuseMaterials( ...
            'name', 'insertedDiffuse', ...
            'modelNameFilter', 'shape-',...
            'applyToOuterModels', false);
        insertedDiffuse.resourceFolder = dataBaseDir;
        tempOtherObjectReflectances = otherObjectReflectances((randperm(length(otherObjectReflectances))));
        tempOtherObjectReflectances = otherObjectReflectances;
        insertedDiffuse.addManySpectra(tempOtherObjectReflectances);
        
        % Assign a specific reflectance to the target object
        targetDiffuse = VseMitsubaDiffuseMaterials( ...
            'name', 'targetDiffuse', ...
            'applyToOuterModels', false, ...
            'modelNameFilter', 'shape-01');
        targetDiffuse.resourceFolder = dataBaseDir;
        reflectanceFileName = sprintf('luminance-%.4f-reflectance-%03d.spd', ...
            workingRecord.targetLuminanceLevel, workingRecord.reflectanceNumber);
        targetDiffuse.addManySpectra({reflectanceFileName});
        
        % Define the VSE style for the rendering we are going to do.
        workingRecord.styles.normal = {fullRendering, ...
            blessBaseLights, areaLightSpectra, ...
            baseSceneDiffuse, insertedDiffuse, targetDiffuse};
        
        % Do the rendering
        innerModels = [insertShapes{:}];
        workingRecord.recipe = vseBuildRecipe(sceneData, innerModels, workingRecord.styles, 'hints', workingRecord.hints);
        workingRecord.recipe = rtbExecuteRecipe(workingRecord.recipe);
        
        % Save the recipe to the recipesFolder
        archiveFile = fullfile(originalsFolder, workingRecord.hints.recipeName);
        excludeFolders = {'scenes', 'renderings', 'images'};
        workingRecord.recipe.input.sceneRecord = workingRecord;
        workingRecord.recipe.input.hints.whichConditions = [];
        rtbPackUpRecipe(workingRecord.recipe, archiveFile, 'ignoreFolders', excludeFolders);
        
        % Make a luminance image
        theHyperspectralImage = load(fullfile(hints.workingFolder,workingRecord.hints.recipeName,'renderings','Mitsuba','normal.mat'));
        xyzInfo = load('T_xyz1931');
        T_xyz = SplineCmf(xyzInfo.S_xyz1931,xyzInfo.T_xyz1931,theHyperspectralImage.S);
        [multispectralCalFormat,m,n] = ImageToCalFormat(theHyperspectralImage.multispectralImage);
        XYZCalFormat = T_xyz*multispectralCalFormat;
        luminanceImage = CalFormatToImage(XYZCalFormat(2,:),m,n);
        save(fullfile(hints.workingFolder,workingRecord.hints.recipeName,'renderings','Mitsuba','luminanceImage'),'luminanceImage');
        imwrite(luminanceImage/max(luminanceImage(:)),fullfile(hints.workingFolder,workingRecord.hints.recipeName,'images','Mitsuba',[workingRecord.hints.recipeName,'_luminanceImage.png']),'png');

%     catch err
%         % Try to save out some diagnostic information if the rendering
%         % barfs.
%         SaveVirtualWorldError(originalsFolder, err, workingRecord.recipe, workingRecord);
%     end
end
