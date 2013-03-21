
Import mojo
Import diddy
Import reflection

Class BrickGame Extends App

	' Stuff to do on startup...
	Method OnCreate ()
		' 60 frames per second, please!
		SetUpdateRate 60
	End Method

	' Stuff to do while running...
	Method OnUpdate ()
	End Method

	' Drawing code...
	Method OnRender ()
		Cls 0, 0, 0						' Clear screen
	End Method

End Class

Class NetError Extends Throwable

	Field str:String

	Method New(s:String)

		str = s
		Print s

	End Method
	
	Method ToString:String()
	
		Return str
		
	End Method

End Class

Class EOFError Extends Throwable

	Field str:String

	Method New(s:String)
	
		str = s
		Print s
	
	End Method

	Method ToString:String()
	
		Return str
		
	End Method

End Class




'Class to perform bit-level reads and writes.
Class BitStream
    
    Const BYTE_LENGTH:Int = 8
    
    Field bits:Int[]
	Field currentBit:Int = 0
	Field totalBits:Int = 0
	Field _stringCache:NetStringCache

	'Constructor with an array of data	
	Method New(data:Int[])
	
		bits = bits.Resize(data.Length)
		totalBits = data.Length * BYTE_LENGTH
		Reset()
		
		For Local i:Int = 0 Until data.Length
		
			bits[i] = data[i]
		
		End For
	
	End Method

	'Constructor with just the size of data
	Method New(length:Int)
	
		bits = bits.Resize(length)
		totalBits = length * BYTE_LENGTH
		Reset()
		
		For Local i:Int = 0 Until length
		
			bits[i] = 0
		
		End For
	
	End Method
	
	'Write a bit to the stream and advance to the next bit.
	Method WriteFlag:Bool(value:Bool)
	
		If currentBit >= totalBits Then
			Throw New NetError("Out of bits!")
		End If
		
		If value = True Then
			bits[(currentBit Shr 3)] |= (1 Shl (currentBit & 7))
		Else
			bits[(currentBit Shr 3)] &= ~(1 Shl (currentBit & 7))
		End If
		
		currentBit += 1
		
		Return value
	End Method

	'Read a bit from the stream and advance to the next bit.
	Method ReadFlag:Bool()
	
		If currentBit >= totalBits Then
			Throw New NetError("Out of bits!")
		End If
		
		Local b:Int = bits[(currentBit Shr 3)]
		
		b Shr= (currentBit & 7)
		currentBit += 1
		b &= 1
		
		If b = 1 Then
			Return True
		End If
		
		Return False
	
	End Method

	'Write an 8-bit byte to the stream.
    Method WriteByte:Void(value:Int)
    
    	WriteInt(value, BYTE_LENGTH)
    
    End Method

	'Read an 8-bit byte from the stream.
	Method ReadByte:Int()
	
		Return ReadInt(BYTE_LENGTH)
		
	End Method		
	
	'Write a signed Int with the specified number of bits.
    '<p>The value written must range from 0..2**bitCount. value
    'is treated as If it is masked against (2**bitCount - 1).</p>	
    Method WriteInt:Void(value:Int, bitCount:Int)
    
    	If bitCount < 32 Then
    		If value < 0 Then
    			Throw New NetError("When bitCount is 31 bits or below, WriteInt can only write positive number")
    		End If
    	End If
    
    	For Local i:Int = 0 Until bitCount
    	
    		If ((value Shr i) & 1) = 1 Then
	    		WriteFlag(True)
    		Else		
    			WriteFlag(False)
    		End If
    	
    	End For
    
    End Method

	'Read a signed int with the specified number of bits.
	'@see writeInt
	Method ReadInt:Int(bitCount:Int)
	
		Local b:Int = 0
		
		For Local i:Int = 0 Until bitCount
		
			b |= (Int(ReadFlag()) Shl i)
		
		End For
		
		Return b
		
	End Method
	
	'Write a UTF8 string.
	'<p>The format is a 10 bit length specified in bytes, followed by that many
	'bytes encoding the String in UTF8.</p>
	Method WriteString:Void(s:String)
	
		WriteInt(s.Length, 10)
		For Local i:Int = 0 Until s.Length
			WriteByte(s[i])
		End For
	
	End Method
	
	'Read a string from the bitstream.
	'@see writeString()
	Method ReadString:String()

		Local lenInBytes:Int = ReadInt(10)
		Local ints:Int[] = New Int[lenInBytes]

		For Local i:Int = 0 Until lenInBytes
			ints[i] = ReadByte()
		End For
		
		Return String.FromChars(ints)
	
	End Method

	'Get number of bits required to encode values from 0..max.
	'@param max The maximum value To be able To be encoded.
	'@Return Bitcount required To encode max value.
	Method GetBitCountForRange:Int(max:Int)

		Local count:Int = 0
		
		'Unfortunately this is a bug with this method... and requires this special
		'case (same issue with the old method log calculation)
		If max = 1 Then
			Return 1
		End If
			
		max -= 1
		While (max Shr count > 0)
			count += 1
		End While
		
		Return count

	End Method
	
	'Write an integer value that can range from min to max inclusive. Calculates
	'required number of bits automatically. 
	Method WriteRangedInt:Void(v:Int, min:Int, max:Int) 
	
		Local range:Int = max - min + 1
		Local bitCount:Int = GetBitCountForRange(range)
	
		WriteInt(v - min, bitCount)
	
	End Method
	
	'Read an integer that can range from min To max inclusive. Calculates required
	'number of bits automatically.
	Method ReadRangedInt:Int(min:Int, max:Int) 
	
		Local range:Int = max - min + 1
		Local bitCount:Int = GetBitCountForRange(range)
	
		Local res:Int = ReadInt(bitCount) + min
		
		If res < min Then
            Throw New NetError("Read int that was below range! (" + res + " < " + min + ")")
		Else If res > max Then
            Throw New NetError("Read int that was above range! (" + res + " > " + max + ")")
		End If
		
		Return res		
	
	End Method

	'Write a float ranging from 0..1 inclusive encoded into the specified number
	'of bits.
	Method WriteFloat:Void(value:Float, bitCount:Int)
	
		If value >= 0.0 And value <= 1.0 Then
			'Good everything is fine as long as the float is 0..1 inclusive	
			WriteInt(Int(value * ((1 Shl bitCount) - 1)), bitCount)
		Else
   			Throw New NetError("WriteFloat can only write value from 0..1 inclusive.")
    	End If
    	
	End Method
	
	'Read a float ranged from 0 to 1 inclusive encoded into the specified number of bits.
	Method ReadFloat:Float(bitCount:Int)
	
		Return Float(ReadInt(bitCount)) / Float((1 Shl bitCount) - 1)
	
	End Method

	Method IsEof:Bool()
	
		If currentBit >= totalBits Then
			Return True
		End If
		
		Return False
	
	End Method
	
	Method Reset:Void()
	
		currentBit = 0
	
	End Method

	'Position in the bit stream at which the next read or write will occur.
	'Reading or writing increments this position.
	Method currentPosition:Int()

		Return currentBit

	End Method
      
	Method currentPosition:Void(pos:Int)

		If pos < 0 Or pos >= totalBits Then
			Throw NetError("Out of bounds!")
		End If
         
		currentBit = pos

	End Method
      
	'How many bits of space left?
	Method remainingBits:Int()
         Return totalBits - currentBit
	End Method
      
	'Get a reference To a ByteArray containing this BitStream's data.
	Method getByteArray:Int[]()
         Return bits
	End Method
      
	'Convenience Property To allow a NetStringCache To be associated with a
	'BitStream; the BitStream doesn't use it itself.
	Method stringCache:Void(sc:NetStringCache)
		_stringCache = sc
	End Method
      
	Method stringCache:NetStringCache()
		Return _stringCache
	End Method
      
	'Read a byte, check that it has the expected value, And Throw an exception with message If it does Not.
	Method assertByte:Void(message:String, expectedByte:Int)
		Print "Checking assertion byte at " + currentPosition
         
		Local b:Int = ReadByte()
		If b <> expectedByte Then
			Throw New NetError("Mismatch: " + message + " (" + b + " != " + expectedByte + ")")
		End If
	End Method

