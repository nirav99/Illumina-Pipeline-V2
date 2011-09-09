#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'Scheduler'
require 'BWAParams'
require 'yaml'

class Aligner
  # Constructor - prepare the context
  def initialize()
    begin
      readConfigParams()
      obtainPathAndResourceInfo()
      findSequenceFiles()
    rescue Exception => e
      $stderr.puts e.message
      $stderr.puts e.backtrace.inspect
      exit -1
    end
  end

  # Create cluster jobs to start the alignment
  def process()
    if @reference.eql?("sequence")
      puts "No alignment to perform since reference is \"sequence\""
      puts "Running postrun script"
      runPostRunCmd("")
      exit 0
    end

    # Previous job ID next job should depend on
    prevJobID = nil

    if @zippedSequences == true
      unzipCmd = buildUnzipCommand()
      objUnzip = Scheduler.new(@fcBarcode + "_unzip_sequences", unzipCmd1)
      objUnzip.setMemory(2000)
      objUnzip.setNodeCores(1)
      objUnzip.setPriority(@queueName)
      objUnzip.runCommand()
      prevJobID = objUnzip1.getJobName()

      # Remove the suffix .bz2 from the sequence file names to prevent any
      # errors downstream
      idx = 0
      while idx < @sequenceFiles.length
        @sequenceFiles[idx].gsub!(/\.bz2$/, "")
        idx = idx + 1
      end
    end

    # Run BWA aln command(s)

    saiFileRead1 = @sequenceFiles[0] + ".sai"

    bwaAlnRead1Cmd = buildAlignCommand(@sequenceFiles[0], saiFileRead1)
    objAlnRead1    = Scheduler.new(@fcBarcode + "_aln_read1", bwaAlnRead1Cmd)
    objAlnRead1.lockWholeNode(@queueName)

    if prevJobID != nil
      objAlnRead1.setDependency(prevJobID)
    end
    objAlnRead1.runCommand()
    bwaAlnRead1JobID = objAlnRead1.getJobName()

    if @isFragment == false
      saiFileRead2 = @sequenceFiles[1] + ".sai"

      bwaAlnRead2Cmd = buildAlignCommand(@sequenceFiles[1], saiFileRead2)
      objAlnRead2    = Scheduler.new(@fcBarcode + "_aln_read2", bwaAlnRead2Cmd)
      objAlnRead2.lockWholeNode(@queueName)

      if prevJobID != nil
        objAlnRead2.setDependency(prevJobID)
      end
      objAlnRead2.runCommand()
      bwaAlnRead2JobID = objAlnRead2.getJobName()

      bwaSampeCmd = buildSampeCommand(saiFileRead1, saiFileRead2)
      sampeObj    = Scheduler.new(@fcBarcode + "_bwa_sampe", bwaSampeCmd)
      sampeObj.setDependency(bwaAlnRead1JobID)
      sampeObj.setDependency(bwaAlnRead2JobID) 
      sampeObj.lockWholeNode(@queueName)
      sampeObj.runCommand()
      prevJobID   = sampeObj.getJobName()
    else
      bwaSamseCmd = buildSamseCommand(saiFileRead1)
      samseObj    = Scheduler.new(@fcBarcode + "_bwa_samse", bwaSamseCmd)
      samseObj.setDependency(bwaAlnRead1JobID)
      samseObj.lockWholeNode(@queueName)
      samseObj.runCommand()
      prevJobID   = samseObj.getJobName()
    end

    # At this stage, BWA would have finished generating a sam file. Process it
    # to make a bam.
    bamProcessCmd = buildBAMProcessingCmd()
    bamProcessObj = Scheduler.new(@fcBarcode + "_processBam", bamProcessCmd)
    bamProcessObj.lockWholeNode(@queueName)
    bamProcessObj.setDependency(prevJobID)
    bamProcessObj.runCommand()
    previousJobName = bamProcessObj.getJobName()
  
  end

  private
 
  # Read the configuration file containing input parameters
  def readConfigParams()
    inputParams = BWAParams.new()
    inputParams.loadFromFile()
    @reference      = inputParams.getReferencePath()  # Reference path
    @filterPhix     = inputParams.filterPhix?()       # Whether to filter phix reads
    @libraryName    = inputParams.getLibraryName()    # Obtain library name
    @chipDesign     = inputParams.getChipDesignName() # Chip design name for capture
                                                      # stats calculation
    @sampleName     = inputParams.getSampleName()     # Sample name
    @rgPUField      = inputParams.getRGPUField()      # PU field for RG tag

    @fcBarcode      = inputParams.getFCBarcode()       # Lane barcode FCName-Lane-BarcodeName
    @baseQualFormat = inputParams.getBaseQualFormat()  # Sanger or Illumina format
    @queueName      = inputParams.getSchedulingQueue() # Queue name on cluster

    # Validate the parameters
    if @reference == nil || @reference.empty?()
      raise "Reference path must be specified in config file"
    elsif @fcBarcode == nil || @fcBarcode.empty?()
      raise "Flowcell barcode must be specified in config file"
    elsif @queueName == nil || @queueName.empty?()
      @queueName = "normal"
    end

    # Create file names for subsequent stages
    @samFileName  = @fcBarcode + ".sam"
    @finalBamName = @fcBarcode + "_marked.bam"

    puts "SAM file name : " + @samFileName
    puts "BAM file name : " + @finalBamName
  end
 
  # Read the configuration yaml and obtain information about BWA path, java
  # directory, and the number of node cores for the queue specified. This method
  # must be called ONLY after readConfigParams
  def obtainPathAndResourceInfo()
    yamlConfigFile = File.dirname(File.expand_path(File.dirname(__FILE__))) +
                     "/config/config_params.yml" 

    configReader = YAML.load_file(yamlConfigFile)

    # Obtain resources to use on the cluster
    @maxMemory = configReader["scheduler"]["memory"]["maxMemory"]
    puts "Max memory : " + @maxMemory.to_s

    @maxNodeCores = configReader["scheduler"]["queue"][@queueName]["maxCores"]
    puts "Max cores per node : " + @maxNodeCores.to_s + " for queue " + @queueName

    # Obtain path information
    @bwaPath = configReader["bwa"]["path"]
    puts "BWA Path = " + @bwaPath
    
    @javaDir = File.dirname(File.expand_path(File.dirname(__FILE__))) + "/java" 
  end

  # Find the sequence files and determine if the sequence event is fragment or
  # paired-end
  def findSequenceFiles()
    fileList = Dir["*_sequence.txt"]

    if fileList == nil || fileList.size < 1
      fileList = Dir["*_sequence.txt.bz2"]
    end

    if fileList.size < 1
      raise "Could not find sequence files in directory " + Dir.pwd
    elsif fileList.size == 1
      @isFragment = true
    elsif fileList.size == 2
      @isFragment = false
    elsif fileList.size > 2
      raise "More than two sequence files detected in directory " + Dir.pwd
    end

    @sequenceFiles = fileList.sort

    puts "Found sequence files "
    @sequenceFiles.each do |seqFile|
      if seqFile.match(/\.bz2$/)
        @zippedSequences = true
      end
      puts seqFile.to_s
    end
  end

  # BWA aln command - number of threads equals maxNodeCores
  def buildAlignCommand(readFile, outputFile)
    cmd = @bwaPath + " aln -t " + @maxNodeCores.to_s 

    if @baseQualFormat.eql?("PHRED+64")
      cmd = cmd + " -I"
    end
    cmd = cmd + " " + @reference + " " + readFile + " > " + outputFile
    return cmd
  end

  # Build the bwa sampe command
  def buildSampeCommand(saiFileRead1, saiFileRead2)
    cmd = @bwaPath + " sampe -P " + " -r " + buildRGString() + " " + @reference +
          " " + saiFileRead1 + " " + saiFileRead2 + " " + @sequenceFiles[0] +
          " " + @sequenceFiles[1] + " > " + @samFileName.to_s
    return cmd
  end

  # Build the bwa samse command for fragment run
  def buildSamseCommand(saiFileRead1)
    cmd = @bwaPath + " samse -r " + buildRGString() + " " + @reference + " " +
          saiFileRead1 + " " + @sequenceFiles[0] + " > " + @samFileName.to_s
    return cmd
  end

  # Returns the value string for RG tag
  def buildRGString()
    currentTime = Time.new
    rgString = "'@RG\\tID:0\\tSM:"

    if @sampleName != nil && !@sampleName.empty?()
      rgString = rgString + @sampleName.to_s
    else
      rgString = rgString + @fcBarcode.to_s
    end

    if @libraryName != nil && !@libraryName.empty?()
      rgString = rgString + "\\tLB:" + @libraryName.to_s
    end

    # If PU field was already obtained from config params, use that. Use a
    # dummy PU field (fcbarcode) if it was not already available.
    if @rgPUField != nil && !@rgPUField.empty?()
       rgString = rgString + "\\tPU:" + @rgPUField.to_s
    else
       rgString = rgString + "\\tPU:" + @fcBarcode.to_s
    end

    rgString = rgString + "\\tCN:BCM\\tDT:" + currentTime.strftime("%Y-%m-%dT%H:%M:%S%z")
    rgString = rgString + "\\tPL:Illumina'"
#    rgString = rgString + "'"
    return rgString.to_s
  end

  # Build the command that converts SAM to BAM, sorts it, mark duplicates, fixes
  # reads and generates alignment statistics.
  def buildBAMProcessingCmd()
    scriptName = File.dirname(File.expand_path(File.dirname(__FILE__))) +
                 "/AlignerHelper.rb"
    cmd = "ruby " + scriptName + " " + @samFileName + " " + @finalBamName + " " +
          @fcBarcode.to_s + " " + @isFragment.to_s
    return cmd
  end

  # Command to run after alignment completes
  def runPostRunCmd(previousJobName)
    puts "TODO: write code for post run"
  end
end

obj = Aligner.new()
obj.process()
