#!/usr/bin/ruby

$:.unshift File.dirname(__FILE__)

require 'yaml'
require 'PathInfo'

# Module to read config file and load the name of LIMS database
# Author: Nirav Shah niravs@bcm.edu

module LimsInfo
  yamlConfigFile = PathInfo::CONFIG_DIR + "/config_params.yml" 
  configReader   = YAML.load_file(yamlConfigFile)
  LIMS_DB_NAME   = configReader["lims"]["databaseName"]
end
