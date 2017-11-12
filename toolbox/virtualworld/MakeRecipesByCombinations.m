function MakeRecipesByCombinations(varargin)
%  MakeRecipesByCombinations  Construct and archive a set of many Ward Land recipes.
%
% The idea here is to generate many WardLand scenes.  We choose values for
% several parameter sets and build a scene for several combinations of
% parameter values, drawing from each parameter set.
%
% Key/value pairs
%   'outputName' - Output folder name (default 'ExampleOutput')
%   'imageWidth' - Image width, should be kept small to keep redering time
%                   low for rejected recipes
%   'imageHeight'- Image height, Should be kept small to keep redering time
%                   low for rejected recipes
%   'makeCropImageHalfSize'  - Size of cropped patch
%   'nOtherObjectSurfaceReflectance' - Number of spectra to be generated
%                   for choosing background surface reflectance (max 999)
%   'luminanceLevels' - luminance levels of target object
%   'reflectanceNumbers' - A row vetor containing Reflectance Numbers of
%                   target object. These are just dummy variables to give a
%                   unique name to each random spectra.
%   'nInsertedLights' - Number of inserted lights
%   'nInsertObjects' - Number of inserted objects (other than target object)
%   'otherObjectReflectanceRandom' - boolean to specify if spectra of
%                   background objects is random or not. Default true
%   'illuminantSpectraRandom' - boolean to specify if spectra of
%                   illuminant is random or not. Default true
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
%   'lightPositionRandom' - boolean to specify illuminant position is fixed
%                   or not. Default is true. False will only work for
%                   library-bigball case.
%   'lightScaleRandom' - boolean to specify illuminant scale/size. Default
%                   is true.
%   'targetPositionRandom' - boolean to specify illuminant scale/size.
%                   Default is true. False will only work for
%                   library-bigball case.
%   'targetScaleRandom' - boolean to specify target scale/size is fixed or
%                   not. Default is true.
%   'targetRotationRandom' - boolean to specify target angular position is
%                   fixed or not. Default is true. False will only work for
%   'baseSceneSet'  - Base scenes to be used for renderings. One of these
%                  base scenes is used for each rendering
%   'objectShapeSet'  - Shapes of the target object other inserted objects
%   'lightShapeSet'  - Shapes of the inserted illuminants

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
p.addParameter('nInsertedLights', 1, @isnumeric);
p.addParameter('nInsertObjects', 0, @isnumeric);
p.addParameter('otherObjectReflectanceRandom', true, @islogical);
p.addParameter('illuminantSpectraRandom', true, @islogical);
p.addParameter('illuminantSpectrumNotFlat', true, @islogical);
p.addParameter('minMeanIlluminantLevel', 10, @isnumeric);
p.addParameter('maxMeanIlluminantLevel', 30, @isnumeric);
p.addParameter('targetSpectrumNotFlat', true, @islogical);
p.addParameter('allTargetSpectrumSameShape', false, @islogical);
p.addParameter('targetReflectanceScaledCopies', false, @islogical);
p.addParameter('lightPositionRandom', true, @islogical);
p.addParameter('lightScaleRandom', true, @islogical);
p.addParameter('targetPositionRandom', true, @islogical);
p.addParameter('targetScaleRandom', true, @islogical);
p.addParameter('targetRotationRandom', true, @islogical);
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
% If p.Results.illuminantSpectraRandom is true, then many illuminant spectra are
% defined, otherwise just one.
%
% * [NOTE - DHB: The hard coding of the number of illuminant spectra here
%    not good, and should be made more transparent.]
dataBaseDir = fullfile(getpref(projectName,'outputDataFolder'),p.Results.outputName,'Data');
illuminantsFolder = fullfile(getpref(projectName,'outputDataFolder'),p.Results.outputName,'Data','Illuminants','BaseScene');
if p.Results.illuminantSpectraRandom
    if (p.Results.illuminantSpectrumNotFlat)
        totalRandomLightSpectra = 999;
        makeIlluminants(projectName,totalRandomLightSpectra,illuminantsFolder, ...
            p.Results.minMeanIlluminantLevel, p.Results.maxMeanIlluminantLevel);
    else
        totalRandomLightSpectra = 10;
        makeFlatIlluminants(totalRandomLightSpectra,illuminantsFolder, ...
            p.Results.minMeanIlluminantLevel, p.Results.maxMeanIlluminantLevel);
    end
