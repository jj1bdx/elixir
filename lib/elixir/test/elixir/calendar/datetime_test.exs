# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2021 The Elixir Team
# SPDX-FileCopyrightText: 2012 Plataformatec

Code.require_file("../test_helper.exs", __DIR__)
Code.require_file("holocene.exs", __DIR__)
Code.require_file("fakes.exs", __DIR__)

defmodule DateTimeTest do
  use ExUnit.Case
  doctest DateTime

  test "sigil_U" do
    assert ~U[2000-01-01T12:34:56Z] ==
             %DateTime{
               calendar: Calendar.ISO,
               year: 2000,
               month: 1,
               day: 1,
               hour: 12,
               minute: 34,
               second: 56,
               std_offset: 0,
               utc_offset: 0,
               time_zone: "Etc/UTC",
               zone_abbr: "UTC"
             }

    assert ~U[2000-01-01T12:34:56+00:00 Calendar.Holocene] ==
             %DateTime{
               calendar: Calendar.Holocene,
               year: 2000,
               month: 1,
               day: 1,
               hour: 12,
               minute: 34,
               second: 56,
               std_offset: 0,
               utc_offset: 0,
               time_zone: "Etc/UTC",
               zone_abbr: "UTC"
             }

    assert ~U[2000-01-01 12:34:56+00:00] ==
             %DateTime{
               calendar: Calendar.ISO,
               year: 2000,
               month: 1,
               day: 1,
               hour: 12,
               minute: 34,
               second: 56,
               std_offset: 0,
               utc_offset: 0,
               time_zone: "Etc/UTC",
               zone_abbr: "UTC"
             }

    assert ~U[2000-01-01 12:34:56Z Calendar.Holocene] ==
             %DateTime{
               calendar: Calendar.Holocene,
               year: 2000,
               month: 1,
               day: 1,
               hour: 12,
               minute: 34,
               second: 56,
               std_offset: 0,
               utc_offset: 0,
               time_zone: "Etc/UTC",
               zone_abbr: "UTC"
             }

    assert_raise ArgumentError,
                 ~s/cannot parse "2001-50-50T12:34:56Z" as UTC DateTime for Calendar.ISO, reason: :invalid_date/,
                 fn -> Code.eval_string("~U[2001-50-50T12:34:56Z]") end

    assert_raise ArgumentError,
                 ~s/cannot parse "2001-01-01T12:34:65Z" as UTC DateTime for Calendar.ISO, reason: :invalid_time/,
                 fn -> Code.eval_string("~U[2001-01-01T12:34:65Z]") end

    assert_raise ArgumentError,
                 ~s/cannot parse "2001-01-01T12:34:56\+01:00" as UTC DateTime for Calendar.ISO, reason: :non_utc_offset/,
                 fn -> Code.eval_string("~U[2001-01-01T12:34:56+01:00]") end

    assert_raise ArgumentError,
                 ~s/cannot parse "2001-01-01 12:34:56Z notalias" as UTC DateTime for Calendar.ISO, reason: :invalid_format/,
                 fn -> Code.eval_string("~U[2001-01-01 12:34:56Z notalias]") end

    assert_raise ArgumentError,
                 ~s/cannot parse "2001-01-01T12:34:56Z notalias" as UTC DateTime for Calendar.ISO, reason: :invalid_format/,
                 fn -> Code.eval_string("~U[2001-01-01T12:34:56Z notalias]") end

    assert_raise ArgumentError,
                 ~s/cannot parse "2001-50-50T12:34:56Z" as UTC DateTime for Calendar.Holocene, reason: :invalid_date/,
                 fn -> Code.eval_string("~U[2001-50-50T12:34:56Z Calendar.Holocene]") end

    assert_raise ArgumentError,
                 ~s/cannot parse "2001-01-01T12:34:65Z" as UTC DateTime for Calendar.Holocene, reason: :invalid_time/,
                 fn -> Code.eval_string("~U[2001-01-01T12:34:65Z Calendar.Holocene]") end

    assert_raise ArgumentError,
                 ~s/cannot parse "2001-01-01T12:34:56+01:00 Calendar.Holocene" as UTC DateTime for Calendar.Holocene, reason: :non_utc_offset/,
                 fn -> Code.eval_string("~U[2001-01-01T12:34:56+01:00 Calendar.Holocene]") end

    assert_raise UndefinedFunctionError, fn ->
      Code.eval_string("~U[2001-01-01 12:34:56 UnknownCalendar]")
    end

    assert_raise UndefinedFunctionError, fn ->
      Code.eval_string("~U[2001-01-01T12:34:56 UnknownCalendar]")
    end
  end

  test "to_string/1" do
    datetime = %DateTime{
      year: 2000,
      month: 2,
      day: 29,
      zone_abbr: "BRM",
      hour: 23,
      minute: 0,
      second: 7,
      microsecond: {0, 0},
      utc_offset: -12600,
      std_offset: 3600,
      time_zone: "Brazil/Manaus"
    }

    assert to_string(datetime) == "2000-02-29 23:00:07-02:30 BRM Brazil/Manaus"
    assert DateTime.to_string(datetime) == "2000-02-29 23:00:07-02:30 BRM Brazil/Manaus"

    assert DateTime.to_string(Map.from_struct(datetime)) ==
             "2000-02-29 23:00:07-02:30 BRM Brazil/Manaus"

    assert to_string(%{datetime | calendar: FakeCalendar}) ==
             "29/2/2000F23::0::7 Brazil/Manaus BRM -12600 3600"

    assert DateTime.to_string(%{datetime | calendar: FakeCalendar}) ==
             "29/2/2000F23::0::7 Brazil/Manaus BRM -12600 3600"
  end

  test "inspect/1" do
    utc_datetime = ~U[2000-01-01 23:00:07.005Z]
    assert inspect(utc_datetime) == "~U[2000-01-01 23:00:07.005Z]"

    assert inspect(%{utc_datetime | year: 99999}) == "#DateTime<99999-01-01 23:00:07.005Z>"

    assert inspect(%{utc_datetime | calendar: FakeCalendar}) ==
             "~U[1/1/2000F23::0::7 Etc/UTC UTC 0 0 FakeCalendar]"

    datetime = %DateTime{
      year: 2000,
      month: 2,
      day: 29,
      zone_abbr: "BRM",
      hour: 23,
      minute: 0,
      second: 7,
      microsecond: {0, 0},
      utc_offset: -12600,
      std_offset: 3600,
      time_zone: "Brazil/Manaus"
    }

    assert inspect(datetime) == "#DateTime<2000-02-29 23:00:07-02:30 BRM Brazil/Manaus>"

    assert inspect(%{datetime | calendar: FakeCalendar}) ==
             "#DateTime<29/2/2000F23::0::7 Brazil/Manaus BRM -12600 3600 FakeCalendar>"
  end

  test "from_iso8601/1 handles positive and negative offsets" do
    assert DateTime.from_iso8601("2015-01-24T09:50:07-10:00") |> elem(1) ==
             %DateTime{
               microsecond: {0, 0},
               month: 1,
               std_offset: 0,
               time_zone: "Etc/UTC",
               utc_offset: 0,
               year: 2015,
               zone_abbr: "UTC",
               day: 24,
               hour: 19,
               minute: 50,
               second: 7
             }

    assert DateTime.from_iso8601("2015-01-24T09:50:07+10:00") |> elem(1) ==
             %DateTime{
               microsecond: {0, 0},
               month: 1,
               std_offset: 0,
               time_zone: "Etc/UTC",
               utc_offset: 0,
               year: 2015,
               zone_abbr: "UTC",
               day: 23,
               hour: 23,
               minute: 50,
               second: 7
             }

    assert DateTime.from_iso8601("0000-01-01T01:22:07+10:30") |> elem(1) ==
             %DateTime{
               microsecond: {0, 0},
               month: 12,
               std_offset: 0,
               time_zone: "Etc/UTC",
               utc_offset: 0,
               year: -1,
               zone_abbr: "UTC",
               day: 31,
               hour: 14,
               minute: 52,
               second: 7
             }
  end

  test "from_iso8601/1 handles negative dates" do
    assert DateTime.from_iso8601("-2015-01-24T09:50:07-10:00") |> elem(1) ==
             %DateTime{
               microsecond: {0, 0},
               month: 1,
               std_offset: 0,
               time_zone: "Etc/UTC",
               utc_offset: 0,
               year: -2015,
               zone_abbr: "UTC",
               day: 24,
               hour: 19,
               minute: 50,
               second: 7
             }

    assert DateTime.from_iso8601("-2015-01-24T09:50:07+10:00") |> elem(1) ==
             %DateTime{
               microsecond: {0, 0},
               month: 1,
               std_offset: 0,
               time_zone: "Etc/UTC",
               utc_offset: 0,
               year: -2015,
               zone_abbr: "UTC",
               day: 23,
               hour: 23,
               minute: 50,
               second: 7
             }

    assert DateTime.from_iso8601("-0001-01-01T01:22:07+10:30") |> elem(1) ==
             %DateTime{
               microsecond: {0, 0},
               month: 12,
               std_offset: 0,
               time_zone: "Etc/UTC",
               utc_offset: 0,
               year: -2,
               zone_abbr: "UTC",
               day: 31,
               hour: 14,
               minute: 52,
               second: 7
             }

    assert DateTime.from_iso8601("-0001-01-01T01:22:07-10:30") |> elem(1) ==
             %DateTime{
               microsecond: {0, 0},
               month: 1,
               std_offset: 0,
               time_zone: "Etc/UTC",
               utc_offset: 0,
               year: -1,
               zone_abbr: "UTC",
               day: 1,
               hour: 11,
               minute: 52,
               second: 7
             }

    assert DateTime.from_iso8601("-0001-12-31T23:22:07-10:30") |> elem(1) ==
             %DateTime{
               microsecond: {0, 0},
               month: 1,
               std_offset: 0,
               time_zone: "Etc/UTC",
               utc_offset: 0,
               year: 0,
               zone_abbr: "UTC",
               day: 1,
               hour: 9,
               minute: 52,
               second: 7
             }
  end

  test "from_iso8601/3 with basic format handles positive and negative offsets" do
    assert DateTime.from_iso8601("20150124T095007-1000", Calendar.ISO, :basic) ==
             DateTime.from_iso8601("2015-01-24T09:50:07-10:00", Calendar.ISO)

    assert DateTime.from_iso8601("20150124T095007+1000", Calendar.ISO, :basic) ==
             DateTime.from_iso8601("2015-01-24T09:50:07+10:00", Calendar.ISO)

    assert DateTime.from_iso8601("00000101T012207+1030", Calendar.ISO, :basic) ==
             DateTime.from_iso8601("0000-01-01T01:22:07+10:30", Calendar.ISO)
  end

  test "from_iso8601/3 with basic format handles negative dates" do
    assert DateTime.from_iso8601("-20150124T095007-1000", Calendar.ISO, :basic) ==
             DateTime.from_iso8601("-2015-01-24T09:50:07-10:00", Calendar.ISO)

    assert DateTime.from_iso8601("-20150124T095007+1000", Calendar.ISO, :basic) ==
             DateTime.from_iso8601("-2015-01-24T09:50:07+10:00", Calendar.ISO)

    assert DateTime.from_iso8601("-00010101T012207+1030", Calendar.ISO, :basic) ==
             DateTime.from_iso8601("-0001-01-01T01:22:07+10:30", Calendar.ISO)

    assert DateTime.from_iso8601("-00010101T012207-1030", Calendar.ISO, :basic) ==
             DateTime.from_iso8601("-0001-01-01T01:22:07-10:30", Calendar.ISO)

    assert DateTime.from_iso8601("-00011231T232207-1030", Calendar.ISO, :basic) ==
             DateTime.from_iso8601("-0001-12-31T23:22:07-10:30", Calendar.ISO)
  end

  test "from_iso8601/2 handles either a calendar or a format as the second parameter" do
    assert DateTime.from_iso8601("20150124T095007-1000", :basic) ==
             DateTime.from_iso8601("2015-01-24T09:50:07-10:00", Calendar.ISO)
  end

  test "from_iso8601 handles invalid date, time, formats correctly" do
    assert DateTime.from_iso8601("2015-01-23T23:50:07") == {:error, :missing_offset}
    assert DateTime.from_iso8601("2015-01-23 23:50:61") == {:error, :invalid_time}
    assert DateTime.from_iso8601("2015-01-32 23:50:07") == {:error, :invalid_date}
    assert DateTime.from_iso8601("2015-01-23 23:50:07A") == {:error, :invalid_format}
    assert DateTime.from_iso8601("2015-01-23T23:50:07.123-00:60") == {:error, :invalid_format}

    assert DateTime.from_iso8601("20150123T235007", Calendar.ISO, :basic) ==
             {:error, :missing_offset}

    assert DateTime.from_iso8601("20150123 235061", Calendar.ISO, :basic) ==
             {:error, :invalid_time}

    assert DateTime.from_iso8601("20150132 235007", Calendar.ISO, :basic) ==
             {:error, :invalid_date}

    assert DateTime.from_iso8601("20150123 235007A", Calendar.ISO, :basic) ==
             {:error, :invalid_format}

    assert DateTime.from_iso8601("2015-01-24T09:50:07-10:00", Calendar.ISO, :basic) ==
             {:error, :invalid_format}

    assert DateTime.from_iso8601("20150123T235007.123-0060", Calendar.ISO, :basic) ==
             {:error, :invalid_format}
  end

  test "from_unix/2" do
    min_datetime = %DateTime{
      calendar: Calendar.ISO,
      day: 1,
      hour: 0,
      microsecond: {0, 0},
      minute: 0,
      month: 1,
      second: 0,
      std_offset: 0,
      time_zone: "Etc/UTC",
      utc_offset: 0,
      year: -9999,
      zone_abbr: "UTC"
    }

    assert DateTime.from_unix(-377_705_116_800) == {:ok, min_datetime}

    assert DateTime.from_unix(-377_705_116_800_000_001, :microsecond) ==
             {:error, :invalid_unix_time}

    assert DateTime.from_unix(143_256_036_886_856, 1024) ==
             {:ok,
              %DateTime{
                calendar: Calendar.ISO,
                day: 17,
                hour: 7,
                microsecond: {320_312, 6},
                minute: 5,
                month: 3,
                second: 22,
                std_offset: 0,
                time_zone: "Etc/UTC",
                utc_offset: 0,
                year: 6403,
                zone_abbr: "UTC"
              }}

    max_datetime = %DateTime{
      calendar: Calendar.ISO,
      day: 31,
      hour: 23,
      microsecond: {999_999, 6},
      minute: 59,
      month: 12,
      second: 59,
      std_offset: 0,
      time_zone: "Etc/UTC",
      utc_offset: 0,
      year: 9999,
      zone_abbr: "UTC"
    }

    assert DateTime.from_unix(253_402_300_799_999_999, :microsecond) == {:ok, max_datetime}

    assert DateTime.from_unix(253_402_300_800) == {:error, :invalid_unix_time}

    minus_datetime = %DateTime{
      calendar: Calendar.ISO,
      day: 31,
      hour: 23,
      microsecond: {999_999, 6},
      minute: 59,
      month: 12,
      second: 59,
      std_offset: 0,
      time_zone: "Etc/UTC",
      utc_offset: 0,
      year: 1969,
      zone_abbr: "UTC"
    }

    assert DateTime.from_unix(-1, :microsecond) == {:ok, minus_datetime}

    assert_raise ArgumentError, fn ->
      DateTime.from_unix(0, :unknown_atom)
    end

    assert_raise ArgumentError, fn ->
      DateTime.from_unix(0, "invalid type")
    end
  end

  test "from_unix!/2" do
    # with Unix times back to 0 Gregorian seconds
    datetime = %DateTime{
      calendar: Calendar.ISO,
      day: 1,
      hour: 0,
      microsecond: {0, 0},
      minute: 0,
      month: 1,
      second: 0,
      std_offset: 0,
      time_zone: "Etc/UTC",
      utc_offset: 0,
      year: 0,
      zone_abbr: "UTC"
    }

    assert DateTime.from_unix!(-62_167_219_200) == datetime

    assert_raise ArgumentError, fn ->
      DateTime.from_unix!(-377_705_116_801)
    end

    assert_raise ArgumentError, fn ->
      DateTime.from_unix!(0, :unknown_atom)
    end

    assert_raise ArgumentError, fn ->
      DateTime.from_unix!(0, "invalid type")
    end
  end

  test "to_unix/2 works with Unix times back to 0 Gregorian seconds" do
    # with Unix times back to 0 Gregorian seconds
    gregorian_0 = %DateTime{
      calendar: Calendar.ISO,
      day: 1,
      hour: 0,
      microsecond: {0, 0},
      minute: 0,
      month: 1,
      second: 0,
      std_offset: 0,
      time_zone: "Etc/UTC",
      utc_offset: 0,
      year: 0,
      zone_abbr: "UTC"
    }

    assert DateTime.to_unix(gregorian_0) == -62_167_219_200
    assert DateTime.to_unix(Map.from_struct(gregorian_0)) == -62_167_219_200

    min_datetime = %{gregorian_0 | year: -9999}
    assert DateTime.to_unix(min_datetime) == -377_705_116_800
  end

  test "compare/2" do
    datetime1 = %DateTime{
      year: 2000,
      month: 2,
      day: 29,
      zone_abbr: "CET",
      hour: 23,
      minute: 0,
      second: 7,
      microsecond: {0, 0},
      utc_offset: 3600,
      std_offset: 0,
      time_zone: "Europe/Warsaw"
    }

    datetime2 = %DateTime{
      year: 2000,
      month: 2,
      day: 29,
      zone_abbr: "AMT",
      hour: 23,
      minute: 0,
      second: 7,
      microsecond: {0, 0},
      utc_offset: -14400,
      std_offset: 0,
      time_zone: "America/Manaus"
    }

    datetime3 = %DateTime{
      year: -99,
      month: 2,
      day: 28,
      zone_abbr: "AMT",
      hour: 23,
      minute: 0,
      second: 7,
      microsecond: {0, 0},
      utc_offset: -14400,
      std_offset: 0,
      time_zone: "America/Manaus"
    }

    assert DateTime.compare(datetime1, datetime1) == :eq
    assert DateTime.compare(datetime1, datetime2) == :lt
    assert DateTime.compare(datetime2, datetime1) == :gt
    assert DateTime.compare(datetime3, datetime3) == :eq
    assert DateTime.compare(datetime2, datetime3) == :gt
    assert DateTime.compare(datetime3, datetime1) == :lt
    assert DateTime.compare(Map.from_struct(datetime3), Map.from_struct(datetime1)) == :lt
  end

  test "before?/2 and after?/2" do
    datetime1 = ~U[2015-01-02T12:34:56Z]
    datetime2 = ~U[2015-01-02T12:55:55Z]

    assert DateTime.before?(datetime1, datetime2)
    assert not DateTime.before?(datetime2, datetime1)

    assert DateTime.after?(datetime2, datetime1)
    assert not DateTime.after?(datetime1, datetime2)
  end

  test "convert/2" do
    datetime_iso = %DateTime{
      year: 2000,
      month: 2,
      day: 29,
      zone_abbr: "CET",
      hour: 23,
      minute: 0,
      second: 7,
      microsecond: {0, 0},
      utc_offset: 3600,
      std_offset: 0,
      time_zone: "Europe/Warsaw"
    }

    datetime_hol = %DateTime{
      year: 12000,
      month: 2,
      day: 29,
      zone_abbr: "CET",
      hour: 23,
      minute: 0,
      second: 7,
      microsecond: {0, 0},
      utc_offset: 3600,
      std_offset: 0,
      time_zone: "Europe/Warsaw",
      calendar: Calendar.Holocene
    }

    assert DateTime.convert(datetime_iso, Calendar.Holocene) == {:ok, datetime_hol}

    assert datetime_iso
           |> DateTime.convert!(Calendar.Holocene)
           |> DateTime.convert!(Calendar.ISO) == datetime_iso

    assert %{datetime_iso | microsecond: {123, 6}}
           |> DateTime.convert!(Calendar.Holocene)
           |> DateTime.convert!(Calendar.ISO) == %{datetime_iso | microsecond: {123, 6}}

    assert DateTime.convert(datetime_iso, FakeCalendar) == {:error, :incompatible_calendars}

    # Test passing non-struct map when converting to different calendar returns DateTime struct
    assert DateTime.convert(Map.from_struct(datetime_iso), Calendar.Holocene) ==
             {:ok, datetime_hol}

    # Test passing non-struct map when converting to same calendar returns DateTime struct
    assert DateTime.convert(Map.from_struct(datetime_iso), Calendar.ISO) ==
             {:ok, datetime_iso}
  end

  test "from_iso8601/1 with tz offsets" do
    assert DateTime.from_iso8601("2017-06-02T14:00:00+01:00")
           |> elem(1) ==
             %DateTime{
               year: 2017,
               month: 6,
               day: 2,
               zone_abbr: "UTC",
               hour: 13,
               minute: 0,
               second: 0,
               microsecond: {0, 0},
               utc_offset: 0,
               std_offset: 0,
               time_zone: "Etc/UTC"
             }

    assert DateTime.from_iso8601("2017-06-02T14:00:00-04:00")
           |> elem(1) ==
             %DateTime{
               year: 2017,
               month: 6,
               day: 2,
               zone_abbr: "UTC",
               hour: 18,
               minute: 0,
               second: 0,
               microsecond: {0, 0},
               utc_offset: 0,
               std_offset: 0,
               time_zone: "Etc/UTC"
             }

    assert DateTime.from_iso8601("2017-06-02T14:00:00+0100")
           |> elem(1) ==
             %DateTime{
               year: 2017,
               month: 6,
               day: 2,
               zone_abbr: "UTC",
               hour: 13,
               minute: 0,
               second: 0,
               microsecond: {0, 0},
               utc_offset: 0,
               std_offset: 0,
               time_zone: "Etc/UTC"
             }

    assert DateTime.from_iso8601("2017-06-02T14:00:00-0400")
           |> elem(1) ==
             %DateTime{
               year: 2017,
               month: 6,
               day: 2,
               zone_abbr: "UTC",
               hour: 18,
               minute: 0,
               second: 0,
               microsecond: {0, 0},
               utc_offset: 0,
               std_offset: 0,
               time_zone: "Etc/UTC"
             }

    assert DateTime.from_iso8601("2017-06-02T14:00:00+01")
           |> elem(1) ==
             %DateTime{
               year: 2017,
               month: 6,
               day: 2,
               zone_abbr: "UTC",
               hour: 13,
               minute: 0,
               second: 0,
               microsecond: {0, 0},
               utc_offset: 0,
               std_offset: 0,
               time_zone: "Etc/UTC"
             }

    assert DateTime.from_iso8601("2017-06-02T14:00:00-04")
           |> elem(1) ==
             %DateTime{
               year: 2017,
               month: 6,
               day: 2,
               zone_abbr: "UTC",
               hour: 18,
               minute: 0,
               second: 0,
               microsecond: {0, 0},
               utc_offset: 0,
               std_offset: 0,
               time_zone: "Etc/UTC"
             }
  end

  test "from_iso8601/3 with basic format with tz offsets" do
    assert DateTime.from_iso8601("20170602T140000+0100", Calendar.ISO, :basic) ==
             DateTime.from_iso8601("2017-06-02T14:00:00+01:00", Calendar.ISO)

    assert DateTime.from_iso8601("20170602T140000-0400", Calendar.ISO, :basic) ==
             DateTime.from_iso8601("2017-06-02T14:00:00-04:00")

    assert DateTime.from_iso8601("20170602T140000+01", Calendar.ISO, :basic) ==
             DateTime.from_iso8601("2017-06-02T14:00:00+01")

    assert DateTime.from_iso8601("20170602T140000-04", Calendar.ISO, :basic) ==
             DateTime.from_iso8601("2017-06-02T14:00:00-04")
  end

  test "truncate/2" do
    datetime = %DateTime{
      year: 2017,
      month: 11,
      day: 6,
      zone_abbr: "CET",
      hour: 0,
      minute: 6,
      second: 23,
      microsecond: {0, 0},
      utc_offset: 3600,
      std_offset: 0,
      time_zone: "Europe/Paris"
    }

    datetime_map = Map.from_struct(datetime)

    assert DateTime.truncate(%{datetime | microsecond: {123_456, 6}}, :microsecond) ==
             %{datetime | microsecond: {123_456, 6}}

    # A struct should be returned when passing a map.
    assert DateTime.truncate(%{datetime_map | microsecond: {123_456, 6}}, :microsecond) ==
             %{datetime | microsecond: {123_456, 6}}

    assert DateTime.truncate(%{datetime | microsecond: {0, 0}}, :millisecond) ==
             %{datetime | microsecond: {0, 0}}

    assert DateTime.truncate(%{datetime | microsecond: {000_100, 6}}, :millisecond) ==
             %{datetime | microsecond: {0, 3}}

    assert DateTime.truncate(%{datetime | microsecond: {000_999, 6}}, :millisecond) ==
             %{datetime | microsecond: {0, 3}}

    assert DateTime.truncate(%{datetime | microsecond: {001_000, 6}}, :millisecond) ==
             %{datetime | microsecond: {1000, 3}}

    assert DateTime.truncate(%{datetime | microsecond: {001_200, 6}}, :millisecond) ==
             %{datetime | microsecond: {1000, 3}}

    assert DateTime.truncate(%{datetime | microsecond: {123_456, 6}}, :millisecond) ==
             %{datetime | microsecond: {123_000, 3}}

    assert DateTime.truncate(%{datetime | microsecond: {123_456, 6}}, :second) ==
             %{datetime | microsecond: {0, 0}}
  end

  describe "diff" do
    test "diff with invalid time unit" do
      dt = DateTime.utc_now()

      message =
        ~r/unsupported time unit\. Expected :day, :hour, :minute, :second, :millisecond, :microsecond, :nanosecond, or a positive integer, got "day"/

      assert_raise ArgumentError, message, fn -> DateTime.diff(dt, dt, "day") end
    end

    test "diff with valid time unit" do
      dt1 = %DateTime{
        year: 100,
        month: 2,
        day: 28,
        zone_abbr: "CET",
        hour: 23,
        minute: 0,
        second: 7,
        microsecond: {0, 0},
        utc_offset: 3600,
        std_offset: 0,
        time_zone: "Europe/Warsaw"
      }

      dt2 = %DateTime{
        year: -0004,
        month: 2,
        day: 29,
        zone_abbr: "CET",
        hour: 23,
        minute: 0,
        second: 7,
        microsecond: {0, 0},
        utc_offset: 3600,
        std_offset: 0,
        time_zone: "Europe/Warsaw"
      }

      assert DateTime.diff(dt1, dt2) == 3_281_904_000

      # Test with a non-struct map conforming to Calendar.datetime
      assert DateTime.diff(Map.from_struct(dt1), Map.from_struct(dt2)) == 3_281_904_000
    end

    test "diff with microseconds" do
      datetime = ~U[2023-02-01 10:30:10.123456Z]

      in_almost_7_days =
        datetime
        |> DateTime.add(7, :day)
        |> DateTime.add(-1, :microsecond)

      assert DateTime.diff(in_almost_7_days, datetime, :day) == 6
    end

    test "diff in microseconds" do
      datetime1 = ~U[2023-02-01 10:30:10.000000Z]
      datetime2 = DateTime.add(datetime1, 1234, :microsecond)

      assert DateTime.diff(datetime1, datetime2, :microsecond) == -1234
    end
  end

  describe "from_naive" do
    test "uses default time zone database from config" do
      Calendar.put_time_zone_database(FakeTimeZoneDatabase)

      assert DateTime.from_naive(
               ~N[2018-07-01 12:34:25.123456],
               "Europe/Copenhagen",
               FakeTimeZoneDatabase
             ) ==
               {:ok,
                %DateTime{
                  day: 1,
                  hour: 12,
                  microsecond: {123_456, 6},
                  minute: 34,
                  month: 7,
                  second: 25,
                  std_offset: 3600,
                  time_zone: "Europe/Copenhagen",
                  utc_offset: 3600,
                  year: 2018,
                  zone_abbr: "CEST"
                }}
    after
      Calendar.put_time_zone_database(Calendar.UTCOnlyTimeZoneDatabase)
    end

    test "with compatible calendar on unambiguous wall clock" do
      holocene_ndt = %NaiveDateTime{
        calendar: Calendar.Holocene,
        year: 12018,
        month: 7,
        day: 1,
        hour: 12,
        minute: 34,
        second: 25,
        microsecond: {123_456, 6}
      }

      assert DateTime.from_naive(holocene_ndt, "Europe/Copenhagen", FakeTimeZoneDatabase) ==
               {:ok,
                %DateTime{
                  calendar: Calendar.Holocene,
                  day: 1,
                  hour: 12,
                  microsecond: {123_456, 6},
                  minute: 34,
                  month: 7,
                  second: 25,
                  std_offset: 3600,
                  time_zone: "Europe/Copenhagen",
                  utc_offset: 3600,
                  year: 12018,
                  zone_abbr: "CEST"
                }}
    end

    test "with compatible calendar on ambiguous wall clock" do
      holocene_ndt = %NaiveDateTime{
        calendar: Calendar.Holocene,
        year: 12018,
        month: 10,
        day: 28,
        hour: 02,
        minute: 30,
        second: 00,
        microsecond: {123_456, 6}
      }

      assert {:ambiguous, first_dt, second_dt} =
               DateTime.from_naive(holocene_ndt, "Europe/Copenhagen", FakeTimeZoneDatabase)

      assert %DateTime{calendar: Calendar.Holocene, zone_abbr: "CEST"} = first_dt
      assert %DateTime{calendar: Calendar.Holocene, zone_abbr: "CET"} = second_dt
    end

    test "with compatible calendar on gap" do
      holocene_ndt = %NaiveDateTime{
        calendar: Calendar.Holocene,
        year: 12019,
        month: 03,
        day: 31,
        hour: 02,
        minute: 30,
        second: 00,
        microsecond: {123_456, 6}
      }

      assert {:gap, first_dt, second_dt} =
               DateTime.from_naive(holocene_ndt, "Europe/Copenhagen", FakeTimeZoneDatabase)

      assert %DateTime{calendar: Calendar.Holocene, zone_abbr: "CET"} = first_dt
      assert %DateTime{calendar: Calendar.Holocene, zone_abbr: "CEST"} = second_dt
    end

    test "with incompatible calendar" do
      ndt = %{~N[2018-07-20 00:00:00] | calendar: FakeCalendar}

      assert DateTime.from_naive(ndt, "Europe/Copenhagen", FakeTimeZoneDatabase) ==
               {:error, :incompatible_calendars}
    end
  end

  describe "from_naive!" do
    test "raises on ambiguous wall clock" do
      assert_raise ArgumentError, ~r"ambiguous", fn ->
        DateTime.from_naive!(~N[2018-10-28 02:30:00], "Europe/Copenhagen", FakeTimeZoneDatabase)
      end
    end

    test "raises on gap" do
      assert_raise ArgumentError, ~r"gap", fn ->
        DateTime.from_naive!(~N[2019-03-31 02:30:00], "Europe/Copenhagen", FakeTimeZoneDatabase)
      end
    end
  end

  describe "shift_zone" do
    test "with compatible calendar" do
      holocene_ndt = %NaiveDateTime{
        calendar: Calendar.Holocene,
        year: 12018,
        month: 7,
        day: 1,
        hour: 12,
        minute: 34,
        second: 25,
        microsecond: {123_456, 6}
      }

      {:ok, holocene_dt} =
        DateTime.from_naive(holocene_ndt, "Europe/Copenhagen", FakeTimeZoneDatabase)

      {:ok, dt} = DateTime.shift_zone(holocene_dt, "America/Los_Angeles", FakeTimeZoneDatabase)

      assert dt == %DateTime{
               calendar: Calendar.Holocene,
               day: 1,
               hour: 3,
               microsecond: {123_456, 6},
               minute: 34,
               month: 7,
               second: 25,
               std_offset: 3600,
               time_zone: "America/Los_Angeles",
               utc_offset: -28800,
               year: 12018,
               zone_abbr: "PDT"
             }
    end

    test "uses default time zone database from config" do
      Calendar.put_time_zone_database(FakeTimeZoneDatabase)

      {:ok, dt} = DateTime.from_naive(~N[2018-07-01 12:34:25.123456], "Europe/Copenhagen")
      {:ok, dt} = DateTime.shift_zone(dt, "America/Los_Angeles")

      assert dt == %DateTime{
               day: 1,
               hour: 3,
               microsecond: {123_456, 6},
               minute: 34,
               month: 7,
               second: 25,
               std_offset: 3600,
               time_zone: "America/Los_Angeles",
               utc_offset: -28800,
               year: 2018,
               zone_abbr: "PDT"
             }
    after
      Calendar.put_time_zone_database(Calendar.UTCOnlyTimeZoneDatabase)
    end
  end

  describe "add" do
    test "add with invalid time unit" do
      dt = DateTime.utc_now()

      message =
        ~r/unsupported time unit\. Expected :day, :hour, :minute, :second, :millisecond, :microsecond, :nanosecond, or a positive integer, got "day"/

      assert_raise ArgumentError, message, fn -> DateTime.add(dt, 1, "day") end
    end

    test "add with non-struct map that conforms to Calendar.datetime" do
      dt_map = DateTime.from_naive!(~N[2018-08-28 00:00:00], "Etc/UTC") |> Map.from_struct()

      assert DateTime.add(dt_map, 1, :second) == %DateTime{
               calendar: Calendar.ISO,
               year: 2018,
               month: 8,
               day: 28,
               hour: 0,
               minute: 0,
               second: 1,
               std_offset: 0,
               time_zone: "Etc/UTC",
               zone_abbr: "UTC",
               utc_offset: 0,
               microsecond: {0, 0}
             }
    end

    test "error with UTC only database and non UTC datetime" do
      dt =
        DateTime.from_naive!(~N[2018-08-28 00:00:00], "Europe/Copenhagen", FakeTimeZoneDatabase)

      assert_raise ArgumentError, fn ->
        DateTime.add(dt, 1, :second)
      end
    end

    test "add/2 with other calendars" do
      assert ~N[2000-01-01 12:34:15.123456]
             |> NaiveDateTime.convert!(Calendar.Holocene)
             |> DateTime.from_naive!("Etc/UTC")
             |> DateTime.add(10, :second) ==
               %DateTime{
                 calendar: Calendar.Holocene,
                 year: 12000,
                 month: 1,
                 day: 1,
                 hour: 12,
                 minute: 34,
                 second: 25,
                 std_offset: 0,
                 time_zone: "Etc/UTC",
                 zone_abbr: "UTC",
                 utc_offset: 0,
                 microsecond: {123_456, 6}
               }
    end
  end

  describe "to_iso8601" do
    test "to_iso8601/2 with a normal DateTime struct" do
      datetime = DateTime.from_naive!(~N[2018-07-01 12:34:25.123456], "Etc/UTC")

      assert DateTime.to_iso8601(datetime) == "2018-07-01T12:34:25.123456Z"
    end

    test "to_iso8601/2 with a non-struct map conforming to the Calendar.datetime type" do
      datetime_map =
        DateTime.from_naive!(~N[2018-07-01 12:34:25.123456], "Etc/UTC") |> Map.from_struct()

      assert DateTime.to_iso8601(datetime_map) == "2018-07-01T12:34:25.123456Z"
    end
  end

  describe "to_date/1" do
    test "upcasting" do
      assert catch_error(DateTime.to_date(~N[2000-02-29 12:23:34]))
    end
  end

  describe "to_time/1" do
    test "upcasting" do
      assert catch_error(DateTime.to_time(~N[2000-02-29 12:23:34]))
    end
  end

  describe "to_naive/1" do
    test "upcasting" do
      assert catch_error(DateTime.to_naive(~N[2000-02-29 12:23:34]))
    end
  end

  test "shift/2" do
    assert DateTime.shift(~U[2000-01-01 00:00:00Z], year: 1) == ~U[2001-01-01 00:00:00Z]
    assert DateTime.shift(~U[2000-01-01 00:00:00Z], month: 1) == ~U[2000-02-01 00:00:00Z]
    assert DateTime.shift(~U[2000-01-01 00:00:00Z], month: 1, day: 28) == ~U[2000-02-29 00:00:00Z]
    assert DateTime.shift(~U[2000-01-01 00:00:00Z], month: 1, day: 30) == ~U[2000-03-02 00:00:00Z]
    assert DateTime.shift(~U[2000-01-01 00:00:00Z], month: 2, day: 29) == ~U[2000-03-30 00:00:00Z]

    assert DateTime.shift(~U[2000-01-01 00:00:00Z], microsecond: {4000, 4}) ==
             ~U[2000-01-01 00:00:00.0040Z]

    assert DateTime.shift(~U[2000-02-29 00:00:00Z], year: -1) == ~U[1999-02-28 00:00:00Z]
    assert DateTime.shift(~U[2000-02-29 00:00:00Z], month: -1) == ~U[2000-01-29 00:00:00Z]

    assert DateTime.shift(~U[2000-02-29 00:00:00Z], month: -1, day: -28) ==
             ~U[2000-01-01 00:00:00Z]

    assert DateTime.shift(~U[2000-02-29 00:00:00Z], month: -1, day: -30) ==
             ~U[1999-12-30 00:00:00Z]

    assert DateTime.shift(~U[2000-02-29 00:00:00Z], month: -1, day: -29) ==
             ~U[1999-12-31 00:00:00Z]

    datetime =
      DateTime.new!(~D[2018-11-04], ~T[03:00:00], "America/Los_Angeles", FakeTimeZoneDatabase)

    assert DateTime.shift(datetime, [month: -1], FakeTimeZoneDatabase) ==
             %DateTime{
               calendar: Calendar.ISO,
               year: 2018,
               month: 10,
               day: 4,
               hour: 4,
               minute: 0,
               second: 0,
               microsecond: {0, 0},
               time_zone: "America/Los_Angeles",
               std_offset: 3600,
               utc_offset: -28800,
               zone_abbr: "PDT"
             }

    datetime =
      DateTime.new!(~D[2018-11-04], ~T[00:00:00], "America/Los_Angeles", FakeTimeZoneDatabase)

    assert DateTime.shift(datetime, [hour: 2], FakeTimeZoneDatabase) ==
             %DateTime{
               calendar: Calendar.ISO,
               year: 2018,
               month: 11,
               day: 4,
               hour: 1,
               minute: 0,
               second: 0,
               microsecond: {0, 0},
               time_zone: "America/Los_Angeles",
               std_offset: 0,
               utc_offset: -28800,
               zone_abbr: "PST"
             }

    datetime =
      DateTime.new!(~D[2019-03-31], ~T[01:00:00], "Europe/Copenhagen", FakeTimeZoneDatabase)

    assert DateTime.shift(datetime, [hour: 1], FakeTimeZoneDatabase) ==
             %DateTime{
               calendar: Calendar.ISO,
               year: 2019,
               month: 03,
               day: 31,
               hour: 3,
               minute: 0,
               second: 0,
               microsecond: {0, 0},
               time_zone: "Europe/Copenhagen",
               std_offset: 3600,
               utc_offset: 3600,
               zone_abbr: "CEST"
             }

    assert_raise ArgumentError,
                 "unknown unit :months. Expected :year, :month, :week, :day, :hour, :minute, :second, :microsecond",
                 fn -> DateTime.shift(~U[2012-01-01 00:00:00Z], months: 12) end
  end
end