End Class

Function TestReadBit:Void()

	Local data:Int[] = [1, -128]
	Local bs:BitStream = New BitStream(data)
	
	Print "First bit we read should be true!"
	Print "First Bit: " + Int(bs.ReadFlag())
	Print "Next 14 Bits should be false."
	For Local i:Int = 0 Until 14
		Print i + " Bit: " + Int(bs.ReadFlag())
	End For
	Print "IsEof: " + Int(bs.IsEof())
	Print "Last bit we read should be true!"
	Print "Last Bit: " + Int(bs.ReadFlag())
	Print "We should be EOS after reading all 16 bits we put in."
	Print "IsEof: " + Int(bs.IsEof())
		
End Function
         
Function TestReadByte:Void()

	Local data:Int[] = [34, 209]
	
	Local bs:BitStream = New BitStream(data)
	
	Print "Byte 1 should be 34, and it is " + bs.ReadByte()
	Print "Byte 2 should be 209, and it is " + bs.ReadByte()
	Print "IsEof: " + Int(bs.IsEof())	 

End Function

Function TestReadWriteBits:Void()

	Local bs:BitStream = New BitStream(1)
	
	bs.WriteFlag(True)
	bs.WriteFlag(False)
	bs.WriteFlag(True)
	bs.WriteFlag(True)
	
	bs.Reset()
	
	Print "First Bit is true, and it is " + Int(bs.ReadFlag())
	Print "Second Bit is false, and it is " + Int(bs.ReadFlag())
	Print "Third Bit is true, and it is " + Int(bs.ReadFlag())
	Print "Fourth Bit is true, and it is " + Int(bs.ReadFlag())

End Function

Function TestReadWriteBytes:Void()

	Local bs:BitStream = New BitStream(4)
	
	bs.WriteByte($DE)
	bs.WriteByte($AD)
	bs.WriteByte($BA)
	bs.WriteByte($BE)
	
	bs.Reset()
	
	Print "First byte is " + $DE + ", and it is " + bs.ReadByte()
	Print "Second byte is " + $AD + " and it is " + bs.ReadByte()
	Print "Third byte is " + $BA + " and it is " + bs.ReadByte()
	Print "Fourth byte is " + $BE + ", and it is " + bs.ReadByte()
	
	Print "IsEof: " + Int(bs.IsEof())

End Function
         
Function TestMixedReadWrite:Void()

	Local bs:BitStream = New BitStream(5)
	
	bs.WriteFlag(True)
	bs.WriteByte($AB)
	bs.WriteByte($CD)
	bs.WriteFlag(False)
	bs.WriteByte($EF)
	bs.WriteByte($00)
	bs.WriteFlag(True)
	
	bs.Reset()
	
	Print "First bit should be true, and it is " + Int(bs.ReadFlag())
	Print "First byte is " + $AB + ", and it is " + bs.ReadByte()
	Print "Second byte is " + $CD + " and it is " + bs.ReadByte()
	Print "Middle bit should be false, and it is " + Int(bs.ReadFlag())
	Print "Third byte is " + $EF + " and it is " + bs.ReadByte()
	Print "Fourth byte is " + $00 + ", and it is " + bs.ReadByte()
	Print "Last bit should be true, and it is " + Int(bs.ReadFlag())

End Function

Function TestStringReadWrite:Void()

	Local test1:String = "Hey there I am a string"
	Local test2:String = "Another string"
	
	Local bs:BitStream = New BitStream(64)
	
	bs.WriteString(test1)
	bs.WriteFlag(True)
	bs.WriteFlag(False)
	bs.WriteString(test2)
	bs.WriteByte(23)
	
	bs.Reset()
	
	Print test1 + " = " + bs.ReadString()
	Print "This bit should be true, and it is " + Int(bs.ReadFlag())
	Print "This bit should be false, and it is " + Int(bs.ReadFlag())
	Print test2 + " = " + bs.ReadString()
	Print "This byte should be 23, and it is " + bs.ReadByte()

End Function            
         
Function TestRangedReadWrite:Void()

	Local test1:String = "Hey there I am a string"
	Local test2:String = "Another string"
	
	Local bs:BitStream = New BitStream(64)
	
	bs.WriteRangedInt(5,  5, 25)
	bs.WriteRangedInt(10, 5, 25)
	bs.WriteRangedInt(25, 5, 25)
         
	bs.WriteRangedInt(0,    0, 1024)
	bs.WriteRangedInt(512,  0, 1024)
	bs.WriteRangedInt(1023, 0, 1024)
   
	bs.Reset()
	
	Print "The correct number is 5, and it is " + bs.ReadRangedInt(5, 25)
	Print "The correct number is 10, and it is " + bs.ReadRangedInt(5, 25)
	Print "The correct number is 25, and it is " + bs.ReadRangedInt(5, 25)
         
	Print "The correct number is 0, and it is " + bs.ReadRangedInt(0, 1024)
	Print "The correct number is 512, and it is " + bs.ReadRangedInt(0, 1024)
	Print "The correct number is 1023, and it is " + bs.ReadRangedInt(0, 1024)

