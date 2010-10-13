require 'java'
begin
  require 'jar/netty-3.2.2.Final'
rescue LoadError
  require 'fileutils'
  FileUtils.mkdir_p 'jar'
  system "wget -O jar/netty-3.2.2.Final.jar http://repository.jboss.org/nexus/content/groups/public-jboss/org/jboss/netty/netty/3.2.2.Final/netty-3.2.2.Final.jar"
  require 'jar/netty-3.2.2.Final'
end

java_import java.net.InetSocketAddress;
java_import java.net.URI;
java_import java.util.concurrent.Executors;

java_import org.jboss.netty.bootstrap.ClientBootstrap;
java_import org.jboss.netty.channel.Channels;
java_import org.jboss.netty.channel.socket.nio.NioClientSocketChannelFactory;
java_import org.jboss.netty.handler.codec.http.DefaultHttpRequest;
java_import org.jboss.netty.handler.codec.http.HttpHeaders;
java_import org.jboss.netty.handler.codec.http.HttpMethod;
java_import org.jboss.netty.handler.codec.http.HttpVersion;
java_import org.jboss.netty.handler.codec.http.HttpClientCodec;
java_import org.jboss.netty.handler.codec.http.HttpContentDecompressor;
java_import org.jboss.netty.channel.SimpleChannelUpstreamHandler;
java_import org.jboss.netty.handler.codec.http.HttpChunk;
java_import org.jboss.netty.util.CharsetUtil;

class HttpClient
  def initialize
    # configure the client
    @bootstrap = ClientBootstrap.new(
      NioClientSocketChannelFactory.new(
        Executors.new_cached_thread_pool,
        Executors.new_cached_thread_pool))

    # set up the event pipeline factory
    @bootstrap.set_pipeline_factory do
      # Create a default pipeline implementation.
      pipeline = Channels.pipeline

      pipeline.add_last "codec", HttpClientCodec.new

      # Remove the following line if you don't want automatic content decompression.
      pipeline.add_last "inflater", HttpContentDecompressor.new

      # Uncomment the following line if you don't want to handle HttpChunks.
      #pipeline.add_last "aggregator", HttpChunkAggregator.new(1048576)

      pipeline.add_last "handler", HttpResponseHandler.new
    
      pipeline
    end
  end
  
  def shutdown
    # Shut down executor threads to exit.
    @bootstrap.release_external_resources
  end
    
  def fetch(url, shutdown = false)
    uri, scheme, host, port = parse_url(url)
    
    # Start the connection attempt.
    future = @bootstrap.connect InetSocketAddress.new(host, port)

    # Wait until the connection attempt succeeds or fails.
    channel = future.await_uninterruptibly.channel
    if !future.is_success
        future.cause.print_stack_trace
        bootstrap.release_external_resources
        return
    end

    request = prepare_request uri, host

    # Send the HTTP request.
    channel.write(request)

    # Wait for the server to close the connection.
    channel.close_future.await_uninterruptibly
    
    # shutdown if requested
    self.shutdown if shutdown
  end
  
  def parse_url(url)
    uri = URI.new url
    scheme = uri.scheme || "http"
    host = uri.host || "localhost"
    port = uri.port
    if port == -1
      if scheme =~ /^http$/i
        port = 80
      end
    end
    
    raise(ArgumentError, "Only HTTP is supported") if scheme !~ /^http$/
    
    return uri, scheme, host, port
  end
  
  def prepare_request(uri, host)
    # Prepare the HTTP request.
    request = DefaultHttpRequest.new(
            HttpVersion::HTTP_1_1, HttpMethod::GET, uri.to_asciistring)
    request.setHeader(HttpHeaders::Names::HOST, host)
    request.setHeader(HttpHeaders::Names::CONNECTION, HttpHeaders::Values::CLOSE)
    request.setHeader(HttpHeaders::Names::ACCEPT_ENCODING, HttpHeaders::Values::GZIP)
    
    request
  end
end

class HttpResponseHandler < SimpleChannelUpstreamHandler
  def initialize
    @readingChunks = false
  end

  def messageReceived(ctx, e)
    if !@readingChunks
      response = e.message

      puts "STATUS: #{response.status}"
      puts "VERSION: #{response.protocol_version}"
      puts

      if !response.header_names.empty?
        response.header_names.each do |name|
          response.headers(name).each do |value|
            puts "HEADER: #{name} = #{value}"
          end
        end
        puts
      end

      if response.status.code == 200 && response.chunked?
          @readingChunks = true;
          puts "CHUNKED_CONTENT {"
      else
        content = response.content
        if content.readable
          puts "CONTENT {"
          puts content.to_string(CharsetUtil::UTF_8)
          puts "} END OF CONTENT"
        end
      end
    else
      chunk = e.message
      if chunk.last?
        @readingChunks = false;
        puts "} END OF CHUNKED CONTENT"
      else
        puts chunk.content.to_string(CharsetUtil::UTF_8)
      end
    end
  end
end

if __FILE__ == $0
  client = HttpClient.new
  client.fetch(ARGV[0] || "http://google.com", true)
end