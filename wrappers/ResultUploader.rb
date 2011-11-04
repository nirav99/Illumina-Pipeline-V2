#!/usr/bin/ruby
$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'rubygems'
require 'hpricot'
require 'fileutils'
require 'PipelineHelper'
require 'ErrorHandler'
require 'BWAParams'
require 'PathInfo'

# Class to upload the result metrics generated by CASAVA after sequences are
# generated. Run this from the same directory where sequence files and BWA
# config parameter file are present.
# Author: Nirav Shah niravs@bcm.edu

# Enumeration like to describe read type
class ReadType
  READ1 = 1
  READ2 = 2
end

# Lane barcode result for specified read type
class LaneResult

  # Class constructor
  def initialize(fcBarcode, readType, isPaired, resultStage, demuxBustardSummaryXML, demuxStatsHTM)
    @fcBarcode = fcBarcode
    @readType  = readType 
    @isPaired  = isPaired
    @resultStage = resultStage # One of two values, SEQUENCE_FINISHED or ANALYSIS_FINISHED

    initializeDefaultParameters()

    # If the upload stage is "SEQUENCE_FINISHED", upload CASAVA generated
    # metrics. If the upload stage is "ANALYSIS_FINISHED", upload alignment
    # metrics and reference path
    if @resultStage.eql?("SEQUENCE_FINISHED")
      parseDemuxBustardSummary(demuxBustardSummaryXML)
      getYieldAndClusterInfo(demuxStatsHTM)
    else
      getReferencePath()
      getAlignAndErrorPercent()
    end
  end

  # Method to get the result string for LIMS upload
  def getLIMSUploadString()
    if @resultStage.eql?("SEQUENCE_FINISHED")
      result = @fcBarcode + " SEQUENCE_FINISHED " +  
               " READ " + @readType.to_s + " PERCENT_PHASING " + @phasing.to_s + 
               " PERCENT_PREPHASING " + @prePhasing.to_s + 
               " PERCENT_PF_READS " + @percentPFReads.to_s +
               " FIRST_CYCLE_INT_PF " + @firstCycleInt.to_s + 
               " PERCENT_INTENSITY_AFTER_20_CYCLES_PF " + @percentIntAfter20.to_s +
               " PIPELINE_VERSION casava1.8"

      if @readType.to_s.eql?("1")
        result = result + " LANE_YIELD_MBASES " + @yield.to_s + " RAW_READS " +
                 @numRawReads.to_s + " PF_READS	" + @numPFReads.to_s +
                 " PERCENT_PERFECT_INDEX " + @percentPerfectIndex.to_s + 
                 " PERCENT_1MISMATCH_INDEX " + @percent1MismatchIndex.to_s +
                 " PERCENT_Q30_BASES " + @percentQ30Bases.to_s +
                 " MEAN_QUAL_SCORE " + @meanQualScore.to_s
      end
    else
      result = @fcBarcode + " ANALYSIS_FINISHED READ " + @readType.to_s +
               " PERCENT_ALIGN_PF " + @percentAligned.to_s + 
               " PERCENT_ERROR_RATE_PF " + @percentError.to_s +
               " REFERENCE_PATH " + @referencePath +
               " RESULTS_PATH " + FileUtils.pwd  +
               " PIPELINE_VERSION casava1.8"

    end
    return result
  end

  private

  # Put default values for results to upload to LIMS
  def initializeDefaultParameters()
    @phasing               = 0
    @prePhasing            = 0
    @yield                 = 0
    @percentPFReads        = 0 # Percentage of purity filtered reads
    @numRawReads           = 0 # Number of raw reads
    @numPFReads            = 0 # Number of purity filtered reads
    @referencePath         = ""
    @percentAligned        = 0
    @percentError          = 100
    @firstCycleInt         = 0 # First cycle intensity
    @percentIntAfter20     = 0 # Percent intensity after 20 cycles
    @percentPerfectIndex   = 0 # Percent of index reads matching perfectly
    @percent1MismatchIndex = 0 # Percentage of index reads with 1 mismatch
    @percentQ30Bases       = 0 # Percentage of bases with Q30 or higher
    @meanQualScore         = 0 # Mean quality score
  end

  # Read DemultiplexedBustardSummary.xml file and obtain values of phasing,
  # prephasing, first cycle intensity and percent intensity after 20 cycles.
  def parseDemuxBustardSummary(demuxBustardSummaryXML)
    laneNumber = @fcBarcode.slice(/-\d/)
    laneNumber.gsub!(/^-/, "")

    xmlDoc = Hpricot::XML(open(demuxBustardSummaryXML))

    (xmlDoc/:'ExpandedLaneSummary Read').each do |read|
      readNumber = (read/'readNumber').inner_html

      if readNumber.to_s.eql?(@readType.to_s)

        (read/'Lane').each do |lane|
          laneNum = (lane/'laneNumber').inner_html
 
          if laneNum.to_s.eql?(laneNumber.to_s)

            tmp = (lane/'phasingApplied').inner_html
            !isEmptyOrNull(tmp) ? @phasing = tmp : @phasing = 0
            tmp = (lane/'prephasingApplied').inner_html
            !isEmptyOrNull(tmp) ? @prePhasing = tmp : @prePhasing = 0
          end
        end
      end
    end

    (xmlDoc/:'LaneResultsSummary Read').each do |read|
      readNumber = (read/'readNumber').inner_html

      if readNumber.to_s.eql?(@readType.to_s)

         (read/'Lane').each do |lane|
           laneNum = (lane/'laneNumber').inner_html

           if laneNum.to_s.eql?(laneNumber.to_s)

             tmp = (lane/'oneSig/mean').inner_html
             !isEmptyOrNull(tmp) ? @firstCycleInt = tmp : @firstCycleInt = 0 
             tmp = (lane/'signal20AsPctOf1/mean').inner_html
             !isEmptyOrNull(tmp) ? @percentIntAfter20 = tmp : @percentIntAfter20 = 0
           end
         end
      end
    end
  end


  # Read Demultiplex_Stats.htm file and get values of yield, percent PF clusters
  # , raw clusters, percentage of reads with no mismatch, one mismatch, mean
  # qual score and percentage of Q30 bases.
  def getYieldAndClusterInfo(demuxStatsHTM)
    doc = open(demuxStatsHTM) { |f| Hpricot(f) }
    rows = (doc/"/html/body/div[@ID='ScrollableTableBodyDiv']/table/tr")

    if rows == nil || rows.length == 0
      rows = (doc/"/html/body/div[@id='ScrollableTableBodyDiv']/table/tr")
    end

    rows.each do |row|
      dataElements = (row/"td")

      if dataElements[1].inner_html.eql?(@fcBarcode)
        @yield = dataElements[7].inner_html.gsub(",", "")
        @percentPFReads = dataElements[8].inner_html
        @numRawReads    = dataElements[9].inner_html.gsub(/,/, "")
        @numPFReads = (@numRawReads.to_f / 100.0) * @percentPFReads.to_f 
        @percentPFReads        = dataElements[8].inner_html
        @percentPerfectIndex   = dataElements[11].inner_html
        @percent1MismatchIndex = dataElements[12].inner_html
        @percentQ30Bases       = dataElements[13].inner_html
        @meanQualScore         = dataElements[14].inner_html
      end
    end
  end

  # Helper method to get the reference path from BWA config file
  def getReferencePath()
    inputParams = BWAParams.new()
    inputParams.loadFromFile()
    @referencePath  = inputParams.getReferencePath()

    if isEmptyOrNull(@referencePath)
      @referencePath = "none"
    end
  end

  # Helper method to get alignment percentage and error rate
  def getAlignAndErrorPercent()
    alignmentResultFile = "BAMAnalysisInfo.xml"

    if !File::exist?(alignmentResultFile)
      raise "Error: Did not find " + alignmentResultFile
    end

    xmlDoc = Hpricot::XML(open(alignmentResultFile))

    xmlDoc.search("AnalysisMetrics/AlignmentResults").each do |alnRes|
      readType = alnRes['ReadType']

      if readType.eql?("READ" + @readType)
        readInfoElem = alnRes.search("ReadInfo")

        if readInfoElem != nil
          @percentAligned = readInfoElem[0]['PercentMapped']
          @percentError   = readInfoElem[0]['PercentMismatch']
        end
      end
    end
  end

  # Private helper method to check if the string is null / empty
  def isEmptyOrNull(value)
    if value == nil || value.eql?("")
      return true
    else
      return false
    end
  end
