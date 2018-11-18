module Metadatable
  extend ActiveSupport::Concern

  require 'json-schema'
  require 'fileutils'
  require 'json' 

  included do

    def validate_sushi 
      puts "this is being validated"
      schema = load_schema
      report = self.attributes.except("compressed")
      report.transform_keys! { |key| key.tr('_', '-') }
   
      puts report["report-datasets"].class
      puts report["report-datasets"]
      # # size = (report["report-datasets"].length)
      # # sample =  (size/8) > 0 ? size : 1
      # # report["report-datasets"] = report["report-datasets"].sample(sample)
      JSON::Validator.fully_validate(schema, report.to_json, :errors_as_objects => true)
    end

    def validate_sample_sushi
      puts "this is being sampled validated"
      schema = load_schema
      report = self.attributes.except("compressed")
      report.transform_keys! { |key| key.tr('_', '-') }
      size = report["report-datasets"].length
      if (size/8) > 0  
        sample =  (size/8) > 100 ? 100 : size
      else
        sample = 1
      end
      report["report-datasets"] = report["report-datasets"].sample(sample)
      JSON::Validator.fully_validate(schema, report.to_json, :errors_as_objects => true)
    end

    def is_valid_sushi? 
      schema = load_schema
      # report = self.attributes.except("compressed").deep_transform_keys { |key| key.tr('_', '-') }
      report = self.attributes.except("compressed")
      report.transform_keys! { |key| key.tr('_', '-') }
      puts report
      JSON::Validator.validate(schema, report.to_json)
    end
  
    USAGE_SCHEMA_FILE = "lib/sushi_schema/sushi_usage_schema.json"
    RESOLUTION_SCHEMA_FILE = "lib/sushi_schema/sushi_resolution_schema.json"


    def load_schema
      report = self.attributes.except("compressed")
      report.transform_keys! { |key| key.tr('_', '-') }
      file = report.dig("report-name") == "resolution report" && report.dig("created-by") == "datacite" ? RESOLUTION_SCHEMA_FILE : USAGE_SCHEMA_FILE
      begin
        File.read(file)
      rescue
        puts 'must redo the settings file'
        {} # return an empty Hash object
      end
    end
  end
end
