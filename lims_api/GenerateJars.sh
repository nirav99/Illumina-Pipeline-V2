#!/bin/bash

fcPlanJarName="FlowcellPlanDownloader.jar"
resultUploadJarName="AnalysisResultUploader.jar"

cd limsClient
rm -rf *.class

echo "Compiling project"
javac *.java

echo "Generating Manifest file"
FCPlanManifestFile=`pwd`"/FCPlanManifest.txt"
ResultUploadManifestFile=`pwd`"/ResultUploadManifest.txt"

echo -e "Main-Class: limsClient.FlowcellPlanBuilder\n" > $FCPlanManifestFile
echo -e "Main-Class: limsClient.AnalysisResultUploader\n" > $ResultUploadManifestFile

echo "Building Jar files"
cd ..

jar cvfm $fcPlanJarName $FCPlanManifestFile limsClient/FlowcellPlanBuilder*.class limsClient/LaneInfo.class limsClient/LIMSClient.class limsClient/LimsInfo.config
jar cvfm $resultUploadJarName $ResultUploadManifestFile limsClient/AnalysisResultUploader*.class limsClient/LIMSClient.class limsClient/LimsInfo.config
