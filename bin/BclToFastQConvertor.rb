#!/usr/bin/ruby
$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'EmailHelper'
require 'Scheduler'
require 'yaml'
require 'PipelineHelper'

# Class to create the analysis directory and convert BCL files to Fastq files.
# Author: Nirav Shah niravs@bcm.edu

class BclToFastQConvertor
  def initialize(cmdParams)
    initializeDefaultParams()
    parseCommandString(cmdParams)
    begin
      @baseCallsDir = PipelineHelper.findBaseCallsDir(@fcName)
      validateRequiredFiles()
      runBclToFastQCommand()
    rescue Exception => e
      $stderr.puts "Exception occurred while pre-processing flowcell : " + @fcName.to_s
      $stderr.puts e.message
      $stderr.puts e.backtrace.inspect
      emailErrorMessage(e.message)
      exit -1
    end
  end

  private
  # Verify that the files required for this step are available in the expected
  # locations. Currently, the only check is to look for a SampleSheet.csv in the
  # /BaseCalls directory of the flowcell.
  def validateRequiredFiles()
    @sampleSheet = @baseCallsDir + "/SampleSheet.csv" 

    if !File.exist?(@sampleSheet)
      raise "Missing SampleSheet.csv in directory: " + @baseCallsDir
    end
  end

  # Method to parse the command line string and validate it
  def parseCommandString(cmdParams)
    cmdParams.each do |line|
      line.strip!
      if line.match(/fcname=/)
        @fcName = line.gsub(/fcname=/,"")      
      elsif line.match?(/use_bases_mask=/)
        @useBasesMask = line.gsub(/use_bases_mask=/,"")
      end
    end

    if @fcName == nil 
       printUsage()
       exit -1
    end
  end

  # Acts like a default constructor
  def initializeDefaultParams()
    @fcName            = nil   # Flowcell name
    @baseCallsDir      = nil   # BaseCalls dir of the flowcell
    @useBasesMask      = nil   # Custom value to provide to BCL->FastQ convertor
    @sampleSheet       = nil   # Path to SampleSheet.csv
    yamlConfigFile     = File.dirname(File.expand_path(File.dirname(__FILE__))) +
                         "/config/config_params.yml" 
    @configReader      = YAML.load_file(yamlConfigFile)
  end


  # Method to build the complete command to convert bcl to fastq
  def runBclToFastQCommand()
    bclToFastQScript = @configReader["casava"]["bclToFastqPath"]

    outputDir = PipelineHelper.getResultDir(@fcName)

    cmd = bclToFastQScript + " --input-dir " + @baseCallsDir + " --output-dir " + 
          outputDir + " --sample-sheet " + @sampleSheet + " --mismatches 1 " +
          " --ignore-missing-stats --ignore-missing-bcl"

    if @useBaseMask != nil && !@useBaseMask.empty?()
      cmd = cmd + " --use-bases-mask " + @useBaseMask.to_s
    end

    output = `#{cmd}`
    returnValue = $?

    if returnValue != 0
      raise "Error while running command : " + cmd.to_s 
    else
      currDir = FileUtils.pwd()
      FileUtils.cd(outputDir)
      runMake()
      FileUtils.cd(currDir)
    end
  end

  # Run make utility to start the conversion
  def runMake()
    puts "Running make to generate Fastq files"

    queue    = "high"
    numCores = @configReader["scheduler"]["highQueue"]["maxCores"]
    cmd      = "make -j" + numCores.to_s

    s = Scheduler.new(@fcName + "_BclToFastQ", cmd)
    s.lockWholeNode(queue)
    s.runCommand()
    @bclToFastQMakeJobName = s.getJobName()

    puts "JOB NAME = " +  @bclToFastQMakeJobName.to_s
  end

  # Show usage information
  def printUsage()
    puts "Script to prepare the flowcell for analysis"
    puts ""
    puts "Usage:"
    puts ""
    puts "ruby " + __FILE__ + " fcname=value use_bases_mask=value"
    puts ""
    puts "fcname         - full flowcell name"
    puts "use_bases_mask - Custom value for use_bases_mask parameter"
    puts "                 Optional: Use only when default value is not"
    puts "                 acceptable."
 end

  # Send email describing the error message to interested watchers
  def emailErrorMessage(msg)
    obj          = EmailHelper.new()
    emailFrom    = "sol-pipe@bcm.edu"
    emailTo      = obj.getErrorRecepientEmailList()
    emailSubject = "Error while converting bcl to Fastq for flowcell " + @fcName + " for analysis" 
    emailText    = "The error is : " + msg.to_s

    obj.sendEmail(emailFrom, emailTo, emailSubject, emailText)
  end
end

cmdParams = ARGV
obj = BclToFastQConvertor.new(cmdParams)
