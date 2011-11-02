#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'PipelineHelper'
require 'BWAParams'
require 'AnalysisInfo'
require 'Scheduler'
require 'PathInfo'
require 'SchedulerInfo'
require 'ErrorHandler'

# Class to start the analysis for a specific lane barcode of a given flowcell
# Author: Nirav Shah niravs@bcm.edu

class LaneAnalyzer
  def initialize(cmdParams)
    initializeDefaultParams()
    parseCommandString(cmdParams)
  end

  def startAnalysis()
    locateAnalysisDirectory()
    obtainAnalysisInfo()
    writeAlignerConfigParams()
    buildFastqFiles()
  end

  private
  def initializeDefaultParams()
    @fcName       = nil      # Complete flowcell directory name
    @laneBarcode  = nil      # Lane barcode
    @fcBarcode    = nil      # Flowcell barcode name (limsFCName-LaneBarcode)
    @analysisDir  = nil      # Analysis directory path
    @analysisInfo = nil      # Object having analysis parameters
    @queueName    = SchedulerInfo::DEFAULT_QUEUE  # Scheduler queue
  end

  # Parse command line parameters
  def parseCommandString(cmdParams)
    cmdParams.each do |entry|
      line = entry.dup
      line.strip!
      if line.match(/fcname=/)
        @fcName = line.gsub(/fcname=/,"") 
      elsif line.match(/lanebarcode=/)
        @laneBarcode = line.gsub(/lanebarcode=/,"")
      elsif line.match(/queue=/)
        @queueName = line.gsub(/queue=/, "")
      end
    end
    
    if @fcName == nil || @laneBarcode == nil
      printUsage()
      exit -1
    elsif
      @fcBarcode = PipelineHelper.getFCBarcodeName(@fcName, @laneBarcode)
      puts "Sequencing Event Name : " + @fcBarcode.to_s
    end
  end

  # Print the usage information
  def printUsage()
    puts __FILE__ + " starts the analysis of the specified lane barcode"
    puts ""
    puts "Usage:"
    puts ""
    puts "ruby " + __FILE__ + " fcname=value lanebarcode=value queue=value"
    puts ""
    puts "fcname      - Full flowcell name"
    puts "lanebarcode - Lane barcode, format : Lane-BarcodeName"
    puts "              e.g. 1-ID01"
    puts "queue       - Scheduler queue. Optional."
  end

  # Method to find the directory where the Fastq files for the given sequencing
  # event are present
  def locateAnalysisDirectory()
    rootLevelResultDir = PipelineHelper.getResultDir(@fcName)
    @analysisDir       = rootLevelResultDir + "/Project_" + @fcName +
                         "/Sample_" + @fcBarcode

    if !File::exist?(@analysisDir) || !File::directory?(@analysisDir) ||
       !File::readable?(@analysisDir) || !File::writable?(@analysisDir)
       msg = "Analysis directory : " + @analysisDir + " does not exist or " +
             " has incorrect permissions"
       @analysisDir = nil
       raise msg
    end
  end

  # Read the flowcell definition file and obtain the required set of parameters
  # to pass to the downstream processes.
  def obtainAnalysisInfo()
    baseCallsDir    = PipelineHelper.findBaseCallsDir(@fcName)
    fcDefinitionXML = baseCallsDir + "/FCDefinition.xml"

    if !File::exist?(fcDefinitionXML)
      raise "Did not find FCDefinition.xml in directory : " + baseCallsDir
    end

    # Read various parameter values from FCDefinition.xml and set the
    # corresponding fields in configParams

    @analysisInfo = AnalysisInfo.new(fcDefinitionXML, @laneBarcode)
  end

  # Helper method to write the configuration file required by subsequent
  # processes in the pipeline
  def writeAlignerConfigParams()
    puts "Writing config parameters in analysis directory : " + @analysisDir 

    configParams = BWAParams.new
    configParams.setschedulingQ(@queueName)
    configParams.setPhixFilter(false)
    configParams.setRGPUField(getPUField())
    configParams.setFCBarcode(@fcBarcode)
    configParams.setReferencePath(@analysisInfo.getReferencePath())
    configParams.setChipDesignName(@analysisInfo.getChipDesign())
    configParams.setSampleName(@analysisInfo.getSampleName())
    configParams.setLibraryName(@analysisInfo.getLibraryName())

    # Set the basecalls quality format to phred+33 (Sanger)
    configParams.setBaseQualFormat("PHRED+33")

    # Write the object to the file
    configParams.toFile(@analysisDir)
  end

  # Method to consume the Illumina generated fastq.gz files and generate two
  # sequence files, one for each read that are purify filtered.
  def buildFastqFiles()
    puts "Creating sequence files for : " + @fcBarcode.to_s
    puts "Sequence type : " + @analysisInfo.getFlowcellType()

    cmd = "ruby " + PathInfo::LIB_DIR + "/FastqBuilder.rb " + 
          @analysisInfo.getFlowcellType() + " " + @fcBarcode
   
    puts cmd
    FileUtils.cd(@analysisDir)

    scheduler = Scheduler.new(@fcBarcode + "_BuildSequences", cmd)
    scheduler.setMemory(16000)
    scheduler.setNodeCores(2)
    scheduler.setPriority(@queue)

    scheduler.runCommand()
    fastqJobName = scheduler.getJobName()
    puts "Job Name : " + fastqJobName.to_s

    postSequenceCommand(fastqJobName)
  end

  # Method to start the alignment after sequence files are created.
  def postSequenceCommand(parentJobName)
    cmd = "ruby " + PathInfo::WRAPPER_DIR + "/PostSequenceCommands.rb"
    puts "Post Sequence Command"
    puts cmd.to_s

    scheduler = Scheduler.new(@fcBarcode + "_post_sequence", cmd)
    scheduler.setMemory(8000)
    scheduler.setNodeCores(1)
    scheduler.setPriority(@queue)
    scheduler.setDependency(parentJobName)

    scheduler.runCommand()

    postSeqJobName = scheduler.getJobName()
    puts "Job Name : " + postSeqJobName.to_s
  end
  
  # Method to obtain the PU (Platform Unit) field for the RG tag in BAMs. The
  # format is machine-name_yyyymmdd_FC_Barcode
  def getPUField()
     puField    = nil
     runDate    = "20" + @fcName.slice(/^\d+/)
     machName   = @fcName.gsub(/^\d+_/,"").slice(/[A-Za-z0-9-]+/).gsub(/SN/, "700")
     puField    = machName.to_s + "_" + runDate.to_s + "_" + 
                  @fcBarcode.to_s 
     return puField.to_s
  end

  # Invoke error handler to get the error handled suitably
  def handleError(msg)
    obj            = ErrorMessage.new()
    obj.msgDetail  = msg
    obj.msgBrief   = "Error in starting analysis for " + @fcBarcode.to_s
    obj.workingDir = Dir.pwd
    obj.fcBarcode  = @fcBarcode.to_s
    ErrorHandler.handleError(obj)
    exit -1
  end
end

cmdParams = ARGV
obj = LaneAnalyzer.new(cmdParams)
obj.startAnalysis()
