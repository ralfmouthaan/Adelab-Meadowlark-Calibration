% Ralf Mouthaan
% University of Adelaide
% February 2023
%
% Class to control Meadowlark SLM.

classdef MeadowlarkSLM
    properties (Access = public)
        
        Width
        Height
        bolApplyWFC = true;
        WFC_ZernikeWeights;

    end

    properties(Access = protected)
     
        % Used for creating SDK
        Board_Number = 1;
        Bit_Depth = 12;
        Is_Nematic_Type = 1;
        Use_GPU = 0;
        Max_Transients = 10;
        RAM_Write_Enable = 1;

        % Used for displaying holograms
        Wait_For_Trigger = 0; % This feature is user-settable; use 1 for 'on' or 0 for 'off'
        Timeout_ms = 5000;
        OutputPulseImageFlip = 0;
        OutputPulseImageRefresh = 0; %only supported on 1920x1152, FW rev 1.8. 

    end

    methods

        function obj = MeadowlarkSLM()
              
            if ~libisloaded('Blink_C_wrapper')
                loadlibrary('Blink_C_wrapper.dll', 'Blink_C_wrapper.h');
            end
            
            if ~libisloaded('ImageGen')
                loadlibrary('ImageGen.dll', 'ImageGen.h');
            end

            Num_Boards_Found = libpointer('uint32Ptr', 0);
            Constructed_Okay = libpointer('int32Ptr', 0);
            Reg_LUT = libpointer('string');
            
            % Call the constructor
            calllib('Blink_C_wrapper', 'Create_SDK', ...
                obj.Bit_Depth, ... 
                Num_Boards_Found, ...
                Constructed_Okay, ...
                obj.Is_Nematic_Type, ...
                obj.RAM_Write_Enable, ... 
                obj.Use_GPU, ... 
                obj.Max_Transients, ...
                Reg_LUT);

            % If failed, delete SDK and try again
            if Constructed_Okay.value ~= 0
                calllib('Blink_C_wrapper', 'Delete_SDK');
                calllib('Blink_C_wrapper', 'Create_SDK', ...
                    obj.Bit_Depth, ... 
                    Num_Boards_Found, ...
                    Constructed_Okay, ...
                    obj.Is_Nematic_Type, ...
                    obj.RAM_Write_Enable, ... 
                    obj.Use_GPU, ... 
                    obj.Max_Transients, ...
                    Reg_LUT);
            end

            % If failed again, give up.
            if Constructed_Okay.value ~= 0
                error('Could not create Blink SDK')
            end

            obj.Width = calllib('Blink_C_wrapper', 'Get_image_width', obj.Board_Number);
            obj.Height = calllib('Blink_C_wrapper', 'Get_image_height', obj.Board_Number);
            obj.SetLUT('Global');
            load("C:\Program Files\Meadowlark Optics\Blink OverDrive Plus\WFC Files\WFC Zernikes.mat", 'ZernikeWeights');
            obj.WFC_ZernikeWeights = ZernikeWeights;
            obj.WFC_ZernikeWeights(1:2) = 0;

        end
        function delete(~)

            % Always call Delete_SDK before exiting
            calllib('Blink_C_wrapper', 'Delete_SDK');
            
            %destruct
            if libisloaded('Blink_C_wrapper')
                unloadlibrary('Blink_C_wrapper');
            end
            
            if libisloaded('ImageGen')
                unloadlibrary('ImageGen');
            end

        end

        function SetLUT(obj, file)

            % A few special cases
            if strcmp(file, 'Global')
                file = 'C:\Program Files\Meadowlark Optics\Blink OverDrive Plus\LUT Files\SN5721_WL532_Global.lut';
            elseif strcmp(file, 'Local')
                file = 'C:\Program Files\Meadowlark Optics\Blink OverDrive Plus\LUT Files\SN5721_WL532_Local.txt';
            elseif strcmp(file, 'Linear')
                file = 'C:\Program Files\Meadowlark Optics\Blink OverDrive Plus\LUT Files\12bit_linear.lut';
            end

            calllib('Blink_C_wrapper', 'Load_LUT_file', obj.Board_Number, file);

        end
        function ShowHologramOnScreen(obj, Holo)

            if obj.bolApplyWFC == true
                Holo = obj.ApplyWFC(Holo);
            end
            
            if isa(Holo, 'lib.pointer')
                Holo = obj.LibPointerToMatrix(Holo);
            end

            if size(Holo, 2) == 1
                Holo = obj.VecToMatrix(Holo);
            end

            imagesc(Holo);
            axis image;
            colormap gray;
            clim([0 255]);
            xticks('');
            yticks('');

        end
        function ShowHologramOnSLM(obj, Holo)

            if obj.bolApplyWFC == true
                Holo = obj.ApplyWFC(Holo);
            end

            if size(Holo, 2) > 1
                Holo = obj.MatrixToVec(Holo);
            end

            calllib('Blink_C_wrapper', 'Write_image', ...
                obj.Board_Number, ...
                Holo, ...
                obj.Width*obj.Height, ...
                obj.Wait_For_Trigger, ... 
                obj.OutputPulseImageFlip, ...
                obj.OutputPulseImageRefresh, ...
                obj.Timeout_ms);
            calllib('Blink_C_wrapper', 'ImageWriteComplete', ...
                obj.Board_Number, obj.Timeout_ms);
            pause(0.1);

        end
        function SaveHologramToFile(obj, Holo, filename)
            
            if isa(Holo, 'lib.pointer')
                Holo = obj.LibPointerToMatrix(Holo);
            end

            if size(Holo, 2) == 1
                Holo = obj.VecToMatrix(Holo);
            end

            imwrite(Holo, filename)

        end
        function Holo = LoadHologramFromFile(~, filename)

            Holo = readmatrix(filename);

            phasetol = 0.1;

            % Convert from phase to grayscale
            if abs(min(min(Holo + pi))) < phasetol
                Holo = Holo + pi;
            end
            if abs(max(max(Holo - 2*pi))) < phasetol
                Holo = Holo/2/pi*255;
            end

        end

        function Holo = ZeroPad(obj, Holo)
            
            BlankHolo = obj.GenerateBlankHolo();
            BlankHolo = obj.LibPointerToMatrix(BlankHolo);
            BlankHolo(round(obj.Height/2 - size(Holo, 1)/2):round(obj.Height/2 + size(Holo, 1)/2) - 1, ...
                round(obj.Width/2 - size(Holo, 2)/2):round(obj.Width/2 + size(Holo, 2)/2) - 1) = Holo;
            Holo = BlankHolo;
            Holo = obj.MatrixToVec(Holo);

        end
        function Holo = ApplyZernikes(obj, Holo, ZernikeWeights)

            if isa(Holo, 'lib.pointer')
                Holo = obj.LibPointerToVec(Holo);
            end

            Zernikes = libpointer('uint8Ptr', zeros(obj.Width*obj.Height, 1));
            
            % Centred on the SLM, as big as the SLM
            CenterX = round(obj.Width/2);
            CenterY = round(obj.Height/2);
            Radius = min(CenterX, CenterY);
            Piston = 0;
            
            % User-Defined (passed in)
            TiltX = ZernikeWeights(1);
            TiltY = ZernikeWeights(2);
            Defocus = ZernikeWeights(3); %For some reason meadowlark call this "Power"
            AstigX = ZernikeWeights(4);
            AstigY = ZernikeWeights(5);
            ComaX = ZernikeWeights(6);
            ComaY = ZernikeWeights(7);
            Spherical = ZernikeWeights(8);
            TrefoilX = ZernikeWeights(9);
            TrefoilY = ZernikeWeights(10);
            SecondaryAstigX = ZernikeWeights(11);
            SecondaryAstigY = ZernikeWeights(12);
            SecondaryComaX = ZernikeWeights(13);
            SecondaryComaY = ZernikeWeights(14);
            SecondarySpherical = ZernikeWeights(15);
            TetraFoilX = ZernikeWeights(16);
            TetraFoilY = ZernikeWeights(17);
            TertiarySpherical = ZernikeWeights(18);
            QuaternarySpherical = ZernikeWeights(19);

            calllib('ImageGen', 'Generate_Zernike', Zernikes, obj.Width, obj.Height, CenterX, CenterY, Radius, Piston, ...
                TiltX, TiltY, Defocus, AstigX, AstigY, ComaX, ComaY, Spherical, TrefoilX, TrefoilY, ...
                SecondaryAstigX, SecondaryAstigY, SecondaryComaX, SecondaryComaY, SecondarySpherical, ...
                TetraFoilX, TetraFoilY, TertiarySpherical, QuaternarySpherical);
            Zernikes = Zernikes.Value;

            Holo = mod(uint16(Zernikes) + uint16(Holo), 256);
            Holo = uint8(Holo);

        end
        function Holo = ApplyWFC(obj, Holo)

            Holo = obj.ApplyZernikes(Holo, obj.WFC_ZernikeWeights);

        end
        function Holo = GenerateBinaryGrating(obj, Gray1, Gray2, PixelsPerStripe)
            
            Holo = libpointer('uint8Ptr', zeros(obj.Width*obj.Height,1));
            calllib('ImageGen', 'Generate_Stripe', Holo, obj.Width, obj.Height, Gray1, Gray2, PixelsPerStripe);

        end
        function Holo = GenerateBlankHolo(obj)

            Holo = libpointer('uint8Ptr', zeros(obj.Width*obj.Height, 1));
            calllib('ImageGen', 'Generate_Solid', Holo, obj.Width, obj.Height, 0);

        end
        function Holo = GenerateBlazedGrating(obj, WeightingX, WeightingY)

            ZernikeWeights = zeros(1,19);
            ZernikeWeights(1) = WeightingX;
            ZernikeWeights(2) = WeightingY;
            Holo = obj.GenerateBlankHolo();
            Holo = obj.ApplyZernikes(Holo, ZernikeWeights);

        end
        function Holo = GenerateCheckerboard(obj, Period)

            Holo = checkerboard(Period, ceil(obj.Height/Period/2), ceil(obj.Width/Period/2));
            Holo = Holo(1:obj.Height,1:obj.Width);
            Holo = obj.MatrixToVec(Holo);
            Holo = Holo > 0.5;
            Holo = Holo*122;
            Holo = uint8(Holo);

        end

        function Holo = LibPointerToVec(~, Holo)

            if isa(Holo, 'lib.pointer') == 0
                error('Holo is not a lib pointer')
            end

            Holo = Holo.Value;

        end
        function Holo = LibPointerToMatrix(obj, Holo)

            if isa(Holo, 'lib.pointer') == 0
                error('Holo is not a lib pointer')
            end
            
            Holo = LibPointerToVec(obj, Holo);
            Holo = obj.VecToMatrix(Holo);

        end
        function Holo = MatrixToVec(~, Holo)
            
            Holo = rot90(Holo, -1);
            Holo = Holo(:);

        end
        function Holo = VecToMatrix(obj, Holo) 
            Holo = reshape(Holo, [obj.Width, obj.Height]);
            Holo = rot90(Holo);
        end
            
    end

end