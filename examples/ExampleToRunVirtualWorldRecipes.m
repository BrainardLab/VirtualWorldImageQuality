
ouputName = 'ExampleScriptOutput';

RunParametricRecipe(...
    'outputName',ouputName, ...
    'imageWidth',320, ...
    'imageHeight',240, ...
    'nOtherObjectSurfaceReflectance', 999, ...          % Number of random surfaces to choose from
    'luminanceLevels',[0.3], ...                        % This can be a list
    'reflectanceNumbers',[1], ...                       % There are dummy indices for each luminance in the above list
    'illuminantSpectrumNotFlat',true, ...               % true is random shape, false is spectrally flat
    'targetSpectrumNotFlat',false, ...                  % true is random shape, false is spectrally flat
    'allTargetSpectrumSameShape', false, ...            % true = same spectra for all images
    'objectShape','Barrel', ...                         % Currently choose from: 'Barrel', 'BigBall', 'ChampagneBottle', 'RingToy', 'SmallBall', 'Xylophone'
    'baseScene','Library' ...                           % Currently choose from: 'CheckerBoard', 'IndoorPlant', 'Library', 'Mill', 'TableChairs', 'Warehouse'  
    );
