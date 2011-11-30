#!/bin/bash

# Script to build BAMAnalyzer project

picardPath=$1

echo "Found picard path : "$picardPath

samJarName=`ls $picardPath"/"sam-*.jar`
picardJarName=`ls $picardPath"/"picard-*.jar`
outJarName="BAMAnalyzer.jar"

rm $outJarName

echo "Building "$outJarName
echo "SAM Jar : "$samJarName
echo "Picard Jar : "$picardJarName

echo "Compiling project"
cd analyzer/BAMAnalyzer
rm *.class
rm ../Common*.class

javac -classpath $samJarName":"$picardJarName ../Common/*.java *.java

echo "Generating Manifest file"
manifestFile=`pwd`"/BAMAnalyzerManifest.txt"

echo -e "Class-Path: "$samJarName" "$picardJarName"\nMain-Class: analyzer.BAMAnalyzer.BAMAnalyzer\n" > $manifestFile

cd ../../
echo "Building Jar file"
pwd

jar cvfm $outJarName $manifestFile ./analyzer/Common/*.class ./analyzer/BAMAnalyzer/*.class
echo "done"
