#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

# Script to perform cleanup after alignment is complete.
# Author: Nirav Shah niravs@bcm.edu
class PostAlignmentProcess
  def initialize()
    uploadResultsToLIMS()
    emailAnalysisResults()
    cleanIntermediateFiles()
    zipSequenceFiles()
  end

  private
  
  # Method to upload the alignment results to LIMS
  def uploadResultsToLIMS()
    uploadCmd = "ruby " + File.dirname(File.expand_path(__FILE__)) +
            "/ResultUploader.rb ANALYSIS_FINISHED"
    output    = `#{uploadCmd}`
    puts output
  end

  # Method to email analysis results
  def emailAnalysisResults()
    cmd = "ruby " + File.dirname(File.expand_path(File.dirname(__FILE__))) +
          "/lib/ResultMailer.rb" 
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
  end

  # Zip the final sequence files to save disk space. Potential improvement: The
  # intermediate .gz fastq files created by CASAVA can also be deleted in this
  # step.
  def zipSequenceFiles()
    puts "Zipping sequence files"
    zipCmd = "bzip2 *sequence.txt"
    `#{zipCmd}`
  end
end

obj = PostAlignmentProcess.new()
