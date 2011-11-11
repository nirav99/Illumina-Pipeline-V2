#!/usr/bin/ruby

$:.unshift File.dirname(__FILE__)

require 'Scheduler'
require 'BWAParams'
require 'PipelineHelper'
require 'yaml'
require 'PathInfo'
require 'SchedulerInfo'
require 'EnvironmentInfo'
require 'ErrorHandler'

# Class to merge BAMs and write the merged bam in the specfied location
# Author: Nirav Shah niravs@bcm.edu

class MergeHelper
  # Class constructor
  # inputList - Array of directory paths of BAMs
  # outputDirectory - where to drop the final merged bam
  def initialize(sampleName, inputList, outputDirectory)
    begin
      @sampleName = sampleName
      initializeDefaultParams()
      findBAMsToMerge(inputList)
      validateOutputLocation(outputDirectory)

      # Now that no errors exist in the input, gather necessary tools to build
      # merge commands.
      obtainPathAndResourceInfo()
    rescue Exception => e
      handleError(e.message + " " + e.backtrace.inspect)
      exit -1
    end 
  end

  # Main worker method to start the merge process
  def startMerge()
    begin
      currDir = Dir.pwd
      Dir.chdir(@outDir)
      process()
      Dir.chdir(currDir)
    rescue Exception => e
      handleError(e.message + " " + e.backtrace.inspect)
    end
  end

  private

  def initializeDefaultParams()
    @bamsToMerge  = Array.new
  end


  # Helper method to find BAM files to merge
  def findBAMsToMerge(inputList)
    if inputList == nil || inputList.length < 1
      raise "Error: the list to merge BAMs is null or empty"
    end
  
    inputList.each do |directoryPath|
      dirPath = directoryPath.dup

      if !File::exist?(dirPath.strip)
        raise "Error: Specified directory path : " + dirPath + " is non-existing"
      end

      bamName = Dir[dirPath + "/" + "*_marked.bam"]
   
      if bamName.length != 1
        raise "Error: Did not find exactly one bam at : " + dirPath
      end

      @bamsToMerge << bamName[0]
    end
  end

  # Verify that the output directory is existing and writable
  def validateOutputLocation(outputDirectory)
    @outDir = outputDirectory.dup
    @outDir.strip!

    if !File::exist?(@outDir) || !File::writable?(@outDir)
      raise "Error: Specified output directory " + @outDir + " does not exist or is not writable"
    end
  end

  # Read the configuration yaml and obtain information about java
  # directory, and the number of node cores for the queue specified. 
  def obtainPathAndResourceInfo()

    yamlConfigFile = PathInfo::CONFIG_DIR + "/config_params.yml" 

    configReader = YAML.load_file(yamlConfigFile)

    # Obtain resources to use on the cluster
    queueName = SchedulerInfo::DEFAULT_QUEUE
    @maxMemory = configReader["scheduler"]["queue"][queueName]["maxMemory"]
    puts "Max memory : " + @maxMemory.to_s

    @maxNodeCores = configReader["scheduler"]["queue"][queueName]["maxCores"]
    puts "Max cores per node : " + @maxNodeCores.to_s + " for queue " + queueName

    @javaDir = PathInfo::JAVA_DIR 

    # Parameters for picard commands
    @picardPath       = configReader["picard"]["path"]
    @picardValStr     = configReader["picard"]["stringency"]
    @picardTempDir    = configReader["picard"]["tempDir"]
    @maxRecordsInRam  = configReader["picard"]["maxRecordsInRAM"]
    @heapSize         = configReader["picard"]["maxHeapSize"]
  end

  # Start the merge process
  def process()
    mergedBamName = @sampleName + "_merged.bam"
    finalBamName  = @sampleName + "_final.bam"   # TODO: needs change

    puts "Merged Bam : " + mergedBamName
    puts "final Bam  : " + finalBamName

    mergeCmd = buildMergeCommand(mergedBamName)
    runCommand(mergeCmd, "MergeCmd")

    markDupCmd = buildMarkDupCommand(mergedBamName, finalBamName)
    runCommand(markDupCmd, "MarkDupCmd")

    bamAnalyzerCmd = buildBamAnalyzerCommand(finalBamName)
    runCommand(bamAnalyzerCmd, "BAMAnalyzerCmd")

    File::delete(mergedBamName)
  end

  # Build the command to merge BAMs
  def buildMergeCommand(outFileName)
    outLog    = @outDir + "/mergeLog.o"
    errLog    = @outDir + "/mergeLog.e"
    mergedBam = @outDir + "/" + outFileName 

    cmd = "java " + @heapSize + " -jar " + @picardPath + "/MergeSamFiles.jar "

    @bamsToMerge.each do |inputFile|
      cmd = cmd + " I=" + inputFile.to_s
    end

   cmd = cmd + " O=" + mergedBam.to_s + " " +  @picardTempDir + " USE_THREADING=true " +
         @maxRecordsInRam.to_s + " " + @picardValStr + " AS=true 1>" + outLog + " 2>" + errLog
   puts cmd
   return cmd
  end

  # Mark duplicates on a sorted BAM
  def buildMarkDupCommand(input, outFileName)
    puts "Mark Dup : Input : " + input + " Output : " + outFileName
    outLog    = @outDir + "/markDups.o"
    errLog    = @outDir + "/markDups.e"
    markedBam = @outDir + "/" + outFileName

    cmd = "java " + @heapSize + " -jar " + @picardPath + "/MarkDuplicates.jar " +
          " I=" + input +  " O=" + markedBam + " " + @picardTempDir + " " +
          @maxRecordsInRam.to_s + " AS=true M=metrics.foo " +
          @picardValStr  + " 1>" + outLog + " 2>" + errLog
    return cmd
  end

  # Run BAMAnalyzer on finished BAM
  def buildBamAnalyzerCommand(input)
    outLog  = @outDir + "/bamAnalyzer.o"
    errLog  = @outDir + "/bamAnalyzer.e"
    jarName = @javaDir + "/BAMAnalyzer.jar"
    txtLog  = @outDir + "/BWA_Map_Stats.txt"
    xmlLog  = @outDir + "/BAMAnalysisInfo.xml"

    cmd = "java " + @heapSize + " -jar " + jarName + " I=" + input +
          " O=" + txtLog + " X=" + xmlLog + " 1>" + outLog + " 2>" + errLog 
    return cmd
  end

  # Method to run the specified command
  def runCommand(cmd, cmdName)
    puts "Running command " + cmdName.to_s
    startTime = Time.now
    `#{cmd}`
    endTime   = Time.now
    returnValue = $?

    timeDiff = (endTime - startTime) / 3600
    puts "Execution time : " + timeDiff.to_s + " hours"

    if returnValue != 0
      handleError(cmdName)
    end
  end

  # Inform the user if an error occurs and abort
  def handleError(commandName)
    err = ErrorMessage.new
    err.workingDir = Dir.pwd
    err.hostName   = EnvironmentInfo.getHostName()
    err.msgBrief   = "Error while merging BAMs"
    err.msgDetail  = "Error while processing command : " + commandName.to_s

    ErrorHandler.handleError(err)
  end
end

i = 0
inputList = Array.new
sample = nil
outDir = nil

ARGV.each do |arg|
  if i == 0
    sample = arg.dup
  elsif i == 1
    outDir = arg.dup
  else
    inputList << arg
  end
  i = i + 1
end
 
obj = MergeHelper.new(sample, inputList, outDir)
obj.startMerge()
