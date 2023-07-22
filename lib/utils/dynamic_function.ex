defmodule DynamicFunction do
  defmacro dynamic_fn_with_arity(fn_name, fn_args) do
    quote do
      # We can specify documentation for the function
      @doc false
      def unquote(fn_name)(unquote_splicing(fn_args)) do
        IO.inspect(arg1)
        IO.inspect(arg2)
      end
    end
  end
end
