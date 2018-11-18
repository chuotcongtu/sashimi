=begin
METRICS API

The SASHIMI API represents a RESTful implementation of SUSHI automation intended to returns COUNTER Research Data Release 1 reports

OpenAPI spec version: 1.0.0
Contact: support@datacite.org
Generated by: https://github.com/swagger-api/swagger-codegen.git

=end

require 'base32/url'
require 'digest'

class Report < ApplicationRecord

  # has_one_attached :report

  # include validation methods for sushi
  include Metadatable

  # include validation methods for sushi
  include Queueable 

  # attr_accessor :month, :year, :compressed
  validates_presence_of :report_id, :created_by, :client_id, :provider_id, :created, :reporting_period, :report_datasets
  validates :uid, uniqueness: true
  validates :validate_sushi, sushi: {presence: true}
  attr_readonly :created_by, :month, :year, :client_id

  # serialize :exceptions, Array
  before_validation :to_compress 
  before_validation :set_uid, on: :create
  after_validation :clean_datasets
  before_create :set_id
  after_commit :push_report

  def push_report
    logger.warn "calling queue for " + uid
    queue_report if ENV["AWS_REGION"].present?
  end

  def compress
    json_report = {
      "report-header": 
      {
        "report-name": self.report_name,
          "report-id": self.report_id,
          "release": "rds",
          "created": self.created,
          "created-by": self.created_by,
          "reporting-period": self.reporting_period,
          "report-filters": self.report_filters,
          "report-attributes": self.report_attributes,
          "exceptions": self.exceptions
        },
        "report-datasets": self.report_datasets
    }

    ActiveSupport::Gzip.compress(json_report.to_json)
  end
  
  def encode_compressed
    return nil if self.compressed.nil?
    Base64.strict_encode64(self.compressed)
  end

  def checksum
     Digest::SHA256.hexdigest(self.compressed)
  end

  private

  # random number that fits into MySQL bigint field (8 bytes)
  def set_id
    self.id = SecureRandom.random_number(9223372036854775807)
  end

  def to_compress
    write_attribute(:compressed, compress)
  end

  def clean_datasets
    puts "cleaning"

    return nil if self.exceptions.empty? 
    return nil if self.compressed.nil?
    code = self.exceptions.dig(0).fetch("code",nil)
    return nil if code != 69

    puts "chainging"

    write_attribute(:report_datasets, compressed_message)
  end

  def compressed_message
    {
      empty: "too large",
      checksum: checksum,
    }
  end



  def set_uid
    return ActionController::ParameterMissing if self.reporting_period.nil?
    self.uid = SecureRandom.uuid if uid.blank?
    self.report_id = self.uid 
    month = Date.strptime(self.reporting_period["begin_date"],"%Y-%m-%d").month.to_s 
    year = Date.strptime(self.reporting_period["begin_date"],"%Y-%m-%d").year.to_s 
    write_attribute(:month,  month ) 
    write_attribute(:year,  year) 
    to_compress
  end
end
