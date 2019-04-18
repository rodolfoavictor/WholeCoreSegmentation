//-----------------------------------------------------------------------------
// Segmentation workflow part 1: denoising
// View online documentation at 
// https://github.com/rodolfoavictor/WholeCoreSegmentation
//
// Author: Rodolfo A. Victor
// Last modified: 18-Apr-2019
//
// Requirements: Non-local means denoising plugin version 1.4.5
//               http://fiji.sc/Non_Local_Means_Denoise
//
//               Raw data file C04B10_Raw140keV.raw from
//               http://www.digitalrocksportal.org/projects/102 
//-----------------------------------------------------------------------------


//Import C04B10_Raw140keV.raw and rename 
//to "Original" before running the code below

//Run non-local means. Results may vary depending on the implementation
selectWindow("Original");
run("32-bit");
setMinAndMax(-1500, 4000);
run("Duplicate...", "title=Denoised duplicate");
run("Non-local Means Denoising", "smoothing_factor=1 auto stack");

//Generate noise field
imageCalculator("Subtract create 32-bit stack", "Original","Denoised");
rename("NoiseField");

//Save results in the same folder
run("Input/Output...", "save"); //Write in little-endian byte order
selectWindow("Original");
path=getInfo("image.directory");
name="Denoised";
for (k=0; k<2; k++) {
	selectWindow(name);
	saveAs("Raw Data", path + File.separator + name + ".raw");

    // Write meta data in a header
    HeaderFile = path + File.separator + name + ".hdr";      
    f=File.delete(HeaderFile);
    f=File.open(HeaderFile);
    print(f,"nx="+getWidth());
    print(f,"ny="+getHeight());
    print(f,"nz="+nSlices);
    print(f,"hx=0.488 mm");
    print(f,"hy=0.488 mm");
    print(f,"hz=1.25 mm");
    print(f,"format 32 bit real little endian");
    File.close(f);    
    name="NoiseField";
}
