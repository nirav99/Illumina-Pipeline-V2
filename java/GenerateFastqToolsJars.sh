#!/bin/bash

picardPath=$1

echo "Found picard path : "$picardPath

samJarName=`ls $picardPath"/"sam-*.jar`
picardJarName=`ls $picardPath"/"picard-*.jar`

fastqDecontJarName="FastqDecontaminator.jar"

echo "Building "$fastqDecontJarName
echo "SAM Jar : "$samJarName
echo "Picard Jar : "$picardJarName

echo "Compiling project"
cd fastqtools
rm *.class

javac -classpath $samJarName":"$picardJarName FastqDecontaminator.java

echo "Generating Manifest files"
fastqDecontManifestFile=`pwd`"/FastqDecontManifest.txt"

echo -e "Class-Path: "$samJarName" "$picardJarName"\nMain-Class: fastqtools.FastqDecontaminator\n" > $fastqDecontManifestFile

cd ../
echo "Building "$fastqDecontJarName
jar cvfm $fastqDecontJarName $fastqDecontManifestFile fastqtools/FastqDecontaminator.class
echo "done"