end

# Class to upload the result string to LIMS
class ResultUploader
  # Class constructor, the parameter is a complete flowcell name (i.e. directory
  # name)
  def initialize(uploadStage)
    begin
      @uploadStage = uploadStage
      defaultInitializer()
      getFCBarcode()

      if uploadStage.eql?("SEQUENCE_FINISHED")
        getResultFileNames()
      end
      isPairedEnd()
    rescue Exception => e
      $stderr.puts "Exception occurred : " + e.message
      puts e.backtrace.inspect
      handleError(e.message)
    end
  end

  # Method to upload the results to LIMS
  def uploadResult()
    cmdPrefix  = "perl " + PathInfo::LIMS_API_DIR + "/setIlluminaLaneStatus.pl"

    laneResult = LaneResult.new(@fcBarcode, "1", @pairedEnd, @uploadStage,
                                @demuxBustardSummaryXML, @demuxStatsHTM) 

    uploadCmd  = cmdPrefix + " " + laneResult.getLIMSUploadString()
    executeUploadCmd(uploadCmd)

    if @pairedEnd == true
      laneResult = LaneResult.new(@fcBarcode, "2", @pairedEnd, @uploadStage,
                                  @demuxBustardSummaryXML, @demuxStatsHTM)
      uploadCmd  = cmdPrefix + " " + laneResult.getLIMSUploadString()
      executeUploadCmd(uploadCmd)
    end
  end

  private
  
  # Default constructor
  def defaultInitializer()
    @fcBarcode              = nil
    @demuxBustardSummaryXML = nil
    @demuxStatsHTM          = nil
    @pairedEnd              = false
  end
    
  # Obtain flowcell barcode for the current sequence event
  def getFCBarcode()
    inputParams = BWAParams.new()
    inputParams.loadFromFile()
    @fcBarcode  = inputParams.getFCBarcode() # FCName-Lane-BarcodeName

    if @fcBarcode == nil || @fcBarcode.empty?()
      raise "FCBarcode cannot be null or empty"
    end
  end  

  # Get names of files containing CASAVA result data
  def getResultFileNames()
    resultDir               = File.dirname(File.dirname(File.expand_path(Dir.pwd)))
    @demuxBustardSummaryXML = resultDir + "/DemultiplexedBustardSummary.xml"

    baseCallsStatsDir       = Dir[resultDir + "/Basecall_Stats_*"]
    @demuxStatsHTM          = baseCallsStatsDir[0] + "/Demultiplex_Stats.htm"

    if !File::exist?(@demuxBustardSummaryXML)
      raise "File " + @demuxBustardSummaryXML + " does not exist or is unreadable"
    end

    if !File::exist?(@demuxStatsHTM)
      raise "File " + @demuxStatsHTM + " does not exist or is unreadable"
    end
    
  end

  # Check if a flowcell is paired-end or fragment
  def isPairedEnd()
    sequenceFiles = Dir["*_sequence.txt*"]
    
    if sequenceFiles.size < 2
      @pairedEnd = false
    else
      @pairedEnd = true
    end
  end

  # Upload the results to LIMS and check for errors
  def executeUploadCmd(cmd)
    puts "Executing command : " + cmd
    output = `#{cmd}`
    exitStatus = $?
    output.downcase!

    puts "OUTPUT FROM LIMS : "
    puts output

    if output.match(/error/)
      puts "ERROR IN UPLOADING ANALYSIS RESULTS TO LIMS"
      puts "Error Message From LIMS : " + output
      handleError("Error in upload sequence metrics to LIMS for " + @fcBarcode) 
    elsif output.match(/success/)
      puts "Successfully uploaded to LIMS"
    end
  end

  # Handle error and abort.
  def handleError(msg)
    obj            = ErrorMessage.new()
    obj.msgDetail  = "LIMS upload error. Error message : " + msg.to_s
    obj.msgBrief   = "LIMS upload error for : " + @fcBarcode.to_s
    obj.fcBarcode  = @fcBarcode.to_s
    obj.workingDir = Dir.pwd
    ErrorHandler.handleError(obj)
    exit -1
  end
end

uploadStage = ARGV[0]

if uploadStage.upcase.eql?("SEQUENCE_FINISHED")
  obj = ResultUploader.new("SEQUENCE_FINISHED")
else
  obj = ResultUploader.new("ANALYSIS_FINISHED")
end

obj.uploadResult()
