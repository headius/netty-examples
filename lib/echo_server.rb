require 'java'
begin
  require 'jar/netty-3.2.2.Final'
rescue LoadError
  require 'fileutils'
  FileUtils.mkdir_p 'jar'
  system "wget -O jar/netty-3.2.2.Final.jar http://repository.jboss.org/nexus/content/groups/public-jboss/org/jboss/netty/netty/3.2.2.Final/netty-3.2.2.Final.jar"
  require 'jar/netty-3.2.2.Final'
end

class EchoServer
  java_import java.net.InetSocketAddress
  java_import java.util.concurrent.Executors
  java_import org.jboss.netty.bootstrap.ServerBootstrap
  java_import org.jboss.netty.channel.ChannelPipelineFactory
  java_import org.jboss.netty.channel.Channels
  java_import org.jboss.netty.channel.SimpleChannelUpstreamHandler
  java_import org.jboss.netty.channel.socket.nio.NioServerSocketChannelFactory
  
  def initialize(port)
    channel_factory =
      NioServerSocketChannelFactory.new(
        Executors.newCachedThreadPool,
        Executors.newCachedThreadPool)
        
    @bootstrap = ServerBootstrap.new(channel_factory)
    @bootstrap.set_pipeline_factory {Channels.pipeline EchoServerHandler.new}
    @bootstrap.bind InetSocketAddress.new port
    puts "Server ready on port #{port}"
  end

  class EchoServerHandler < SimpleChannelUpstreamHandler
    def messageReceived(context,e)
      e.channel.write(e.message)
    end
  end
end

if __FILE__ == $0
  EchoServer.new 8080
end