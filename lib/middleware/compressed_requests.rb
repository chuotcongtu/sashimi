require 'yajl'
require 'json'

class CompressedRequests
  def initialize(app)
    @app = app
  end

  def method_handled?(env)
    !!(env['REQUEST_METHOD'] =~ /(POST|PUT)/)
  end

  def encoding_handled?(env)
    ['gzip', 'deflate'].include? env['HTTP_CONTENT_ENCODING']
  end

  def call(env)
    request = Rack::Request.new(env)
    if method_handled?(env) && encoding_handled?(env)
      extracted = decode(env['rack.input'], env['HTTP_CONTENT_ENCODING'])

      hsh = Rails.env.test? ?  Yajl::Parser.parse(extracted) : Yajl::Parser.parse(eval(extracted))

      puts "This is PARSED"

      request.update_param('report_header', hsh.fetch("report-header",{}).deep_transform_keys { |key| key.tr('-', '_') } )
      puts "This is header"

      request.update_param('compressed', env['rack.input'])
      puts "This is body"

      request.update_param('encoding', env['HTTP_CONTENT_ENCODING'])

      env.delete('HTTP_CONTENT_ENCODING')
      env['CONTENT_LENGTH'] = extracted.length
      env['rack.input'] = StringIO.new(extracted)
    end


    status, headers, response = @app.call(env)
    return [status, headers, response]
  end

  def decode(input, content_encoding)
    puts "This is middleware"
    case content_encoding
      when 'gzip' then Zlib::GzipReader.new(input).read
      when 'deflate' then Zlib::Inflate.inflate(input.read)
    end
  end
end