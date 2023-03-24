% Ralf Mouthaan
% University of Adelaide
% March 2023
%
% Script that shows a checkerboard pattern multiplied through by a blazed
% grating, which facilitates the alignment of the pinhole.

clc; clear variables; close all;

fprintf('RPM PINHOLE ALIGNMENT\n')

addpath('Functions\')
addpath('..\Meadowlark SDK\')

%%

SLM = MeadowlarkSLM();

SLM.SetLUT('Global');
SLM.bolApplyWFC = false;

CheckerBoard = SLM.GenerateCheckerboard(100);
Grating = SLM.GenerateBlazedGrating(0,125);

CheckerBoard = SLM.VecToMatrix(CheckerBoard);
Grating = SLM.VecToMatrix(Grating);
CheckerBoard = uint32(CheckerBoard);
Grating = uint32(Grating);
Holo = Grating;
Holo(CheckerBoard > 75) = 0;
Holo = uint8(Holo);

SLM.ShowHologramOnScreen(Holo);
SLM.ShowHologramOnSLM(Holo);