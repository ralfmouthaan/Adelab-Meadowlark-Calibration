// Blink_SDK_example.cpp : Defines the entry point for the console application.
//


#include "Blink_SDK.h"  // Relative path to SDK header.
#include "ImageGen.h"
#include <afx.h>

// ------------------------- Blink_SDK_example --------------------------------
// Simple example using the Blink_SDK DLL to load diffraction patterns to the SLM
// and measure the 1st order intensity by reading from an analog input board, then
// saving the measurements to raw files for post processing to generate either 
// a regional or global LUT.
// ----------------------------------------------------------------------------
int main()
{
	CStdioFile sFile;
	CString FileName, str;
	int board_number;

	// Construct a Blink_SDK instance
	unsigned int bits_per_pixel = 12U; //8U = small 512, 16U = large 512; 12U = 1920x1152
	bool         is_nematic_type = true;
	bool         RAM_write_enable = true;
	bool         use_GPU_if_available = true;
	unsigned int n_boards_found = 0U;
	bool         constructed_okay = true;
	Blink_SDK sdk(bits_per_pixel, &n_boards_found,&constructed_okay, is_nematic_type, RAM_write_enable, use_GPU_if_available, 10U, 0);

	//constructed okay == 0 means it is fine, -1 means there was an error
	if (constructed_okay == 0)
	{
		board_number = 1;

		// To measure the raw response we want to disable the LUT by loading a linear LUT
		char* lut_file = "C:\\Program Files\\Meadowlark Optics\\Blink OverDrive Plus\\LUT Files\\12bit_linear.LUT";
		sdk.Load_LUT_file(board_number, lut_file);

		//get the SLM dimensions
		int height = sdk.Get_image_height(board_number);
		int width = sdk.Get_image_width(board_number);
		int NumDataPoints = 256;
		int NumRegions = 1;

		//Create an array to hold the image data
		unsigned char* Image = new unsigned char[width*height];

		//Create an array to hold measurements from the analog input (AI) board
		float* AI_Intensities = new float[NumDataPoints];
		memset(AI_Intensities, 0, NumDataPoints);


		//initialize the SLM to a blank image
		bool ExternalTrigger = false;
		//Both pulse options can be false, but only one can be true. You either generate a pulse when the new image begins loading to the SLM
		//or every 1.184 ms on SLM refresh boundaries, or if both are false no output pulse is generated.
		bool OutputPulseImageFlip = false;
		bool OutputPulseImageRefresh = false; //only supported on 1920x1152, FW rev 1.8. 
		Generate_Solid(Image, width, height, 0);
		sdk.Write_image(board_number, Image, width*height, ExternalTrigger, OutputPulseImageFlip, OutputPulseImageRefresh, 5000);


		//load diffraction patterns, and record the 1st order intensity
		int PixelOneVal = 0; //use a reference graylevel of 0
		int PixelsPerStripe = 8; //use a fairly high frequency pattern to separate the 0th from the 1st order
		for (int region = 0; region < NumRegions; region++)
		{
			printf("Region: %d\n", region);

			for (int Gray = 0; Gray < NumDataPoints; Gray++)
			{
				printf("Gray: %d\r", Gray);

				//generate a stripe
				Generate_Stripe(Image, width, height, PixelOneVal, Gray, PixelsPerStripe);
				Mask_Image(Image, width, height, region, NumRegions);

				//load the iamge to the SLM. Write image returns when the DMA is complete, and Image Write Complete
				//returns when the hardware memory bank is available to receive the next DMA
				sdk.Write_image(board_number, Image, width*height, ExternalTrigger, OutputPulseImageFlip, OutputPulseImageRefresh, 5000);
				sdk.ImageWriteComplete(board_number, 5000);

				//give the LC time to settle into the image
				Sleep(10);

				//YOU FILL IN HERE...FIRST: read from your specific AI board, note it might help to clean up noise to average several readings
				//SECOND: store the measurement in your AI_Intensities array
				//AI_Intensities[Gray] = measured value

			}
			printf("\n");

			FileName.Format(_T("Raw%d.csv"), region);
			sFile.Open(FileName, CFile::modeCreate | CFile::modeWrite | CFile::typeText);
			for (int i = 0; i < NumDataPoints; i++)
			{
				str.Format(_T("%d, %f\n"), i, AI_Intensities[i]);
				sFile.WriteString(str);
			}
			sFile.Close();
		}


		delete[]Image;
		delete[]AI_Intensities;
	}

	return (okay) ? EXIT_SUCCESS : EXIT_FAILURE;
}
