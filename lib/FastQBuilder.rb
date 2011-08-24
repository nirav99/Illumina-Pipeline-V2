#!/usr/bin/ruby

$:.unshift File.dirname(__FILE__)

require 'zlib'
require 'Scheduler'
require 'EmailHelper'
require 'PipelineHelper'

# Class to build final fastq files for use with BWA. It removes reads that do
# not pass purity filter.
# Author: Nirav Shah niravs@bcm.edu

class FastQBuilder

  # Class constructor
  # dirPath: The directory where to look up bclToFastQ convertor files and
  #          generate final sequence files.
  # mode:    Mode of operation - fragment or paired end
  # namePrefix: Prefix applied to names of final filtered sequences
  def initialize(dirPath, mode, namePrefix)
    initializeDefaultValues()
    @executionDir = dirPath.to_s
    @seqNameRead1 = namePrefix + "_1_sequence.txt"
        
    if mode.downcase.eql?("fragment")
      @mode = "fragment"
    else
      @seqNameRead2 = namePrefix + "_2_sequence.txt"
      @mode = "paired"
    end
  end

  private
  def initializeDefaultValues()
    @mode          = nil      # mode of operation
    @read1FileList = nil      # List of compressed fastq files for read1
    @read2FileList = nil      # List of compressed fastq files for read2 
    @executionDir  = nil      # Where to run
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

  def writeFinalSequenceFiles()
    if mode.eql?("paired")   
       writeFinalSequencesPE()
    else
       writeFinalSequenceFrag()
    end 
    showStatistics()
  end

  def writeFinalSequencesPE()
     outFile1 = File.new(@seqNameRead1, "w")
     outFile2 = File.new(@seqNameRead2, "w")

     idx = 0

     while(idx < @seqNameRead1.length)
       reader1 = Zlib::GzipReader.open(@seqNameRead1[idx])
       reader2 = Zlib::GzipReader.open(@seqNameRead2[idx])

       while((line1 = reader1.gets) && (line2 = reader2.gets))
         line1.strip!
         line2.strip!

         if line1.match(/^@/) && line2.match(/^@/)
           @numReadsRead1 = @numReadsRead1 + 1
           readStringRead1 = reader1.gets.strip
           qualHeaderRead1 = reader1.gets.strip
           qualStringRead1 = reader1.gets.strip

           @numReadsRead2 = @numReadsRead2 + 1
           readStringRead2 = reader2.gets.strip
           qualHeaderRead2 = reader2.gets.strip
           qualStringRead2 = reader2.gets.strip

           if line1.match(/\s\d:N:/) && line2.match(/\s\d:N:/)
             @numFilteredRead1 = @numFilteredRead1 + 1
             @numFilteredRead2 = @numFilteredRead2 + 1

             writeFastqRecordToFile(outFile1, line1, readStringRead1,
                                    qualHeaderRead1, qualStringRead1) 
             writeFastqRecordToFile(outFile2, line2, readStringRead2,
                                    qualHeaderRead2, qualStringRead2) 
           end
         end
       end
       reader1.close
       reader2.close
     end
  end

  # Write one final sequence if running in the fragment mode
  def writeFinalSequenceFrag()
    outFile = File.new(@seqNameRead1, "w")

    @read1FileList.each do |file|
      reader = Zlib::GzipReader.open(file)
      while(line = reader.gets)
        line.strip!

        if line.match(/^@/)
          @numReadsRead1 = @numReadsRead1 + 1

          # Read next 3 lines to complete reading 1 Fastq record
          readString = reader.gets.strip
          qualHeader = reader.gets.strip
          qualString = reader.gets.strip

          if line.match(/\s\d:N:/)
            @numFilteredRead1 = @numFilteredRead1 + 1
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

  # Show the results of filtering
  def showStatistics()
    puts "Read Type : Read 1"
    puts "Total Reads                   : " + @numReadsRead1.to_s
    puts "Total Filtered Reads          : " + @numFilteredRead1.to_s
    percentagePassed = @numFilteredRead1.to_f /  @numReadsRead1.to_f * 100.0
    puts "Percent Reads Passed Filter   : " + percentagePassed.to_s
    puts ""

    if @numReadsRead2 > 0
      puts "Read Type : Read 2"
      puts "Total Reads                 : " + @numReadsRead2.to_s
      puts "Total Filtered Reads        : " + @numFilteredRead2.to_s
      percentagePassed = @numFilteredRead2.to_f /  @numReadsRead2.to_f * 100.0
      puts "Percent Reads Passed Filter : " + percentagePassed.to_s
      puts ""
    end
  end
end
