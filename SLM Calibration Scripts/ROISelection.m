% Ralf Mouthaan
% University of Adelaide
% February 2023
% 
% Script to set ROI and exposure time for Meadlowlark calibration
% measurements

clc; clear variables; close all;
commandwindow;

fprintf('RPM MEADOWLARK ROI SELECTION\n')

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

PixelsPerStripe = 4;
NumRegions = 1; % Set to 64 for regional calibration
NumDataPoints = 256;

% Generate Hologram
Holo = SLM.GenerateBinaryGrating(0, 122, PixelsPerStripe);
SLM.ShowHologramOnSLM(Holo);

% Take an image
Img = Cam.CaptureAverageImage;

% Show image
figure(1); imagesc(Img);
hold on
rectangle('Position', Cam.ROI, 'EdgeColor', 'r')
colormap gray
drawnow;
hold off