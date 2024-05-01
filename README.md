# light-phone-note-to-self

> A simple script to fetch the most recent Notes from your Light Phone and send them to yourself via Email

## Background & Vision



## Installation

1. `git clone https://github.com/KrauseFx/light-phone-note-to-self`
1. `cd light-phone-note-to-self`
1. `bundle install`
1. `cp .env.example .env`

## Configuration

```sh
# Login on https://dashboard.thelightphone.com/ and copy the token from the network tab, including the "Bearer " prefix
export BEARER_TOKEN="Bearer ..."

# Select your device from the Light Phone dashboard, and copy the device ID from the URL
export DEVICE_TOOL_ID=""

# Your Sendgrid API key
export SENDGRID_BEARER_TOKEN="Bearer ..."

# The email address you want to send from
export SENDGRID_FROM=""

# The email address you want to send to
export SENDGRID_TO=""
```

## Usage

```sh
bundle exec ruby run.rb
```

## Run on a schedule

There are many different ways to run scripts on a schedule, for example using `cron` on macOS or Linux. To run the script every hour, you can use the following steps:

1. `crontab -e`
1. Add a new line with the following content: `0 * * * * /bin/bash -l -c 'cd /path/to/light-phone-note-to-self && source .env && bundle exec ruby run.rb'`


