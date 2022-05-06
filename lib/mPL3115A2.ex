defmodule MPL3115A2 do
  alias Circuits.I2C
  import Bitwise

  @moduledoc """
  Documentation for `Mpl3115a2`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Mpl3115a2.hello()
      :world

  """
  def hello do
    :world
  end

  @addr_pressure_data 0x01
  @addr_altitude_data 0x01
  @addr_temperature_data 0x04
  @addr_whoami 0x0C
  @addr_barometric_input 0x14
  @addr_register_1 0x26
  @addr_register_2 0x27

  @register_1_ost 0x02
  @register_1_alt 0x80

  def write_to_register({:error, str}), do: {:error, str}

  def write_to_register(ref, addr, ctrl_bits) do
    :ok = I2C.write(ref, 0x60, <<addr, ctrl_bits>>)
    ref
  end

  def write_to_register(addr, ctrl_bits) do
    {:ok, ref} = I2C.open("i2c-1")

    :ok = I2C.write(ref, 0x60, <<addr, ctrl_bits>>)

    ref
  end

  def set_control_register_1(ctrl_bits) do
    write_to_register(@addr_register_1, ctrl_bits)
  end

  def temperature_reading_to_celsius(data) do
    <<t_msb, t_lsb>> = data
    (t_msb <<< 8 ||| t_lsb) / 255
  end

  def altitude_reading_to_meters(data) do
    <<a_msb, a_csb, a_lsb>> = data
    (a_msb <<< 24 ||| a_csb <<< 16 ||| a_lsb <<< 8) / 65536
  end

  def pressure_reading_to_pascals(data) do
    <<p_msb, p_csb, p_lsb>> = data
    (p_msb <<< 16 ||| p_csb <<< 8 ||| p_lsb) / 64
  end

  def read_data_out_register({:error, str}), do: {:error, str}

  def read_data_out_register(ref, register, bytes) do
    {:ok, out} = I2C.write_read(ref, 0x60, <<register>>, bytes)
    out
  end

  def write_to_barometric_input({:error, str}, _), do: {:error, str}

  def write_to_barometric_input(ref, pressure) do
    input = pressure >>> 1

    case I2C.write(ref, 0x60, <<@addr_barometric_input, input >>> 8, input &&& 0x00FF>>) do
      :ok -> ref
      _ -> {:error, "Failed to write to ref"}
    end
  end

  def get_reading(:altitude),
    do:
      set_control_register_1(@register_1_ost ||| @register_1_alt)
      |> read_data_out_register(@addr_altitude_data, 3)
      |> altitude_reading_to_meters

  def get_reading(:pressure),
    do:
      set_control_register_1(@register_1_ost)
      |> read_data_out_register(@addr_pressure_data, 3)
      |> pressure_reading_to_pascals

  def get_reading(:temperature),
    do:
      set_control_register_1(@register_1_ost)
      |> read_data_out_register(@addr_temperature_data, 2)
      |> temperature_reading_to_celsius
end
