//-----------------------------------------------------------------------------
// Segmentation workflow part 5: segmenting micro regions
// View online documentation at 
// https://github.com/rodolfoavictor/WholeCoreSegmentation
//
// Author: Rodolfo A. Victor
// Last modified: 18-Apr-2019
//
// Requirements: Macro regions segmentation from part 3
//               Beam hardening corrected image from part 4
//-----------------------------------------------------------------------------

//Import denoised_BHC raw data 
//Import SegMacro raw data
//You can run part by part by selecting blocks delimited by "//--------"


selectWindow("SegMacro.raw");
rename("SegMacro");
run("physics");
setMinAndMax(0,3);

selectWindow("Denoised_BHC.raw");
rename("Denoised_BHC");

//-----------------------------------------------------------------------------
//A. Create gray value only with phase 2 (micro regions in SegMacro)
//-----------------------------------------------------------------------------
selectWindow("SegMacro")
run("Duplicate...", "title=IntensityPhase2 duplicate");
setThreshold(2,2);
run("Convert to Mask", "method=Default background=Default black");
run("Divide...","value=255 stack");
run("32-bit");
imageCalculator("Divide stack", "IntensityPhase2","IntensityPhase2");
imageCalculator("Multiply stack", "IntensityPhase2","Denoised_BHC");

//-----------------------------------------------------------------------------
//B. Enhance constrast in preparation for statistical region merging
//-----------------------------------------------------------------------------
selectWindow("IntensityPhase2");
//Get phase 2 intensity histogram
run("Histogram", "bins=256 use x_min=-1000 x_max=3108.45 y_max=Auto stack");
Plot.getValues(x, y);
close("Histogram of IntensityPhase2");
//Transform into cummulative histogram
for (i=1; i<y.length; i++) {
	y[i]+=y[i-1]; 
}
//Normalize for cummulative density function
for (i=0; i<y.length; i++) {
	y[i]/=y[y.length-1]; 
}
//Get percentile 1
for (i=0; i<y.length; i++) {  
	if (y[i]>0.01) {
		perc01=x[i];
		break;
	}
}
//Get percentile 99
for (i=y.length-1; i>=0; i--) {  
	if (y[i]<0.99) {
		perc99=x[i];
		break;
	}
}
//Modify dynamic range and convert to 8-bit
selectWindow("IntensityPhase2");
setMinAndMax(perc01,perc99);
run("8-bit");
//Histogram equalization
run("Enhance Contrast...", "saturated=0.4 normalize equalize process_all use");
rename("IntensityPhase2Normalized");

//-----------------------------------------------------------------------------
//C. Recursive statistical region merging
//-----------------------------------------------------------------------------
itermax=50;
Q=1024;
targetnumberofphases=10;
selectWindow("IntensityPhase2Normalized");
rename("SRM");
for (iter=0; iter<=itermax; iter++){
    print("Merging regions: it "+iter+" of "+itermax+", q="+Q);
    selectWindow("SRM");
    rename("SRMold");
    run("Statistical Region Merging", "q="+Q+" showaverages 3d");    
    rename("SRM");
    setMinAndMax(0,255);
    run("8-bit");
    close("SRMold");
    run("Clear Results");
    //check number of phases
    selectWindow("SRM");
    setSlice(1);
    getHistogram(values,counts,256);
    for (k=1; k<=nSlices; k++) {
        setSlice(k);
        getHistogram(valuesaux,countsaux,256);
        for (m=0; m<256; m++) counts[m]+=countsaux[m];
    }
    numberphases=0;
    for (k=0; k<256; k++) {
        if (counts[k]>0) {
            numberphases++;
        }
    }
    print("SRM #phases="+numberphases);
    if (numberphases<targetnumberofphases) break;
    Q=Q/2;
}
run("Collect Garbage");


//-----------------------------------------------------------------------------
//D. Sort regions after SRM
//-----------------------------------------------------------------------------
run("Clear Results");
selectWindow("SRM");
run("Duplicate...", "title=SRMsorted duplicate");
setSlice(1);
getHistogram(values,counts,256);
for (k=1; k<=nSlices; k++) {
    setSlice(k);
    getHistogram(valuesaux,countsaux,256);
    for (m=0; m<256; m++) counts[m]+=countsaux[m];
}
maxphase=1; //<-Start putting micro regions in phase 2
for (k=0; k<256; k++) {
    print("Sorting regions: "+k+"/255");
    if (counts[k]>0)  {
        maxphase++;
        run("Macro...", "code=[if (v=="+k+") v="+maxphase+"] stack");
    }
}
setMinAndMax(0,maxphase);
print("Number of micro phases: "+maxphase);
setMinAndMax(0,maxphase+1);

//-----------------------------------------------------------------------------
//E. Merge with macro regions
//-----------------------------------------------------------------------------
//Create regions starting with phase 2
selectWindow("SRMsorted");
run("Duplicate...", "title=MacroMicroMerge duplicate");

//Enforce zero outside macro phase 2
selectWindow("SegMacro");
run("Duplicate...", "title=MaskPhase2 duplicate");
setThreshold(2,2);
run("Convert to Mask", "method=Default background=Default black");
run("Divide...","value=255 stack");
setMinAndMax(0, 1);
imageCalculator("Multiply stack", "MacroMicroMerge","MaskPhase2");
close("MaskPhase2");

//Add macro phase 1
selectWindow("SegMacro")
run("Duplicate...", "title=MaskPhase1 duplicate");
setThreshold(1,1);
run("Convert to Mask", "method=Default background=Default black");
run("Divide...","value=255 stack");
setMinAndMax(0, 1);
imageCalculator("Add stack", "MacroMicroMerge","MaskPhase1");
close("MaskPhase1");

//Add macro phase 3 as the last segmentation phase
selectWindow("MacroMicroMerge");
run("Histogram", "bins=256 x_min=0 x_max=256 y_max=Auto stack");
Plot.getValues(x, y);
close("Histogram of MacroMicroMerge");
maxphase=-1;
for (i=1; i<y.length; i++) {
	if (y[i]>0) maxphase=x[i]; 
}
selectWindow("SegMacro")
run("Duplicate...", "title=MaskPhase3 duplicate");
setThreshold(3,3);
run("Convert to Mask", "method=Default background=Default black");
run("Divide...","value=255 stack");
run("Multiply...","value="+(maxphase+1)+" stack");
imageCalculator("Add stack", "MacroMicroMerge","MaskPhase3");
close("MaskPhase3");

//-----------------------------------------------------------------------------
//F. Save...
//-----------------------------------------------------------------------------
selectWindow("SegMacro");
path=getInfo("image.directory");
selectWindow("MacroMicroMerge");
saveAs("Raw Data", path + File.separator + "Segmentation.raw");

// Write meta data in a header
HeaderFile = path + File.separator + "Segmentation.hdr";      
f=File.delete(HeaderFile);
f=File.open(HeaderFile);
print(f,"nx="+getWidth());
print(f,"ny="+getHeight());
print(f,"nz="+nSlices);
print(f,"hx=0.488 mm");
print(f,"hy=0.488 mm");
print(f,"hz=1.25 mm");
print(f,"format 8 bit unsigned integer");
File.close(f);    
