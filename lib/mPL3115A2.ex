defmodule MPL3115A2 do
  alias Circuits.I2C
  import Bitwise

  @moduledoc """
  API for the `MPL3115A2` pressure/temperature/altitude sensor.
  """

  @type chip_state :: %{
          ref: I2C.bus(),
          addr: byte(),
          sea_level_pressure: non_neg_integer
        }

  @i2c_code "i2c-1"
  @chip_addr 0x60
  @sea_level_pressure 101_326

  @addr_pressure_data 0x01
  @addr_altitude_data 0x01
  @addr_temperature_data 0x04
  @addr_whoami 0x0C
  @addr_barometric_input 0x14
  @addr_register_1 0x26
  @addr_register_2 0x27

  @register_1_ost 0x02
  @register_1_alt 0x80

  @doc """
  Initialize an MPL3115A2 sensor
  
  ## Parameters
    - :i2c - the device code to pass to `I2C.open`
    - :sea_level_pressure - the standard pressure at sea level in the sampling location, to calibrate altitude
  """
  @spec init(list()) :: chip_state | {:error, term()}
  def init(opts \\ []) do
    device = Keyword.get(opts, :i2c, @i2c_code)
    sea_level_pressure = Keyword.get(opts, :sea_level_pressure, @sea_level_pressure)
    case I2C.open(device) do
      {:ok, ref} -> %{ref: ref, addr: @chip_addr, sea_level_pressure: sea_level_pressure}
      err -> err
    end
  end

  @doc """
  Write to a given register

  ## Parameters
    - state - a `chip_state` as returned by `init`
    - register - a register address (see MPL3115A2 specsheet)
    - ctrl_bits - the modifiers to a register (see spec)
  """
  @spec write_to_register({:error, term()}) :: {:error, term()}
  def write_to_register({:error, str}), do: {:error, str}

  @spec write_to_register(chip_state, non_neg_integer, binary) :: chip_state | {:error, term()}
  def write_to_register(state, register, ctrl_bits) do
    case I2C.write(state[:ref], state[:addr], <<register>> <> ctrl_bits) do
      :ok -> state
      err -> err
    end
  end

  @doc """
  Set the primary control register

  ## Parameters
    - state - a `chip_state`
    - ctrl_bits - binary data to send to register 1
  """
  @spec set_control_register_1({:error, term()}) :: {:error, term()}
  def set_control_register_1({:error, str}), do: {:error, str}

  @spec set_control_register_1(chip_state, binary) :: chip_state | {:error, term()}
  def set_control_register_1(state, ctrl_bits) do
    write_to_register(state, @addr_register_1, ctrl_bits)
  end

  @doc """
  Convert a temperature reading to degrees celsius

  ## Parameters
    - reading - a binary as obtained from `read_data_out_register`
  """
  @spec temperature_reading_to_celsius(binary) :: float()
  def temperature_reading_to_celsius(data) do
    <<t_msb, t_lsb>> = data
    (t_msb <<< 8 ||| t_lsb) / 255
  end

  @doc """
  Convert an altitude reading to meters

  ## Parameters
    - reading - a binary as obtained from `read_data_out_register`
  """
  @spec altitude_reading_to_meters(binary) :: float()
  def altitude_reading_to_meters(data) do
    <<a_msb, a_csb, a_lsb>> = data
    (a_msb <<< 24 ||| a_csb <<< 16 ||| a_lsb <<< 8) / 65536
  end

  @doc """
  Convert a pressure reading to pascals

  ## Parameters
    - reading - a binary as obtained from `read_data_out_register`
  """
  @spec pressure_reading_to_pascals(binary) :: integer
  def pressure_reading_to_pascals(data) do
    <<p_msb, p_csb, p_lsb>> = data
    (p_msb <<< 16 ||| p_csb <<< 8 ||| p_lsb) >>> 6
  end

  @doc """
  Reads data from the output register

  ## Parameters
    - state: a `chip_state`
    - register: the register to read from
    - bytes: control parameters
  """
  @spec read_data_out_register({:error, term()}) :: {:error, term()}
  def read_data_out_register({:error, str}), do: {:error, str}

  @spec read_data_out_register(chip_state, non_neg_integer, non_neg_integer) ::
          binary | {:error, term()}
  def read_data_out_register(state, register, bytes) do
    case I2C.write_read(state.ref, state.addr, <<register>>, bytes) do
      {:ok, out} -> out
      err -> err
    end
  end

  @doc """
  Write a value to the barometric input register to calibrate altitude readings

  This uses the `sea_level_pressure` value of `chip_state`

  ## Parameters
    - state: a `chip_state`
  """
  @spec write_to_barometric_input({:error, term()}) :: {:error, term()}
  def write_to_barometric_input({:error, str}, _), do: {:error, str}

  @spec write_to_barometric_input(chip_state) :: chip_state | {:error, term()}
  def write_to_barometric_input(state) do
    input = state.sea_level_pressure >>> 1

    case I2C.write(
           state.ref,
           state.addr,
           <<@addr_barometric_input>> <> <<input >>> 8>> <> <<input &&& 0x00FF>>
         ) do
      :ok -> state
      err -> err
    end
  end

  @doc """
  Get a reading. Values for `:altitude`, `:pressure` and `:temperature`. Pipe from
  `init` to use non-default values (especially for setting pressure to read altitude)
  """
  def get_reading(:altitude), do: init() |> get_reading(:altitude)
  def get_reading(:pressure), do: init() |> get_reading(:pressure)
  def get_reading(:temperature), do: init() |> get_reading(:temperature)

  def get_reading({:error, term}, _), do: {:error, term}
  def get_reading(state, :altitude),
    do:
      state
      |> write_to_barometric_input
      |> set_control_register_1(<<@register_1_ost ||| @register_1_alt>>)
      |> read_data_out_register(@addr_altitude_data, 3)
      |> altitude_reading_to_meters

  def get_reading(state, :pressure),
    do:
      state
      |> set_control_register_1(<<@register_1_ost>>)
      |> read_data_out_register(@addr_pressure_data, 3)
      |> pressure_reading_to_pascals

  def get_reading(state, :temperature),
    do:
      state
      |> set_control_register_1(<<@register_1_ost>>)
      |> read_data_out_register(@addr_temperature_data, 2)
      |> temperature_reading_to_celsius
end
