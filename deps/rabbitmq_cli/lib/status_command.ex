## The contents of this file are subject to the Mozilla Public License
## Version 1.1 (the "License"); you may not use this file except in
## compliance with the License. You may obtain a copy of the License
## at http://www.mozilla.org/MPL/
##
## Software distributed under the License is distributed on an "AS IS"
## basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
## the License for the specific language governing rights and
## limitations under the License.
##
## The Original Code is RabbitMQ.
##
## The Initial Developer of the Original Code is GoPivotal, Inc.
## Copyright (c) 2007-2016 Pivotal Software, Inc.  All rights reserved.


defmodule StatusCommand do
  import Helpers

  @otp_version_tag "otp_version"
  @erts_version_tag "erts_version"
  @n_app_divider_space 3


  def status(options) do
    case options[:node] do
      nil -> get_rabbit_hostname |> :rpc.call(:rabbit, :status, [])
      host when is_atom(host) -> host |> :rpc.call(:rabbit, :status, [])
      host when is_binary(host) -> host |> String.to_atom() |> :rpc.call(:rabbit, :status, [])
    end
  end

  def print_status(result) do
    result 
    |> print_pid
    |> print_os
    |> print_line_break
    |> print_otp_version
    |> print_erts_version
    |> print_line_break
    |> print_running_apps
    |> print_line_break
    |> print_memory_usage
    |> print_line_break
  end

  defp print_os(result) when not is_list(result), do: result
  defp print_os(result) when is_list(result) do
    case result[:os] do
      nil -> nil
      _ -> IO.puts "OS: #{os_name}"
    end
    result
  end

  defp print_pid(result) when not is_list(result), do: result
  defp print_pid(result) when is_list(result) do
    case result[:pid] do
      nil -> nil
      _ -> IO.puts "PID: #{result[:pid]}"
    end
    result
  end

  defp print_otp_version(result) when not is_list(result), do: result
  defp print_otp_version(result) when is_list(result) do
    case erl = result[:erlang_version] do
      nil -> nil
      _ -> IO.puts "OTP version: #{otp_version_number(to_string(erl))}"
    end
    result
  end

  defp print_erts_version(result) when not is_list(result), do: result
  defp print_erts_version(result) when is_list(result) do
    case erl = result[:erlang_version] do
      nil -> nil
      _ -> IO.puts "Erlang RTS version: #{erts_version_number(to_string(erl))}"
    end
    result
  end

  defp print_running_apps(result) when not is_list(result), do: result
  defp print_running_apps(result) when is_list(result) do
    IO.puts "Applications currently running:"
    {id_width, name_width, version_width} = app_column_widths(result)
    print_line({id_width, name_width, version_width})

    case result[:running_applications] do
      nil -> nil
      _ -> result[:running_applications] |> Enum.map(
              fn ({id, name, version}) ->
                :io.format(
                  "~-#{id_width}s | ~-#{name_width}s | ~s\n", 
                  [id, name, version]
                )
              end
            )
    end
    result
  end

  defp print_memory_usage(result) when not is_list(result), do: result
  defp print_memory_usage(result) when is_list(result) do
    case result[:memory] do
      nil -> nil
      _   -> IO.puts "Memory usage:"
              {mem_type_width, mem_value_width} = memory_column_widths(result)

              print_line({mem_type_width, mem_value_width})
              result[:memory] |> Enum.map(
                fn ({mem_type, mem_value}) ->
                  :io.format(
                    "~-#{mem_type_width}s | ~B\n", 
                    [mem_type, mem_value]
                  )
                end
              )
    end
    result
  end

  defp print_line_break(result) when not is_list(result), do: result
  defp print_line_break(result) do
    IO.puts ""
    result
  end
#----------------------------------------------------------------------------

  defp os_name do
    :os.type
    |> elem(1)
    |> Atom.to_string
    |> Mix.Utils.camelize
  end

  defp otp_version_number(erlang_string) do
    ~r/OTP (?<#{@otp_version_tag}>\d+)/
    |> Regex.named_captures(erlang_string)
    |> Map.fetch!(@otp_version_tag)
  end

  defp erts_version_number(erlang_string) do
    ~r/\[erts\-(?<#{@erts_version_tag}>\d+\.\d+\.\d+)\]/
    |> Regex.named_captures(erlang_string)
    |> Map.fetch!(@erts_version_tag)
  end

  defp app_column_widths(nil), do: {0,0,0}
  defp app_column_widths(result), do: column_widths(result[:running_applications], 3)

  defp memory_column_widths(nil), do: {0,0}
  defp memory_column_widths(result), do: column_widths(result[:memory], 2)

  # Calculates the widths needed to print the given columns
  defp column_widths(tuple_list, ncols) do
    case tuple_list do
      nil   -> List.duplicate(0, ncols) |> List.to_tuple
      _ -> tuple_list |> get_field_widths |> max_accumulator(ncols)
    end
  end

  defp print_line(nil), do: nil
  defp print_line(field_widths) do
    line_length = dividing_line_length(field_widths)
    IO.puts String.duplicate("-", line_length)
  end

  defp dividing_line_length(field_widths) do
    field_widths
    |> Tuple.to_list
    |> Enum.sum
    |> + (@n_app_divider_space * num_dividers(field_widths))
  end

  defp num_dividers(field_widths) do
    tuple_size(field_widths) - 1
  end

  defp elt_length(target) when is_list(target) do
    target |> length
  end

  defp elt_length(target) when is_atom(target) do
    target |> Atom.to_char_list |> length
  end

  defp elt_length(target) when is_integer(target) do
    target |> Integer.to_char_list |> length
  end

  # input: A list of atom or character list 3-tuples
  # output: A list of 3-elt lists containing the lengths of the inputs' strings
  defp get_field_widths(tuple_list) do
    tuple_list |> Enum.map(
      fn(tup) ->
        tup
        |> Tuple.to_list
        |> Enum.map(&elt_length/1)
      end
    )
  end

  # input:  a list of 3-element lists generated by get_field_widths
  #         an integer of value > 0 representing the number of fields
  # output: a 3-tuple containing the largest element in each column.
  defp max_accumulator(app_widths_list, ncols) do
    Enum.reduce(
      app_widths_list,
      List.duplicate(0, ncols),
      fn (app_widths, acc) ->
        List.zip([app_widths, acc]) |> Enum.map(fn({a,b}) -> max(a,b) end) |> List.to_tuple
      end
    )
  end
end