End Function

Function TestFloatReadWrite:Void()

	Local bs:BitStream = New BitStream(128)
         
	'Determining the exact decimation that will occur is hard, so
	'instead we'll estimate acceptable error and fail if we exceed
	'that.
	'
	'(Note: simply duplicating the decimation that happens in the
	'writeFloat isn't a suitable test; we need an independent test.)
         
	For Local bitCount:Int = 2 To 30

		'Figure the acceptable error at this bit count.
		Local acceptableError:Float = 1.0 / Float(((1 Shl bitCount)-1))
            
		'We choose a hundred random numbers, encode, decode, and validate them.
		For Local i:Int = 0 Until 100
			Local randNum:Float = Rnd() 'Random number from 0 .. 1
               
			bs.Reset()
			bs.WriteFloat(randNum, bitCount)
   
			bs.Reset()
			Local result:Float = bs.ReadFloat(bitCount)
   
			If Abs(randNum - result) > acceptableError Then
				Print "FAIL - Exceeded acceptable error (randNum=" + randNum + ", result=" + result +
                      ", error=" + Abs(randNum - result) + ", acceptableError=" + acceptableError
			End If
		End For
	End For
	
	Print "Finish Float test"

End Function

Function AssertTrue:Void(b:Bool)

	If b = False Then
		Print "FAIL - should be True!"
	End If

End Function

Function AssertFalse:Void(b:Bool)

	If b = True Then
		Print "FAIL - should be False!"
	End If

End Function

Function AssertEquals:Void(v1:Int, v2:Int)

	If v1 <> v2 Then
		Print "FAIL - value is not the same! v1 = " + v1 + " <> v2 = " + v2
	End If

End Function

Function AssertEquals:Void(v1:String, v2:String)

	If v1 <> v2 Then
		Print "FAIL - value is not the same! v1 = " + v1 + " <> v2 = " + v2
	End If

End Function

Function TestIntReadWrite:Void()

	Local bs:BitStream = New BitStream(128)
    
	#rem
    Print "$7FFFFFFF = " + $7FFFFFFF
         
	bs.Reset()
	bs.WriteInt(0, 32)
	bs.WriteInt(-1, 32)
	bs.WriteInt(-2, 32)
	bs.WriteInt($7FFFFFFF, 32)
	bs.WriteInt($80000000, 32)
	bs.Reset()
	AssertEquals(bs.ReadInt(32), 0)
	AssertEquals(bs.ReadInt(32), -1)
	AssertEquals(bs.ReadInt(32), -2)
	AssertEquals(bs.ReadInt(32), $7FFFFFFF)
	AssertEquals(bs.ReadInt(32), $80000000)
	#End
	

	'Test smaller bit counts by checking every value.
	'Here we check everything from 1 to 8 bits.
	For Local curCount:Int = 0 To 8

		Local maxVal:Int = (1 Shl curCount) - 1

		For Local curVal:Int = 1 To maxVal

			'Write some test data.
			bs.Reset()
			bs.WriteFlag(True)
			bs.WriteFlag(False)
			bs.WriteInt(curVal, curCount)
			bs.WriteByte($13)
               
			'Read it back.
			bs.Reset()
			AssertTrue(bs.ReadFlag())
			AssertFalse(bs.ReadFlag())
			AssertEquals(bs.ReadInt(curCount), curVal)
			AssertEquals(bs.ReadByte(), $13)

		End For

	End For
	         
	'For higher bit counts, we run a hundred random numbers through each count.
	For Local curCount:Int = 9 To 32

		Local maxVal:Int = (1 Shl curCount) - 1
		If curCount = 31 Then
			maxVal = $7FFFFFFF
		End If
		
		Print "curCount: " + curCount
		Print "maxVal: " + maxVal

		For Local trial:Int = 0 Until 100

			'Generate a random value.
			Local randVal:Int = Int(Rnd() * maxVal)
			'Print "randVal: " + randVal
               
			'Write the data out. We also write zero And max To be sure they
			'encode ok.
			bs.Reset()
			bs.WriteByte($FF)
			bs.WriteInt(randVal, curCount)
			bs.WriteInt(0, curCount)
			bs.WriteInt(maxVal, curCount)
			bs.WriteFlag(True)
               
			'And read it back...
			bs.Reset()
			AssertEquals(bs.ReadByte(), $FF)
			AssertEquals(bs.ReadInt(curCount), randVal)
			AssertEquals(bs.ReadInt(curCount), 0)
			AssertEquals(bs.ReadInt(curCount), maxVal)
			AssertTrue(bs.ReadFlag())
			
		End For

	End For
	
End Function

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
			Local startRead:Int = bs.currentPosition
            
			' Read the ID we're overwriting.
			Local newId:Int = bs.ReadInt(stringRefBitCount)
            
			' And the String.
			readString = bs.ReadString()
            
			bytesRead += (bs.currentPosition / startRead) / 8.0
            
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
		End If
         
		' Note the ID.
		Local foundId:Int = ce.id         
         
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

End Class

