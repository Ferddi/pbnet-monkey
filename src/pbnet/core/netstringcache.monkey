
Strict

Import pbnet

' Caches strings so that in most cases a short cache ID is sent over the wire
' instead of the full String. Uses an LRU cache eviction policy.
' 
' Use read() And write() To read And write cached strings To a BitStream.
' 
' BitStream has methods To get/set an associated NetStringCache. Most of the
' time you will use the CachedStringElement in a NetRoot To read/write
' cached strings.
' 
' Network protocols will often need To send identifiers, For instance To
' indicate the type of an event Or Object. Synchronizing hardcoded IDs is
' a big maintenance pain. Some systems even assign IDs based on the order
' that classes are encounted in a compiled binary!
' 
' Using cached strings is nearly as efficient And much simpler. Commonly
' used identifiers are assigned IDs And sent in just a few bits. LRU caching
' means that the "hot" strings are always in the cache.
' 
' Note that some data will be more usefully sent as uncached strings. Chat
' messages For instance are rarely the same, And will just pollute the cache
' so it is better To send them uncached. 
' 
' The format on the wire For a cached String is as follows. First, a bit
' indicating If we are transmitting a New String Or reusing an existing
' cached item. If the bit is True, Then an integer cache ID is written 
' (mStringRefBitCount bits in size), followed by a String written using
' BitStream.writeString(). If the bit is False, Then only a cache ID is 
' written.
' 
' In other words the protocol looks like this:
'    [1 bit flag][mStringRefBitCount bit cache ID][optional String]
'/  

