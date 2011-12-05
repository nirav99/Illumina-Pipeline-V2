#!/usr/bin/ruby
$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'PipelineHelper'
require 'ErrorHandler'
require 'BWAParams'
require 'rubygems'
require 'hpricot'
require 'PathInfo'

# Wrapper for SequenceAnalyzer
# Author: Nirav Shah niravs@bcm.edu

class SequenceAnalyzerWrapper
  def initialize()
    begin
      @tmpDirPath = "/space1/tmp/" + ENV['PBS_JOBID'].to_s
      puts "Path to temp dir = " + @tmpDirPath.to_s
      getFlowcellBarcode()
      cmd = buildCommand()
      runCommand(cmd)
      findAndUploadResult()
    rescue Exception => e
      handleError(e.message)
    end
  end

  private

  #Method to read config file and obtain flowcell barcode
  def getFlowcellBarcode()
    @fcBarcode = nil

    inputParams = BWAParams.new()
    inputParams.loadFromFile()
    @fcBarcode  = inputParams.getFCBarcode() # Lane barcode FCName-Lane-BarcodeName

    if @fcBarcode == nil || @fcBarcode.empty?()
      raise "Did not obtain flowcell barcode in directory : " + Dir.pwd
    end
  end

  # Helper method to build the Jar command to perform sequence analysis.  
  def buildCommand()
    jarName = PathInfo::JAVA_DIR + "/SequenceAnalyzer.jar"

    sequenceFiles = PipelineHelper.findSequenceFiles(Dir.pwd)

    if sequenceFiles == nil || sequenceFiles.size < 1
      raise "Could not find sequence files in directory " + Dir.pwd
    elsif sequenceFiles.size > 2
      raise "More than two sequence files detected in directory " + Dir.pwd
    end

    # Sort this array so that first entry is for read 1 and second entry for
    # read 2
    sequenceFiles.sort! 

    cmd = "java -Xmx8G -jar " + jarName + " R1=" + sequenceFiles[0].strip

    if sequenceFiles.size == 2
      cmd = cmd + " R2=" + sequenceFiles[1].strip
    end

    cmd = cmd + " O=" + @fcBarcode + "_uniqueness.txt X=" + @fcBarcode +
          "_uniqueness.xml TMP_DIR=" + @tmpDirPath.to_s
    return cmd
  end

  # Method to run the command to analyze sequences
  def runCommand(cmd)
    startTime = Time.now
    `#{cmd}`
    returnValue = $?
    endTime   = Time.now

    puts "Return value   : " + returnValue.to_s
    puts "Execution time : " + (endTime - startTime).to_s

    puts "Deleting temp files from tempdir"

    cmd = "rm " + @tmpDirPath + "/*.seq"
    `#{cmd}`

    if returnValue != 0
      handleError("SequenceAnalyzer failed for flowcell : " + @fcBarcode)
    end
  end

  # Read the result XML generated by SequenceAnalyzer.jar and upload results to
  # LIMS  
  def findAndUploadResult()
    resultFile = @fcBarcode + "_uniqueness.xml"

    if !File::exist?(resultFile)
      raise "Did not find " + resultFile + ", can't upload results to LIMS"
    end
    xmlDoc = Hpricot::XML(open(resultFile))
    uniquePercent = xmlDoc.at("AnalysisMetrics/Uniqueness")["PercentUnique"] 

    puts "Unique Percentage : " + uniquePercent.to_s
    
    limsScript = PathInfo::LIMS_API_DIR + "/setIlluminaLaneStatus.pl"

    limsUploadCmd = "perl " + limsScript + " " + @fcBarcode + 
                    " UNIQUE_PERCENT_FINISHED UNIQUE_PERCENT " + uniquePercent.to_s +
                    " PIPELINE_VERSION casava1.8"
    puts limsUploadCmd
    output = `#{limsUploadCmd}`
    puts "Output from LIMS upload command : " + output.to_s
  end

  # Method to handle error
  def handleError(errorMsg)
    $stderr.puts "Error encountered : " + errorMsg
    $stderr.puts "Current directory : " + Dir.pwd

    obj            = ErrorMessage.new()
    obj.fcBarcode  = @fcBarcode.to_s
    obj.workingDir = Dir.pwd
    obj.msgDetail  = errorMsg.to_s
    obj.msgBrief   = "Error while running SequenceAnalyzer for " + @fcBarcode.to_s
    ErrorHandler.handleError(obj)
    exit -1
  end
end

obj = SequenceAnalyzerWrapper.new()
