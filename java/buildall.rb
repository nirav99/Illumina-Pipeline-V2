#!/usr/bin/ruby
require 'yaml'

# Script to build all Java projects

yamlConfigFile = File.dirname(File.expand_path(File.dirname(__FILE__))) +
                 "/config/config_params.yml"
configReader   = YAML.load_file(yamlConfigFile)
picardPath     = configReader["picard"]["path"]

puts "Picard path : " + picardPath.to_s

puts "Building BAMAnalyzer"
cmd    = "sh GenerateBAMAnalyzerJar.sh " + picardPath
output = `#{cmd}`
puts output

puts "Building SequenceAnalyzer"
cmd    = "sh GenerateSequenceAnalyzerJar.sh " + picardPath
output = `#{cmd}`
puts output

puts "Building bamtools package Jars"
cmd    = "sh GenerateBAMToolsJars.sh " + picardPath
output = `#{cmd}`
puts output

puts "Building barcode package Jars"
cmd = "sh GenerateBarcodesJars.sh" 
output = `#{cmd}`
puts output

puts "Building attachment mailer Jar"
cmd = "sh GenerateAttachmentMailer.sh"
output = `#{cmd}`
puts output

puts "Building fastqtools package Jars"
cmd = "sh GenerateFastqToolsJars.sh " + picardPath
output = `#{cmd}`
puts output
