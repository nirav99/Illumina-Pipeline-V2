#!/bin/bash

outJarName="AttachmentMailer.jar"

cd tools
rm -rf $outJarName *.class

echo "Compiling project"
javac -classpath ./mail.jar *.java

echo "Generating Manifest file"
manifestFile=`pwd`"/AttachmentMailer.txt"

echo -e "Class-Path: ./mail.jar \nMain-Class: tools.AttachmentMailer\n" > $manifestFile

echo "Building Jar file"
cp mail.jar ../
cd ..

jar cvfm $outJarName $manifestFile tools/AttachmentMailer.class tools/EmailHost.config
