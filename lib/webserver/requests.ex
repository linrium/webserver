defmodule Webserver.Requests.KVRequest do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:key, :string)
    field(:value, :string)
  end

  def changeset(params) do
    %__MODULE__{}
    |> cast(params, [:key, :value])
    |> validate_required([:key, :value])
    |> validate_length(:key, min: 1)
  end
end
