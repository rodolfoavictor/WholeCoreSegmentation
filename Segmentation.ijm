//Open C04B19Raw140keV

run("Close All");
run("Raw...", "open=/nethome/EXA_NetApp/Temp_Rodolfo/WholeCores/C04B19Raw140keV.raw image=[16-bit Signed] width=512 height=512 number=012523 little-endian");
rename("Original");

source=getInfo("image.filename");
if (source=="C04B19Raw140keV.raw") {
  OX=135; NX=250;
  OY=106; NY=250;
  OZ=47;  NZ=665;  
  X1=235; Y1=468;
  X2=260; Y2=468;
} else {
	exit("I don't know how to handle this "+source+" sample!");	
}

//--------------------------------------------------------------------
//Denoise
//Result may vary for distinc implementations of NLM filter
//--------------------------------------------------------------------
selectWindow("Original");
run("32-bit");
setMinAndMax(-1500, 4000);
run("Duplicate...", "title=Denoised duplicate");
run("Non-local Means Denoising", "smoothing_factor=1 auto stack");
imageCalculator("Subtract create 32-bit stack", "Original","Denoised");
rename("Noise field");


//--------------------------------------------------------------------
//Crop
//--------------------------------------------------------------------
selectWindow(source);
run("Properties...", "unit=mm pixel_width=0.488 pixel_height=0.488 voxel_depth=1.25");
rename("Original");
run("Slice Keeper", "first="+OZ+" last="+(OZ+NZ-1)+" increment=1");
setMinAndMax(-1500, 4000);
makeOval(OX, OY, NX, NY);
run("Crop");
rename("Cropped");
run("Make Inverse");
run("Set...", "value=-2000 stack");
run("Make Inverse");
run("Select None");


//--------------------------------------------------------------------
//Deconvolution
//https://imagej.net/Parallel_Iterative_Deconvolution
//version 1.9
//--------------------------------------------------------------------

//Fitting error function
  X1=235; Y1=468;
  X2=260; Y2=468;
selectWindow("Original");
setSlice(nSlices/2);
makeLine(X1, Y1, X2, Y2);
run("Plot Profile");
Plot.getValues(xpoints, ypoints);
Fit.doFit(24, xpoints, ypoints);
Fit.plot;
sigma=Fit.p(3)/sqrt(2);

//Point spread function
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

//Deconvolve
pathToBlurredImage = "Cropped";
pathToPsf = "PSF";
pathToDeblurredImage = "'$DEBLURRED'";'
boundary = "PERIODIC"; //available options: REFLEXIVE, PERIODIC, ZERO
resizing = "AUTO"; // available options: AUTO, MINIMAL, NEXT_POWER_OF_TWO
output = "FLOAT"; // available options: SAME_AS_SOURCE, BYTE, SHORT, FLOAT
precision = "SINGLE"; //available options: SINGLE, DOUBLE
threshold = "-1"; //if -1, then disabled
maxIters = "5";
nOfThreads = "8";
showIter = "false";
gamma = "0";
filterXY = "1.0";
filterZ = "1.0";
normalize = "false";
logMean = "false";
antiRing = "true";
changeThreshPercent = "0.01";
db = "false";
detectDivergence = "true";
call("edu.emory.mathcs.restoretools.iterative.ParallelIterativeDeconvolution3D.deconvolveWPL", pathToBlurredImage, pathToPsf, pathToDeblurredImage, boundary, resizing, output, precision, threshold, maxIters, nOfThreads, showIter, gamma, filterXY, filterZ, normalize, logMean, antiRing, changeThreshPercent, db, detectDivergence);'


run("3D Iterative Deconvolution...", "blurred=cropped");