else
    totalRandomLightSpectra = 1;
    if (p.Results.illuminantSpectrumNotFlat)
        makeIlluminants(projectName,totalRandomLightSpectra,illuminantsFolder, ...
            p.Results.minMeanIlluminantLevel, p.Results.maxMeanIlluminantLevel);
    else
        makeFlatIlluminants(totalRandomLightSpectra,illuminantsFolder, ...
            p.Results.minMeanIlluminantLevel, p.Results.maxMeanIlluminantLevel);
    end
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
    
    
    try
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
        % * [NOTE - DHB]: This is sort of long and might better be a
        %   function to improve readability at the top level.]
        
        % Target object rotation
        targetShape = objectShapes{targetShapeIndex};
        if p.Results.targetPositionRandom
            % Random rotation
            targetRotationX = randi([0, 359]);
            targetRotationY = randi([0, 359]);
            targetRotationZ = randi([0, 359]);
        else
            % Fixed rotation.
            % These values were chosen for the mill-ringtoy case by Vijay Singh
            targetRotationX = 0;
            targetRotationY = 233;
            targetRotationZ = 183;
        end
        
        % Target object position
        if p.Results.targetPositionRandom
            % Random position
            targetPosition = GetRandomPosition([0 0; 0 0; 0 0], baseSceneInfo.objectBox);
        else
            % Fixed position.  Some possible choices below
            % targetPosition = [ -0.010709 4.927981 0.482899];  % BigBall-Library Case 1
            % targetPosition = [ 1.510709 5.527981 2.482899];   % BigBall-Library Case 2
            % targetPosition = [ -0.510709 0.0527981 0.482899]; % BigBall-Library Case 3
            targetPosition = [-2.626092 -6.054515 1.223028];    % BigBall-Mill Case 4
        end
        
        % Target object scaling
        if p.Results.targetScaleRandom
            % Random scaling
            targetScale = 0.3 + rand()/2;
        else
            % Fixed scaling
            targetScale =  1; % BigBall-Mill Case 4
        end
        
        % Target object transformation
        transformation = mexximpScale(targetScale) ...
            * mexximpRotate([1 0 0], targetRotationX) ...
            * mexximpRotate([0 1 0], targetRotationY) ...
            * mexximpRotate([0 0 1], targetRotationZ) ...
            * mexximpTranslate(targetPosition);
        
        % Set up target for insertion after transformation.  The
        % insertShapes cell array will hold information for the target
        % object plus the additional inserted objects.
        insertShapes = cell(1, p.Results.nInsertObjects+1);
        insertShapes{1} = targetShape.copy( ...
            'name', 'shape-01', ...
            'transformation', transformation);
        
        % Pick other objects and light shapes to insert
        %
        % For each shape to insert, choose a random spatial transformation.
        
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
        
        % This seems to do the same thing for the other objects
        otherShapeIndices = randi(nObjectShapes, [1, p.Results.nInsertObjects]);
        for sss = 1:p.Results.nInsertObjects
            shape = objectShapes{otherShapeIndices(sss)};
            
            rotationX = randi([0, 359]);
            rotationY = randi([0, 359]);
            rotationZ = randi([0, 359]);
            position = GetRandomPosition([0 0; 0 0; 0 0], baseSceneInfo.objectBox);
            scale = 0.3 + rand()/2;
            transformation = mexximpScale(scale) ...
                * mexximpRotate([1 0 0], rotationX) ...
                * mexximpRotate([0 1 0], rotationY) ...
                * mexximpRotate([0 0 1], rotationZ) ...
                * mexximpTranslate(position);
            
            % Tuck info info away.
            %            
            % The addition of 1 to sss here and in the column headers for
            % the conditions file below is because the first inserted shape
            % is the target object.
            shapeName = sprintf('shape-%d', sss+1);
            insertShapes{sss+1} = shape.copy( ...
                'name', shapeName, ...
                'transformation', transformation);
            
            % Setup for saving the position, scale and rotation of the
            % other inserted objects in the conditions file.
            objectColumn = sprintf('object-%d', sss+1);
            positionColumn = sprintf('object-position-%d', sss+1);
            rotationColumn = sprintf('object-rotation-%d', sss+1);
            scaleColumn = sprintf('object-scale-%d', sss+1);
            varNames = {objectColumn, positionColumn, rotationColumn, scaleColumn};
            allNames = cat(2, allNames, varNames);
            varValues = {shape.name, ...
                position, ...
                [rotationX rotationY rotationZ], ...
                scale};
            allValues = cat(2, allValues, varValues);
        end
        
        % Insert lights.  This parallels object insertion above.
        lightIndexes = randi(nLightShapes, [1, p.Results.nInsertedLights]);
        insertLights = cell(1, p.Results.nInsertedLights);
        for ll = 1:p.Results.nInsertedLights
            light = lightShapes{lightIndexes(ll)};
            
            % Light rotation, position and scaling
            rotationX = randi([0, 359]);
            rotationY = randi([0, 359]);
            rotationZ = randi([0, 359]);
            if p.Results.lightPositionRandom
                % Random light position
                position = GetRandomPosition(baseSceneInfo.lightExcludeBox, baseSceneInfo.lightBox);
            else
                % Fixed light position that works for the Library base scene
                position = [-6.504209 18.729564 5.017080];
            end
            if p.Results.lightScaleRandom
                scale = 0.3 + rand()/2;
            else
                scale = 1;
            end
            
            % Compute spatial transformation for the light
            transformation = mexximpScale(scale) ...
                * mexximpRotate([1 0 0], rotationX) ...
                * mexximpRotate([0 1 0], rotationY) ...
                * mexximpRotate([0 0 1], rotationZ) ...
                * mexximpTranslate(position);
            
            lightName = sprintf('light-%d', ll);
            insertLights{ll} = light.copy(...
                'name', lightName, ...
                'transformation', transformation);
            
            % Setup the conditions file for saving position of lights
            lightColumn = sprintf('light-%d', ll);
            positionColumn = sprintf('light-position-%d', ll);
            rotationColumn = sprintf('light-rotation-%d', ll);
            scaleColumn = sprintf('light-scale-%d', ll);
            varNames = {lightColumn, positionColumn, rotationColumn, scaleColumn};
            allNames = cat(2, allNames, varNames);
            varValues = {light.name, ...
                position, ...
                [rotationX rotationY rotationZ], ...
                scale};
            allValues = cat(2, allValues, varValues);
        end
        
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
        
        % Any lights we inserted
        blessInsertedLights = VseMitsubaAreaLights( ...
            'name', 'blessInsertedLights', ...
            'applyToOuterModels', false, ...
            'modelNameFilter', 'light-', ...
            'elementNameFilter', '');
        
        % Assign spectra to all the lights.  
        % 
        % This is magic VSE code that gets the illuminant spcectra assigned
        % to each light.
        areaLightSpectra = VseMitsubaEmitterSpectra( ...
            'name', 'areaLightSpectra', ...
            'pluginType', 'area', ...
            'propertyName', 'radiance');
        areaLightSpectra.resourceFolder = dataBaseDir;
        if p.Results.illuminantSpectraRandom
            tempIlluminantSpectra = illuminantSpectra((randperm(length(illuminantSpectra))));
        else
            tempIlluminantSpectra = illuminantSpectra;
        end
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
        if p.Results.otherObjectReflectanceRandom
            tempBaseSceneReflectances = baseSceneReflectances((randperm(length(baseSceneReflectances))));
        else
            tempBaseSceneReflectances = baseSceneReflectances;
        end
        baseSceneDiffuse.addManySpectra(tempBaseSceneReflectances);
        
        % Assign spectra to all materials of inserted shapes
        insertedDiffuse = VseMitsubaDiffuseMaterials( ...
            'name', 'insertedDiffuse', ...
            'modelNameFilter', 'shape-',...
            'applyToOuterModels', false);
        insertedDiffuse.resourceFolder = dataBaseDir;
        if p.Results.otherObjectReflectanceRandom
            tempOtherObjectReflectances = otherObjectReflectances((randperm(length(otherObjectReflectances))));
        else
            tempOtherObjectReflectances = otherObjectReflectances;
        end
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
            blessBaseLights, blessInsertedLights, areaLightSpectra, ...
            baseSceneDiffuse, insertedDiffuse, targetDiffuse};
        
        % Do the rendering
        innerModels = [insertShapes{:} insertLights{:}];
        workingRecord.recipe = vseBuildRecipe(sceneData, innerModels, workingRecord.styles, 'hints', workingRecord.hints);
        workingRecord.recipe = rtbExecuteRecipe(workingRecord.recipe);
        
        % Save the recipe to the recipesFolder
        archiveFile = fullfile(originalsFolder, workingRecord.hints.recipeName);
        excludeFolders = {'scenes', 'renderings', 'images'};
        workingRecord.recipe.input.sceneRecord = workingRecord;
        workingRecord.recipe.input.hints.whichConditions = [];
        rtbPackUpRecipe(workingRecord.recipe, archiveFile, 'ignoreFolders', excludeFolders);
        
        % Make a luminance image
               
    catch err
        % Try to save out some diagnostic information if the rendering
        % barfs.
        SaveVirtualWorldError(originalsFolder, err, workingRecord.recipe, workingRecord);
    end
end
