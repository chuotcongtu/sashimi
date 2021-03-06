class ReportFullSubsetSerializer < ActiveModel::Serializer
  type 'report'

  attributes :id, :report_header, :report_datasets, :report_subsets, :exceptions

  def id
    object.report_id
  end

  def gzip
    object.gzip
  end

  def report_subsets
    [{gzip: object.gzip, checksum: object.checksum}]
  end

  def report_datasets
    []
  end
end
