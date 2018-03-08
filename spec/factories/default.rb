FactoryBot.define do
  factory :report do
    sequence(:report_id) { |n| "dsr-12hd-zt#{n}" }
    client_id "datacite.datacite"
    provider_id "datacite"

    created_by "DataCite"
    report_datasets [{
      "yop": "2010",
      "platform": "DataONE",
      "data_type": "Dataset",
      "publisher": "DataONE",
      "dataset_id": [{
          "type": "DOI",
          "value": "0931-865"
      }]
    }]
  end
end
