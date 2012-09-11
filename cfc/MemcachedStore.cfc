/*------------------------------------------------------------------------------
Author 	    : 	Aaron Greenlee
				This work is licensed under a Creative Commons Attribution-Share-Alike 3.0 Unported License
				http://wreckingballmedia.com/
				
Description : 	A ColdBox ObjectStore that supports the Memcached database as
				well as the Amazone ElastiCache service.
					
				Many thanks go to Job Hurschi for his contribution to our
				community with the release of cfmemcached (download it at:
				http://cfmemcached.riaforge.org/) with which this source code
				is based. 
------------------------------------------------------------------------------*/

/** CacheBox Object Store supporting native Memcached and Amazon ElastiCache. **/
component
output=false
hint="I work with Memcached directly to store and obtain objects from your cache. I work hared. Love me."
implements="coldbox.system.cache.store.IObjectStore"
{			
	// Endpoints used by the Memcached Client.
	variables.config =
	{
		 'endpoints' = ''
		,'defaultTimeoutUnit' = 'MILLISECONDS'
		,'defaultRequestTimeout' = 400
		,'defaultTimeoutValue' = 500
		,'dotNotationPathToCFCs' = ''
		,'skipLookupDoubleGet' = true
	};
	
	variables.instance = {};

	/**
		@cacheProvider The associated cache provider as coldbox.system.cache.ICacheProvider.
	**/
	public MemcachedStore function init(required cacheProvider)
	{
		var strings = {
			 badConfig = 'Invalid MemcachedStore Configuratrion'
			,noCreate = 'Error creating MemcachedStore!'
		};
		
		// Flag to determine if we've activated an instance of Memcache...
		variables.active = false;
		
		// Import the configuration options from the ColdBox CacheProvider
		var config = arguments.cacheProvider.getConfiguration();
		
		// Verify the imported config has the keys we need
		var requiredConfigKeys = ['awsSecretKey','awsAccessKey','discoverEndpoints','endpoints','skipLookupDoubleGet'];
		var missingKeys = [];
		for(var k in requiredConfigKeys) if (!structKeyExists(config,k)) arrayAppend(missingKeys,k);

		// Save our instance copy of the config.
		structAppend(variables.config,config,true);
		
		// Validate the config...
		//
		// Require All Config Keys
		if (!arrayIsEmpty(missingKeys)) throw(message=strings.noCreate,detail='The MemcachedStore needs some information to be passed via the CacheBox.cfc settings file when a provider is defined for this cache. These settings would typically be passed as settings when a CacheBox Provider is constructed. The missing configuration settings are: #arrayToList(missingKeys)#.');
		//
		// Make sure we have a known endpoint or have permission to find one.
		variables.config.endpoints = (len(trim(config.endpoints)) > 0) ? config.endpoints : "";
		if (!config.discoverEndpoints && len(variables.config.endpoints) == 0) throw(message=strings.badConfig,detail="You have specified you do not want the MemcachedStore to discover endpoints using your AWS credentials; however, you have not provided any endpoints. The MemcachedStore won't know which server to talk to!");
		//
		// Discover Endpoints?
		if (config.discoverEndpoints)
		{
			// todo... load AWS and ask for endpoints.
			variables.config.endpoints &= '';
		}
		//
		// Do we have valid endpoint's yet? 
		if (len(trim(variables.config.endpoints)) == 0) throw(message="MemcachedStore was unable to determine endpoints.",detail="No endpoints were provided and no active ElastiCache endpoints were discovered.")
		//
		// Are all endpoints valid?
		var invalidEndpoints = [];
		for(var endpoint in listToArray(variables.config.endpoints,' ') ) if (listLen(endpoint,':') != 2 || !isNumeric(listLast(endpoint,':'))) arrayAppend(invalidEndpoints,endpoint); 
		if (!arrayIsEmpty(invalidEndpoints)) throw(message="MemcachedStore rejected endpoints.",detail='The following endpoint(s) do not appear to be valid. Expecting something like 127.0.0.1:{11233} or aws-really-long-128.00.11.11-name.elasticache.com. The rejected endpoints are #arrayToList(invalidEndpoints)#.');
		
		// 
		variables.instance.indexer = createObject("component","#variables.config.dotNotationPathToCFCs#.MemcachedIndexer").init("");

		debug("MemcachedStore:init();");

		return this;	
	}

	public void function flush(){
		debug("MemcachedStore:Flush();");
	}
	public void function reap(){
		debug("MemcachedStore:Reap();");
	}
	public void function clearAll()
	{
		// Ensure Memcached Exists
		if (!variables.active) build("memcached");
		
		debug("MemcachedStore:ClearAll();");
	}
	public any function getIndexer()
	{
		debug("MemcachedStore:getIndexer();");
		return variables.instance.indexer;
	}
	public any function getKeys()
	{
		debug("MemcachedStore:getKeys();");
		
		return [];
	}
	public any function lookup(
		required any objectKey
	){
		// Ensure Memcached Exists
		if (!variables.active) build("memcached");
		
		debug("MemcachedStore:lookup(#arguments.objectKey#);");

		writeDump(var=get(objectKey=arguments.objectKey),top=3,abort=false,output="console");

		return (isNull(get(objectKey=arguments.objectKey))) ? false : true;
	}
	public any function get(
		required any objectKey
	){
		// Ensure Memcached Exists
		if (!variables.active) build("memcached");
		
		debug("MemcachedStore:get(#arguments.objectKey#);");
		
		return blockingGet(arguments.objectKey);
	}
	public any function getQuiet(
		required any objectKey
	){
		// Ensure Memcached Exists
		if (!variables.active) build("memcached");
		
		debug("MemcachedStore:getQuiet(#arguments.objectKey#);");
		return get(objectKey=arguments.objectKey);
	}
	public void function expireObject(
		required any objectKey
	){
		// Ensure Memcached Exists
		if (!variables.active) build("memcached");
		
		debug("MemcachedStore:expireObject(#arguments.objectKey#);");
	}
	public any function isExpired(
		required any objectKey
	){
		// Ensure Memcached Exists
		if (!variables.active) build("memcached");
		
		debug("MemcachedStore:isExpired(#arguments.objectKey#);");
	}
	
	public void function set(
		 required any objectKey
		,required any object
		,any timeout=35
		,any lastAccessTimeout=''
		,any extras
	){
		// Ensure Memcached Exists
		if (!variables.active) build("memcached");
		
		debug("MemcachedStore:set(#arguments.objectKey#);");
		
		blockingSet(
			 key=arguments.objectKey
			,value=arguments.object
			,expiry=500
		);
		
		return;
	}
	public any function clear(
		required any objectKey
	){
		debug("MemcachedStore:clear(#arguments.objectKey#);");
	}
	/** Return the number of items stored within Memcached. **/
	public any function getSize(){
		var Memcached = build("memcached");

		var stats = convertHashMapToStruct(Memcached.getStats());
		
		var r = 0;
		for(var machine in stats) r += convertHashMapToStruct(stats[machine]).total_items;
		
		return r;
	}

	// -------------------------------------------------------------------------
	// PRIVATE
	// -------------------------------------------------------------------------
	
	/**
		A mini factory to build objects. Ensures only one Singleton is created
		for our Memcached client and acts as a proxy for other builds to help
		facilitate unit testing.
		
		@alias An alias for the factory.
	**/
	private any function build(required string alias){
		switch(arguments.alias)
		{
			// Special handling for our Memcached interface to ensure we 
			// only create one singleton.
			case 'memcached':
				// Does this singleton exist? If so, just return.
				if (structKeyExists(variables.instance,arguments.alias)) return variables.instance[arguments.alias];

				// Begin construction...
				lock name="MemcachedStoreBuilding#arguments.alias#" timeout="25"
				{
					// If we were queued we don't need to create...
					if (structKeyExists(variables.instance,'Memcached')) return variables.instance[arguments.alias];
					
					// Build it!
					lock name="MemcachedStoreBuilding#arguments.alias#_StepTwo" timeout="25"
					{
						return buildMemcached(); break;
					}
				}
			break;

			case 'AddrUtil':
				return createObject("java","net.spy.memcached.AddrUtil");
			break;
			case 'MemcachedClient':
				return createObject("java","net.spy.memcached.MemcachedClient");
			break;
			case 'TimeUnit':
				return CreateObject("java", "java.util.concurrent.TimeUnit");
			break;
			case 'ByteArrayOutputStream':
				return CreateObject("java", "java.io.ByteArrayOutputStream");
			break;
			case 'ObjectOutputStream':
				return CreateObject("java", "java.io.ObjectOutputStream");
			break;
			case 'FutureTask':
				return createObject("component","#variables.config.dotNotationPathToCFCs#.FutureTask");
			break;			
			
			default:
				throw(message="MemcachedStore internalFactory was unable to produce!",detail="Trying to produce alias #arguments.alias#");
			break;
		}
	}
	
	/**
		Build a new Memcached client instance. The result is saved within the
		instance of this MemcachedStore and returned by this method.
		
		@servers A space delimited list of servers the Memcached client should connect to.
	**/
	private any function buildMemcached(){
		if (!structKeyExists(variables.config,'endpoints') || trim(len(variables.config.endpoints)) == 0);
		if (!structKeyExists(variables.instance,'AddrUtil')) variables.instance.addrUtil = build("AddrUtil").init();

		variables.instance.memcached = build("MemcachedClient").init(variables.instance.addrUtil.getAddresses(variables.config.endpoints));
		variables.instance.timeUnit = build("TimeUnit");
		variables.instance.transcoder = variables.instance.memcached.getTranscoder();
	
		variables.active = true;
	
		return variables.instance.memcached;
	}
	
	/** Convert the configured time unit into a Java Time Unit type. **/
	private any function getTimeUnitType(required string timeUnit)
	{
		switch(arguments.timeunit)
		{
			case 'nanoseconds' : return variables.timeunit.NANOSECONDS; break;
			case 'microseconds' : return variables.timeunit.MICROSECONDS; break;
			case 'milliseconds' : return variables.timeunit.MILLISECONDS; break;
			
			case 'SECONDS' :
			default :
				return variables.timeunit.SECONDS;
			break; 
		}
	}
	
	/** Serialize objects for storage in Memcached. Returns simple objects
		as-is, otherwise, converts objects into a ByteArray. **/
	private any function serialize(required any value)
	{
		if (isSimpleValue(arguments.value))	return arguments.value;
		
		var ByteArrayOutputStream = build("ByteArrayOutputStream").init();
		var ObjectOutputStream = build("ObjectOutputStream").init(ByteArrayOutputStream);
		
		ObjectOutputStream.writeObject(arguments.value);
		var result = ByteArrayOutputStream.toByteArray();
		
		ObjectOutputStream.close();
		ByteArrayOutputStream.close();
		
		return result;
	}
	
	/** Deserializes the given value from a byte stream.
		Includes support for multiple keys being returned
		
		@value The value to deserialize. 
	**/
	private any function deserialize()
	{
		var ret = "";
		var byteInStream = CreateObject("java", "java.io.ByteArrayInputStream");
		var objInputStream = CreateObject("java", "java.io.ObjectInputStream");
		var keys = "";
		var i =1;
		// all these trys in here are to catch null values that come across from java
		if ( isStruct(arguments.value) )	{
			// got a struct here.  go over the struct of keys and return
			// values for each of the items
			ret = structNew();
			keys = listToArray(structKeyList(arguments.value));
			for (i=1; i lte arrayLen(keys);i=i+1)	{
				try 	{
					if (structKeyExists(arguments.value,keys[i]))	{
						ret[keys[i]] = doDeserialize(arguments.value[keys[i]],objInputStream,byteInStream);
					} else {
						ret[keys[i]] = "";
					}
				} catch(Any excpt)	{
					ret[keys[i]] = "";
				}
			}
		}  else if ( isArray(arguments.value) and not isBinary(arguments.value) )	{
			// if the returned value is an array, then we need to loop over the array
			// and return the value  we have to check against the isBinary
			// because apparently coldfusion can't differentiate between an array and a binary
			// value
			ret = arrayNew(1);
			for (i=1; i lte arrayLen(arguments.value); i=i+1)	{
				try	{
					// this try is necessary because null values can be returned
					// from java and this is the only way we have to check for them
					arrayAppend(ret,doDeserialize(arguments.value[i],objInputStream,byteInStream));	
				} catch (Any excpt)	{
					arrayAppend(ret,"");
				}
			}
		} else {
			// we either got a simple value here or we've gotten nothing returned
			// if we get an empty value, then we pretty much assume that it's 
			// a bum value and we'll return a false
			try {
				ret = doDeserialize(arguments.value,objInputStream,byteInStream);
			} catch(Any excpt)	{
				ret = "";
			}
		}
	}
	
	/**
		Add an object to the cache if it does not exist already. Returns a
		future representing the processing of this operation.
		
		@key The key to cache. Keys are case-sensitive.
		@value The value to cache.
		@expiry The exp value is passed along to memcached exactly as given, and will be processed per 
		the memcached protocol specification: 

		The actual value sent may either be Unix time 
		(number of seconds since January 1, 1970, as a 32-bit value), 
		or a number of seconds starting from current time. 
		In the latter case, this number of seconds may not 
		exceed 60*60*24*30 (number of seconds in 30 days); 
		if the number sent by a client is larger than that, the server will consider it to be 
		real Unix time value rather than an offset from current time. 
	**/
	private function add(
		 required string key
		,required any value
		,numeric expiry=0
	){
		var futureTask = "";
		var ret = "";
		try {
			ret = variables.instance.memcached.add(arguments.key, arguments.expiry, serialize(arguments.value) );
		} catch (Any e)	{
			rethrow;
			// failing gracefully
		}
		return build("futuretask").init(ret);
	}
	
	/** 
		Get the given key asynchronously. returns the future value of those keys
		what you get back wht you use this function is an object that has the future value
		of the key you asked to retrieve.  You can check at anytime to see if the value has been
		retrieved by using the  ret.isDone() method. once you get a true from that value, you 
		need to then call the ret.get() function.
		
		@key Given a key, get the value for the key asnycronously. Case-Sensitive.
	**/
	private any function asyncGet(required string key)
	{
		var ret = "";
		var futureTask ="";
		// gotta go through all this to catch the nulls.
		try	{
			ret = variables.instance.memcached.asyncGet(arguments.key);
			// additional processing might be required.
		} catch(Any e)	{
			// failing gracefully
			rethrow;
		}
		return createObject("component","#variables.config.dotNotationPathToCFCs#.FutureTask").init(ret);
	}
	
	/**
		Get with a single key. Blocks until the server responds.
	**/
	private any function blockingGet(
		 required key
		,numeric timeout
		,string timeoutUnit
	){
		if (!structKeyExists(arguments,'timeout')) arguments.timeout = variables.config.defaultTimeoutValue;
		if (!structKeyExists(arguments,'timeoutUnit')) arguments.timeoutUnit = variables.config.defaultTimeoutUnit;

		// If we already looked up this value within the request just return it.
		// This prevents double cache-hits by the ColdBox framework since it looks up
		// a value before returning it and Memcached can't do that.		
		if (variables.config.skipLookupDoubleGet)
		{
			var requestCacheExists = structKeyExists(request,'MemcachedAccelerator');
			if (requestCacheExists && structKeyExists(request.MemcachedAccelerator,arguments.key) && !isNull(request.MemcachedAccelerator[arguments.key])) return request.MemcachedAccelerator[arguments.key];
		}
		
		var result = variables.instance.memcached.asyncGet(arguments.key);	
		if (!isNull(result))
		{
			var futureTask = createObject("component","#variables.config.dotNotationPathToCFCs#.FutureTask").init(result);
			var result = futureTask.get(timeout=arguments.timeout,timeoutUnit=arguments.timeoutUnit);
		}
		
		if (isNull(result)) return JavaCast("null","");

		// Cache within the request if we are accelerating our double lookups
		if (variables.config.skipLookupDoubleGet)
		{		
			if (!requestCacheExists) request.MemcachedAccelerator = {};
			request.MemcachedAccelerator[arguments.key] = result;
		}
		
		return result;		
	}	
	/**
		Shortcut to delete that will immediately delete the item from the cache. 
		or in the delay specified. returns a future object that allows you to 
		check back on the processing further if you choose.
	**/
	private any function delete(
		 required key
		,numeric delay=0
	){
		var ret = false;
		var futureTask = "";
		try 	{
			if (arguments.delay gt 0)	{
				ret = variables.instance.memcached.delete(arguments.deletekey,arguments.delay);
			} else {
				ret = variables.instance.memcached.delete(arguments.deletekey);
			}
		}  catch (Any e)	{
			// failing gracefully
			rethrow;
			ret = "";
		}
		if (isdefined("ret"))	{
			return createobject("component","#variables.config.dotNotationPathToCFCs#.FutureTask").init(ret);
		}  else {
			return createobject("component","#variables.config.dotNotationPathToCFCs#.FutureTask").init();
		}
	}
	
	private any function blockingSet(
		 required string key
		,required any value
		,numeric expiry=0
	){
		var futureTask = "";
		var ret = "";
		try 	{
			ret = variables.instance.memcached.set(arguments.key,arguments.expiry,serialize(arguments.value));
		}  catch (Any e)	{
			rethrow;
			// failing gracefully
			ret = "";
		}
		
		//var d = directoryList(expandPath('/app'));
		//writeDump(d);abort;
		
		return createObject("component","#variables.config.dotNotationPathToCFCs#.FutureTask").init(ret);
	}
	
	/**
		@timeout Defaults to no-timeout. Defines how many units of the TimeoutUnit before a timeout occurs.
		@timeoutUnit AN instance of java.util.concurrent.TimeUnit.
	**/
	private any function shutdown(
		 numeric timeout=0
		,string timeoutUnit
	){
		if (!variables.active || !structKeyExists(variables.instance,'memcached')) return false;
				
		if (!structKeyExists(arguments,'timeoutUnit')) arguments.timeoutUnit = variables.config.defaultRequestTimeout;

		if (arguments.timeout > 0) return variables.instance.memcached.shutdown(arguments.timeout,arguments.timeUnit);
		
		variables.active = false;
		return variables.instance.memcached.shutdown();
	}
	
	private struct function convertHashMapToStruct(required hashMap)
	{
		var theStruct = structNew();
		var key = "";
		var newStructKey = ""; 
		var keys = arguments.hashMap.keySet();
		var iter = keys.Iterator();
		
		while(iter.HasNext()) {
			key = iter.Next();
			newStructKey = key.toString();
			theStruct[newStructKey] = arguments.hashMap.get(key);
		}
		
		return theStruct;
	}
	
	private function debug(string m)
	{ 
		writeDump(var="------> " & arguments.m,output='Console');
	}
}

