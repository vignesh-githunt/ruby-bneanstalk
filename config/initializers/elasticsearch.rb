Elasticsearch::Model.client = Elasticsearch::Client.new url: ENV['ELASTICSEARCH_URL'] || "http://localhost:9200"

# unless Prospect.__elasticsearch__.index_exists?
#  Prospect.__elasticsearch__.create_index! force: true
#  Prospect.import
# end
