# Example usage of Blink_C_wrapper.dll
# Meadowlark Optics Spatial Light Modulators
# September 12 2019

import os
import numpy
from ctypes import *
from scipy import misc
from time import sleep

# Load the DLL
# Blink_C_wrapper.dll, Blink_SDK.dll, ImageGen.dll, FreeImage.dll and wdapi1021.dll
# should all be located in the same directory as the program referencing the
# library
cdll.LoadLibrary("C:\\Program Files\\Meadowlark Optics\\Blink OverDrive Plus\\SDK\\Blink_C_wrapper")
slm_lib = CDLL("Blink_C_wrapper")

# Open the image generation library
cdll.LoadLibrary("C:\\Program Files\\Meadowlark Optics\\Blink OverDrive Plus\\SDK\\ImageGen")
image_lib = CDLL("ImageGen")

# Basic parameters for calling Create_SDK
bit_depth = c_uint(12)
num_boards_found = c_uint(0)
constructed_okay = c_bool(0)
is_nematic_type = c_bool(1)
RAM_write_enable = c_bool(1)
use_GPU = c_bool(1)
max_transients = c_uint(20)
board_number = c_uint(1)
wait_For_Trigger = c_uint(0)
timeout_ms = c_uint(5000)
center_x = c_float(256)
center_y = c_float(256)
VortexCharge = c_uint(3)

# Both pulse options can be false, but only one can be true. You either generate a pulse when the new image begins loading to the SLM
# or every 1.184 ms on SLM refresh boundaries, or if both are false no output pulse is generated.
OutputPulseImageFlip = c_uint(0)
OutputPulseImageRefresh = c_uint(0); #only supported on 1920x1152, FW rev 1.8. 


# Call the Create_SDK constructor
# Returns a handle that's passed to subsequent SDK calls
slm_lib.Create_SDK(bit_depth, byref(num_boards_found), byref(constructed_okay), is_nematic_type, RAM_write_enable, use_GPU, max_transients, 0)

if constructed_okay == -1:
    print ("Blink SDK was not successfully constructed");
    # Python ctypes assumes the return value is always int
    # We need to tell it the return type by setting restype
    slm_lib.Get_last_error_message.restype = c_char_p
    print (slm_lib.Get_last_error_message());

    # Always call Delete_SDK before exiting
    slm_lib.Delete_SDK()
else:
    print ("Blink SDK was successfully constructed");
    print ("Found %s SLM controller(s)" % num_boards_found.value);
    height = c_uint(slm_lib.Get_image_height(board_number));
    width = c_uint(slm_lib.Get_image_width(board_number));
    center_x = c_uint(width.value//2);
    center_y = c_uint(height.value//2);
	
	#***you should replace *bit_linear.LUT with your custom LUT file***
	#but for now open a generic LUT that linearly maps input graylevels to output voltages
	#***Using *bit_linear.LUT does NOT give a linear phase response***
    if width == 512:
        slm_lib.Load_LUT_file(board_number, "C:\\Program Files\\Meadowlark Optics\\Blink OverDrive Plus\\LUT Files\\8bit_linear.LUT");
    else:
        slm_lib.Load_LUT_file(board_number, "C:\\Program Files\\Meadowlark Optics\\Blink OverDrive Plus\\LUT Files\\12bit_linear.LUT");

    # Create two vectors to hold values for two SLM images with opposite ramps.
    ImageOne = numpy.empty([width.value*height.value], numpy.uint8, 'C');
    ImageTwo = numpy.empty([width.value*height.value], numpy.uint8, 'C');
    
    # Write a blank pattern to the SLM to get going
    image_lib.Generate_Solid(ImageOne.ctypes.data_as(POINTER(c_ubyte)), width.value, height.value, 0);
    slm_lib.Write_image(board_number, ImageOne.ctypes.data_as(POINTER(c_ubyte)), height.value*width.value, wait_For_Trigger, OutputPulseImageFlip, OutputPulseImageRefresh, timeout_ms)
    
	# Generate phase gradients
    VortexCharge = 5;
    image_lib.Generate_LG(ImageOne.ctypes.data_as(POINTER(c_ubyte)), width.value, height.value, VortexCharge, center_x.value, center_y.value, 0);
    VortexCharge = 3;
    image_lib.Generate_LG(ImageTwo.ctypes.data_as(POINTER(c_ubyte)), width.value, height.value, VortexCharge, center_x.value, center_y.value, 0);

    # Loop between our phase gradient images
    for i in range(0, 10):
    
    	#write image returns on DMA complete, ImageWriteComplete returns when the hardware
		#image buffer is ready to receive the next image. Breaking this into two functions is 
		#useful for external triggers. It is safe to apply a trigger when Write_image is complete
		#and it is safe to write a new image when ImageWriteComplete returns
        slm_lib.Write_image(board_number, ImageOne.ctypes.data_as(POINTER(c_ubyte)), height.value*width.value, wait_For_Trigger, OutputPulseImageFlip, OutputPulseImageRefresh,timeout_ms)
        slm_lib.ImageWriteComplete(board_number, timeout_ms);
        sleep(1.0) # This is in seconds. IF USING EXTERNAL TRIGGERS, SET THIS TO 0
        slm_lib.Write_image(board_number, ImageTwo.ctypes.data_as(POINTER(c_ubyte)), height.value*width.value, wait_For_Trigger, OutputPulseImageFlip, OutputPulseImageRefresh, timeout_ms)
        slm_lib.ImageWriteComplete(board_number, timeout_ms);
        sleep(1.0) # This is in seconds. IF USING EXTERNAL TRIGGERS, SET THIS TO 0

    # Always call Delete_SDK before exiting
    slm_lib.Delete_SDK()