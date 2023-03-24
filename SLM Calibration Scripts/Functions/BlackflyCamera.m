% Ralf Mouthaan
% University of Adelaide
% February 2023
%
% Class to control Blackfly camera

classdef BlackflyCamera

    properties (Access = protected)

        cam;

    end
    properties (Access = public)

        ROI;
        NoAverages = 6;

    end
    methods

        function obj = BlackflyCamera()

            obj.cam = gigecam(1);
            obj.cam.GammaEnable = 'false';
            obj.cam.ExposureAuto = 'Off';
            obj.cam.GainAuto = 'Off';
            obj.SetGain(3);
            obj.SetExposureTime(1000);

            [~] = snapshot(obj.cam);

        end
        function delete(obj)
            
            delete(obj.cam);
            
        end

        function SetExposureTime(obj, ExposureTime)
            
            warning('off');
            obj.cam.ExposureTime = ExposureTime;
            warning('on');

        end
        function ExposureTime = GetExposureTime(obj)
            ExposureTime = obj.cam.ExposureTime;
        end
        function SetGain(obj, Gain)

            warning('off');
            obj.cam.Gain = Gain;
            warning('on');

        end
        function Gain = GetGain(obj)
            Gain = obj.cam.Gain;
        end
        function Img = CaptureImage(obj)

            % For some reason it's not quite 16 bit. It caps out at 65408.
            Img = snapshot(obj.cam);

        end
        function AvImg = CaptureAverageImage(obj)

            AvImg = im2double(obj.CaptureImage());
            
            for ii = 1:obj.NoAverages - 1
                AvImg = AvImg + im2double(obj.CaptureImage());
            end

            AvImg = im2double(AvImg)/obj.NoAverages;

        end
        function Img = ExtractROI(obj, Img)
            
            Img = Img(obj.ROI(2):obj.ROI(2)+obj.ROI(4),...
                obj.ROI(1):obj.ROI(1)+obj.ROI(3));

        end

    end


end