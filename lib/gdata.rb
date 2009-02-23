$:.unshift(File.expand_path(File.dirname(__FILE__))) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

module GData #:nodoc:
   require 'net/https'
   require 'cgi'

   class Connection
      attr_reader  :http_connection

      # Establishes SSL connection to Google host
      def initialize(host, port, proxy=nil, proxy_port=nil, proxy_user=nil, proxy_passwd=nil)
         conn = Net::HTTP.new(host, port, proxy, proxy_port, proxy_user, proxy_passwd)
         conn.use_ssl = true
         conn.verify_mode = OpenSSL::SSL::VERIFY_PEER
         conn.verify_mode = OpenSSL::SSL::VERIFY_NONE
         store = OpenSSL::X509::Store.new
         store.set_default_paths
         conn.cert_store = store
         conn.start
         @http_connection = conn
      end

      # Performs the http request and returns the http response
      def perform(method, path, body=nil, header=nil)
         req = Net::HTTPGenericRequest.new(method, !body.nil?, true, path)
         req['Content-Type'] = header['Content-Type'] if header['Content-Type']
         req['Authorization'] = header['Authorization'] if header['Authorization']
         req['Content-length'] = body.length.to_s if body
         resp = @http_connection.request(req, body)
         return resp
      end
   end

   class GDataError < RuntimeError
      attr_accessor :code, :input, :reason
   end
end
