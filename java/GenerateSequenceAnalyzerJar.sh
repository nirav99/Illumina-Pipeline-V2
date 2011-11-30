#!/bin/bash
# Script to build SequenceAnalyzer project

picardPath=$1
samJarName=`ls $picardPath"/"sam-*.jar`
picardJarName=`ls $picardPath"/"picard-*.jar`
outJarName="SequenceAnalyzer.jar"

rm -rf $outJarName
echo "Building "$outJarName

echo "Compiling project"
cd analyzer/SequenceAnalyzer
rm *.class
rm ../Common/*.class

javac -classpath $samJarName":"$picardJarName ../Common/*.java *.java

echo "Generating Manifest file"
manifestFile=`pwd`"/SequenceAnalyzerManifest.txt"

echo -e "Class-Path: "$samJarName" "$picardJarName"\nMain-Class: analyzer.SequenceAnalyzer.SequenceAnalyzer\n" > $manifestFile

cd ../../

echo "Building Jar file"
jar cvfm $outJarName $manifestFile analyzer/Common/*.class analyzer/SequenceAnalyzer/*.class
echo "done"