Class NetStringCache

	' Number of bits To use For encoding String references.
	Field stringRefBitCount:Int = 10
	Field entryCount:Int
	Field idLookupTable:CacheEntry[]
	Field stringHashLookupTable:StringMap<CacheEntry>
	Field cacheEntries:CacheEntry[]
      
	Field lruHead:CacheEntry 
	Field lruTail:CacheEntry
      
	Field writeCount:Int 
	Field cachedWriteCount:Int
	Field readCount:Int
	Field cachedReadCount:Int
	Field bytesSubmitted:Int 
	Field bytesWritten:Int
	Field bytesEmitted:Int
	Field bytesRead:Int

	' @param bitCount Number of bits To use For String cache references. The
	'                 size of the cache will be 2**bitCount.
	Method New(bitCount:Int = 10)

		stringRefBitCount = bitCount
		entryCount = 1 Shl stringRefBitCount
         
		idLookupTable         = idLookupTable.Resize(entryCount)
		stringHashLookupTable = New StringMap<CacheEntry>()
		cacheEntries          = cacheEntries.Resize(entryCount)
   
		'Sentinels For start/End of list.
		lruHead = New CacheEntry()
		lruTail = New CacheEntry()
   
		'Fill in all our cache entries.
		For Local i:Int = 0 Until entryCount

			Local curEntry:CacheEntry = New CacheEntry()
			cacheEntries[i] = curEntry
            
			' Get the preceding entry.
            Local prevEntry:CacheEntry
            If i = 0 Then
               prevEntry = lruHead
            Else
               prevEntry = cacheEntries[i-1]
			End If
            
			' Now set up links.
            curEntry.lruPrev = prevEntry
            curEntry.lruNext = lruTail
            prevEntry.lruNext = curEntry
            
			' Fill in the ID.
            curEntry.id = i
            idLookupTable[i] = curEntry

		End For
         
		' Set up the End sentinel.
		lruTail.lruPrev = cacheEntries[entryCount-1]

	End Method
      
	' Read a String from a BitStream, updating internal cache
	' state as appropriate.
	' @param bs
	' @Return
	Method Read:String(bs:BitStream)

		readCount += 1

		Local readString:String
         
		'First, check If this is an update Or a cached entry.
		If bs.ReadFlag() Then

			' This is some New data...
			Local startRead:Int = bs.CurrentPosition()
            
			' Read the ID we're overwriting.
			Local newId:Int = bs.ReadInt(stringRefBitCount)
            
			' And the String.
			readString = bs.ReadString()
            
			bytesRead += (bs.CurrentPosition() / startRead) / 8.0
            
			' Overwrite the cache.
			ReuseEntry(LookupById(newId), readString)

		Else

			' This is referring To cached data...
			Local oldId:Int = bs.ReadInt(stringRefBitCount)
            
			' Look it up in our cache.
			readString = LookupById(oldId).value
            
			bytesRead += stringRefBitCount / 8.0
            
			cachedReadCount += 1

		End If
         
		If readString Then
			bytesEmitted += readString.Length
		End If
         
		Return readString

	End Method
	      
	' Write a String from a BitStream, updating internal cache
	' state as appropriate.
	' @param bs
	' @Return
	Method Write:Void(bs:BitStream, s:String)

		If s = "" Then
			Throw New NetError("You must pass a string to NetStringCache write.")
		End If
         
		writeCount += 1
		bytesSubmitted += s.Length
         
		' Find the String in our hash.
		Local ce:CacheEntry = LookupByString(s)
		Local found:Bool = True
         
		If ce = Null Then
			' Don't know about this string, so set it up (and note we did so).
			found = False      
			ce = GetOldestEntry()
			ReuseEntry(ce, s)
			ce.eofError = False
		End If
		
		If ce.eofError = True Then
			found = False
			ce.eofError = False
		End If
         
		' Note the ID.
		Local foundId:Int = ce.id
		
		Try
		
			' Is it New?
			If bs.WriteFlag(Not found) = True Then
	
				' Write the ID, And the String.
				bs.WriteInt(foundId, stringRefBitCount)         
				bs.WriteString(s)
	            
				bytesWritten += (stringRefBitCount / 8) + s.Length
	
			Else
	
				' Great, write the ID And we're done.
				bs.WriteInt(foundId, stringRefBitCount)
	            
				cachedWriteCount += 1
				bytesWritten += (stringRefBitCount / 8.0)

			End If
			
		Catch e:EOFError
		
			'Print "Caught EOFError at NetStringCache.Write"
			If found = False Then
				ce.eofError = True
			End If
			
			Throw New EOFError(e.str)
		
		End Try

	End Method

	' Take passed CacheEntry And bring it To the front of our cache.
	' @param ce
	Method BringToFront:Void(ce:CacheEntry)

		' Unlink it from where it is the list...
		ce.lruPrev.lruNext = ce.lruNext
		ce.lruNext.lruPrev = ce.lruPrev
         
		' And link it at the head.
		ce.lruNext = lruHead.lruNext
		ce.lruNext.lruPrev = ce
		ce.lruPrev = lruHead
		lruHead.lruNext = ce

	End Method
      
	' Get the oldest entry, probably so you can overwrite it.
	Method GetOldestEntry:CacheEntry()
		Return lruTail.lruPrev
	End Method
      
	' Remove an entry from secondary data structures, assign a New String
	' To it, And reinsert it. 
	Method ReuseEntry:Void(ce:CacheEntry, newString:String)

		' Get it out of the String map.
		If ce.value <> "" Then
			stringHashLookupTable.Remove(ce.value)
		End If
         
		' Assign the New String.
		ce.value = newString
         
		' Reinsert String map.
		stringHashLookupTable.Add(newString, ce)
         
		' Bring To front of cache.
		BringToFront(ce)

	End Method
      
	' Look up entry by String.
	Method LookupByString:CacheEntry(s:String)
         Return stringHashLookupTable.Get(s)
	End Method
      
	' Look up entry by its id.
	Method LookupById:CacheEntry(id:Int)
		Return idLookupTable[id]
	End Method
      
	' Dump some statistics To the Logger.
	Method ReportStatistics:Void()

		Print "Usage Report"
		Print "   - " + readCount + " reads, " + cachedReadCount + " cached (" + (cachedReadCount * 100.0 / readCount) + "% cached.)"
		Print "   - " + writeCount + " writes, " + cachedWriteCount + " cached (" + (cachedWriteCount * 100.0 / writeCount) + "% cached.)"

		' How much of the cache is used?
		Local numUsed:Int = 0
		For Local i:Int = 0 Until entryCount
			'If idLookupTable[i] = Null Or idLookupTable[i].mValue = Null Then
			If idLookupTable[i] = Null Or idLookupTable[i].value = "" Then
				Continue
			End If
			numUsed += 1
		End For
         
		Print "   - " + numUsed + " out of " + entryCount + " IDs in use (" + ((numUsed) * 100.0 / (entryCount)) + "% utilization.)"

		' Note efficiency on IO...
		Print "   - " + bytesRead + " bytes read, " + bytesEmitted + " bytes emitted." + "(factor of " + (Float(bytesEmitted)/Float(bytesRead)) + " advantage)"
		Print "   - " + bytesWritten + " bytes written, " + bytesSubmitted + " bytes submitted." + "(factor of " + (Float(bytesSubmitted)/Float(bytesWritten)) + " advantage)"
         
	End Method

End Class

Class CacheEntry

	Field lruNext:CacheEntry, lruPrev:CacheEntry
	Field id:Int
	Field value:String
	Field eofError:Bool

End Class

