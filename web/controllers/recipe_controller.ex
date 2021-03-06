defmodule GroceryGnome.RecipeController do
  use GroceryGnome.Web, :controller

		plug GroceryGnome.Plug.Authenticate

		alias GroceryGnome.Recipe
		alias GroceryGnome.Ingredient
		alias GroceryGnome.Foodcatalog
		alias GroceryGnome.Meal
		import Ecto.Query

  plug :scrub_params, "recipe" when action in [:create, :update]

  def index(conn, _params) do
		userid = conn.assigns.current_user.id
		query = from p in Recipe, where: p.user_id == ^userid
    recipes = Repo.all(query)
    render(conn, "index.html", recipes: recipes)
  end

  def recipebook(conn, _params) do
    render(conn, "recipebook.html")
  end

  def new(conn, _params) do
    changeset = Recipe.changeset(%Recipe{})
		query = from f in Foodcatalog
		foodcatalogs = Repo.all(query)
		ingmap = %{}
    render(conn, "new.html", changeset: changeset, foodcatalogs: foodcatalogs, ingmap: ingmap)
  end

  def create(conn, %{"recipe" => recipe_params}) do
    changeset = Recipe.changeset(%Recipe{}, %{recipe_title: recipe_params["recipe_title"], instructions: recipe_params["instructions"], prep_time: recipe_params["prep_time"], cook_time: 0, serving_size: recipe_params["serving_size"], user_id: conn.assigns.current_user.id})
		
    case Repo.insert(changeset) do
      {:ok, _recipe} ->
				# Since change was inserted into the database ok
				recipe_id = _recipe.id
				# Removing keywords from parameter map
				ingredient_params = recipe_params
				ingredient_params = Map.delete(ingredient_params,"recipe_title")
				ingredient_params = Map.delete(ingredient_params,"serving_size")
				ingredient_params = Map.delete(ingredient_params,"instructions")
				ingredient_params = Map.delete(ingredient_params,"prep_time")
				ingredient_params = Map.delete(ingredient_params,"user_id")
				ingredient_params = Map.delete(ingredient_params,"cook_time")
				# Iterate through the rest of the params and create ingredients from them
				#for {key,value} <- ingredient_params do
				#			ingredient_changeset = Ingredient.changeset(%Ingredient{}, %{ foodcatalog_id: key, ingredientquantity: value, recipe_id: recipe_id})
				#			Repo.insert(ingredient_changeset)
				#end
				#createloop(String.to_integer(ingredient_params["rowcount"]),ingredient_params)
				count = Map.get(ingredient_params, "rowcount")
				case count do
					string ->
						createloop(String.to_integer(string),recipe_id,ingredient_params)
				end
				#createloop(String.to_integer(count),recipe_id,ingredient_params)
        conn
        |> put_flash(:info, "Recipe created successfully. #{count}")
        |> redirect(to: recipe_path(conn, :index))
      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

	def createloop(i, recipe_id, map) do
		if i > 0 do
			namestring = "name" <> Integer.to_string(i)
			name = Map.get(map,namestring)
			result = Repo.get_by(Foodcatalog, foodname: name)
			case result do
				nil ->
				s2 = "bah"
				foodcatalog ->
					quantitystring = "quantity" <> Integer.to_string(i)
					quantity = String.to_integer(Map.get(map,quantitystring))
					ingredient_changeset = Ingredient.changeset(%Ingredient{}, %{ foodcatalog_id: foodcatalog.id, ingredientquantity: quantity, recipe_id: recipe_id})
					Repo.insert(ingredient_changeset)
			end
			createloop((i-1),recipe_id,map)
		end
	end

	
  def show(conn, %{"id" => id}) do
    recipe = Repo.get!(Recipe, id)
		query = from i in Ingredient, where: i.recipe_id == ^id, preload: [:foodcatalog]
    ingredients = Repo.all(query)
    render(conn, "show.html", recipe: recipe, ingredients: ingredients)
  end

  def edit(conn, %{"id" => id}) do
    recipe = Repo.get!(Recipe, id)
    changeset = Recipe.changeset(recipe)
    render(conn, "edit.html", recipe: recipe, changeset: changeset)
  end

  def update(conn, %{"id" => id, "recipe" => recipe_params}) do
    recipe = Repo.get!(Recipe, id)
    changeset = Recipe.changeset(recipe, recipe_params)

    case Repo.update(changeset) do
      {:ok, recipe} ->
        conn
        |> put_flash(:info, "Recipe updated successfully.")
        |> redirect(to: recipe_path(conn, :show, recipe))
      {:error, changeset} ->
        render(conn, "edit.html", recipe: recipe, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    recipe = Repo.get!(Recipe, id)

    # Here we use delete! (with a bang) because we expect
    # it to always work (and if it does not, it will raise).
    Repo.delete!(recipe)

    conn
    |> put_flash(:info, "Recipe deleted successfully.")
    |> redirect(to: recipe_path(conn, :index))
  end


	def deleterecipe(conn, delete_param) do
		id = delete_param["recipe"]
    recipe = Repo.get!(Recipe, id)

		# query all known tables that have this foodcatalog's id and delete them
		query = from i in Ingredient, where: i.recipe_id == ^id
		ingredients = Repo.all(query)

		for ingredient <- ingredients do
			Repo.delete!(ingredient)
		end

		mealquery = from m in Meal, where: m.recipe_id == ^id
		meals = Repo.all(mealquery)

		for meal <- meals do
			Repo.delete!(meal)
		end
		
    # Here we use delete! (with a bang) because we expect
    # it to always work (and if it does not, it will raise).
    Repo.delete!(recipe)

    conn
    |> put_flash(:info, "Recipe deleted successfully.")
    |> redirect(to: recipe_path(conn, :index))
	end
	
	
				
end
