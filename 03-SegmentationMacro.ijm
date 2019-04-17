//Import denoised_crpop raw data and rename image to "Denoise_Crop"
//Import deblurred raw data and rename image to "Deblurred"


selectWindow("Denoised_Crop");
setMinAndMax(-1000,4000);
selectWindow("Deblurred");
setMinAndMax(-1000,4500);

//Inclusions
selectWindow("Deblurred");
run("Duplicate...", "title=InclusionSeeds duplicate");
setThreshold(3500, 1e8); //<--Threshold for high attenuation voxels
run("Convert to Mask", "method=Default background=Dark black");

//Vugs
selectWindow("Deblurred");
run("Duplicate...", "title=VugSeeds duplicate");
setThreshold(-3000, 1200); //<--Threshold for vugs
run("Convert to Mask", "method=Default background=Dark black");
makeOval(0,0,getWidth(),getHeight());
run("Make Inverse");
run("Set...", "value=0 stack");
run("Select None");

//Remove vug seeds in 3 voxels from mask inclusions
selectWindow("InclusionSeeds");
run("Duplicate...", "title=InclusionsSeedsDilated duplicate");
for (k=0; k<3; k++) run("Dilate (3D)", "iso=255");
imageCalculator("Subtract stack", "VugSeeds","InclusionsSeedsDilated");
close("InclusionsSeedsDilated");

//Compose seed
imageCalculator("OR create stack", "InclusionSeeds","VugSeeds");
rename("MicroSeeds");
run("Invert", "stack");
makeOval(0,0,getWidth(),getHeight());
run("Make Inverse");
run("Set...", "value=0 stack");
run("Select None");
run("Erode (3D)", "iso=255");
run("Divide...","value=255 stack");
run("Multiply...","value=3 stack");
selectWindow("VugSeeds");
run("Divide...","value=255 stack");
run("Multiply...","value=2 stack");
selectWindow("InclusionSeeds");
run("Divide...","value=255 stack");
run("Multiply...","value=4 stack");
run("Duplicate...", "title=MaskSeed duplicate");
run("Multiply...","value=0 stack");
makeOval(0,0,getWidth(),getHeight());
run("Make Inverse");
run("Set...", "value=255 stack");
run("Select None");
for (k=0;k<10;k++) run("Erode (3D)", "iso=255");
run("Divide...","value=255 stack");
run("physics");
setMinAndMax(0,4);
imageCalculator("Add stack", "MaskSeed","VugSeeds");
imageCalculator("Add stack", "MaskSeed","MicroSeeds");
imageCalculator("Add stack", "MaskSeed","InclusionSeeds");
selectWindow("MaskSeed");
rename("Seeds");
close("VugSeeds");
close("MicroSeeds");
close("InclusionSeeds");

//Region growing
run("Seeded Region Growing ...", "image=Denoised_Crop seeds=Seeds stack=[3D volume]");
run("Subtract...","value=1 stack");
rename("SegMacro");
setMinAndMax(0,3);

//Save
selectWindow("Deblurred");
path=getInfo("image.directory");
selectWindow("SegMacro");
saveAs("Raw Data", path + File.separator + "SegMacro.raw");
// Write meta data in a header
HeaderFile = path + File.separator + "SegMacro.hdr";      
f=File.delete(HeaderFile);
f=File.open(HeaderFile);
print(f,"nx="+getWidth());
print(f,"ny="+getHeight());
print(f,"nz="+nSlices);
print(f,"hx=0.488 mm");
print(f,"hy=0.488 mm");
print(f,"hz=1.25 mm");
print(f,"format 8 bit uns integer");
File.close(f);    