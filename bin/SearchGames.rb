#! /usr/bin/env ruby
# frozen_string_literal: true

require_relative '../src/Utils/data_helper'

DataHelper.actual_price_for(ARGV[0])
