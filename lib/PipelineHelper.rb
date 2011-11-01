#!/usr/bin/ruby

$:.unshift File.dirname(__FILE__)

require 'rubygems'
require 'hpricot'
require 'fileutils'
require 'yaml'
require 'PathInfo'

# This class encapsulates common routines required by other 
# pipeline scripts
# Author: Nirav Shah niravs@bcm.edu
class PipelineHelper

  # Method to take a complete fc name and return the portion used for
  # interacting with LIMS
  def self.formatFlowcellNameForLIMS(fcName)
    limsFCName = fcName.slice(/([a-zA-Z0-9-]+)$/)

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

  # Given a flowcell name and the lane or lane barcode name, return the flowcell
  # barcode name. This is the name by which this event would be represented in
  # LIMS.
  def self.getFCBarcodeName(fcName, laneBarcode)
    limsFCName = formatFlowcellNameForLIMS(fcName)
    fcBarcode  = limsFCName + "-" + laneBarcode.to_s
    return fcBarcode
  end

  # This helper method searches for flowcell in list of volumes and returns
  # the path of the flowcell including it's directory.
  # If it does not find the path for flowcell, it aborts with an exception
    def self.findFCPath(fcName)
      fcPath    = ""
      parentDir = Array.new

      # This represents location where to search for flowcell
      rootDir    = getInstrumentRootDir() 

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

  # Method to return the name of the top-level directory where results i.e.,
  # output of CASAVA is written
  def self.getResultDir(fcName)
    baseCallsDir = findBaseCallsDir(fcName)
    baseCallsDir.strip!
    outDir = baseCallsDir.gsub(/Data\/Intensities\/BaseCalls/, "Results")
    return outDir
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

  # Method to obtain the PU (Platform Unit) field for the RG tag in BAMs. The
  # format is machine-name_yyyymmdd_FC_Barcode
  def self.getPUField(fcName, laneBarcode)
     puField    = nil
     coreFCName = nil
     begin
       runDate    = "20" + fcName.slice(/^\d+/)
       machName   = fcName.gsub(/^\d+_/,"").slice(/[A-Za-z0-9-]+/).gsub(/SN/, "700")
       puts "Generating FCName for PU field"
       coreFCName = PipelineHelper.formatFlowcellNameForLIMS(@fcName) 
       puts "Core FC Name : "
       puts coreFCName.to_s
       puField    = machName.to_s + "_" + runDate.to_s + "_" + 
                    coreFCName.to_s + "-" + laneBarcode.to_s
     rescue
       puField = machName.to_s + "_" + runDate.to_s + "_" +
                 fcName.to_s + "_" + laneBarcode.to_s 
     end
     return puField.to_s
  end

  # Method to get the sorted list of sequence files from the specified result
  #  directory
  def self.findSequenceFiles(resultDir)
    fileList = Dir[resultDir + "/*_sequence.txt"]

    if fileList == nil || fileList.size < 1
      fileList = Dir[resultDir + "/*_sequence.txt.bz2"]
    end

    if fileList != nil && fileList.size > 0
      return fileList.sort
    end
  end

  # Method to find the root directory where the sequencers write their data
  def self.getInstrumentRootDir()
    configFile   = PathInfo::CONFIG_DIR + "/config_params.yml"
    configReader = YAML.load_file(configFile)
    rootDir      = configReader["sequencers"]["rootDir"]
    return rootDir
  end
end
