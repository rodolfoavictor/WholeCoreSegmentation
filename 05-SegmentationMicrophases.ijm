//Import denoised_BHC raw data 
//Import SegMacro raw data

selectWindow("SegMacro.raw");
rename("SegMacro");
run("physics");
setMinAndMax(0,3);

selectWindow("Denoised_BHC.raw");
rename("Denoised_BHC");

//Resample Intensity to 8-bit based on min and max of phase 2
selectWindow("SegMacro")
run("Duplicate...", "title=Phase2 duplicate");
setThreshold(2,2);
run("Convert to Mask", "method=Default background=Default black");
imageCalculator("Divide 32-bit stack", "Phase2","Phase2");
rename("IntensityPhase2");
imageCalculator("Multiply stack", "IntensityPhase2","Denoised_BHC");
selectWindow("IntensityPhase2");
minvalue=200000;
maxvalue=-200000;
for (k=1; k<=nSlices; k++) {
    setSlice(k);
    getStatistics(area, mean, min, max);
    if (min<minvalue) minvalue=min;
    if (max>maxvalue) maxvalue=max;
}
print(minvalue+"-----"+maxvalue);
setMinAndMax(minvalue,maxvalue);
run("8-bit");
rename("SRM");


//Recursive statistical region merging
selectWindow("SRM");
run("Enhance Contrast...", "saturated=0.4 normalize equalize process_all use");
itermax=50;
Q=1024;
targetnumberofphases=10;
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

//Sort regions
run("Clear Results");
selectWindow("SRM");
setSlice(1);
getHistogram(values,counts,256);
for (k=1; k<=nSlices; k++) {
    setSlice(k);
    getHistogram(valuesaux,countsaux,256);
    for (m=0; m<256; m++) counts[m]+=countsaux[m];
}

print("Number phases: "+numberphases);
maxphase=-1;
for (k=0; k<256; k++) {
    print("Sorting regions: "+k+"/255");
    if (counts[k]>0)  {
        maxphase++;
        run("Macro...", "code=[if (v=="+k+") v="+maxphase+"] stack");
    }
}
setMinAndMax(0,maxphase);
rename("FinalMicroRegions");
print("Total phases: "+maxphase);

selectWindow("FinalMicroRegions");
setMinAndMax(0,maxphase+1);

