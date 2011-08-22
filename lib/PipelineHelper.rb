#!/usr/bin/ruby
require 'rubygems'
require 'hpricot'
require 'fileutils'

# This class encapsulates common routines required by other 
# pipeline scripts
# Author: Nirav Shah niravs@bcm.edu
class PipelineHelper

  # Method to take a complete fc name and return the portion used for
  # interacting with LIMS
  def self.formatFlowcellNameForLIMS(fcName)
    limsFCName = fcName.slice(/([a-zA-Z0-9]+)$/)

    if limsFCName.match(/^FC/)
      limsFCName.gsub!(/^FC/, "")
    end

    # For HiSeqs, a flowcell is prefixed with letter "A" or "B".
    # We remove this prefix from the reduced flowcell name, since
    # a flowcell name is entered without the prefix letter in LIMS.
    # For GA2, there is no change.
    limsFCName.slice!(/^[a-zA-Z]/)
    return limsFCName.to_s
  end

  # This helper method searches for flowcell in list of volumes and returns
  # the path of the flowcell including it's directory.
  # If it does not find the path for flowcell, it aborts with an exception
    def self.findFCPath(fcName)
      fcPath    = ""
      parentDir = Array.new

      # This represents location where to search for flowcell
      rootDir    = "/stornext/snfs0/next-gen/Illumina/Instruments"
      # To add additional locations, append to array rootDir

      dirEntries = Dir.entries(rootDir)

      # In the rootDir of the data copied over from the sequencers, find 
      # directories corresponding to each sequencer and populate the 
      # parentDir array
      dirEntries.each do |dirEntry|
        if !dirEntry.eql?(".") && !dirEntry.eql?("..") &&
           File::directory?(rootDir + "/" + dirEntry.to_s)
           parentDir << rootDir + "/" + dirEntry.to_s
        end
      end

      parentDir.each do |path|
        if File::exist?(path + "/" + fcName) &&
           File::directory?(path + "/" + fcName)
           fcPath = path + "/" + fcName
        end
      end

      if fcPath.eql?("")
        puts "Error : Did not find path for flowcell : " + fcName
        raise "Error in finding path for flowcell : " + fcName
      end
      return fcPath.to_s
    end

  # Helper method to locate the basecalls (bustard) directory for the
  # specified flowcell
  def self.findBaseCallsDir(fcName)
    fcPath = ""

    # This represents directory hierarchy where GERALD directory
    # gets created.
    baseCallsDirPaths = Array.new
    baseCallsDirPaths << "Data/Intensities/BaseCalls"
    
    fcPath = findFCPath(fcName)
    
    baseCallsDirPaths.each{ |bcPath|
      if File::exist?(fcPath + "/" + bcPath) &&
         File::directory?(fcPath + "/" + bcPath)
         return fcPath.to_s + "/" + bcPath.to_s
      end
    }
    raise "Did not find Base calls directory for flowcell : " + fcName
  end

  # Method to return the RTA version given the flowcell name. Current behavior
  # is to look in the file runParameters.xml in flowcell's main directory and
  # return the value of the node "RTAVersion". If this file does not exist,
  # check in Basecalling_Netcopy_complete.txt file. 
  # Otherwise, return nil
  def self.findRTAVersion(fcName)
    rtaVersion = nil
    fcPath = findFCPath(fcName) 
    fcConfigFile = fcPath + "/runParameters.xml"
   
    if File.exist?(fcConfigFile)
      xmlDoc     = Hpricot::XML(open(fcConfigFile))
      xmlElement = xmlDoc.at("RunParameters/Setup/RTAVersion")
  
      if xmlElement != nil
        return xmlElement.inner_html
      end
    else
      # If this flowcell was on a GAIIx, use the following file instead.
      fcConfigFile = fcPath + "/Basecalling_Netcopy_complete.txt"
      
      if File.exist?(fcConfigFile)
        lines = IO.readlines(fcConfigFile)

        lines.each do |line|
          if line.match(/Illumina\s+RTA/)
            return line.gsub(/Illumina\s+RTA\s+/, "")
          end
        end
      end
    end
    return nil
  end

  # Helper method that returns true if the specified flowcell is HiSeq.
  # False if GA2.
  def self.isFCHiSeq(fcName)
    # If the name of the flowcell contains the string "EAS034" or "EAS376
    # then it is GA2 flowcell, else it is HiSeq flowcell
    if !fcName.match("EAS034") && !fcName.match("EAS376")
      return true
    else
      return false
    end
  end
end
