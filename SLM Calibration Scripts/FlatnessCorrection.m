% Ralf Mouthaan
% University of Adelaide
% January 2023

clc; clear variables; close all;
commandwindow;

addpath('Functions\')
addpath('..\Meadowlark SDK\')

fprintf('RPM MEADOWLARK WAVEFRONT CORRECTION\n');

%% Set up SLM + Camera + Other Parameters

fprintf('  Starting up SLM + Camera...\n')

SLM = MeadowlarkSLM();
Cam = BlackflyCamera();

SLM.SetLUT('Global');
SLM.bolApplyWFC = false;

Cam.ROI = [750, 360, 80, 80];
Cam.SetExposureTime(75);
Cam.SetGain(3);

% Setting bolOptimise to true runs the optimisation algorithm and displays
% the result. Setting bolOptimise to false just displays the last result
bolOptimise = true;

% Setting bolStartFromPrevious to false starts with Zernike weightings set
% to zero. Setting bolStartfromPrevious to true uses the last Zernike
% estimate as a starting point.
bolStartFromPrevious = true;

% Setting bolShowAtStart to true shows the entire capturedimage for the 
% starting Zernikes. This allows the ROI to be set, for example.
bolShowAtStart = false;

%% Zernikes

if bolStartFromPrevious == true
    load('Results\WFC Zernikes.mat', 'ZernikeWeights')  % Start from previous best guess
elseif bolStartFromPrevious == false
    ZernikeWeights = zeros(1,19); % Start from scratch
end

ZernikeWeights(1) = 150;
ZernikeWeights(2) = 0;

% ZernikeWeights(1) = 140; % TiltX
% ZernikeWeights(2) = 0; % TiltY
% ZernikeWeights(3) = -1.1; % Defocus
% ZernikeWeights(4) = -1.6; % AstigX
% ZernikeWeights(5) = 0.7; % AstigY
% ZernikeWeights(6) = 0; % ComaX
% ZernikeWeights(7) = 0; % ComaY
% ZernikeWeights(8) = 0; % Spherical
% ZernikeWeights(9) = 0; % TrefoilX
% ZernikeWeights(10) = 0; % TrefoilY
% ZernikeWeights(11) = 0; % Secondary AstigX
% ZernikeWeights(12) = 0; % Secondary AstigY
% ZernikeWeights(13) = 0; % Secondary ComaX
% ZernikeWeights(14) = 0; % Secondary ComaY
% ZernikeWeights(15) = 0; % SecondarySpherical
% ZernikeWeights(16) = 0; % TetraFoilX
% ZernikeWeights(17) = 0; % TetraFoilY
% ZernikeWeights(18) = 0; % Tertiary Spherical
% ZernikeWeights(19) = 0; % Quaternary Spherical

%% 

HoloBlank = SLM.GenerateBlankHolo();

if bolShowAtStart == true

    Holo = SLM.ApplyZernikes(HoloBlank, ZernikeWeights);
    SLM.ShowHologramOnSLM(Holo);
    
    % Capture image
    Img = Cam.CaptureAverageImage();
    
    % Show image
    figure; 
    imagesc(Img); 
    colormap gray; 
    axis image; 
    drawnow;
    
    return;

end

%% Optimise

fprintf('  Optimising Zernikes...\n')

if bolOptimise == true
    for ii = 3:10
    
        BestVal = 0;
        BestWeight = 0;
    
        for CurrWeight = (ZernikeWeights(ii)-1):0.1:(ZernikeWeights(ii)+1)
            
            % Set Hologram on SLM
            ZernikeWeights(ii) = CurrWeight;
            Holo = SLM.ApplyZernikes(HoloBlank, ZernikeWeights);
            SLM.ShowHologramOnSLM(Holo);
    
            % Capture image
            Img = Cam.CaptureAverageImage();
            Img = Cam.ExtractROI(Img);
            CurrVal = max(max(Img));

            if CurrVal > 0.95
                warning('Oversaturated. Turn down exposure time')
            end
            
            % Show Image
            figure(1);
            imagesc(Img);
            colormap gray;
            axis image;
    
            if CurrVal > BestVal
                BestWeight = CurrWeight;
                BestVal = CurrVal;
            end
    
        end
        
        ZernikeWeights(ii) = BestWeight;
    
    end
end

%% Display Results

% Generate optimal hologram
Holo = SLM.ApplyZernikes(HoloBlank, ZernikeWeights);
SLM.ShowHologramOnSLM(Holo);

% Capture and show image
Img = Cam.CaptureAverageImage();
Img = Cam.ExtractROI(Img);
figure(1);
imagesc(Img);
colormap gray;
axis image;

% Set tilts to zero
ZernikeWeights(1:2) = 0;

% Show WFC on screen
figure(2);
Holo = SLM.ApplyZernikes(HoloBlank, ZernikeWeights);
SLM.ShowHologramOnScreen(Holo);
SLM.SaveHologramToFile(Holo, "Results\WFC.bmp");

% Print WFC Zernikes
fprintf('Defocus = %0.1f\n', ZernikeWeights(3));
fprintf('AstigX = %0.1f\n', ZernikeWeights(4));
fprintf('AstigY = %0.1f\n', ZernikeWeights(5));
fprintf('ComaX = %0.1f\n', ZernikeWeights(6));
fprintf('ComaY = %0.1f\n', ZernikeWeights(7));
fprintf('Spherical = %0.1f\n', ZernikeWeights(8));
fprintf('TrefoilX = %0.1f\n', ZernikeWeights(9));
fprintf('TrefoilY = %0.1f\n', ZernikeWeights(10));

% Save image of WFC
save('Results\WFC Zernikes.mat', 'ZernikeWeights')

fprintf('  Done\n')