Function TestNetStringCache:Void()
	
	'Make quite a large BitStream as we'll be writing loads of data.
	Local bs:BitStream = New BitStream(1024*1024)

	'First, let's test that writing a single string multiple times
	'is working correctly.
		Local nsc:NetStringCache = New NetStringCache()

		For Local i:Int = 0 Until 4096
			nsc.Write(bs, "hello world how are you?");
		End For
            
		'At this time, the bitstream should be approximately
		'10bits * 4096 long (plus overhead For the first time,
		'when we encode the String). If we hit 8192 bytes we
		'have Not operated properly, as that's 16bits per entry
		'And we should only be using 10 plus a little bit on
		'average.
		AssertTrue(bs.currentPosition < 8192*8);
            
		'Ok, great - now let's read back.
		bs.Reset();
		For Local i:Int = 0 Until 4096
			AssertEquals(nsc.Read(bs), "hello world how are you?");
		End For

		nsc.ReportStatistics()

	'Reset the BS so we can do another test.
	bs.Reset();
         
	'Great - now let's force it to purge stuff, so we can confirm
	'that A) the LRU logic isn't totally broken and B) we're meeting
	'our expectations on bit usage.

		nsc = New NetStringCache();

		'Write two thousand unique values, Then quite a few of the same thing
		For Local i:Int = 0 Until 2048
			nsc.Write(bs, "#" + i)
		End For
            
		For Local i:Int = 0 Until 4096
			nsc.Write(bs, "i am long but I will be cached as I am always the same.");
		End For
            
		'We should see a fairly low size of the String.
		'Working conservatively, we should have 
		'4095*2 + 2049 * (2 + 4)  = 20484 bytes in the stream.
		AssertTrue(bs.currentPosition < 20484*8);
            
		'Do the readback.
		bs.Reset();
            
		For Local i:Int = 0 Until 2048
			AssertEquals(nsc.Read(bs), "#" + i);
		End For
            
		For Local i:Int = 0 Until 4096
			AssertEquals(nsc.Read(bs), "i am long but I will be cached as I am always the same.");
		End For
		
		nsc.ReportStatistics()

End Function

'----------------------------------------------------------------------------------------------------------------------------
'----------------------------------------------------------------------------------------------------------------------------

' Interface for a NetElement.
Interface INetElement

	Method GetName:String()
	Method SetName:Void(v:String)

	' Write this NetElement's current state to a BitStream.
	Method Serialize:Void(bs:BitStream)

	' Read state from a BitStream And store it in this NetElement.
	Method Deserialize:Void(bs:BitStream)
      
	' After instantiation, access any attributes from the XML describing
	' this NetElement.
	Method InitFromXML:Void(xml:XMLElement)
      
	' Make a deep copy of this NetElement. Used when initializing a New
	' NetRoot.
	Method DeepCopy:INetElement()

End Interface

' Interface for a NetElement that exposes String data.
Interface IStringNetElement Extends INetElement
	Method GetValue:String()
	Method SetValue:Void(v:String)     
End Interface

' Interface For a NetElement that exposes integer data.
Interface IIntegerNetElement Extends INetElement
	Method GetValue:Int()
	Method SetValue:Void(v:Int)
End Interface

' Interface For a NetElement that exposes floating point data.
Interface IFloatNetElement Extends INetElement
	Method GetValue:Float()
	Method SetValue:Void(v:Float)
End Interface

' Interface For a NetElement that exposes boolean data.
Interface IBooleanNetElement Extends INetElement
	Method GetValue:Bool()
	Method SetValue:Void(v:Bool)
End Interface
   
' Interface For something that can contain NetElements.
Interface INetElementContainer

	' Add a NetElement To this container.
	Method AddElement:Void(e:INetElement)
      
	' Get an element by name. Searches all child containers as well.
	Method GetElement:INetElement(name:String)
      
	' Get number of NetElements in just this container (Not subcontainers).
	Method GetElementCount:Int()
     
	' Get a NetElement on this container by index.
	Method GetElementByIndex:INetElement(index:Int)

End Interface

' Interface describing the accessors on a NetElement container.
'
' Basically, these methods let you get typed data by name.
Interface IContainerAccessors

	Method GetString:String(name:String)
	Method GetInteger:Int(name:String)
	Method GetFloat:Float(name:String)
	Method GetBoolean:Bool(name:String)
      
	Method SetString:Void(name:String, v:String)
	Method SetInteger:Void(name:String, v:Int)
	Method SetFloat:Void(name:String, v:Float)
	Method SetBoolean:Void(name:String, v:Bool)

End Interface

' A simple String.
Class StringElement Implements IStringNetElement
	Field _name:String
	Field value:String
      
	Method New(n:String = "", v:String = "")
		_name = n;
		value = v;
	End Method

	Method GetName:String()
		Return _name;
	End Method

	Method SetName:Void(v:String)
		_name = v;
	End Method

	Method Serialize:Void(bs:BitStream)
		bs.WriteString(value);
	End Method

	Method Deserialize:Void(bs:BitStream)
		value = bs.ReadString();
	End Method

	Method InitFromXML:Void(xml:XMLElement)
		'value = xml.@value.toString();
		value = xml.GetFirstChildByName("value").Value
	End Method

	Method DeepCopy:INetElement()
		Return New StringElement(_name, value);
	End Method

	Method GetValue:String()
		Return value;
	End Method

	Method SetValue:Void(v:String)
		value = v;
	End Method

End Class

' A String, cached using a NetStringCache.
Class CachedStringElement Implements IStringNetElement

	Field _name:String
	Field value:String
      
	Method New(n:String = "", v:String = "")
		_name = n;
		value = v;
	End Method

	Method GetName:String()
		Return _name;
	End Method

	Method SetName:Void(v:String)
		_name = v;
	End Method
      
	Method Serialize:Void(bs:BitStream)
		bs.stringCache.Write(bs, value);
	End Method

	Method Deserialize:Void(bs:BitStream)
		value = bs.stringCache.Read(bs);
	End Method
      
	Method InitFromXML:Void(xml:XMLElement)
	End Method
      
	Method DeepCopy:INetElement()
		Return New CachedStringElement(_name, value);
	End Method
      
	Method GetValue:String()
		Return value;
	End Method

	Method SetValue:Void(v:String)
		value = v;
	End Method

End Class

' A floating point value that can be encoded with variable precision.
Class FloatElement Implements IFloatNetElement

	Field _name:String
	Field bitCount:Int = 30
	Field value:Float
      
	Method New(n:String = "", bc:Int = 30, v:Float = 0.0)
		_name = n;
		bitCount = bc;
		value = v;
	End Method

	Method GetName:String()
		Return _name;
	End Method

	Method SetName:Void(v:String)
		_name = v;
	End Method

	Method Serialize:Void(bs:BitStream)
		bs.WriteFloat(value, bitCount);
	End Method

	Method Deserialize:Void(bs:BitStream)
		value = bs.ReadFloat(bitCount);
	End Method

	Method InitFromXML:Void(xml:XMLElement)
		bitCount = Int(xml.GetFirstChildByName("bitCount").Value)
	End Method

	Method DeepCopy:INetElement()
		Return New FloatElement(_name, bitCount, value);
	End Method

	Method GetValue:Float()
		Return value;
	End Method

	Method SetValue:Void(v:Float)
		value = v;
	End Method

