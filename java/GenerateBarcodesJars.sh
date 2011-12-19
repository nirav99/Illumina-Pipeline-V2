#!/bin/bash

barcodeEditDistJarName="BarcodeEditDist.jar"
barcodeFreqCounterJarName="BarcodeFrequencyCounter.jar"

echo "Building package barcodes"

echo "Compiling project"
cd barcodes
rm *.class

javac BarcodeEditDist.java
javac BarcodeFrequencyCounter.java

echo "Generating Manifest files"
barcodeEditDistManifestFile=`pwd`"/BarcodeEditDistManifest.txt"
barcodeFreqCounterManifestFile=`pwd`/"BarcodeFreqCounterManifest.txt"

echo -e "Main-Class: barcodes.BarcodeEditDist\n" > $barcodeEditDistManifestFile
echo -e "Main-Class: barcodes.BarcodeFrequencyCounter\n" > $barcodeFreqCounterManifestFile

cd ../
echo "Building "$barcodeEditDistJarName
jar cvfm $barcodeEditDistJarName $barcodeEditDistManifestFile barcodes/BarcodeEditDist.class
echo "done"

echo "Building "$barcodeFreqCounterJarName
jar cvfm $barcodeFreqCounterJarName $barcodeFreqCounterManifestFile barcodes/BarcodeFrequencyCounter.class
echo "done"
