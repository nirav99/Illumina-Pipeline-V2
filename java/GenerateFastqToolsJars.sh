#!/bin/bash

picardPath=$1

echo "Found picard path : "$picardPath

samJarName=`ls $picardPath"/"sam-*.jar`
picardJarName=`ls $picardPath"/"picard-*.jar`

fastqDecontJarName="FastqDecontaminator.jar"
fastqTrimmerJarName="FastqTrimmer.jar"

echo "Building "$fastqDecontJarName
echo "SAM Jar : "$samJarName
echo "Picard Jar : "$picardJarName

echo "Compiling project"
cd fastqtools
rm *.class

javac -classpath $samJarName":"$picardJarName FastqDecontaminator.java
javac -classpath $samJarName":"$picardJarName FastqTrimmer.java

echo "Generating Manifest files"
fastqDecontManifestFile=`pwd`"/FastqDecontManifest.txt"
fastqTrimmerManifestFile=`pwd`"/FastqTrimManifest.txt"

echo -e "Class-Path: "$samJarName" "$picardJarName"\nMain-Class: fastqtools.FastqDecontaminator\n" > $fastqDecontManifestFile
echo -e "Class-Path: "$samJarName" "$picardJarName"\nMain-Class: fastqtools.FastqTrimmer\n" > $fastqTrimmerManifestFile

cd ../
echo "Building "$fastqDecontJarName
jar cvfm $fastqDecontJarName $fastqDecontManifestFile fastqtools/FastqDecontaminator.class
echo "done"

echo "Building "$fastqTrimmerJarName
jar cvfm $fastqTrimmerJarName $fastqTrimmerManifestFile fastqtools/FastqTrimmer.class
echo "done"
