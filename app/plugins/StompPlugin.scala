package plugins

import org.fusesource.stomp.jms.{StompJmsConnectionFactory, StompJmsDestination}
import javax.jms.{DeliveryMode, Session}
import play.api.{Application, Play, Plugin}


trait MessageQueueConfiguration {
  private val QueuePrefix = "message_queue"
    
  val BrokerUri = configValue("broker_uri")
  val Username = configValue("username")
  val Password = configValue("password")
  val QueueName = configValue("queue_name")
  
  private def configValue(key: String): String =
    Play.current.configuration.getString(s"$QueuePrefix.$key")
    .getOrElse(throw new Exception(s"Unable to read message_queue configuration for $key"))
}

trait MessageQueueConnection {
  def send(messageText: String): Unit
  def close: Unit
}

class StompJmsMessageQueueConnection extends MessageQueueConnection with MessageQueueConfiguration {
  private val factory = new StompJmsConnectionFactory()
  factory.setBrokerURI(BrokerUri)
  private val connection = factory.createConnection(Username, Password)

  private val session = connection.createSession(false, Session.CLIENT_ACKNOWLEDGE)
  private val destination = new StompJmsDestination(QueueName)
  private val producer = session.createProducer(destination)
  producer.setDeliveryMode(DeliveryMode.NON_PERSISTENT)

  
  override def send(messageText: String): Unit = {
    val message = session.createTextMessage(messageText)
    producer.send(message)
  }
  
  override def close: Unit = session.close
  
}

class MockMessageQueueConnection extends MessageQueueConnection {
  override def send(messageText: String): Unit = {}
  override def close: Unit = {}
}

class StompPlugin(application: Application) extends Plugin {
  lazy val queueConnection: MessageQueueConnection = 
    if (useMock) new MockMessageQueueConnection
    else new StompJmsMessageQueueConnection
  
  override def onStart(): Unit = queueConnection
  
  override def onStop(): Unit = queueConnection.close
  
  private def useMock: Boolean = Play.current.configuration.getBoolean("message_queue.mock").getOrElse(false)
}