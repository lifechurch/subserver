Subserver
==============

[![Gem Version](https://badge.fury.io/rb/subserver.svg)](https://rubygems.org/gems/subserver)
[![Build Status](https://travis-ci.com/lifechurch/subserver.svg?branch=master)](https://travis-ci.com/lifechurch/subserver)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](./CONTRIBUTING.md)

Subserver is a background server process for processing messages from Google Pub/Sub.

Subserver was designed to be an efficient, configurable process that easily integrates into any ruby app. 
It is built as a wrapper around [Google's Pub/Sub gem](https://github.com/GoogleCloudPlatform/google-cloud-ruby/tree/master/google-cloud-pubsub) and
provides:
- Threaded multi-subscription support
- Message processing middleware.
- Auto subscriber loading.
- Per subscriber configuration.
- Error handling and logging. 

Subserver is based off of [Sidekiq](https://github.com/mperham/sidekiq). A huge thanks to [@mperham](https://github.com/mperham) and the Sidekiq contributers for giving Subserver an incredible foundation to build off of.

## Requirements
Subserver Supports:
- Ruby >= 2.4.0
- All Rails releases >= 4.0
- Google Cloud PubSub Ruby >= 1.7.0

## Getting Started
### Install
```
gem install subserver
```
Checkout the [Getting Started](https://github.com/lifechurch/subserver/wiki/Getting-Started) page in the wiki to follow the setup for Subserver.

## Contributing

The main purpose of this repository is to continue to grow the Subserver gem, making it faster and easier to use and more robust. Development of Subserver happens in the open on GitHub, and we look forward to working with many talented developers on this project. Read below to learn how you can take part in improving Subserver.

### Contributing Guide

Read our [contribution guide](./CONTRIBUTING.md) to learn about our development process, how to propose bugfixes and improvements, and how to build and test your changes to Subserver.

### License

Subserver is [MIT licensed](./LICENSE).

## Open Digerati

This project is part of the Open Digerati initiative at [Life.Church](https://life.church). It's our belief that we can move faster together and that starts with irrational generosity so we are opening up our code to the community. 

To find more projects like this one, or join the initiative, checkout our website at [opendigerati.com](https://www.opendigerati.com/).

