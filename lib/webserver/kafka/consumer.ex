defmodule Webserver.Kafka.Consumer do
  use Broadway

  require Logger

  def start_link(_opts) do
    config = Application.get_env(:webserver, :kafka)

    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module:
          {BroadwayKafka.Producer,
           [
             hosts: config[:brokers],
             group_id: config[:group_id],
             topics: config[:topics]
           ]},
        concurrency: 1
      ],
      processors: [
        default: [
          concurrency: 10
        ]
      ]
    )
  end

  @impl true
  def handle_message(_, message, _) do
    Logger.info("Received Kafka message: #{inspect(message.data)}")
    message
  end
end
