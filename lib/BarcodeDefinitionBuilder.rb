#!/usr/bin/ruby

$:.unshift File.dirname(__FILE__)

require 'PathInfo'

# Class to create a mapping between the barcode tag IDs and the actual barcode
# sequences. 
# Author Nirav Shah niravs@bcm.edu

class  BarcodeDefinitionBuilder
  def initialize()
  end

  # Write a list of barcode names and the sequences in the specified output
  # directory, (usually the basecalls directory of the given flowcell).
  # This is to allow different sets of sequences to be written for different
  # flowcells to let mix and match of barcodes with different lengths. 
  # Shorter sequences are padded with additional characters to make all the
  # sequence lengths consistent.
  def self.writeBarcodeMapFile(outputDirectory, barcodeTagList)
    # To check if barcodes of different lengths are mixed
    minSeqLength = 10000000
    maxSeqLength = 0
    padding      = ""

    barcodeTagMap = Hash.new

    # Look for pattern match on string ID to determine that a lane has barcode.
    # For non-multiplexed flowcells, this check will fail, resulting in nothing
    # being written to the barcode definition file
    barcodeTagList.each do |barcodeTagName|
      if barcodeTagName.match(/ID/)
         bTag = barcodeTagName.gsub(/^\d-/, "")
         barcodeTagMap[bTag] = nil
      end
    end

    if barcodeTagMap.empty?()
      puts "Provided list does not have barcodes. Not writing barcode definition file."
      return
    end

    outputFileName = getBarcodeDefinitionFileName(outputDirectory)
    outputFile = File.open(outputFileName, "w")

    barcodeLabelFile = PathInfo::CONFIG_DIR + "/barcode_label.txt"

    lines = IO.readlines(barcodeLabelFile)

    lines.each do |line|
      tokens = line.split(",")
      barcodeLabel = tokens[0].strip
      barcodeSeq   = tokens[1].strip
      if barcodeTagMap.has_key?(barcodeLabel)
         barcodeTagMap[barcodeLabel] = barcodeSeq

         if barcodeSeq.length.to_i < minSeqLength.to_i
            minSeqLength = barcodeSeq.length
         end

         if barcodeSeq.length.to_i > maxSeqLength.to_i
            maxSeqLength = barcodeSeq.length
         end
      end
    end

    if (maxSeqLength - minSeqLength) == 3
       padding = "CTC"
    end

    # Write all the tag name, sequence pairs to the output file
    barcodeTagMap.each do |key, value|
      result = key.strip + "," + value.strip
      if value.length == minSeqLength
         result = result + padding
      end 
      outputFile.puts result
    end
    outputFile.close
  end

  # Given a valid barcode tag, return the sequence for this barcode
  # Read the barcode definition from the config file specified in the output
  # directory (usually the basecalls directory) of the current flowcell.
  def self.findBarcodeSequence(outputDirectory, barcodeTag)
    barcode = ""
    if barcodeTag == nil || barcodeTag.empty?()
      return ""
    end

    barcodeLabelFile = getBarcodeDefinitionFileName(outputDirectory)

    if !File.exist?(barcodeLabelFile)
      puts "Barcode definition file does not exist in dir : " + outputDirectory
      return nil
    end

    lines = IO.readlines(barcodeLabelFile)

    lines.each do |line|
      tokens = line.split(",")
      if tokens[0].strip.eql?(barcodeTag)
         barcode = tokens[1].strip
      end
    end

    if barcode.empty?()
      raise "Invalid barcode tag specified"
    else
      return barcode
    end
  end

  private
  # Return the filename where the barcode tag, sequence mapping information
  # should be stored.
  def self.getBarcodeDefinitionFileName(outputDirectory)
    outputFileName = outputDirectory + "/barcode_definition.txt"
    return outputFileName.to_s
  end
end
