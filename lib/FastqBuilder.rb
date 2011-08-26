#!/usr/bin/ruby

$:.unshift File.dirname(__FILE__)

require 'zlib'

# Class to build final fastq files for use with BWA. It removes reads that do
# not pass purity filter.
# Author: Nirav Shah niravs@bcm.edu

class FastqBuilder

  # Class constructor
  # mode      : Mode of operation - fragment or paired
  # namePrefix: Prefix applied to names of final filtered sequences
  def initialize(mode, namePrefix)
    initializeDefaultValues()
    @seqNameRead1 = namePrefix + "_1_sequence.txt"
        
    if mode.downcase.eql?("fragment")
      @mode = "fragment"
    else
      @seqNameRead2 = namePrefix + "_2_sequence.txt"
      @mode = "paired"
    end
  end

  # Write final sequence files
  def writeFinalSequenceFiles()
    findFastqFiles()
    writeFinalSequences()
    logStatistics($stdout)
    logFile = File.new("SequencePFMetrics.metrics", "w")
    logStatistics(logFile)
    logFile.close
  end

  private
  def initializeDefaultValues()
    @mode          = nil      # mode of operation
    @read1FileList = nil      # List of compressed fastq files for read1
    @read2FileList = nil      # List of compressed fastq files for read2 
    @seqNameRead1  = nil      # Name of final sequence file for read 1
    @seqNameRead2  = nil      # Name of final sequence file for read 2
    @currDir       = Dir.pwd
    @numReadsRead1 = 0        # Num. reads for read 1 in CASAVA generated
                              # fastq files
    @numReadsRead2 = 0        # Num. reads for read 2 in CASAVA generated
                              # fastq files
    @numFilteredRead1 = 0     # Num. reads in the final sequence file for read 1
    @numFilteredRead2 = 0     # Num. reads in the final sequence file for read 2

  end

  # Method to find all CASAVA generated fastq files and represent those file
  # names in two arrays sorted by their names
  def findFastqFiles()
    @read1FileList = Dir["*_R1_*.fastq.gz"]
    @read2FileList = Dir["*_R2_*.fastq.gz"]

    if @read1FileList == nil || @read1FileList.length < 1
      raise "Did not find any fastq files for read 1"
    else
      @read1FileList.sort! # Sort all the filenames by segment number
    end

    if @mode.eql?("paired") && (@read2FileList == nil || @read2FileList.length < 1) 
      raise "Did not find any fastq files for read 2 for paired-end mode"
    end

    if @read2FileList != nil && @read2FileList.length >= 1
      @read2FileList.sort! # Sort the read 2 fastq filenames by segment number
    end
  end

  # Public method to create sequences
  def writeFinalSequences()
    puts "Generating sequence file for read 1"
    startTime = Time.now
    writeSequence(1, @read1FileList, @seqNameRead1)  
    endTime   = Time.now

    puts "Execution Time : " + (endTime - startTime).to_s + " sec"

    if @read2FileList != nil && @read2FileList.length >= 1
      puts "Generating sequence file for read 2"
      startTime = Time.now
      writeSequence(2, @read2FileList, @seqNameRead2)
      endTime   = Time.now
      puts "Execution Time : " + (endTime - startTime).to_s + " sec"
    end
  end

  # Helper method for writing sequence for specified read
  def writeSequence(readType, fileListToRead, outputFileToWrite)
    outFile = File.new(outputFileToWrite, "w")

    fileListToRead.each do |file|
      reader = Zlib::GzipReader.open(file)
      while(line = reader.gets)
        line.strip!

        if line.match(/^@/)
           if readType == 1
             @numReadsRead1 = @numReadsRead1 + 1
           else
             @numReadsRead2 = @numReadsRead2 + 1
           end

           # Read next 3 lines to complete reading 1 Fastq record
           readString = reader.gets.strip
           qualHeader = reader.gets.strip
           qualString = reader.gets.strip

           # Did this read pass quality filtering ? "N" means passed !
           if line.match(/\s\d:N:/)
             if readType == 1
               @numFilteredRead1 = @numFilteredRead1 + 1
             else
               @numFilteredRead2 = @numFilteredRead2 + 1
             end
             writeFastqRecordToFile(outFile, line, readString, qualHeader,
                                    qualString)
           end
        end
      end
      reader.close
    end
    outFile.close
  end

  # Helper method to write one fastq record to the specified file
  def writeFastqRecordToFile(outFile, readName, readString, qualName, qualString) 
    outFile.puts readName
    outFile.puts readString
    outFile.puts qualName
    outFile.puts qualString
  end

  # Log the results of filtering
  def logStatistics(dest)
    dest.puts "Read Type : Read 1"
    dest.puts "Total Reads                   : " + @numReadsRead1.to_s
    dest.puts "Total Filtered Reads          : " + @numFilteredRead1.to_s

    if @numReadsRead1 > 0
      percentPassed = @numFilteredRead1.to_f /  @numReadsRead1.to_f * 100.0
    else
      percentPassed = 0
    end
    dest.puts "Percent Reads Passed Filter   : " + percentPassed.to_s
    dest.puts ""

    if @numReadsRead2 > 0
      dest.puts "Read Type : Read 2"
      dest.puts "Total Reads                 : " + @numReadsRead2.to_s
      dest.puts "Total Filtered Reads        : " + @numFilteredRead2.to_s
      percentPassed = @numFilteredRead2.to_f /  @numReadsRead2.to_f * 100.0
      dest.puts "Percent Reads Passed Filter : " + percentPassed.to_s
      dest.puts ""
    end
  end
end

obj = FastqBuilder.new(ARGV[0], ARGV[1])
obj.writeFinalSequenceFiles()
