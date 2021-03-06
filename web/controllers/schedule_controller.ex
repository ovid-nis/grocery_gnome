defmodule GroceryGnome.ScheduleController do
	use GroceryGnome.Web, :controller

	plug GroceryGnome.Plug.Authenticate
	alias GroceryGnome.Day
	alias GroceryGnome.Recipe
	alias GroceryGnome.Groceryitem
	alias GroceryGnome.Pantryitem
	alias GroceryGnome.Foodcatalog
	alias GroceryGnome.Ingredient
	alias GroceryGnome.Meal

	def index(conn, _params) do
		userid = conn.assigns.current_user.id
		days = Repo.all from d in Day, where: d.user_id == ^userid,
    join: m in assoc(d, :meals),
    join: r in assoc(m, :recipe),
    preload: [meals: {m, recipe: r}]
		#days = Repo.all(Day)
		for d <- days do
			IO.inspect d
		end
		render(conn, "index.html", days: days)
	end

	def create(conn, %{"date" => d}) do
		selection = conn.params["form_data"]
		userid = conn.assigns.current_user.id
		changeset = %Day{
			date: d,
			user_id: userid
		}
		case Repo.insert(changeset) do
			{:ok, day} ->
				for {type, mls} <- [{0, selection["breakfast"]}, {1, selection["lunch"]}, {2, selection["dinner"]}] do
					m = Repo.get_by(Recipe, id: mls)
					meal = Meal.changeset(%Meal{}, %{
								meal_type: type,
								recipe_id: m.id,
								day_id: day.id,
																		 })
					Repo.insert(meal)
				end
				conn
				|> put_flash(:info, "Created plan")
				|> redirect(to: schedule_path(conn, :index))
			{:error, changeset} ->
				conn
				|> put_flash(:error, "Error occured")
				|> redirect(to: schedule_path(conn, :index))
		end
	end
				
		# changeset = %Day{
		# 	breakfast: [selection["breakfast"]],
		# 	lunch: [selection["lunch"]],
		# 	dinner: [selection["dinner"]],
		# 	date: d,
		# 	user_id: userid}
		# IO.inspect changeset
		# case Repo.insert(changeset) do
		# 	{:ok, _day} ->
		# 		conn
		# 		|> put_flash(:info, "Created plan")
		# 		|> redirect(to: schedule_path(conn, :index))
		# 	{:error, changeset} ->
		# 		IO.inspect changeset
		# 		conn
		# 		|> put_flash(:error, "Error occured")
		# 		|> redirect(to: schedule_path(conn, :index))
		# end
	# 	redirect(conn, to: schedule_path(conn, :index))
	# end

	def generate(conn, _params) do
		date = conn.params["form_data"]["date"]
		userid = conn.assigns.current_user.id
		{:ok, meals} = GroceryGnome.Spoonacular.caloried_meal_plan 2000, "day"
		[breakfast, lunch, dinner] = meals["meals"]
		IO.inspect date
		d = ~s/#{date["year"]}-#{date["month"]}-#{date["day"]}/
		changeset = Day.changeset(%Day{}, %{
					breakfast: [breakfast["id"]],
					lunch: [lunch["id"]],
					dinner: [dinner["id"]],
					date: d,
					user_id: userid})
		case Repo.insert(changeset) do
			{:ok, _day} ->
				conn
				|> put_flash(:info, "Generated plan")
				|> redirect(to: schedule_path(conn, :index))
			{:error, changeset} ->
				IO.inspect changeset
				conn
				|> put_flash(:error, "Error occured")
				|> redirect(to: schedule_path(conn, :index))
		end
	end

	def generatetodatabase(conn, _params) do
		date = conn.params["form_data"]["date"]
		userid = conn.assigns.current_user.id
		{:ok, meals} = GroceryGnome.Spoonacular.caloried_meal_plan 2000, "day"
		[breakfast, lunch, dinner] = meals["meals"]
		IO.inspect date
		date = ~s/#{date["year"]}-#{date["month"]}-#{date["day"]}/

		changeset = Day.changeset(%Day{}, %{
					date: date,
					user_id: userid})
		
		case Repo.insert(changeset) do
			{:ok, day} ->
				for {type, mls} <- [{0, breakfast}, {1, lunch}, {2, dinner}] do
					{:ok, m} = GroceryGnome.Spoonacular.recipe_information mls["id"], false
					recipe_add(userid,m)
					n = Repo.get_by(Recipe, recipe_title: m["title"])
					meal = Meal.changeset(%Meal{}, %{
								meal_type: type,
								recipe_id: n.id,
								day_id: day.id,
																		 })
					Repo.insert(meal)
				end
				conn
				|> put_flash(:info, "Generated plan")
				|> redirect(to: schedule_path(conn, :index))
			{:error, changeset} ->
				IO.inspect changeset
				conn
				|> put_flash(:error, "Error occured")
				|> redirect(to: schedule_path(conn, :index))
		end
	end


	def recipe_add(userid, recipe) do
		#	{:ok, recipe} = GroceryGnome.Spoonacular.recipe_information id, false
		#	IO.inspect recipe

		# create the recipe
    changeset = Recipe.changeset(%Recipe{}, %{recipe_title: recipe["title"], instructions: "Filler", prep_time: recipe["readyInMinutes"], cook_time: recipe["readyInMinutes"],serving_size: recipe["servings"], user_id: userid})

    case Repo.insert(changeset) do
      {:ok, _recipe} ->
				# Since change was inserted into the database ok
				recipe_id = _recipe.id
				# Removing keywords from parameter map
				for ingredient <- recipe["extendedIngredients"] do
					result = Repo.get_by(Foodcatalog, foodname: ingredient["name"])
					case result do
						nil ->
							foodcatalogchangeset = Foodcatalog.changeset(%Foodcatalog{}, %{foodname: ingredient["name"], unit: ingredient["unit"], info: ingredient["aisle"]})
							case Repo.insert(foodcatalogchangeset) do
								{:ok, _foodcatalog} ->
									ingredient_changeset = Ingredient.changeset(%Ingredient{}, %{ foodcatalog_id: _foodcatalog.id, ingredientquantity: ingredient["amount"], recipe_id: recipe_id})
									Repo.insert(ingredient_changeset)
							end
						foodcatalog ->
							ingredient_changeset = Ingredient.changeset(%Ingredient{}, %{ foodcatalog_id: foodcatalog.id, ingredientquantity: ingredient["amount"], recipe_id: recipe_id})
							Repo.insert(ingredient_changeset)
					end
				end
		end
	end
	

	def delete(conn, %{"id" => id}) do
		day = Repo.get!(Day, id)

		query = from m in Meal, where: m.day_id == ^id
		meals = Repo.all(query)
		for meal <- meals do
			Repo.delete(meal)
		end

		
		Repo.delete!(day)

		conn
		|> put_flash(:info, "Deleted day")
		|> redirect(to: schedule_path(conn, :index))
	end

	def new(conn, _params) do
		IO.inspect conn
		changeset = Day.changeset(%Day{})
		render(conn, "new.html", changeset: changeset)
	end

	def new_day(conn, _params) do
		date = conn.params["form_data"]["date"]
		# IO.inspect Ecto.Date. date
		date_string = "#{date["year"]}-#{date["month"]}-#{date["day"]}"
		userid = conn.assigns.current_user.id
		query = from p in Recipe, where: p.user_id == ^userid
		recipes = Repo.all(query)

		items = for item <- recipes, into: [] do
			{item.recipe_title, item.id}
		end
		
		render(conn, "new_day_form.html", date: date_string, recipes: items)
	end

	def isensured(conn) do
		userid  = conn.assigns.current_user.id
		days = Repo.all from d in Day, where: d.user_id == ^userid,
           join: m in assoc(d, :meals),
           join: r in assoc(m, :recipe),
           preload: [meals: {m, recipe: r}]
		imap = %{}
		ingredientmap = map_days(days,imap)
		is_list_ensured(Map.to_list(ingredientmap),true,userid)
	end

	def is_list_ensured(ingredientlist,bool,userid) do
		case bool do
			false ->
				false
			true ->
				result = List.first(ingredientlist)
				case result do
					nil ->
						true
					{key,value} ->
						foodcatalog = Repo.get_by(Foodcatalog, foodname: key)
						additiontostock = get_pantryquantity(foodcatalog.id,userid) + get_groceryquantity(foodcatalog.id,userid) - value
						if additiontostock < 0 do
							is_list_ensured(List.delete(ingredientlist,result),false,userid)
						else
							is_list_ensured(List.delete(ingredientlist,result),true,userid)
						end
				end
		end
	end
		

	def ensure_schedule(conn, _params) do
		userid = conn.assigns.current_user.id
		days = Repo.all from d in Day, where: d.user_id == ^userid,
           join: m in assoc(d, :meals),
           join: r in assoc(m, :recipe),
           preload: [meals: {m, recipe: r}]
		imap = %{}
		ingredientmap = map_days(days,imap)
		for {key,value} <- ingredientmap do
			foodcatalog = Repo.get_by(Foodcatalog, foodname: key)
			stock = get_pantryquantity(foodcatalog.id,userid) + get_groceryquantity(foodcatalog.id,userid) - value
			if stock < 0 do
				truevalue = (-1 * stock)
				result = Repo.get_by(Groceryitem, foodcatalog_id: foodcatalog.id, user_id: userid)
				case result do
					nil ->
						changeset = Groceryitem.changeset(%Groceryitem{}, %{groceryquantity: truevalue, foodcatalog_id: foodcatalog.id , user_id: userid})
						Repo.insert(changeset)
					groceryitem ->
						changeset = Groceryitem.changeset(groceryitem,  %{id: groceryitem.id, groceryquantity: groceryitem.groceryquantity + truevalue, foodcatalog_id: foodcatalog.id , user_id: userid})
						Repo.update(changeset)
				end
			end
		end
		index(conn,_params)
	end

	def get_pantryquantity(foodcatalogid,userid) do
			result = Repo.get_by(Pantryitem, foodcatalog_id: foodcatalogid, user_id: userid)
			case result do
				nil ->
					0
				pantryitem ->
					pantryitem.pantryquantity
			end
	end

	def get_groceryquantity(foodcatalogid,userid) do
			result = Repo.get_by(Groceryitem, foodcatalog_id: foodcatalogid, user_id: userid)
			case result do
				nil ->
					0
				groceryitem ->
					groceryitem.groceryquantity
			end
	end
	
	def map_days(daylist, imap) do
	result = List.first(daylist)
	case result do
		nil ->
			imap
		day ->
			newimap = map_meals(day.meals,imap)
			newlist = List.delete(daylist,day)
			map_days(newlist,newimap)	
	end
	end

	def map_meals(meallist, imap) do
		result = List.first(meallist)
		case result do
			nil ->
				imap
			meal ->
				newlist = List.delete(meallist,meal)
				recipeid = meal.recipe_id
				recipe = Repo.get!(Recipe, recipeid)
				query = from i in Ingredient, where: i.recipe_id == ^recipeid, preload: [:foodcatalog]
				ingredients = Repo.all(query)
				newmap = map_ingredients(ingredients,imap)
				map_meals(newlist,newmap)
		end
	end

	def map_ingredients(ilist, imap) do
		result = List.first(ilist)
		case result do
			nil ->
				imap
			ingredient ->
				newlist = List.delete(ilist,ingredient)
				name = ingredient.foodcatalog.foodname
				mappedname = Map.get(imap,name)
				case mappedname do
					nil ->
						newmap = Map.put(imap,name,ingredient.ingredientquantity)
						map_ingredients(newlist,newmap)
					namevalue ->
						newmap = Map.put(imap,name, namevalue + ingredient.ingredientquantity)
						map_ingredients(newlist,newmap)
				end
		end
	end



end
