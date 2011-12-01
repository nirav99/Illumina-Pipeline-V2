#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'PathInfo'

# Script to perform cleanup after alignment is complete.
# Author: Nirav Shah niravs@bcm.edu
class PostAlignmentProcess
  def initialize()
    uploadResultsToLIMS()
    emailAnalysisResults()
    cleanIntermediateFiles()
    runSNPCaller()
    zipSequenceFiles()
  end

  private
  
  # Method to upload the alignment results to LIMS
  def uploadResultsToLIMS()
    uploadCmd = "ruby " + PathInfo::WRAPPER_DIR + 
                "/ResultUploader.rb ANALYSIS_FINISHED"
    output    = `#{uploadCmd}`
    puts output
  end

  # Method to email analysis results
  def emailAnalysisResults()
    cmd = "ruby " + PathInfo::LIB_DIR + "/ResultMailer.rb" 
    output = `#{cmd}`
    puts output
  end
 
  # Delete the intermediate files created during the alignment process
  def cleanIntermediateFiles()
   puts "Deleting intermediate files"
   deleteTempFilesCmd = "rm *.sam *.sai"
   `#{deleteTempFilesCmd}`

   # Be careful here, delete only _sorted.bam
   puts "Deleting intermediate BAM file"
   deleteTempBAMFileCmd = "rm *_sorted.bam"
  `#{deleteTempBAMFileCmd}`

   makeDirCmd = "mkdir casava_fastq"
   `#{makeDirCmd}`
   moveCmd = "mv *.fastq.gz ./casava_fastq"
   `#{moveCmd}`
  end

  # Zip the final sequence files to save disk space. Potential improvement: The
  # intermediate .gz fastq files created by CASAVA can also be deleted in this
  # step.
  def zipSequenceFiles()
    puts "Zipping sequence files"
    zipCmd = "bzip2 *sequence.txt"
    `#{zipCmd}`
  end

  def runSNPCaller()
    bamFile = Dir["*_marked.bam"]
    if bamFile != nil && bamFile.length > 0
       snpCallCmd = "ruby /stornext/snfs6/1000GENOMES/challis/geyser_Atlas2_wrapper/Atlas2Submit.rb " +
                     File.expand_path(bamFile[0])
       `#{snpCallCmd}`
    end
  end
end

obj = PostAlignmentProcess.new()
