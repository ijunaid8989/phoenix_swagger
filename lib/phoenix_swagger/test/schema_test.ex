defmodule PhoenixSwagger.SchemaTest do
  @moduledoc """
  Testing helper module that makes it convenient to assert that phoenix controller responses conform to a swagger spec.

  ## Example

      use YourApp.ConnCase
      use PhoenixSwagger.SchemaTest "priv/static/swagger.json"

      test "Get a user by ID", %{conn: conn, swagger_schema: schema} do
        user = Repo.insert! struct(User, @valid_attrs)
        response =
          conn
          |> get(user_path(conn, :show, user))
          |> validate_resp_schema(schema, "UserResponse")
          |> json_response(200)

        assert response["data"]["id"] == user.id
      end

  Errors will be output with the json-path of the location in the response body for the error:

      Response JSON does not conform to swagger schema from #/definitions/UserResponse.
      At #/data/email: Expected "foobaz" to be an email address.
      {
        "data": {
          "name": "Yu Ser",
          "id": 141,
          "email": "foobaz"
        }
      }
  """


  @doc """
  Given a swagger file path, defines an ExUnit `setup_all` block that will
  add the resolved swagger schema to the ExUnit context.
  """
  defmacro __using__(swagger_file) do
    quote do
      @swagger_file unquote(swagger_file)

      import PhoenixSwagger.SchemaTest, only: [validate_resp_schema: 3]

      setup_all _context do
        PhoenixSwagger.SchemaTest.read_swagger_schema(@swagger_file)
      end
    end
  end

  @doc false
  def read_swagger_schema(swagger_file) do
    schema =
      swagger_file
      |> File.read!()
      |> Poison.decode!()
      |> ExJsonSchema.Schema.resolve()

    [swagger_schema: schema]
  end

  @doc """
  Validates a response body against a swagger schema.

  ## Example

      use MyApp.ConnCase
      use PhoenixSwagger.SchemaTest "priv/static/swagger.json"

      test "get user by ID", %{conn: conn, swagger_schema: schema} do
        response =
          conn
          |> get(user_path(conn, :show, 123))
          |> validate_resp_schema(schema, "User")
          |> json_response(200)

        assert response["data"]["id"] == 123
      end
  """
  def validate_resp_schema(conn, swagger_schema, model_name) do
    response_data = conn.resp_body |> Poison.decode!
    schema = swagger_schema.schema["definitions"][model_name]
    errors_with_list_paths = ExJsonSchema.Validator.validate(swagger_schema, schema, response_data, ["#"])
    case errors_with_list_paths do
      [] -> conn
      errors ->
        headline = "Response JSON does not conform to swagger schema from #/definitions/#{model_name}."
        error_details =
          errors
          |> Enum.map(fn {msg, path} -> {msg, Enum.join(path, "/")} end)
          |> Enum.map(fn {msg, path} -> "At #{path}: #{msg}" end)
          |> Enum.join("\n")

        response_pretty = Poison.encode!(response_data, pretty: true)
        message = Enum.join([headline, error_details, response_pretty], "\n")
        ExUnit.Assertions.flunk message
    end
  end
end