End Class

' A boolean element that, if true, serializes its children as well.
Class FlagElement Extends NetElementContainer Implements IBooleanNetElement

	Field value:Bool
      
	Method New(n:String = "", v:Bool = False)
		Super.New();
		SetName(n);
		value = v;
	End Method

	Method GetName:String()
		Return Super.GetName()
	End Method
      
	Method SetName:Void(v:String)
		Super.SetName(v)
	End Method

	Method Serialize:Void(bs:BitStream)
		If bs.WriteFlag(value)
			Super.Serialize(bs)
		End If
	End Method

	Method Deserialize:Void(bs:BitStream)
		If value = bs.ReadFlag()
			Super.Deserialize(bs)
		End If
	End Method
      
	Method InitFromXML:Void(xml:XMLElement)
		Super.InitFromXML(xml)
	End Method
	
	Method DeepCopy:INetElement()
		Return Super.DeepCopy()
	End Method

	Method GetValue:Bool()
		Return value;
	End Method
      
	Method SetValue:Void(v:Bool)
		value = v;
	End Method

End Class
   
' Just like FlagElement, but also assigns itself a dirty bit, And participates
' in dirty bit tracking. Used in ghosts.
Class DirtyFlagElement Extends FlagElement Implements IBooleanNetElement, INetElementContainer

	' The index of the dirty bit that corresponds To this flag.
	Field dirtyFlagIndex:Int
      
	Method New(n:String="", v:Bool=False)
		Super.New(n, v)
	End Method

	Method GetName:String()
		Return Super.GetName()
	End Method
      
	Method SetName:Void(v:String)
		Super.SetName(v)
	End Method

	Method Serialize:Void(bs:BitStream)
		Super.Serialize(bs)
	End Method

	Method Deserialize:Void(bs:BitStream)
		Super.Deserialize(bs)
	End Method

	Method InitFromXML:Void(xml:XMLElement)
		Super.InitFromXML(xml)
	End Method

	Method DeepCopy:INetElement()
		Local c:DirtyFlagElement = DirtyFlagElement(Super.DeepCopy())
		c.dirtyFlagIndex = dirtyFlagIndex;
		c.value = value;
		Return c;
	End Method

	Method GetValue:Bool()
		Return Super.GetValue()
	End Method
      
	Method SetValue:Void(v:Bool)
		Super.SetValue(v)
	End Method
	
	Method AddElement:Void(e:INetElement)
		Super.AddElement(e)
	End Method
      
	Method GetElement:INetElement(name:String)
		Return Super.GetElement(name)
	End Method	

	Method GetElementCount:Int()
		Return Super.GetElementCount()
	End Method

	Method GetElementByIndex:INetElement(index:Int)
		Return Super.GetElementByIndex(index)
	End Method

End Class

' An integer value that can range from min To max.
Class RangedIntElement Implements IIntegerNetElement

	Field _name:String
	Field min:Int
	Field max:Int
	Field value:Int
      
	Method New(n:String = "", mn:Int = 0, mx:Int = 100, v:Int = 1)
         _name = n;
         min = mn;
         max = mx;
         value = v;   
	End Method

	Method GetName:String()
         Return _name;
	End Method
      
	Method SetName:Void(v:String)
         _name = v;
	End Method
      
	Method Serialize:Void(bs:BitStream)
         bs.WriteRangedInt(value, min, max);
	End Method
      
	Method Deserialize:Void(bs:BitStream)
         value = bs.ReadRangedInt(min, max);
	End Method
      
	Method InitFromXML:Void(xml:XMLElement)
         'min = xml.@min;
         'max = xml.@max;
         min = Int(xml.GetFirstChildByName("min").Value)
         max = Int(xml.GetFirstChildByName("max").Value)
	End Method
      
	Method DeepCopy:INetElement()
         Return New RangedIntElement(_name, min, max, value);
	End Method

	Method GetValue:Int()
		Return value;
	End Method
      
	Method SetValue:Void(v:Int)
		value = v;
	End Method

End Class

' Base Class For NetElements that can contain other NetElements.
Class NetElementContainer Implements INetElement, INetElementContainer, IContainerAccessors

	Field name:String
	Field elementList:List<INetElement> = New List<INetElement>()

	Method GetName:String()
		Return name
	End Method
      
	Method SetName:Void(v:String)
		name = v;
	End Method
      
	Method Serialize:Void(bs:BitStream)
		For Local e:INetElement = Eachin elementList
            e.Serialize(bs);
		End For
	End Method
      
	Method Deserialize:Void(bs:BitStream)
		For Local e:INetElement = Eachin elementList
			e.Deserialize(bs);
		End For
	End Method
      
	Method InitFromXML:Void(xml:XMLElement)
	End Method
      
	Method DeepCopy:INetElement()

		' Get our Class And make a New instance of it. This allows us
		' To work properly with subclasses.
		
		
		Local cinfo:ClassInfo = GetClass(Self)
		
		'Local thisClassName:String = GetQualifiedClassName(e);
		'If Not thisClassName
		'	Throw TError("Somehow we don't know about our own class's name!");
		'End If
         
		'Local thisClass:Object = GetClass(thisClassName)
		'If Not thisClass
		'	Throw TError("Somehow we don't know about our own class!");
		'End If

		'Local thisCopy:NetElementContainer = NetElementContainer(thisClass.NewInstance())
		Local thisCopy:NetElementContainer = NetElementContainer(cinfo.NewInstance())
		If Not thisCopy
			Throw NetError("Somehow we can't instantiate a new version of ourselves.");
		End If
         
		' Actually copy contents.
		thisCopy.SetName(GetName());
		For Local e:INetElement = Eachin elementList
			thisCopy.AddElement(e.DeepCopy());
		End For

		Return thisCopy;
		
	End Method
      
	Method AddElement:Void(e:INetElement)
         elementList.AddFirst(e);
	End Method
      
	Method GetElement:INetElement(name:String)

		For Local curNE:INetElement = Eachin elementList
			' Check this element For a match.
			'Local curNE:INetElement = INetElement(elementList[i])
            
			If curNE.GetName().ToLower() = name.ToLower()
				Return curNE;
			End If

			' Or maybe it's a container?
			Local curNEC:INetElementContainer = INetElementContainer(curNE);
            If Not curNEC
				Continue
			End If
               
			' Great, ask it For a match.
			Local curNECChild:INetElement = curNEC.GetElement(name);
            If curNECChild
               Return curNECChild
			End If

		End For
		
		Return Null;

	End Method

	Method GetElementCount:Int()
		Return elementList.Count();
	End Method
      
	Method GetElementByIndex:INetElement(index:Int)

		Local i:Int = 0
		
		For Local e:INetElement = Eachin elementList
			If i = index Then
				Return e
			End If
			i += 1
		End For

	End Method

	Method GetString:String(name:String)
		Local netElement:IStringNetElement = IStringNetElement(GetElement(name))
		Return netElement.GetValue();
	End Method
      
	Method GetInteger:Int(name:String)
		Local netElement:IIntegerNetElement = IIntegerNetElement(GetElement(name))
		Return netElement.GetValue();
	End Method
      
	Method GetFloat:Float(name:String)
		Local netElement:IFloatNetElement = IFloatNetElement(GetElement(name))
		Return netElement.GetValue();
	End Method
      
	Method GetBoolean:Bool(name:String)
		Local netElement:IBooleanNetElement = IBooleanNetElement(GetElement(name))
		Return netElement.GetValue();
	End Method

	Method SetString:Void(name:String, v:String)
		Local netElement:IStringNetElement = IStringNetElement(GetElement(name))
		netElement.SetValue(v);
	End Method
      
	Method SetInteger:Void(name:String, v:Int)
		Local netElement:IIntegerNetElement = IIntegerNetElement(GetElement(name))
		netElement.SetValue(v);
	End Method
      
	Method SetFloat:Void(name:String, v:Float)
		Local netElement:IFloatNetElement = IFloatNetElement(GetElement(name))
		netElement.SetValue(v);
	End Method
      
	Method SetBoolean:Void(name:String, v:Bool)
		Local netElement:IBooleanNetElement = IBooleanNetElement(GetElement(name))
		netElement.SetValue(v);
	End Method

