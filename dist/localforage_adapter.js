(function() {
  "use strict";
  DS.LSAdapter = DS.Adapter.extend(Ember.Evented, {

    /*
    This is the main entry point into finding records. The first parameter to
    this method is the model's name as a string.
    
    @method find
    @param {DS.Model} type
    @param {Object|String|Integer|null} id
     */
    find: function(store, type, id, opts) {
      var adapter, allowRecursive, namespace;
      adapter = this;
      allowRecursive = true;
      namespace = this._namespaceForType(type);

      /*
      In the case where there are relationships, this method is called again
      for each relation. Given the relations have references to the main
      object, we use allowRecursive to avoid going further into infinite
      recursiveness.
      
      Concept from ember-indexdb-adapter
       */
      if (opts && typeof opts.allowRecursive !== "undefined") {
        allowRecursive = opts.allowRecursive;
      }
      return new Ember.RSVP.Promise(function(resolve, reject) {
        return namespace.then(function(value) {
          var record;
          record = Ember.A(value.records[id]);
          if (allowRecursive && !Ember.isEmpty(record)) {
            return adapter.loadRelationships(type, record).then(function(finalRecord) {
              return Ember.run(null, resolve, finalRecord);
            });
          } else {
            if (Ember.isEmpty(record)) {
              return Ember.run(null, reject);
            } else {
              return Ember.run(null, resolve, record);
            }
          }
        });
      });
    },
    findMany: function(store, type, ids) {
      var adapter, namespace;
      adapter = this;
      namespace = this._namespaceForType(type);
      return new Ember.RSVP.Promise(function(resolve, reject) {
        return namespace.then(function(value) {
          var i, results;
          results = [];
          i = 0;
          while (i < ids.length) {
            results.push(Ember.copy(value.records[ids[i]]));
            i++;
          }
          return Ember.run(null, resolve, results);
        }).then(function(records) {
          if (records.get("length")) {
            return adapter.loadRelationshipsForMany(type, records);
          } else {
            return records;
          }
        });
      });
    },
    findQuery: function(store, type, query, recordArray) {
      var adapter, namespace;
      namespace = this._namespaceForType(type);
      adapter = this;
      return new Ember.RSVP.Promise(function(resolve, reject) {
        return namespace.then(function(value) {
          var results;
          results = adapter.query(value.records, query);
          if (results.get("length")) {
            results = adapter.loadRelationshipsForMany(type, results);
          }
          return Ember.run(null, resolve, results);
        });
      });
    },
    query: function(records, query) {
      var id, property, push, record, results, test;
      results = [];
      id = void 0;
      record = void 0;
      property = void 0;
      test = void 0;
      push = void 0;
      for (id in records) {
        record = records[id];
        for (property in query) {
          test = query[property];
          push = false;
          if (Object.prototype.toString.call(test) === "[object RegExp]") {
            push = test.test(record[property]);
          } else {
            push = record[property] === test;
          }
        }
        if (push) {
          results.push(record);
        }
      }
      return results;
    },
    findAll: function(store, type) {
      var namespace, results;
      namespace = this._namespaceForType(type);
      results = [];
      return new Ember.RSVP.Promise(function(resolve, reject) {
        return namespace.then(function(value) {
          var id;
          for (id in value.records) {
            results.push(Ember.copy(value.records[id]));
          }
          return Ember.run(null, resolve, results);
        });
      });
    },
    createRecord: function(store, type, record) {
      var adapter, namespace;
      namespace = this._namespaceForType(type);
      adapter = this;
      return new Ember.RSVP.Promise(function(resolve, reject) {
        return namespace.then(function(value) {
          var recordHash;
          recordHash = record.serialize({
            includeId: true
          });
          value.records[recordHash.id] = recordHash;
          return adapter.persistData(type, value).then(function(record) {
            return Ember.run(null, resolve);
          });
        });
      });
    },
    updateRecord: function(store, type, record) {
      var adapter, id, namespace;
      namespace = this._namespaceForType(type);
      id = record.get("id");
      adapter = this;
      return new Ember.RSVP.Promise(function(resolve, reject) {
        return namespace.then(function(value) {
          value.records[id] = record.serialize({
            includeId: true
          });
          return adapter.persistData(type, value).then(function(value) {
            return Ember.run(null, resolve);
          });
        });
      });
    },
    deleteRecord: function(store, type, record) {
      var adapter, id, namespaceRecords;
      namespaceRecords = this._namespaceForType(type);
      id = record.get("id");
      adapter = this;
      return new Ember.RSVP.Promise(function(resolve, reject) {
        return namespaceRecords.then(function(value) {
          delete value.records[id];
          return adapter.persistData(type, value).then(function(value) {
            return Ember.run(null, resolve);
          });
        });
      });
    },
    generateIdForRecord: function() {
      return Math.random().toString(32).slice(2).substr(0, 5);
    },
    adapterNamespace: function() {
      return this.namespace || "DS.LSAdapter";
    },
    loadData: function() {
      var storage;
      storage = this._adapter().getItem(this.adapterNamespace());
      if (storage) {
        return storage;
      } else {
        return {};
      }
    },
    persistData: function(type, data) {
      var adapter, localStorageData, modelNamespace;
      modelNamespace = this.modelNamespace(type);
      localStorageData = this.loadData();
      adapter = this;
      return localStorageData.then(function(value) {
        value[modelNamespace] = data;
        return adapter._adapter().setItem(adapter.adapterNamespace(), value);
      });
    },
    _namespaceForType: function(type) {
      var namespace, storage;
      namespace = this.modelNamespace(type);
      storage = this._adapter().getItem(this.adapterNamespace());
      return storage.then(function(value) {
        if (value) {
          return value[namespace] || {
            records: {}
          };
        } else {
          return {
            records: {}
          };
        }
      });
    },
    _adapter: function() {
      return localforage;
    },
    modelNamespace: function(type) {
      return type.url || type.toString();
    },

    /*
    This takes a record, then analyzes the model relationships and replaces
    ids with the actual values.
    
    Stolen from ember-indexdb-adapter
    
    Consider the following JSON is entered:
    
    ```js
    {
    "id": 1,
    "title": "Rails Rambo",
    "comments": [1, 2]
    }
    
    This will return:
    
    ```js
    {
    "id": 1,
    "title": "Rails Rambo",
    "comments": [1, 2]
    
    "_embedded": {
    "comment": [{
    "_id": 1,
    "comment_title": "FIRST"
    }, {
    "_id": 2,
    "comment_title": "Rails is unagi"
    }]
    }
    }
    
    This way, whenever a resource returned, its relationships will be also
    returned.
    
    @method loadRelationships
    @private
    @param {DS.Model} type
    @param {Object} record
     */
    loadRelationships: function(type, record) {
      var adapter;
      adapter = this;
      return new Ember.RSVP.Promise(function(resolve, reject) {
        var relationshipNames, relationshipPromises, relationships, resultJSON, typeKey;
        resultJSON = {};
        typeKey = type.typeKey;
        relationshipNames = void 0;
        relationships = void 0;
        relationshipPromises = [];
        relationshipNames = Ember.get(type, "relationshipNames");
        relationships = relationshipNames.belongsTo;
        relationships = relationships.concat(relationshipNames.hasMany);
        relationships.forEach(function(relationName) {
          var embedPromise, opts, promise, relationEmbeddedId, relationModel, relationProp, relationType;
          relationModel = type.typeForRelationship(relationName);
          relationEmbeddedId = record[relationName];
          relationProp = adapter.relationshipProperties(type, relationName);
          relationType = relationProp.kind;
          promise = void 0;
          embedPromise = void 0;

          /*
          This is the relationship field.
           */
          opts = {
            allowRecursive: false
          };

          /*
          embeddedIds are ids of relations that are included in the main
          payload, such as:
          
          {
          cart: {
          id: "s85fb",
          customer: "rld9u"
          }
          }
          
          In this case, cart belongsTo customer and its id is present in the
          main payload. We find each of these records and add them to _embedded.
           */
          if (relationEmbeddedId) {
            if (relationType === "belongsTo" || relationType === "hasOne") {
              promise = adapter.find(null, relationModel, relationEmbeddedId, opts);
            } else {
              if (relationType === "hasMany") {
                promise = adapter.findMany(null, relationModel, relationEmbeddedId, opts);
              }
            }
            embedPromise = new Ember.RSVP.Promise(function(resolve, reject) {
              return promise.then(function(relationRecord) {
                var finalPayload;
                finalPayload = adapter.addEmbeddedPayload(record, relationName, relationRecord);
                return resolve(finalPayload);
              });
            });
            return relationshipPromises.push(embedPromise);
          }
        });
        return Ember.RSVP.all(relationshipPromises).then(function() {
          return resolve(record);
        });
      });
    },

    /*
    Given the following payload,
    
    {
    cart: {
    id: "1",
    customer: "2"
    }
    }
    
    With `relationshipName` being `customer` and `relationshipRecord`
    
    {id: "2", name: "Rambo"}
    
    This method returns the following payload:
    
    {
    cart: {
    id: "1",
    customer: "2"
    },
    _embedded: {
    customer: {
    id: "2",
    name: "Rambo"
    }
    }
    }
    
    which is then treated by the serializer later.
    
    @method addEmbeddedPayload
    @private
    @param {Object} payload
    @param {String} relationshipName
    @param {Object} relationshipRecord
     */
    addEmbeddedPayload: function(payload, relationshipName, relationshipRecord) {
      var arrayHasIds, isValidRelationship, objectHasId;
      objectHasId = relationshipRecord && relationshipRecord.id;
      arrayHasIds = relationshipRecord.length && relationshipRecord.everyBy("id");
      isValidRelationship = objectHasId || arrayHasIds;
      if (isValidRelationship) {
        if (!payload["_embedded"]) {
          payload["_embedded"] = {};
        }
        payload["_embedded"][relationshipName] = relationshipRecord;
        if (relationshipRecord.length) {
          payload[relationshipName] = relationshipRecord.mapBy("id");
        } else {
          payload[relationshipName] = relationshipRecord.id;
        }
      }
      if (this.isArray(payload[relationshipName])) {
        payload[relationshipName] = payload[relationshipName].filter(function(id) {
          return id;
        });
      }
      return payload;
    },
    isArray: function(value) {
      return Object.prototype.toString.call(value) === "[object Array]";
    },

    /*
    Same as `loadRelationships`, but for an array of records.
    
    @method loadRelationshipsForMany
    @private
    @param {DS.Model} type
    @param {Object} recordsArray
     */
    loadRelationshipsForMany: function(type, recordsArray) {
      var adapter;
      adapter = this;
      return new Ember.RSVP.Promise(function(resolve, reject) {
        var i, loadNextRecord, promises, recordsToBeLoaded, recordsWithRelationships;
        recordsWithRelationships = [];
        recordsToBeLoaded = [];
        promises = [];

        /*
        Some times Ember puts some stuff in arrays. We want to clean it so
        we know exactly what to iterate over.
         */
        for (i in recordsArray) {
          if (recordsArray.hasOwnProperty(i)) {
            recordsToBeLoaded.push(recordsArray[i]);
          }
        }
        loadNextRecord = function(record) {

          /*
          Removes the first item from recordsToBeLoaded
           */
          var promise;
          recordsToBeLoaded = recordsToBeLoaded.slice(1);
          promise = adapter.loadRelationships(type, record);
          return promise.then(function(recordWithRelationships) {
            recordsWithRelationships.push(recordWithRelationships);
            if (recordsToBeLoaded[0]) {
              return loadNextRecord(recordsToBeLoaded[0]);
            } else {
              return resolve(recordsWithRelationships);
            }
          });
        };

        /*
        We start by the first record
         */
        return loadNextRecord(recordsToBeLoaded[0]);
      });
    },

    /*
    @method relationshipProperties
    @private
    @param {DS.Model} type
    @param {String} relationName
     */
    relationshipProperties: function(type, relationName) {
      var relationships;
      relationships = Ember.get(type, "relationshipsByName");
      if (relationName) {
        return relationships.get(relationName);
      } else {
        return relationships;
      }
    }
  });

}).call(this);

