% Ralf Mouthaan
% University of Adelaide
% February 2023
% 
% Script to run LUT calibration for Meadowlark SLM

clc; clear variables; close all;
commandwindow;

fprintf('RPM MEADOWLARK LUT CALIBRATION\n')

addpath('Functions\')
addpath('..\Meadowlark SDK\')

%% Set up SLM + Camera + Other Parameters

fprintf('  Setting up SLM + Camera...\n')

SLM = MeadowlarkSLM();
Cam = BlackflyCamera();

SLM.SetLUT('Global');
SLM.bolApplyWFC = true;

Cam.ROI = [250, 670, 80, 80];
Cam.SetExposureTime(25000);
Cam.SetGain(3);

PixelsPerStripe = 100;
NumRegions = 1; % Set to 64 for regional calibration
NumDataPoints = 4;

%% Measurement

for Region = 0:NumRegions - 1

    if NumRegions > 1
        fprintf('  Region = %d\n', Region)
    else
        fprintf('  Setting exposure time...\n')
    end

    % SET EXPOSURE TIME

    maxmax = 0;
    while maxmax < 0.7 || maxmax > 0.90

        maxmax = 0;
        for Gray = 80:10:150

            % Generate Hologram
            Holo = SLM.GenerateBinaryGrating(0, Gray, PixelsPerStripe);
            SLM.ShowHologramOnSLM(Holo);
    
            % Take an image
            Img = Cam.CaptureImage;
            Img = Cam.ExtractROI(Img);
            if max(max(Img)) > maxmax
                maxmax = max(max(Img));
            end

        end

        maxmax = double(maxmax)/65408; % 65408 seems to be camera maximum
        if maxmax < 0.7 || maxmax > 0.9
            ExposureTime = Cam.GetExposureTime;
            Cam.SetExposureTime(ExposureTime/maxmax*0.8);
        end

    end

    % MEASUREMENT

    if NumRegions == 1
        fprintf('  Performing calibration...\n')
    end
    
    maxmax = 0;
    AI_Intensities = zeros(NumDataPoints,2);
      
    for Gray = 0:(NumDataPoints-1)
    
        % Generate Hologram
        Holo = SLM.GenerateBinaryGrating(0, Gray, PixelsPerStripe);
        SLM.ShowHologramOnSLM(Holo);
        
        % Take an image
        Img = Cam.CaptureAverageImage;
        SubImg = Cam.ExtractROI(Img);
    
        % Show image
        figure(1); imagesc(Img);
        hold on
        rectangle('Position', Cam.ROI, 'EdgeColor', 'r')
        title(['Gray = ' num2str(Gray)]);
        colormap gray
        drawnow;
        hold off
    
        if max(max(SubImg)) > 1
            warning('Over-Exposed: Turn down exposure time')
        end
        if max(max(SubImg)) > maxmax
            maxmax = max(max(SubImg));
        end
    
        AI_Intensities(Gray + 1, 1) = Gray;
        AI_Intensities(Gray + 1, 2) = sum(sum(SubImg));
    
    end

    % RESULTS
    figure(2);
    plot(AI_Intensities(:, 1), AI_Intensities(:,2), 'LineWidth', 2);
    xlabel('Grayscale');
    ylabel('Intensity');
    xlim([0 255])

    % dump the AI measurements to a csv file
    filename = ['Results\Raw' num2str(Region) '.csv'];
    csvwrite(filename, AI_Intensities);

end

clear SLM; clear Cam;

fprintf('  Done.\n')