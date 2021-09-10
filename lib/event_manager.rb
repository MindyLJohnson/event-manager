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
  Time.strptime(reg_date, '%m/%d/%Y %k:%M').hour
end

def print_peak_hours(peak_hours)
  if peak_hours.length > 2
    peak_hours.reduce('') do |print_hours, hour|
      if hour == peak_hours.last
        print_hours + "and #{hour}:00."
      else 
        print_hours + "#{hour}:00, "
      end
    end
  elsif peak_hours.length == 2
    "#{peak_hours[0]}:00 and #{peak_hours[1]}:00"
  else
    "#{peak_hours}:00"
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

content.each do |row|
  id = row[0]
  name = row[:first_name]
  phone_number = clean_phone_number(row[:homephone])
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  form_letter = erb_template.result(binding)
  save_thank_you_letter(id, form_letter)
  reg_hours[count_reg_hours(row[:regdate])] += 1
end

peak_hours = reg_hours.select { |k, v| v == reg_hours.max_by(&:last)[1] }.keys

puts "The peak registration hours are #{print_peak_hours(peak_hours)}"
