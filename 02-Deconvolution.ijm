//-----------------------------------------------------------------------------
// Segmentation workflow part 2: deconvolution
// View online documentation at 
// https://github.com/rodolfoavictor/WholeCoreSegmentation
//
// Author: Rodolfo A. Victor
// Last modified: 18-Apr-2019
//
// Requirements: Parallel Iterative Deconvolution plugin
//               https://imagej.net/Parallel_Iterative_Deconvolution
//
//               Denoised tomogram from part 1
//-----------------------------------------------------------------------------

//Import denoised raw data from part 1 and rename image to "Denoised"
//You can run part by part by selecting blocks delimited by "//--------"

//-----------------------------------------------------------------------------
//A. Create non-negative TIFF version for the deblurring filter
//Deconvolution filter implementation requires non-negative values
//-----------------------------------------------------------------------------
selectWindow("Denoised");
run("Select None");
run("Properties...", "unit=mm pixel_width=0.488 pixel_height=0.488 voxel_depth=1.25");
run("Add...", "value=3000 stack"); 
path=getInfo("image.directory");
saveAs("Tiff", path + File.separator + "Denoised.tiff");
run("Subtract...", "value=3000 stack");
rename("Denoised");

//-----------------------------------------------------------------------------
//B. Fit error function at the transition air-quartz 
//and generate point spread function
//-----------------------------------------------------------------------------
selectWindow("Denoised");
path=getInfo("image.directory");
setSlice(nSlices/2);
makeLine(235, 468, 260, 468); //<-- Make sure this line passes through the center of the calibration bar
run("Plot Profile");
Plot.getValues(xpoints, ypoints);
Fit.doFit(24, xpoints, ypoints);
Fit.plot;
sigma=Fit.p(3)/sqrt(2);

N=round(5*sigma/0.488);
newImage("PSF", "32-bit black", N, N, N);
run("Properties...", "unit=mm pixel_width=0.488 pixel_height=0.488 voxel_depth=1.25");
for (k=1; k<=nSlices; k++) {
	setSlice(k);
	z=((k-1)-nSlices/2)*1.25;
	for (j=0; j<getHeight(); j++) {
		y=(j-getHeight()/2)*0.488;
		for (i=0; i<getWidth(); i++) {
			x=(i-getWidth()/2)*0.488;
			value=exp(-(x*x+y*y+z*z)/2/sigma/sigma);						
			setPixel(i, j, value);
			if (i==getWidth()/2 && j==getHeight()/2 && k>nSlices/2) {
				print(x,y,z,sigma,value);
				exit();
			}
		}
	}
}
setSlice(nSlices/2);
saveAs("Tiff", path + File.separator + "PSF.tiff");

//-----------------------------------------------------------------------------
//C. Deconvolve
//-----------------------------------------------------------------------------
selectWindow("Denoised");
path=getInfo("image.directory");
pathToBlurredImage = path + "Denoised.tiff";
pathToPsf = path + "PSF.tiff";
pathToDeblurredImage = path + "Deblurred.tif";
boundary = "PERIODIC"; //available options: REFLEXIVE, PERIODIC, ZERO
resizing = "AUTO"; // available options: AUTO, MINIMAL, NEXT_POWER_OF_TWO
output = "SAME_AS_SOURCE"; // available options: SAME_AS_SOURCE, BYTE, SHORT, FLOAT
precision = "DOUBLE"; //available options: SINGLE, DOUBLE
threshold = "-1"; //if -1, then disabled
maxIters = "5";
nOfThreads = "8";
showIter = "false";
gamma = "0";
filterXY = "1.0";
filterZ = "1.0";
normalize = "true";
logMean = "false";
antiRing = "true";
changeThreshPercent = "0.01";
db = "false";
detectDivergence = "true";
call("edu.emory.mathcs.restoretools.iterative.ParallelIterativeDeconvolution3D.deconvolveWPL", pathToBlurredImage, pathToPsf, pathToDeblurredImage, boundary, resizing, output, precision, threshold, maxIters, nOfThreads, showIter, gamma, filterXY, filterZ, normalize, logMean, antiRing, changeThreshPercent, db, detectDivergence);'

//-----------------------------------------------------------------------------
//D. Correct values, crop, and save raw
//-----------------------------------------------------------------------------
run("Input/Output...", "save"); //Write in little-endian byte order
selectWindow("Denoised");
path=getInfo("image.directory");
open(path + File.separator + "Deblurred.tif");
run("Subtract...", "value=3000 stack"); //Restore raw image
setMinAndMax(-1500, 4000);
name="Deblurred";
for (k=0; k<2; k++) {
	makeOval(133, 110, 250, 250); //<--Make sure this circle is centered at the rock core
	run("Crop");
	run("Make Inverse");
	run("Set...", "value=-1000 stack");
	run("Select None");
	run("Slice Remover", "first=1 last=30 increment=1");
	run("Slice Remover", "first=701 last=728 increment=1");
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
	if (k==0) selectWindow("Denoised");
	name="Denoised_Crop";
}