#!/usr/bin/ruby

# Module to hold all the relevant directory paths
# Author: Nirav Shah niravs@bcm.edu

module PathInfo
  myPath        = File.expand_path(__FILE__)
  rootDir       = File.dirname(File.dirname(myPath))
  BIN_DIR       = rootDir + "/bin"
  LIB_DIR       = rootDir + "/lib"
  JAVA_DIR      = rootDir + "/java"
  CONFIG_DIR    = rootDir + "/config"
  WRAPPER_DIR   = rootDir + "/wrappers"
  BLACK_BOX_DIR = rootDir + "/blackbox_wrappers"
  LIMS_API_DIR  = rootDir + "/lims_api"
end
