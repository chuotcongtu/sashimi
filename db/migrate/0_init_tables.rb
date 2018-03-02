=begin
METRICS API

The SASHIMI API represents a RESTful implementation of SUSHI automation intended to returns COUNTER Research Data Release 1 reports 

OpenAPI spec version: 1.0.0
Contact: support@datacite.org
Generated by: https://github.com/swagger-api/swagger-codegen.git

=end

class InitTables < ActiveRecord::Migration[5.0]
  def change
    create_table "error_model".pluralize.to_sym, id: false do |t|
      t.integer :code
      t.string :severity
      t.string :message
      t.string :help_url
      t.string :cata

      t.timestamps
    end

    create_table "publisher".pluralize.to_sym, id: false do |t|
      t.string :publisher_name
      t.string :publisher_id
      t.string :path

      t.timestamps
    end

    create_table "report".pluralize.to_sym, id: false do |t|
      t.string :id
      t.string :report_name
      t.string :report_id
      t.string :release
      t.string :created
      t.string :created_by
      t.string :report_datasets
      t.string :exceptions

      t.timestamps
    end

    create_table "report_types".pluralize.to_sym, id: false do |t|
      t.string :report_id
      t.string :release
      t.string :report_description
      t.string :path

      t.timestamps
    end

    create_table "status".pluralize.to_sym, id: false do |t|
      t.string :description
      t.boolean :service_active
      t.string :registry_url
      t.string :note
      t.string :alerts

      t.timestamps
    end

    create_table "status_alerts".pluralize.to_sym, id: false do |t|
      t.string :date_time
      t.string :alert

      t.timestamps
    end

  end
end