End Class

' NetRoot wraps an XML bitstream protocol description to simplify 
' serializing/deserializing your data.
' 
' Basically, you describe the protocol you want in a simple XML syntax. Then
' the XML description is used To construct a tree of NetElement subclasses,
' which do the actual serialization/deserialization.
' 
' Elements in the tree are named, and can have their values set or retrieved
' by those names. So you can have an element named "id" and set it to 12.
' But because the protocol is defined in XML, you can tweak how many bits
' are used, Or wrap it in a flag so that the data is only sent If the flag
' is true.
' 
' The NetElements system also interfaces with Ghosts. Using the dirtyFlag
' tag, you can group like fields together. If any one of them changes in the
' ghosted object, then all are updated.

Class NetRoot Extends NetElementContainer Implements INetElement, INetElementContainer

	Field smRoots:StringMap<NetRoot> = New StringMap<NetRoot>()
	Field xmlReader:XMLParser = New XMLParser
      
	Method GetName:String()
		Return Super.GetName()
	End Method
      
	Method SetName:Void(v:String)
		Super.SetName(v)
	End Method

	Method Serialize:Void(bs:BitStream)
		Super.Serialize(bs)
	End Method

	Method Deserialize:Void(bs:BitStream)
		Super.Deserialize(bs)
	End Method
      
	Method InitFromXML:Void(xml:XMLElement)
		Super.InitFromXML(xml)
	End Method
      
	Method DeepCopy:INetElement()
		Return Super.DeepCopy()
	End Method

	Method AddElement:Void(e:INetElement)
		Super.AddElement(e)
	End Method
      
	Method GetElement:INetElement(name:String)
		Return Super.GetElement(name)
	End Method	

	Method GetElementCount:Int()
		Return Super.GetElementCount()
	End Method

	Method GetElementByIndex:INetElement(index:Int)
		Return Super.GetElementByIndex(index)
	End Method

	' Parse XML descriptions of protocol And store by name.
	Method LoadNetProtocol:Void(libraryText:String)

		'Local parsedData:XML = New XML(libraryText);
		'For Local e:XML = Eachin parsedData
		'	smRoots.Add(e.name.ToString().ToLowerCase(), CreateFromXML(e.ToString()))
		'End For

		Local doc:XMLDocument = xmlReader.ParseString(libraryText)
		Local rootElement:XMLElement = doc.Root

		For Local xml:XMLElement = Eachin rootElement.Children
			Print "name = " + xml.GetFirstChildByName("name").Value
		End For
		
	End Method
	      
	' Fetch a NetRoot from a named item in the library. This makes a deep
	' copy, so serialization state is not shared between objects.
	Method GetByName:NetRoot(name:String)

		If Not smRoots
			Return Null
		End If

		Local r:NetRoot = smRoots.Get(name.ToLower())

		If Not r
			Return Null
		End If

		Return NetRoot(r.DeepCopy())

	End Method
      
	' Create a NetRoot directly from an XML description.
	Method CreateFromXML:NetRoot(x:String)
		'Local nr:NetRoot = New NetRoot();
		'ParseFromXML(parsedData, nr);
		'nr.setName(parsedData.@name.toString());
		'Return nr;

		Local doc:XMLDocument = xmlReader.ParseString(x)
		Local rootElement:XMLElement = doc.Root

		For Local xml:XMLElement = Eachin rootElement.Children
			Print "name = " + xml.GetFirstChildByName("name").Value
		End For
	End Method
      
	Method ParseFromXML:Void(x:XMLElement, container:INetElementContainer)
	
		For Local e:XMLElement = Eachin x.Children
			Local ne:INetElement = Null;
            
			' Identify the kind of element we need To add...
			Local newElemName:String  = e.GetFirstChildByName("name").Value

			If newElemName.ToLower() = "string"

				ne = New StringElement();

			Else If newElemName.ToLower() = "cachedstring"

				ne = New CachedStringElement();

			Else If newElemName.ToLower() = "float"

				ne = New FloatElement();

			Else If newElemName.ToLower() = "flag"

				ne = New FlagElement();
				ParseFromXML(e, INetElementContainer(ne));

			Else If newElemName.ToLower() = "dirtyflag"

				ne = New DirtyFlagElement();
				ParseFromXML(e, INetElementContainer(ne));

			Else If newElemName.ToLower() = "rangedint"

				ne = New RangedIntElement();

			Else

				Throw New NetError("Unknown tag " + newElemName);

			End If
            
			' Set the name
			ne.SetName(e.GetFirstChildByName("name").Value);
            
			' Let it parse itself...
			ne.InitFromXML(e);
            
			' Add it To the root...
			container.AddElement(ne);            

		End For

	End Method

	' Map dirty bit indices To a DirtyFlagElement.
	Field bitToDirtyFlagMap:List<DirtyFlagElement> = Null
      
	' Map INetElements to their dirty flags.
	Field elementsToDirtyFlagsMap:StringMap<Int> = Null
      
	Method UpdateDirtyFlagMap_r:Void(item:INetElement, activeDirtyFlags:Int)

		' Is this one a dirty flag?
		Local curFlag:DirtyFlagElement = DirtyFlagElement(item)

		If curFlag
		
			' Assign an ID.
			curFlag.dirtyFlagIndex = bitToDirtyFlagMap.Count();
			bitToDirtyFlagMap.AddFirst(curFlag);
            
			' Note the New bit in our parameter.
			activeDirtyFlags |= 1 Shl curFlag.dirtyFlagIndex;
			
		End If

		' Note what flags this element is affected by.
		elementsToDirtyFlagsMap.Set(item.GetName(), activeDirtyFlags)
         
		' Process children.
		Local curContainer:INetElementContainer = INetElementContainer(item)
		If Not curContainer
            Return
		End If

		For Local i:Int = 0 Until curContainer.GetElementCount()
            UpdateDirtyFlagMap_r(curContainer.GetElementByIndex(i), activeDirtyFlags);
		End For

	End Method
      
	Method UpdateDirtyFlagMap:Void()

		' Wipe existing data.
		bitToDirtyFlagMap = New List<DirtyFlagElement>()
		'elementsToDirtyFlagsMap = New Dictionary(True)
		elementsToDirtyFlagsMap = New StringMap<Int>()
         
		' Traverse the whole tree And assign dirty flags.
		UpdateDirtyFlagMap_r(Self, 0);

	End Method

	' An element may have one Or more dirty bits that correspond To it.
	' For instance, it might nested two deep in DirtyFlags. So this 
	' returns whatever bits need To be set when it changes For it To
	' get serialized.
	Method GetElementDirtyBits:Int(name:String)

		If Not bitToDirtyFlagMap
			UpdateDirtyFlagMap()
		End If
         
		'Return elementsToDirtyFlagsMap[getElement(name)];
		Return elementsToDirtyFlagsMap.Get(name)
	End Method
      
	' Tells you the name of the DirtyFlag element that corresponds to
	' the specified bit. Notice that bit is a log2 parameter, ie the 4th
	' bit would be 0x8 from GetElementDirtyBits but 4 here.
	Method GetDirtyBitElement:DirtyFlagElement(bit:Int)

		If Not bitToDirtyFlagMap
			UpdateDirtyFlagMap()
		End If

		'Return bitToDirtyFlagMap[bit];
		'TODO
		
		Local i:Int = 0
		For Local e:DirtyFlagElement = Eachin bitToDirtyFlagMap
			If i = bit
				Return e
			End If
			i += 1
		End For

		Return Null
		
	End Method
      
	' Set the state of all the DirtyFlag nodes in this root based on 
	' dirty bits.
	Method SetDirtyState:Void(v:Int)

		If Not bitToDirtyFlagMap
			UpdateDirtyFlagMap();
		End If

		Local i:Int = 0
		For Local e:DirtyFlagElement = Eachin bitToDirtyFlagMap
			e.value = Bool((1 Shl i) & v);'
			i += 1
		End For
		
	End Method

