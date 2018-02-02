# Twilio List Lookup

## Setup

Install git:
```
git status
```

Install Homebrew:
```
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```

Install Elixir:
```
brew install elixir
```

Clone the repository:
```
git clone https://github.com/justicedemocrats/twilio_list_lookup.git
```

Enter the repositories directory:
```
cd twilio_list_lookup
```

Create the data directory:
```
mkdir data
```

Open the config directory:
```
open config/
```

Paste the secrets.exs in there that you get from Ben.

Install Elixir dependencies:
```
mix deps.get
```

## Usage

Now, you can paste the your csv inside data:
```
open data
```

Paste the csv, which we'll assume is called `your-csv.csv` in there – 

Now, you can run:
```
mix run_lookup data/your-csv.csv
```

At the end of the script being run, you should see:
```
14 lookups performed
```

but something else instead of 14 - record that number.

And after you run:
```
open data/
```

You should see `your-csv-mobile.csv`, `your-csv-landline.csv`,
`your-csv-processed.csv`, etc. Those are your results!
