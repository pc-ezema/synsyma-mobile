const countryNames = {'CA': 'Canada', 'US': 'United States', 'GB': 'United Kingdom'};

const regionLabel = {'CA': 'Province', 'US': 'State', 'GB': 'Nation'};
const postalLabel = {'CA': 'Postal code', 'US': 'ZIP code', 'GB': 'Postcode'};

const regionsByCountry = <String, List<String>>{
  'CA': ['Alberta', 'British Columbia', 'Manitoba', 'New Brunswick', 'Newfoundland and Labrador', 'Northwest Territories', 'Nova Scotia', 'Nunavut', 'Ontario', 'Prince Edward Island', 'Quebec', 'Saskatchewan', 'Yukon'],
  'US': ['Alabama', 'Alaska', 'Arizona', 'Arkansas', 'California', 'Colorado', 'Connecticut', 'Delaware', 'District of Columbia', 'Florida', 'Georgia', 'Hawaii', 'Idaho', 'Illinois', 'Indiana', 'Iowa', 'Kansas', 'Kentucky', 'Louisiana', 'Maine', 'Maryland', 'Massachusetts', 'Michigan', 'Minnesota', 'Mississippi', 'Missouri', 'Montana', 'Nebraska', 'Nevada', 'New Hampshire', 'New Jersey', 'New Mexico', 'New York', 'North Carolina', 'North Dakota', 'Ohio', 'Oklahoma', 'Oregon', 'Pennsylvania', 'Rhode Island', 'South Carolina', 'South Dakota', 'Tennessee', 'Texas', 'Utah', 'Vermont', 'Virginia', 'Washington', 'West Virginia', 'Wisconsin', 'Wyoming'],
  'GB': ['England', 'Scotland', 'Wales', 'Northern Ireland'],
};

final _postal = <String, RegExp>{
  'CA': RegExp(r'^[ABCEGHJ-NPRSTVXY]\d[A-Z] ?\d[A-Z]\d$'),
  'US': RegExp(r'^\d{5}(-\d{4})?$'),
  'GB': RegExp(r'^[A-Z]{1,2}\d[A-Z\d]? ?\d[A-Z]{2}$'),
};

bool postalValid(String country, String value) => _postal[country]?.hasMatch(value.trim().toUpperCase()) ?? false;
