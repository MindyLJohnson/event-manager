require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'

def clean_phone_number(phone_number)
  phone_number = phone_number.delete(' .()-').delete_prefix('1')[0..9]
  phone_number.length < 10 ? nil : phone_number
end

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    legislators = civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representative by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')
  filename = "output/thanks_#{id}.html"
  File.open(filename, 'w') { |file| file.puts form_letter }
end

def count_reg_hours(reg_date)
  "#{Time.strptime(reg_date, '%m/%d/%Y %k:%M').hour}:00"
end

def count_reg_days(reg_date)
  Date::DAYNAMES[Time.strptime(reg_date, '%m/%d/%Y %k:%M').wday]
end

def print_peaks(peaks)
  if peaks.length > 2
    peaks.reduce('') do |print_peaks, peak|
      if peak == peaks.last
        "s are " + print_peaks + "and #{peak}."
      else 
        "s are " + print_peaks + "#{peak}, "
      end
    end
  elsif peaks.length == 2
    "s are #{peaks[0]} and #{peaks[1]}."
  else
    " is #{peaks[0]}."
  end
end

puts 'Event Manager Initialized!'

content = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter
reg_hours = Hash.new(0)
reg_days = Hash.new(0)

content.each do |row|
  id = row[0]
  name = row[:first_name]
  phone_number = clean_phone_number(row[:homephone])
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  form_letter = erb_template.result(binding)
  save_thank_you_letter(id, form_letter)
  reg_hours[count_reg_hours(row[:regdate])] += 1
  reg_days[count_reg_days(row[:regdate])] += 1
end

peak_hours = reg_hours.select { |k, v| v == reg_hours.max_by(&:last)[1] }.keys
peak_days = reg_days.select { |k, v| v == reg_days.max_by(&:last)[1] }.keys

puts "The peak registration hour#{print_peaks(peak_hours)}"
puts "The peak registration weekday#{print_peaks(peak_days)}"