End Class

Function TestNetElements:Void()

	' Set up the serialization structure.
	Local nr:NetRoot = New NetRoot();
	nr.AddElement(New StringElement("chatText", "hey there world"));
	nr.AddElement(New FloatElement("chatVolume", 14, 0.90001));
         
	' Write out To a stream. 
	Local bs:BitStream = New BitStream(64);
   
	Try
		nr.Serialize(bs);         
	Catch e:EOFError
		Error e.ToString()
	End Try   
         
	' Change values.
	nr.SetString("chatText", "filler");
	nr.SetFloat("chatVolume", 0.0);
         
	' Read back.
	bs.Reset();
	Try
		nr.Deserialize(bs);
	Catch e:EOFError
		Error e.ToString()
	End Try

	' Validate results.
	Print "chatText: " + nr.GetString("chatText")
	AssertEquals(nr.GetString("chatText"), "hey there world");
         
	Local floatVal:Float = nr.GetFloat("chatVolume");
	Print "Abs: " + Abs(floatVal - 0.90001)
	If Abs(floatVal - 0.90001) > 0.01
		Error "Did not get back our expected float."
	End If

End Function

      
Function TestFlagElement:Void()

	DebugStop()

	' Set up serialization 
	Local nr:NetRoot = New NetRoot();
	nr.AddElement(New FlagElement("flag", True));
	nr.AddElement(New StringElement("string2", "end"));

	Local fe:FlagElement = FlagElement(nr.GetElement("flag"));
	fe.AddElement(New StringElement("string", "hey there"));
         
	' Blast some permutations out To a BitStream.
	Local bs:BitStream = New BitStream(256);
         
	' Write with flag set To True...
	Try
		nr.Serialize(bs);
	Catch e:EOFError
		Error e.ToString()
	End Try
         
	' Write it with flag set To False.
	nr.SetBoolean("flag", False);

	Try
		nr.Serialize(bs);
	Catch e:EOFError
		Error e.ToString()
	End Try

	' Ok, now read back the first one.
	bs.Reset();
         
	nr.SetString("string2", "bad");
	nr.SetString("string", "bad2");
         
	Try
		nr.Deserialize(bs);
	Catch e:EOFError
		Error e.ToString()
	End Try
         
	' Both strings should change in this Case...
	AssertEquals(nr.GetString("string2"), "end");
	AssertTrue(nr.GetBoolean("flag"));
	AssertEquals(nr.GetString("string"), "hey there");

	' Set more state To garbage...
	nr.SetString("string2", "bad");
	nr.SetString("string", "bad2");
         
	' Now, read back the second one.
	Try
		nr.Deserialize(bs);
	Catch e:EOFError
		Error e.ToString()
	End Try

	' And check state...
	AssertEquals(nr.GetString("string2"), "end");
	AssertFalse(nr.GetBoolean("flag"));
	AssertEquals(nr.GetString("string"), "bad2");

End Function

