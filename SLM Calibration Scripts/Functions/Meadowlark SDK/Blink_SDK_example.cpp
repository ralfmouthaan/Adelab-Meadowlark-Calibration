#include "Blink_C_wrapper.h"  // Relative path to SDK header.
#include "ImageGen.h"
#include "math.h"
#include <Windows.h>

// ------------------------- Blink_SDK_example --------------------------------
// Simple example using the Blink_SDK DLL to send a sequence of phase targets
// to a single SLM.
// To run the example, ensure that Blink_SDK.dll is in the same directory as
// the Blink_SDK_example.exe.
// ----------------------------------------------------------------------------
int main()
{
  int board_number;
  // Construct a Blink_SDK instance
  unsigned int bits_per_pixel = 12U;   //12U is used for 1920x1152 SLM, 8U used for the small 512x512
  bool         is_nematic_type = true;
  bool         RAM_write_enable = true;
  bool         use_GPU_if_available = true;
  unsigned int n_boards_found = 0U;
  int         constructed_okay = true;
  bool ExternalTrigger = false;
  
  //Both pulse options can be false, but only one can be true. You either generate a pulse when the new image begins loading to the SLM
  //or every 1.184 ms on SLM refresh boundaries, or if both are false no output pulse is generated.
  bool OutputPulseImageFlip = false;
  bool OutputPulseImageRefresh = false; //only supported on 1920x1152, FW rev 1.8. 

  //if bits per pixel is wrong, the lower level code will figure out
  //what it should be and construct properly.
  Create_SDK(bits_per_pixel, &n_boards_found, &constructed_okay, is_nematic_type, RAM_write_enable, use_GPU_if_available, 10U, 0);

  // return of 0 means okay, return -1 means error
  if (constructed_okay == 0)
  {
    board_number = 1;
	  int height = Get_image_height(board_number);
	  int width = Get_image_width(board_number);
	
      //***you should replace *bit_linear.LUT with your custom LUT file***
	  //but for now open a generic LUT that linearly maps input graylevels to output voltages
	  //***Using *bit_linear.LUT does NOT give a linear phase response***
	  char* lut_file;
	  if(width == 512)
		  lut_file = "C:\\Program Files\\Meadowlark Optics\\Blink OverDrive Plus\\LUT Files\\8bit_linear.LUT";
	  else 
		  lut_file = "C:\\Program Files\\Meadowlark Optics\\Blink OverDrive Plus\\LUT Files\\12bit_linear.LUT";
	  Load_LUT_file(board_number, lut_file);


	  // Create two vectors to hold values for two SLM images with opposite ramps.
	  unsigned char* ImageOne = new unsigned char[width*height];
	  unsigned char* ImageTwo = new unsigned char[width*height];
	  memset(ImageOne, 0, width*height);
	  memset(ImageTwo, 0, width*height);
	
	  //start the SLM with a blank image
	  Write_image(board_number, ImageOne, width*height, ExternalTrigger, OutputPulseImageFlip, OutputPulseImageRefresh, 5000);
	  ImageWriteComplete(board_number, 5000);	
	
	  // Generate phase gradients
	  int VortexCharge = 5;
	  Generate_LG(ImageOne, width, height, VortexCharge, width / 2.0, height / 2.0, false);
	  VortexCharge = 3;
	  Generate_LG(ImageTwo, width, height, VortexCharge, width / 2.0, height / 2.0, false);

	  for (int i = 0; i < 5; i++)
	  {
		  //write image returns on DMA complete, ImageWriteComplete returns when the hardware
		  //image buffer is ready to receive the next image. Breaking this into two functions is 
		  //useful for external triggers. It is safe to apply a trigger when Write_image is complete
		  //and it is safe to write a new image when ImageWriteComplete returns
		  Write_image(board_number, ImageOne, width*height, ExternalTrigger, OutputPulseImageFlip, OutputPulseImageRefresh, 5000);
		  ImageWriteComplete(board_number, 5000);
		  Sleep(500);

		  Write_image(board_number, ImageTwo, width*height, ExternalTrigger, OutputPulseImageFlip, OutputPulseImageRefresh, 5000);
		  ImageWriteComplete(board_number, 5000);
		  Sleep(500);
	  }

	  delete[]ImageOne;
	  delete[]ImageTwo;

	  SLM_power(false);
	  Delete_SDK();
	  return EXIT_SUCCESS;
  }

  return EXIT_FAILURE;
}