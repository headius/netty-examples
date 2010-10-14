import java.net.InetSocketAddress
import java.util.concurrent.Executors
import org.jboss.netty.bootstrap.ServerBootstrap
import org.jboss.netty.channel.ChannelPipelineFactory
import org.jboss.netty.channel.ChannelHandler
import org.jboss.netty.channel.Channels
import org.jboss.netty.channel.SimpleChannelUpstreamHandler
import org.jboss.netty.channel.socket.nio.NioServerSocketChannelFactory
import org.jboss.netty.channel.MessageEvent

class EchoServerHandler < SimpleChannelUpstreamHandler
  def messageReceived(ctx, e)
    e.getChannel.write(e.getMessage)
  end
end

# Had to use a real class here because the closure didn't seem to infer right
class EchoPipelineFactory
  implements ChannelPipelineFactory
  def getPipeline	
    # no varargs support yet in Mirah :(
    ary = ChannelHandler[1]
    ary[0] = EchoServerHandler.new
    Channels.pipeline(ary)
  end
end

class EchoServer
  def initialize(port: fixnum)
    channel_factory = NioServerSocketChannelFactory.new(Executors.newCachedThreadPool, Executors.newCachedThreadPool)
        
    @bootstrap = ServerBootstrap.new(channel_factory)
    @bootstrap.setPipelineFactory EchoPipelineFactory.new
    @bootstrap.bind InetSocketAddress.new port
    puts "Server ready on port #{port}"
  end
end

EchoServer.new(8080)