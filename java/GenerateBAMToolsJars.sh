#!/bin/bash

picardPath=$1

echo "Found picard path : "$picardPath

samJarName=`ls $picardPath"/"sam-*.jar`
picardJarName=`ls $picardPath"/"picard-*.jar`
mateInfoFixJarName="MateInfoFixer.jar"
fixCIGARJarName="CIGARFixer.jar"
bamHeaderFixerJarName="BAMHeaderFixer.jar"
peToFragJarName="PEToFragConvertor.jar"

echo "Building "$outJarName
echo "SAM Jar : "$samJarName
echo "Picard Jar : "$picardJarName

echo "Compiling project"
cd bamtools
rm *.class

javac -classpath $samJarName":"$picardJarName *.java

echo "Generating Manifest files"
mateInfoFixerManifestFile=`pwd`"/MateInfoFixerManifest.txt"
cigarFixerManifestFile=`pwd`"/CIGARFixerManifest.txt"
bamHeaderFixerManifestFile=`pwd`"/BAMHeaderFixerManifest.txt"
peToFragManifestFile=`pwd`"/PEToFragManifest.txt"

echo -e "Class-Path: "$samJarName" "$picardJarName"\nMain-Class: bamtools.MateInfoFixer\n" > $mateInfoFixerManifestFile
echo -e "Class-Path: "$samJarName" "$picardJarName"\nMain-Class: bamtools.CIGARFixer\n" > $cigarFixerManifestFile
echo -e "Class-Path: "$samJarName" "$picardJarName"\nMain-Class: bamtools.BAMHeaderFixer\n" > $bamHeaderFixerManifestFile
echo -e "Class-Path: "$samJarName" "$picardJarName"\nMain-Class: bamtools.PEToFragConvertor\n" > $peToFragManifestFile

cd ../
echo "Building "$mateInfoFixJarName 
jar cvfm $mateInfoFixJarName $mateInfoFixerManifestFile bamtools/SAMRecordFixer.class bamtools/MateInfoFixer.class
echo "done"

echo "Building "$fixCIGARJarName
jar cvfm $fixCIGARJarName $cigarFixerManifestFile bamtools/SAMRecordFixer.class bamtools/CIGARFixer.class
echo "done"

echo "Building "$bamHeaderFixerJarName
jar cvfm $bamHeaderFixerJarName $bamHeaderFixerManifestFile bamtools/BAMHeaderFixer.class
echo "done"

echo "Building "$peToFragJarName
jar cvfm $peToFragJarName $peToFragManifestFile bamtools/PEToFragConvertor.class
echo "done"