(function() {
  "use strict";
  DS.LSSerializer = DS.JSONSerializer.extend({
    serializeHasMany: function(record, json, relationship) {
      var key, relationshipType;
      key = relationship.key;
      relationshipType = DS.RelationshipChange.determineRelationshipType(record.constructor, relationship);
      if (relationshipType === "manyToNone" || relationshipType === "manyToMany" || relationshipType === "manyToOne") {
        return json[key] = record.get(key).mapBy("id");
      }
    },

    /*
    Extracts whatever was returned from the adapter.
    
    If the adapter returns relationships in an embedded way, such as follows:
    
    ```js
    {
    "id": 1,
    "title": "Rails Rambo",
    
    "_embedded": {
    "comment": [{
    "id": 1,
    "comment_title": "FIRST"
    }, {
    "id": 2,
    "comment_title": "Rails is unagi"
    }]
    }
    }
    
    this method will create separated JSON for each resource and then push
    them individually to the Store.
    
    In the end, only the main resource will remain, containing the ids of its
    relationships. Given the relations are already in the Store, we will
    return a JSON with the main resource alone. The Store will sort out the
    associations by itself.
    
    @method extractSingle
    @private
    @param {DS.Store} store the returned store
    @param {DS.Model} type the type/model
    @param {Object} payload returned JSON
     */
    extractSingle: function(store, type, payload) {
      var embeddedPayload, relation, typeName;
      if (payload && payload._embedded) {
        for (relation in payload._embedded) {
          typeName = Ember.String.singularize(relation);
          embeddedPayload = payload._embedded[relation];
          if (embeddedPayload) {
            if (Ember.isArray(embeddedPayload)) {
              store.pushMany(typeName, embeddedPayload);
            } else {
              store.push(typeName, embeddedPayload);
            }
          }
        }
        delete payload._embedded;
      }
      return this.normalize(type, payload);
    },

    /*
    This is exactly the same as extractSingle, but used in an array.
    
    @method extractSingle
    @private
    @param {DS.Store} store the returned store
    @param {DS.Model} type the type/model
    @param {Array} payload returned JSONs
     */
    extractArray: function(store, type, payload) {
      var serializer;
      serializer = this;
      return payload.map(function(record) {
        var extracted;
        extracted = serializer.extractSingle(store, type, record);
        return serializer.normalize(type, record);
      });
    }
  });

}).call(this);
