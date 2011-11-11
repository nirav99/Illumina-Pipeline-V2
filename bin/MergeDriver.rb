#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'Scheduler'
require 'PathInfo'
require 'SchedulerInfo'
require 'ErrorHandler'

# Class to initiate merges of BAM files
# Author: Nirav Shah niravs@bcm.edu
class MergeController
  def initialize(cmdParams)
    initializeDefaultParams()
    parseCommandString(cmdParams)
    begin
      startMergeProcess()
    rescue Exception => e
      $stderr.puts e.message
      $stderr.puts e.backtrace.inspect 
      handleError(e.message + "/r/n" + e.backtrace.inspect)
    end
  end

  private 
  def initializeDefaultParams()
    @sampleName = nil
    @inputList  = Array.new
    @outputDir  = nil
  end

  def parseCommandString(cmdParams)
    if cmdParams != nil
      cmdParams.each do |entry|
        line = entry.dup
        line.strip!

        if line.match(/sample=/)
          @sampleName = line.gsub(/sample=/,"")
        elsif line.match(/input=/)
          @inputList << line.gsub(/input=/, "")
        elsif line.match(/outputdir=/)
          @outputDir = line.gsub(/outputdir=/, "")
        end
      end
    end

    foundError = false

    if @sampleName == nil || @sampleName.eql?("")
      $stderr.puts "Error: samplename not specified"
      foundError = true
    elsif foundError == false && (@inputList == nil || @inputList.size < 2)
      $stderr.puts "Error: At least two files should be specified for merging"
      foundError = true
    elsif foundError == false && (@outputDir == nil || @outputDir.eql?("") ||
          !File::directory?(@outputDir))
      $stderr.puts "Error: outputdir is not specified or is not a valid directory"
      foundError = true
    elsif foundError == false
      @inputList.each do |inputFile|
        if !File::exist?(inputFile)
           foundError = true
           $stderr.puts "Error: " + inputFile + " is non-existing"
           break
        end
      end
    end
    if foundError == true
      printUsage()
      exit -1
    end
  end

  # Start the merge process by scheduling appropriate merge job on the cluster.
  def startMergeProcess()
    schedulerQueue = SchedulerInfo::DEFAULT_QUEUE
    yamlConfigFile = PathInfo::CONFIG_DIR + "/config_params.yml" 
    configReader = YAML.load_file(yamlConfigFile)

    cmd = "ruby " + PathInfo::LIB_DIR + "/MergeHelper.rb " + @sampleName.to_s +
          " " + @outputDir

    @inputList.each do |inputDir|
      cmd = cmd + " " + inputDir
    end

    obj = Scheduler.new("Merge_" + @sampleName.to_s, cmd)
    obj.lockWholeNode(schedulerQueue)
    obj.runCommand()
    jobID = obj.getJobName()

    puts "Job ID : " + jobID.to_s
  end

  # Print the usage
  def printUsage()
    puts "Utility to merge multiple BAM files"
    puts ""
    puts "Usage:"
    puts ""
    puts "ruby " + __FILE__ + " sample=value outputdir=value input=value..."
    puts ""
    puts "samplename      - Name of the sample. Used in prefix of output file"
    puts "outputdir       - Directory where to write the merged file"
    puts "input           - Path to a BAM to be merged."
    puts "                  Must be specified at least twice"
  end

  # Handle error and exit
  def handleError(errorMessage)
    obj       = ErrorMessage.new()
    obj.msgDetail  = errorMessage.to_s
    obj.msgBrief   = "Error while merging sample " + @sampleName.to_s
    obj.workingDir = Dir.pwd

 #   hostName = EnvironmentInfo.getHostName()

=begin
    if hostName != nil && !hostName.eql?("")
      obj.hostName = hostName.to_s
    end
=end

    puts "CAME HERE"
    #ErrorHandler.handleError(obj)
    exit
  end
end

cmdParams = ARGV
obj = MergeController.new(cmdParams)
