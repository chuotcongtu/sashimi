class ConvertJob < ActiveJob::Base
  queue_as :sashimi

  def perform(id, options={})
    logger = Logger.new(STDOUT)

    subset = ReportSubset.where(id: id).first
    full_report = ActiveSupport::Gzip.decompress(subset.compressed)
    parsed = JSON.parse(full_report)

    # recursively convert all hash keys to use dash
    converted_report = convert_hash_keys(parsed)

    compressed_report = ActiveSupport::Gzip.compress(converted_report.to_json)
    subset.update_columns(compressed: compressed_report)
    message = "[ConvertJob] Subset #{id} of Usage Report #{subset.report.uid} successfully converted."
    logger.info message
    true
  rescue StandardError => exception
    Raven.capture_exception(exception)
    message = "[ConvertJobError] Subset #{id} of Usage Report #{subset.report.uid} could not be converted. #{exception.message}."
    logger.error message
    false
  end

  def convert_hash_keys(value)
    case value
      when Array
        value.map { |v| convert_hash_keys(v) }
      when Hash
        Hash[value.map { |k, v| [k.dasherize, convert_hash_keys(v)] }]
      else
        value
     end
  end
end
