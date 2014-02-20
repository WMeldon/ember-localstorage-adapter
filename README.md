Ember Data Local Forage Adapter [![Build Status](https://travis-ci.org/WMeldon/ember-localstorage-adapter.png?branch=forage-engine)](https://travis-ci.org/WMeldon/ember-localstorage-adapter)
================================

Store your ember application data in ~~localStorage~~ whatever offline storage is available.

This is a twisted amalgamation of Ryan Florence's [Ember Data Local Storage Adapter](https://github.com/rpflorence/ember-localstorage-adapter) and Mozilla's [localForage](https://github.com/mozilla/localForage).

Compatible with Ember Data 1.0.beta.6.

# This is a very rough experiment

I was curious to try out localForage and wanted to see if I could get a working Ember Data adapter through it.  I forked Ryan Florence's localStorage adapter and then did the bare minimum to get the tests passing.

The biggest change that needed to be made was converting all of the synchronous localStorage interactions to work with the asynchronous API provided by localForage.  It's not 100% yet but I'll continue to tinker to get things running.

## Why localForage

LocalForage leverages newer, asynchronous offline browser solutions whenever it can with a consistent API.  That API happens to be identical to the existing localStorage API, but it provides async interaction.

It's a little more future proof and a lot more Ember-like.

Usage
-----

Include `localforage_adapter.js` in your app and then like all adapters:

```js
App.ApplicationSerializer = DS.LSSerializer.extend();
App.ApplicationAdapter = DS.LSAdapter.extend({
    namespace: 'yournamespace'
});
```

### Local Storage Namespace

All of your application data lives on a single key, it defaults to `DS.LSAdapter` but if you supply a `namespace` option it will store it there:

```js
DS.LSAdapter.create({
  namespace: 'my app'
});
```

### Models

Whenever the adapter returns a record, it'll also return all
relationships, so __do not__ use `{async: true}` in you model definitions.

#### Namespace

If your model definition has a `url` property, the adapter will store the data on that namespace. URL is a weird term in this context, but it makes swapping out adapters simpler by not requiring additional properties on your models.

```js
var List = DS.Model.extend({
  // ...
});
List.reopen({
  url: '/some/url'
});
```

### Quota Exceeded Handler
## This shouldn't really be an issue any more.

Browser's `localStorage` has limited space, if you try to commit application data and the browser is out of space, then the adapter will trigger the `QUOTA_EXCEEDED_ERR` event.

```js
App.store.adapter.on('QUOTA_EXCEEDED_ERR', function(records){
  // do stuff
});

App.store.commit();
```

Todo
----

- Fix that bulk save error (seems to be a false assumtion in the testing logic?)
- Continue to improve the dev environement.
- Misc Cleanups (especially the automatic coffeescript conversion)

Developing
-----

Install the dependencies

    npm install

I'm primarily using [Gulp](https://github.com/gulpjs/gulp) and [Testem](https://github.com/airportyh/testem).

Build from src:

    gulp scripts
    # or do it automatically
    gulp watch

Run the tests

    gulp test
    # or automaticaly
    testem

License & Copyright
-------------------

Copyright (c) 2012 Ryan Florence
MIT Style license. http://opensource.org/licenses/MIT
