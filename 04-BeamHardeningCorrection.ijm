//-----------------------------------------------------------------------------
// Segmentation workflow part 4: beam hardening corrections
// View online documentation at 
// https://github.com/rodolfoavictor/WholeCoreSegmentation
//
// Author: Rodolfo A. Victor
// Last modified: 18-Apr-2019
//
// Requirements: Cropped denoised image from part 2
//               Macro regions segmentation from part 3
//-----------------------------------------------------------------------------

//Import cropped denoised raw data from part 2
//Import macro regions segmentation from part 4

selectWindow("Denoised_Crop.raw");
rename("Denoised_Crop");
setMinAndMax(-1000,4000);
selectWindow("SegMacro.raw");
rename("SegMacro");
run("physics");
setMinAndMax(0,3);


//Calculating z-projection, not using vug voxels
selectWindow("SegMacro");
run("Duplicate...", "title=SegMacroNoVug duplicate");
run("Macro...", "code=[if (v==1)  v=0;] stack");
run("Macro...", "code=[if (v>0)  v=1;] stack");
run("32-bit");
run("Z Project...", "projection=[Sum Slices]");
rename("ZCount");
selectWindow("Denoised_Crop");
run("Z Project...", "projection=[Sum Slices]");
rename("ZSum");
imageCalculator("Divide create 32-bit", "ZSum","ZCount");
rename("ZAverage");
run("Min...","value=-1e5");
run("Max...","value=1e5");
setMinAndMax(-1000, 4000);
close("ZCount");
close("ZSum");
close("SegMacroNoVug");

//Average in theta direction
selectWindow("ZAverage");
run("Properties...", "unit=pixel pixel_width=1 pixel_height=1");
x0=getWidth()/2;
y0=getHeight()/2;
r0=getHeight()/2-2;
avgprofile=newArray(r0+1);
r=newArray(r0+1);
for (i=0; i<avgprofile.length; i++) {
	avgprofile[i] = 0;
	r[i] = i;
}
N=0;
for (theta=0; theta<360; theta+=2) {	
	N++;
	x1=x0+r0*cos(theta*PI/180);	
	y1=y0+r0*sin(theta*PI/180);
	makeLine(x0, y0, x1, y1);
	profile = getProfile();
	for (i=0; i<profile.length; i++) {
		avgprofile[i]+=profile[i];
	}
}
for (i=0; i<avgprofile.length; i++) {
	avgprofile[i] /= N;
}
Fit.doFit(20, r, avgprofile);//8th dgree polynomial fit
Fit.plot;

//Build an average correction profile
selectWindow("ZAverage");
run("Duplicate...","title=ZCorrection");
run("Set...","value=0");
for (i=0; i<getWidth(); i++) {
	for (j=0; j<getHeight(); j++) {
		x=i-getWidth()/2;
		y=j-getHeight()/2;
		r=sqrt(x*x+y*y);
		factor=Fit.f(0)/Fit.f(r);
		setPixel(i,j,factor);
	}	
}
selectWindow("ZCorrection");
makeOval(0, 0, getWidth(), getHeight());
run("Make Inverse");
run("Set...", "value=1");
run("Select None");

//Aplly correction
selectWindow("Denoised_Crop");
run("Duplicate...", "title=Denoised_BHC duplicate");
for (k=1; k<nSlices; k++) {
	selectWindow("Denoised_BHC");
	setSlice(k);
	imageCalculator("Multiply", "Denoised_BHC","ZCorrection");
}

//Save beam hardening correction result
run("Input/Output...", "save"); //Write in little-endian byte order
selectWindow("Denoised_Crop");
path=getInfo("image.directory");
selectWindow("Denoised_BHC");
saveAs("Raw Data", path + File.separator + "Denoised_BHC.raw");
// Write meta data in a header
HeaderFile = path + File.separator + "Denoised_BHC.hdr";      
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
