defmodule GroceryGnome.Foodcatalog do
  use GroceryGnome.Web, :model

  schema "foodcatalogs" do
    field :foodname, :string
    field :info, :string
    field :unit, :string

    timestamps
  end

  @required_fields ~w(foodname info unit)
  @optional_fields ~w()

  @doc """
  Creates a changeset based on the `model` and `params`.

  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
		|> unique_constraint(:foodname, name: :foodcatalog_index, on: GroceryGnome.Repo)
  end
end
