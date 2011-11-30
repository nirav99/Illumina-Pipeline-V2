#!/bin/bash

barcodeEditDistJarName="BarcodeEditDist.jar"

echo "Building "$outJarName
echo "SAM Jar : "$samJarName
echo "Picard Jar : "$picardJarName

echo "Compiling project"
cd barcodes
rm *.class

javac BarcodeEditDist.java

echo "Generating Manifest files"
barcodeEditDistManifestFile=`pwd`"/BarcodeEditDistManifest.txt"

echo -e "Class-Path: "$samJarName" "$picardJarName"\nMain-Class: barcodes.BarcodeEditDist\n" > $barcodeEditDistManifestFile

cd ../
echo "Building "$barcodeEditDistJarName
jar cvfm $barcodeEditDistJarName $barcodeEditDistManifestFile barcodes/BarcodeEditDist.class
echo "done"