#rem
Function testXML:Void()

	Local eventXML:String = "" +
		"<library>" +
		"	<event>" +
		"		<name>chat</name>" +
		"		<string>" +
		"			<name>message</name>" +
		"		<string>" +	
		"	</event>" +
		"	<event>" +
		"		<name>circle</name>" +
		"		<rangedInt>" +
		"			<name>x</name>" +
		"			<min>0</min>" +
		"			<max>1000</max>" +
		"		</rangedInt>" +
		"		<rangedInt>" +
		"			<name>y</name>" +
		"			<min>0</min>" +
		"			<max>1000</max>" +
		"		</rangedInt>" +
		"	</event>" +
		"	<ghost>" +
		"		<name>CircleGhost</name>" +
		"		<dirtyFlag>" +
		"			<name>flag1</name>" +
		"			<rangedInt>" +
		"				<name>x</name>" +
		"				<min>0</min>" +
		"				<max>1000</max>" +
		"			</rangedInt>" +
		"			<rangedInt>" +
		"				<name>y</name>" +
		"				<min>0</min>" +
		"				<max>1000</max>" +
		"			</rangedInt>" +
		"			<flag>" +
		"				<name>state</name>" +
		"			</flag>" +
		"		</dirtyFlag>" +
		"	</ghost>" +
		"</library>"
	'NetRoot.loadNetProtocol(eventXML)

	Local testXml:String = "" +
		"<root>" + 
		"	<string>" + 
		"		<name>stringItem</name>" +
		"	</string>" +
		"	<float>" +
		"		<name>floatItem</name>" +
		"		<bitCount>8</bitCount>" +
		"	</float>" +
		"	<flag>" +
		"		<name>flagItem</name>" +
		"		<float>" +
		"			<name>floatItem2</name>" +
		"			<bitCount>16</bitcount>" +
		"		</float>" +
		"	</flag>" +
		"</root>"
         
	' Note we test the deep copy here as well.
	Local nr:NetRoot = Null 'NetRoot(NetRoot.CreateFromXML(testXml).DeepCopy())
         
	' Make sure elements are of correct types And their properties are right.
	If nr.GetElement("stringItem") <> "StringElement"
		Print "stringItem <> StringElement"
		Print "stringItem = " + nr.getElement("stringItem")
		Print "StringElement = " + StringElement
	End If
	If nr.getElement("floatItem") = FloatElement
		Print "floatItem <> FloatElement"
	End If
	AssertEquals((FloatElement(nr.getElement("floatItem"))).bitCount, 8);
         
	If nr.getElement("floatItem2") = FloatElement
		Print "floatItem2 <> FloatElement"
	End If
	AssertEquals((FloatElement(nr.getElement("floatItem2"))).bitCount, 16);

End Function
      
Function testDirtyFlags:Void()

	Local testXml:String =	"" +
		"<root>" +
		"	<dirtyFlag>" +
		"		<name>dirty01</name>" +
		"		<string>" +
		"			<name>stringField1</name>" +
		"		</string>" +
		"		<float>" +
		"			<name>floatItem</name>" +
		"			<bitCount>8</bitcount>" +
		"		</float>" +
		"	</dirtyFlag>" +
		"	<dirtyFlag>" +
		"		<name>dirty02</name>" +
		"		<float>" +
		"			<name>floatItem2</name>" +
		"			<bitCount>16</bitCount>" +
		"		</float>" +
		"		<dirtyFlag>" +
		"			<name>dirty03</name>" +
		"			<string>" +
		"				<name>stringField2</name>" +
		"			</string>" +
		"		</dirtyFlag>" +
		"	</dirtyFlag>" +
		"</root>"
                     
	' Note we test the deep copy here as well.
	Local nr:NetRoot = NetRoot(NetRoot.CreateFromXML(testXml).DeepCopy())
         
	' Ok, let's check the dirty bits for each element. In reality, we do not assume what bits
	' get assigned where, since it's for internal tracking only.
	AssertEquals(nr.GetElementDirtyBits("stringField1"), $1);
	AssertEquals(nr.GetElementDirtyBits("floatItem"), $1);
	AssertEquals(nr.GetElementDirtyBits("floatItem2"), $2);
	AssertEquals(nr.GetElementDirtyBits("stringField2"), $2 | $4);
         
	' Test getting elemeny by id.
	AssertEquals(nr.GetDirtyBitElement(0).GetName(), "dirty01");
	AssertEquals(nr.GetDirtyBitElement(1).GetName(), "dirty02");
	AssertEquals(nr.GetDirtyBitElement(2).GetName(), "dirty03");

	' Set some dirty states And check that the dirty flags are set properly.
	nr.SetDirtyState($0);
	AssertEquals(nr.GetBoolean("dirty01"), False);
	AssertEquals(nr.GetBoolean("dirty02"), False);
	AssertEquals(nr.GetBoolean("dirty03"), False);

	nr.SetDirtyState($1);
	AssertEquals(nr.GetBoolean("dirty01"), True);
	AssertEquals(nr.GetBoolean("dirty02"), False);
	AssertEquals(nr.GetBoolean("dirty03"), False);

	nr.SetDirtyState($1 | $2);
	AssertEquals(nr.GetBoolean("dirty01"), True);
	AssertEquals(nr.GetBoolean("dirty02"), True);
	AssertEquals(nr.GetBoolean("dirty03"), False);

	nr.SetDirtyState($1 | $2 | $4);
	AssertEquals(nr.GetBoolean("dirty01"), True);
	AssertEquals(nr.GetBoolean("dirty02"), True);
	AssertEquals(nr.GetBoolean("dirty03"), True);
         
	nr.SetDirtyState($2 | $4);
	AssertEquals(nr.GetBoolean("dirty01"), False);
	AssertEquals(nr.GetBoolean("dirty02"), True);
	AssertEquals(nr.GetBoolean("dirty03"), True);

End Function
#End

Function Main ()
	
	'New BrickGame
	
	Print "Hello World"
	
	TestReadBit()
	TestReadByte()
	TestReadWriteBits()
	TestReadWriteBytes()
	TestMixedReadWrite()
	TestStringReadWrite()
	TestRangedReadWrite()
	TestFloatReadWrite()
	TestIntReadWrite()

	TestNetStringCache()

	TestNetElements()
	TestFlagElement()	
	
	For Local i:Int = 0 Until 8
	
		Print ""
	
	End For
	
End Function

